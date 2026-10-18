"""Deterministic multi-session regression for pending identity reassignment."""
import json
import os
import subprocess
import tempfile
import time


def check_access_concurrency(psql, connection):
    sessions = []
    environment = dict(os.environ, PGCLIENTENCODING="UTF8")

    def command(*arguments):
        return [psql, "-X", "--no-password", "-qAt", "-v", "ON_ERROR_STOP=1",
                "-d", connection, *arguments]

    def query(sql):
        result = subprocess.run(command(), input=sql, capture_output=True,
                                text=True, encoding="utf-8", env=environment, timeout=15)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result.stdout.strip()

    class Session:
        def __init__(self, name, sql):
            self.name = name
            self.output = tempfile.TemporaryFile(mode="w+b")
            self.process = subprocess.Popen(
                command(), stdin=subprocess.PIPE, stdout=self.output,
                stderr=self.output, text=True, encoding="utf-8",
                env=dict(environment, PGAPPNAME=name))
            sessions.append(self)
            self.send(sql)

        def send(self, sql):
            self.process.stdin.write(sql + "\n")
            self.process.stdin.flush()

        def state(self):
            if self.process.poll() is not None:
                self.output.seek(0)
                raise AssertionError("Session exited unexpectedly: " + self.name + "\n" +
                                     self.output.read().decode("utf-8", errors="replace"))
            raw = query("SELECT row_to_json(s) FROM (SELECT pid,state,wait_event_type,"
                        "pg_blocking_pids(pid) AS blockers FROM pg_stat_activity "
                        f"WHERE datname=current_database() AND application_name='{self.name}') s")
            return json.loads(raw) if raw else None

        def finish(self):
            self.send("COMMIT;\n\\q")
            self.process.wait(timeout=15)
            if self.process.returncode:
                self.output.seek(0)
                raise AssertionError(self.output.read().decode("utf-8", errors="replace"))

    def wait_until(description, predicate):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            result = predicate()
            if result:
                return result
            time.sleep(0.05)
        raise AssertionError("Timed out waiting for " + description)

    admin_uid = "40000000-0000-0000-0000-000000000001"
    old_uid = "40000000-0000-0000-0000-000000000002"
    new_uid = "40000000-0000-0000-0000-000000000003"
    grant_id = "40000000-0000-0000-0000-000000000004"
    scope_id = "40000000-0000-0000-0000-000000000005"
    query(f"""
        INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
        ('{admin_uid}','race-admin@example.test',now()),
        ('{old_uid}','race-a@example.test',now()),
        ('{new_uid}','race-b@example.test',now());
        INSERT INTO private.admin_allowlist VALUES('{admin_uid}');
        INSERT INTO public.congregations(id,name) VALUES('{scope_id}','Synthetic race');
        INSERT INTO public.user_access(id,user_email,role,congregation_id)
        VALUES('{grant_id}','race-a@example.test','Membro da direção da campanha','{scope_id}');
        -- Test-only gate allows the old-target business lock to be observed before
        -- reassignment can finish, without adding hooks to production functions.
        CREATE FUNCTION public.test_reassignment_gate() RETURNS trigger
        LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
          IF NEW.user_email IS DISTINCT FROM OLD.user_email THEN
            PERFORM pg_advisory_xact_lock(711039002);
          END IF;
          RETURN NEW;
        END $$;
        CREATE TRIGGER test_reassignment_gate BEFORE UPDATE ON public.user_access
        FOR EACH ROW EXECUTE FUNCTION public.test_reassignment_gate();
    """)
    try:
        gate = Session("ieadpe_race_gate", "BEGIN; SELECT pg_advisory_xact_lock(711039002);")
        wait_until("reassignment gate", lambda: (gate.state() or {}).get("state") == "idle in transaction")
        binder = Session("ieadpe_race_binder", f"""BEGIN;
            SET LOCAL ROLE authenticated;
            SELECT set_config('request.jwt.claim.sub','{old_uid}',true);
            SELECT public.ieadpe_get_scope();""")
        wait_until("uncommitted verified binding", lambda: (binder.state() or {}).get("state") == "idle in transaction")
        binder_pid = binder.state()["pid"]
        business = Session("ieadpe_race_business", f"""BEGIN;
            SELECT private.lock_access(ARRAY['{old_uid}'::uuid]);""")
        wait_until("business queued behind binding UID lock",
                   lambda: binder_pid in (business.state() or {}).get("blockers", []))
        save = Session("ieadpe_race_save", f"""BEGIN;
            SET LOCAL ROLE authenticated;
            SELECT set_config('request.jwt.claim.sub','{admin_uid}',true);
            SELECT public.ieadpe_save_access('40000000-0000-0000-0000-000000000006',
            '{{"id":"{grant_id}","user_email":"race-b@example.test",
            "role":"Membro da direção da campanha","congregation_id":"{scope_id}"}}'::jsonb);""")
        wait_until("reassignment queued behind uncommitted binding",
                   lambda: binder_pid in (save.state() or {}).get("blockers", []))
        binder.finish()
        wait_until("old-target business UID lock acquired",
                   lambda: (business.state() or {}).get("state") == "idle in transaction")
        business_pid = business.state()["pid"]
        gate.finish()

        def reassignment_outcome():
            state = save.state() or {}
            if business_pid in state.get("blockers", []):
                return "blocked_by_business"
            if state.get("state") == "idle in transaction":
                return "bypassed_business"
            return None

        outcome = wait_until("reassignment to wait on old-target business lock", reassignment_outcome)
        assert outcome == "blocked_by_business", (
            "ASSERTION: reassignment bypassed the newly bound old-target business UID lock")
        business.finish()
        wait_until("reassignment after business commit",
                   lambda: (save.state() or {}).get("state") == "idle in transaction")
        save.finish()
        assert query(f"SELECT version FROM private.access_versions WHERE user_id='{old_uid}'") == "2", (
            "ASSERTION: binding and reassignment must each advance the old-target version")
        assert query(f"SELECT user_id FROM public.user_access WHERE id='{grant_id}'") == new_uid, (
            "ASSERTION: reassignment must bind the new verified identity")
        print("PASS: pending binding -> reassignment waits for old-target business lock; version=2", flush=True)
    finally:
        # Close owned clients first; PostgreSQL rolls back any remaining transactions.
        for session in reversed(sessions):
            if session.process.poll() is None:
                session.process.terminate()
            try:
                session.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                session.process.kill()
                session.process.wait(timeout=5)
            session.process.stdin.close()
            session.output.close()
