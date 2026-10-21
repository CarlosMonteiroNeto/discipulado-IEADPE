"""Exercise real import/zero-report and competing legacy ID transactions."""
import json
import os
import subprocess
import tempfile
import time


def check_import_concurrency(psql, connection):
    sessions = []
    environment = dict(os.environ, PGCLIENTENCODING="UTF8")

    def command():
        return [psql, "-X", "--no-password", "-qAt", "-v", "ON_ERROR_STOP=1",
                "-d", connection]

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
                command(), stdin=subprocess.PIPE, stdout=self.output, stderr=self.output,
                text=True, encoding="utf-8", env=dict(environment, PGAPPNAME=name))
            sessions.append(self)
            self.send(sql)

        def send(self, sql):
            self.process.stdin.write(sql + "\n")
            self.process.stdin.flush()

        def state(self):
            if self.process.poll() is not None:
                self.output.seek(0)
                raise AssertionError(self.name + ": " + self.output.read().decode("utf-8"))
            raw = query("SELECT row_to_json(s) FROM (SELECT pid,state,wait_event_type,"
                        "pg_blocking_pids(pid) AS blockers FROM pg_stat_activity "
                        f"WHERE datname=current_database() AND application_name='{self.name}') s")
            return json.loads(raw) if raw else {}

        def finish(self):
            self.send("COMMIT;\n\\q")
            self.process.wait(timeout=15)
            if self.process.returncode:
                self.output.seek(0)
                raise AssertionError(self.output.read().decode("utf-8"))

    def wait_until(description, predicate):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            result = predicate()
            if result:
                return result
            time.sleep(0.05)
        raise AssertionError("Timed out waiting for " + description)

    registrar = "53000000-0000-0000-0000-000000000001"
    manager = "53000000-0000-0000-0000-000000000002"
    scope = "53000000-0000-0000-0000-000000000003"
    query(f"""
        INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
        ('{registrar}','race-registrar@example.test',now()),
        ('{manager}','race-manager@example.test',now());
        INSERT INTO private.admin_allowlist VALUES('{manager}'),('{registrar}');
        INSERT INTO public.congregations(id,name) VALUES('{scope}','Synthetic concurrent');
    """)
    # Keep this real race scenario open even on Sunday before 20:00.
    # Closed-window eligibility belongs to weekly_test.sql, not this lock fixture.
    query("""
        CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
        LANGUAGE sql STABLE SET search_path='' AS $$
        SELECT CASE WHEN private.report_week(now()) IS NULL
          THEN now()-interval '1 day' ELSE now() END $$;
    """)
    week = query("SELECT private.report_week(private.weekly_now())")

    def authenticated(actor):
        return ("BEGIN; SET LOCAL ROLE authenticated; "
                f"SELECT set_config('request.jwt.claim.sub','{actor}',true);")

    def create(operation):
        payload = json.dumps(dict(name="Synthetic race", landmark="Square", gender="male",
                                  conversion_date=week, worship_type="01 - Oração",
                                  internal_id="race-"+operation, congregation_name="Synthetic concurrent"), ensure_ascii=False)
        return (authenticated(registrar) +
                f"SELECT public.ieadpe_import_convert('{operation}','{payload}'::jsonb);")

    def confirm(operation):
        return f"public.ieadpe_confirm_zero('{operation}','{{\"congregation_id\":\"{scope}\"}}'::jsonb)"

    try:
        zero = Session("ieadpe_zero_first", authenticated(manager) +
                       "SELECT " + confirm("53000000-0000-0000-0000-000000000004") + ";")
        wait_until("uncommitted zero confirmation", lambda: zero.state().get("state") == "idle in transaction")
        zero_pid = zero.state()["pid"]
        creator = Session("ieadpe_create_second", create("53000000-0000-0000-0000-000000000005"))
        wait_until("create blocked behind zero guard", lambda: zero_pid in creator.state().get("blockers", []))
        zero.finish()
        wait_until("create after zero commit", lambda: creator.state().get("state") == "idle in transaction")
        creator.finish()
        assert query("SELECT count(*) FROM public.weekly_reports") == "0", "ASSERTION: create must remove committed zero"
        assert query("SELECT conversion_count FROM private.congregation_week_guards") == "1", "ASSERTION: count must be one"
        assert query("SELECT revision FROM public.converts") == "1", "ASSERTION: imported revision must be one"
        assert query("SELECT person_id IS NULL FROM public.converts") == "t", "ASSERTION: imported legacy row must stay unlinked"
        query("TRUNCATE public.converts CASCADE; DELETE FROM public.weekly_reports; DELETE FROM private.congregation_week_guards;")

        creator = Session("ieadpe_create_first", create("53000000-0000-0000-0000-000000000006"))
        wait_until("uncommitted create", lambda: creator.state().get("state") == "idle in transaction")
        creator_pid = creator.state()["pid"]
        zero = Session("ieadpe_zero_second", authenticated(manager) + f"""
            DO $$ BEGIN
              BEGIN PERFORM {confirm('53000000-0000-0000-0000-000000000007')};
                RAISE EXCEPTION 'ASSERTION: zero accepted a concurrent conversion';
              EXCEPTION WHEN invalid_parameter_value THEN
                IF SQLERRM <> 'week_has_conversions' THEN RAISE; END IF;
              END;
            END $$;
        """)
        wait_until("zero blocked behind create guard", lambda: creator_pid in zero.state().get("blockers", []))
        creator.finish()
        wait_until("zero rejected after create commit", lambda: zero.state().get("state") == "idle in transaction")
        zero.finish()
        assert query("SELECT count(*) FROM public.weekly_reports") == "0", "ASSERTION: no false zero may remain"
        assert query("SELECT conversion_count FROM private.congregation_week_guards") == "1", "ASSERTION: concurrent count must be one"
        assert query("SELECT revision FROM public.converts") == "1", "ASSERTION: concurrent import revision must be one"
        assert query("SELECT person_id IS NULL FROM public.converts") == "t", "ASSERTION: concurrent import must stay unlinked"
        assert query("SELECT count(*) FROM private.mutation_receipts WHERE operation_id='53000000-0000-0000-0000-000000000007'") == "0", "ASSERTION: rejected zero must leave no receipt"
        # Different global users and operation IDs race on one legacy key.
        query("TRUNCATE public.converts CASCADE; DELETE FROM public.weekly_reports; DELETE FROM private.congregation_week_guards;")
        first = Session("ieadpe_import_legacy_first", create("53000000-0000-0000-0000-000000000008"))
        wait_until("first legacy import", lambda: first.state().get("state") == "idle in transaction")
        payload = json.dumps(dict(internal_id="race-53000000-0000-0000-0000-000000000008", name="Synthetic race", landmark="Square", gender="male", conversion_date=week, worship_type="Prayer", congregation_name="Synthetic concurrent"))
        second = Session("ieadpe_import_legacy_second", authenticated(manager) +
            f"SELECT public.ieadpe_import_convert('53000000-0000-0000-0000-000000000009','{payload}'::jsonb);")
        first_pid = first.state()["pid"]
        wait_until("competing legacy ID lock", lambda: first_pid in second.state().get("blockers", []))
        first.finish()
        wait_until("second legacy import", lambda: second.state().get("state") == "idle in transaction")
        second.finish()
        assert query("SELECT count(*) FROM public.converts") == "1", "ASSERTION: competing import duplicated legacy ID"
        assert query("SELECT conversion_count FROM private.congregation_week_guards") == "1", "ASSERTION: duplicate incremented guard"
        assert query("SELECT revision FROM public.converts") == "1", "ASSERTION: duplicate reset revision"
        assert query("SELECT person_id IS NULL FROM public.converts") == "t", "ASSERTION: duplicate created a person link"
        assert query("SELECT result->>'status' FROM private.mutation_receipts WHERE operation_id='53000000-0000-0000-0000-000000000009'") == "duplicate", "ASSERTION: competing import must report skipped"
        assert query("SELECT count(*) FROM public.convert_events") == "0", "ASSERTION: import invented events"
        print("PASS: import/confirm-zero serialize on week guard in both commit orders", flush=True)
    finally:
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
