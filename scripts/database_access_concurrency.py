"""Deterministic multi-session regression for pending identity reassignment.

The earlier version held a test-only advisory gate and assumed the business
row-lock waiter would always win after the pending binder committed. Row locks
and advisory locks use different wait mechanisms, so the reassignment could
acquire the old-target row first, block on the gate, and starve the business
session. The phases below acquire each lock deliberately; no production
function is changed.
"""
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

        def abort(self):
            """Disconnect a session that is waiting so its server transaction rolls back."""
            if self.process.poll() is None:
                self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)

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
    """)
    try:
        # Phase 1: an uncommitted verified binding serializes the edit. Stop the
        # editor by disconnecting it; it must not observe the pre-binding row.
        binder = Session("ieadpe_race_binder", f"""BEGIN;
            SET LOCAL ROLE authenticated;
            SELECT set_config('request.jwt.claim.sub','{old_uid}',true);
            SELECT public.ieadpe_get_scope();""")
        wait_until("uncommitted verified binding", lambda: (binder.state() or {}).get("state") == "idle in transaction")
        binder_pid = binder.state()["pid"]
        blocked_save = Session("ieadpe_race_save_blocked", f"""BEGIN;
            SET LOCAL ROLE authenticated;
            SELECT set_config('request.jwt.claim.sub','{admin_uid}',true);
            SELECT public.ieadpe_save_access('40000000-0000-0000-0000-000000000006',
            '{{"id":"{grant_id}","user_email":"race-b@example.test",
            "role":"Membro da direção da campanha","congregation_id":"{scope_id}"}}'::jsonb);""")
        wait_until("save queued behind uncommitted binding",
                   lambda: binder_pid in (blocked_save.state() or {}).get("blockers", []))
        blocked_save.abort()
        binder.finish()
        assert query(f"SELECT user_id FROM public.user_access WHERE id='{grant_id}'") == old_uid, (
            "ASSERTION: the pending grant must bind the old verified identity")
        assert query(f"SELECT version FROM private.access_versions WHERE user_id='{old_uid}'") == "1", (
            "ASSERTION: binding must advance the old-target version exactly once")

        # Phase 2: acquire the old-target business lock before the reassignment
        # starts, then prove the reassignment waits for that lock.
        business = Session("ieadpe_race_business", f"""BEGIN;
            SELECT private.lock_access(ARRAY['{old_uid}'::uuid]);""")
        wait_until("old-target business UID lock acquired",
                   lambda: (business.state() or {}).get("state") == "idle in transaction")
        business_pid = business.state()["pid"]
        save = Session("ieadpe_race_save", f"""BEGIN;
            SET LOCAL ROLE authenticated;
            SELECT set_config('request.jwt.claim.sub','{admin_uid}',true);
            SELECT public.ieadpe_save_access('40000000-0000-0000-0000-000000000007',
            '{{"id":"{grant_id}","user_email":"race-b@example.test",
            "role":"Membro da direção da campanha","congregation_id":"{scope_id}"}}'::jsonb);""")
        wait_until("reassignment queued behind business UID lock",
                   lambda: business_pid in (save.state() or {}).get("blockers", []))
        business.finish()
        wait_until("reassignment after business commit",
                   lambda: (save.state() or {}).get("state") == "idle in transaction")
        save.finish()
        assert query(f"SELECT version FROM private.access_versions WHERE user_id='{old_uid}'") == "2", (
            "ASSERTION: binding and reassignment must each advance the old-target version")
        assert query(f"SELECT user_id FROM public.user_access WHERE id='{grant_id}'") == new_uid, (
            "ASSERTION: reassignment must bind the new verified identity")
        print("PASS: pending binding serialized; reassignment waited for the held "
              "old-target business lock; version=2", flush=True)
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
