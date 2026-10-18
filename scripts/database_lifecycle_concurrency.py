"""Exercise lifecycle record locks and grant revocation with actual database sessions."""
import json
import os
import subprocess
import tempfile
import time


def check_lifecycle_concurrency(psql, connection):
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

    admin = "61000000-0000-0000-0000-000000000001"
    actor = "61000000-0000-0000-0000-000000000002"
    other = "61000000-0000-0000-0000-000000000003"
    scope = "61000000-0000-0000-0000-000000000004"
    record = "61000000-0000-0000-0000-000000000005"
    grant = "61000000-0000-0000-0000-000000000006"
    query(f"""
      INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
      ('{admin}','lifecycle-admin@example.test',now()),
      ('{actor}','lifecycle-actor@example.test',now()),
      ('{other}','lifecycle-other@example.test',now());
      INSERT INTO private.admin_allowlist VALUES('{admin}'),('{other}');
      INSERT INTO public.congregations(id,name) VALUES('{scope}','Synthetic lifecycle race');
      INSERT INTO public.user_access(id,user_email,user_id,role,congregation_id)
      VALUES('{grant}','lifecycle-actor@example.test','{actor}','Membro da direção da campanha','{scope}');
      INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id)
      VALUES('{record}','race','Synthetic','Square','male',private.business_today()-100,'Synthetic','{scope}');
    """)

    def authenticated(uid):
        return ("BEGIN; SET LOCAL ROLE authenticated; "
                f"SELECT set_config('request.jwt.claim.sub','{uid}',true);")

    def transition(action, operation=None):
        operation = operation or query("SELECT gen_random_uuid()")
        payload = json.dumps(dict(id=record, action=action))
        return f"public.ieadpe_transition_convert('{operation}','{payload}'::jsonb)"

    def reject(call, message):
        return f"""DO $$ BEGIN
          BEGIN PERFORM {call}; RAISE EXCEPTION 'ASSERTION: rejected action accepted';
          EXCEPTION WHEN invalid_parameter_value OR insufficient_privilege THEN
            IF SQLERRM<>'{message}' THEN RAISE; END IF;
          END;
        END $$;"""

    def ready(session):
        wait_until(session.name + " transaction", lambda: session.state().get("state") == "idle in transaction")

    def blocked(session, owner):
        pid = owner.state()["pid"]
        wait_until(session.name + " lock", lambda: pid in session.state().get("blockers", []))

    try:
        operation = query("SELECT gen_random_uuid()")
        first = Session("lifecycle_visit_first", authenticated(actor) + "SELECT " + transition('visit', operation) + ";")
        ready(first)
        second = Session("lifecycle_visit_retry", authenticated(actor) + "SELECT " + transition('visit', operation) + ";")
        blocked(second, first)
        first.finish()
        ready(second)
        second.finish()
        assert query("SELECT visit_count FROM public.converts") == "1", "ASSERTION: double visit incremented twice"
        assert query("SELECT count(*) FROM public.convert_events") == "1", "ASSERTION: double visit emitted twice"
        assert query("SELECT count(*) FROM private.mutation_receipts") == "1", "ASSERTION: retry receipt duplicated"

        query("UPDATE public.converts SET last_visit_date=private.business_today()-100; DELETE FROM public.convert_events; DELETE FROM private.mutation_receipts;")
        first = Session("lifecycle_fresh_visit_first", authenticated(actor) + "SELECT " + transition('visit') + ";")
        ready(first)
        second = Session("lifecycle_fresh_visit_second", authenticated(other) + reject(transition('visit'), 'visit_not_due'))
        blocked(second, first)
        first.finish()
        ready(second)
        second.finish()
        assert query("SELECT visit_count FROM public.converts") == "2", "ASSERTION: competing fresh visits incremented twice"
        assert query("SELECT count(*) FROM public.convert_events") == "1", "ASSERTION: competing fresh visits emitted twice"
        assert query("SELECT count(*) FROM private.mutation_receipts") == "1", "ASSERTION: rejected fresh visit left receipt"

        # Different actors use different UID locks: the record lock must re-read
        # the winning terminal state. Exercise both terminal commit orders.
        for winning, losing in [('complete', 'deviate'), ('deviate', 'complete')]:
            query("UPDATE public.converts SET is_discipleship_completed=false,is_deviated=false,is_in_discipleship=true,visit_count=3,discipleship_start_date=private.business_today()-90; DELETE FROM public.convert_events; DELETE FROM private.mutation_receipts;")
            first = Session("lifecycle_terminal_first", authenticated(actor) + "SELECT " + transition(winning) + ";")
            ready(first)
            second = Session("lifecycle_terminal_second", authenticated(other) + reject(transition(losing), 'convert_terminal'))
            blocked(second, first)
            first.finish()
            ready(second)
            second.finish()
            assert query("SELECT (is_discipleship_completed<>is_deviated) AND NOT is_in_discipleship FROM public.converts") == "t", "ASSERTION: conflicting terminal state"
            assert query("SELECT count(*) FROM public.convert_events") == "1", "ASSERTION: conflicting terminal events"
            assert query("SELECT count(*) FROM private.mutation_receipts") == "1", "ASSERTION: rejected terminal receipt persisted"

        query("UPDATE public.converts SET is_discipleship_completed=false,is_deviated=false,is_in_discipleship=false,last_visit_date=private.business_today()-100; DELETE FROM public.convert_events; DELETE FROM private.mutation_receipts;")
        # An authorized write already holding its UID lock finishes before revoke.
        first = Session("lifecycle_before_revoke", authenticated(actor) + "SELECT " + transition('visit') + ";")
        ready(first)
        revoke = Session("lifecycle_revoke_second", authenticated(admin) + f"SELECT public.ieadpe_revoke_access(gen_random_uuid(),'{{\"id\":\"{grant}\"}}'::jsonb);")
        blocked(revoke, first)
        first.finish()
        ready(revoke)
        revoke.finish()
        assert query("SELECT count(*) FROM public.convert_events") == "1", "ASSERTION: authorized earlier visit lost"
        query(f"INSERT INTO public.user_access(id,user_email,user_id,role,congregation_id) VALUES('{grant}','lifecycle-actor@example.test','{actor}','Membro da direção da campanha','{scope}');")
        query("UPDATE public.converts SET last_visit_date=private.business_today()-100; DELETE FROM public.convert_events; DELETE FROM private.mutation_receipts;")
        # Revoke wins the UID lock; a waiting actor must recheck current grants.
        revoke = Session("lifecycle_revoke_first", authenticated(admin) + f"SELECT public.ieadpe_revoke_access(gen_random_uuid(),'{{\"id\":\"{grant}\"}}'::jsonb);")
        ready(revoke)
        second = Session("lifecycle_after_revoke", authenticated(actor) + reject(transition('visit'), 'forbidden'))
        blocked(second, revoke)
        revoke.finish()
        ready(second)
        second.finish()
        assert query("SELECT count(*) FROM public.convert_events") == "0", "ASSERTION: revoked actor emitted event"
        assert query(f"SELECT count(*) FROM private.mutation_receipts WHERE actor_uid='{actor}'") == "0", "ASSERTION: revoked actor receipt persisted"
        assert query("SELECT visit_count FROM public.converts") == "4", "ASSERTION: revoked actor changed visits"
        print("PASS: concurrent retry; both terminal orders; both revocation orders", flush=True)
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
