"""Exercise competing replacements of the same ministry role slot in independent sessions."""
import json
import os
import subprocess
import tempfile
import time


def check_ministry_registry_concurrency(psql, connection):
    sessions = []
    env = dict(os.environ, PGCLIENTENCODING="UTF8")

    def command():
        return [psql, "-X", "--no-password", "-qAt", "-v", "ON_ERROR_STOP=1", "-d", connection]

    def query(sql):
        result = subprocess.run(command(), input=sql, capture_output=True, text=True,
                               encoding="utf-8", env=env, timeout=15)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result.stdout.strip()

    class Session:
        def __init__(self, name, sql):
            self.name = name
            self.output = tempfile.TemporaryFile(mode="w+b")
            self.process = subprocess.Popen(command(), stdin=subprocess.PIPE, stdout=self.output,
                                            stderr=self.output, text=True, encoding="utf-8",
                                            env=dict(env, PGAPPNAME=name))
            sessions.append(self)
            self.process.stdin.write(sql + "\n")
            self.process.stdin.flush()

        def state(self):
            if self.process.poll() is not None:
                self.output.seek(0)
                raise AssertionError(self.name + ": " + self.output.read().decode("utf-8"))
            raw = query("SELECT row_to_json(s) FROM (SELECT pid,state,pg_blocking_pids(pid) AS blockers "
                        "FROM pg_stat_activity WHERE datname=current_database() "
                        f"AND application_name='{self.name}') s")
            return json.loads(raw) if raw else {}

        def finish(self):
            self.process.stdin.write("COMMIT;\\q\n")
            self.process.stdin.flush()
            self.process.wait(timeout=15)
            if self.process.returncode:
                self.output.seek(0)
                raise AssertionError(self.output.read().decode("utf-8"))

    def wait_for(description, predicate):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(.05)
        raise AssertionError("Timed out waiting for " + description)

    actor = "95000000-0000-0000-0000-000000000001"
    scope = "95000000-0000-0000-0000-000000000002"
    old = "95000000-0000-0000-0000-000000000003"
    candidates = ["95000000-0000-0000-0000-000000000004", "95000000-0000-0000-0000-000000000005"]
    slot = "95000000-0000-0000-0000-000000000006"
    query(f"""
      INSERT INTO auth.users(id,email,email_confirmed_at) VALUES('{actor}','registry-race@example.test',now());
      INSERT INTO public.congregations(id,name) VALUES('{scope}','Registry race');
      INSERT INTO public.ministry_grants(user_id,congregation_id,role) VALUES('{actor}','{scope}','ministry_staff');
      INSERT INTO public.ministry_contacts(id,congregation_id,name,normalized_name,scope,role_code,updated_by) VALUES
       ('{old}','{scope}','Old Teacher','old teacher','congregation','teacher','{actor}'),
       ('{candidates[0]}','{scope}','Candidate One','candidate one','congregation','teacher','{actor}'),
       ('{candidates[1]}','{scope}','Candidate Two','candidate two','congregation','teacher','{actor}');
      INSERT INTO public.ministry_role_slots(id,congregation_id,scope,role_code,contact_id,updated_by)
       VALUES('{slot}','{scope}','congregation','teacher','{old}','{actor}');
    """)
    authenticated = f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{actor}',true);"
    operation = "96000000-0000-0000-0000-000000000001"
    try:
        first = Session("ministry_role_claim_first", authenticated + f"""
          SELECT public.ieadpe_ministry_replace_role_holder('{operation}',
           '{{"scope":"congregation","congregation_id":"{scope}","role_code":"teacher","previous_contact_id":"{old}","previous_expected_revision":1,"id":"{candidates[0]}","expected_revision":1}}'::jsonb);
        """)
        wait_for("first replacement transaction", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("ministry_role_claim_second", authenticated + f"""
          DO $$ BEGIN
            BEGIN PERFORM public.ieadpe_ministry_replace_role_holder('96000000-0000-0000-0000-000000000002',
             '{{"scope":"congregation","congregation_id":"{scope}","role_code":"teacher","previous_contact_id":"{old}","previous_expected_revision":1,"id":"{candidates[1]}","expected_revision":1}}'::jsonb);
              RAISE EXCEPTION 'ASSERTION: second role claim succeeded';
            EXCEPTION WHEN serialization_failure THEN NULL; END;
          END $$;
        """)
        wait_for("second claim blocks on affected contact", lambda: first_pid in second.state().get("blockers", []))
        first.finish()
        wait_for("second claim revalidates after winner", lambda: second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT contact_id FROM public.ministry_role_slots WHERE id='{slot}'") == candidates[0]
        assert query("SELECT count(*) FROM public.ministry_contacts WHERE revision=2") == "2"
        assert query("SELECT count(*) FROM private.mutation_receipts") == "1"
        print("PASS: competing role-slot replacements serialize; one winner and one stale rejection", flush=True)
    finally:
        for session in reversed(sessions):
            if session.process.poll() is None:
                session.process.terminate()
                session.process.wait(timeout=5)
            session.process.stdin.close()
            session.output.close()
