"""Race two independently authorized actors promoting the same convert."""
import json
import os
import subprocess
import tempfile
import time


def check_convert_student_concurrency(psql, connection):
    env = dict(os.environ, PGCLIENTENCODING="UTF8")
    sessions = []

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
            # Keep psql meta commands on their own line; it must not parse \q as SQL.
            self.process.stdin.write("COMMIT;\n\\q\n")
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

    actor_a = "a6100000-0000-0000-0000-000000000001"
    actor_b = "a6100000-0000-0000-0000-000000000002"
    scope = "a6200000-0000-0000-0000-000000000001"
    query(f"""
      INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
       ('{actor_a}','race-link-a@example.test',now()),('{actor_b}','race-link-b@example.test',now());
      INSERT INTO public.congregations(id,name) VALUES('{scope}','Link race');
      INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
       ('race-link-a@example.test','{actor_a}','Membro da direção da campanha','{scope}'),
       ('race-link-b@example.test','{actor_b}','Membro da direção da campanha','{scope}');
      INSERT INTO public.ministry_grants(user_id,congregation_id,role) VALUES
       ('{actor_a}','{scope}','ministry_staff'),('{actor_b}','{scope}','ministry_staff');
      INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,phone) VALUES
       ('a6500000-0000-0000-0000-000000000001','{scope}','Race One','race one','+5511999999901'),
       ('a6500000-0000-0000-0000-000000000002','{scope}','Race Two','race two','+5511999999902');
      INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id,phone,person_id)
       VALUES
       ('a6300000-0000-0000-0000-000000000001','link-race-one','Race One','Place','female','2026-10-01','Service','{scope}','+5511999999901','a6500000-0000-0000-0000-000000000001'),
       ('a6300000-0000-0000-0000-000000000002','link-race-two','Race Two','Place','male','2026-10-02','Service','{scope}','+5511999999902','a6500000-0000-0000-0000-000000000002');
    """)
    try:
        for index, first_is_a in enumerate((True, False), start=1):
            convert_id = f"a6300000-0000-0000-0000-{index:012d}"
            op_a = f"a6400000-0000-0000-0000-{index * 2 - 1:012d}"
            op_b = f"a6400000-0000-0000-0000-{index * 2:012d}"

            def invocation(operation):
                payload = json.dumps(dict(convert_id=convert_id, congregation_id=scope, student_id=None),
                                     separators=(",", ":"))
                return f"public.ieadpe_promote_convert_to_student('{operation}','{payload}'::jsonb)"

            def begin(actor):
                return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{actor}',true);"

            actor_first, operation_first = (actor_a, op_a) if first_is_a else (actor_b, op_b)
            actor_second, operation_second = (actor_b, op_b) if first_is_a else (actor_a, op_a)
            first = Session(f"convert_link_first_{index}", begin(actor_first) + f" SELECT {invocation(operation_first)};")
            wait_for("first promotion to hold its transaction", lambda: first.state().get("state") == "idle in transaction")
            first_pid = first.state()["pid"]
            second = Session(f"convert_link_second_{index}", begin(actor_second) + "\n" +
                             "DO $$ BEGIN BEGIN PERFORM " + invocation(operation_second) + "; "
                             "RAISE EXCEPTION 'ASSERTION: competing promotion unexpectedly succeeded'; "
                             "EXCEPTION WHEN invalid_parameter_value THEN NULL; END; END $$;")
            wait_for("second promotion to wait behind convert row", lambda: first_pid in second.state().get("blockers", []))
            first.finish()
            wait_for("losing promotion to resolve safely", lambda: second.state().get("state") == "idle in transaction")
            second.finish()
            assert query(f"SELECT count(*) FROM public.ministry_students WHERE convert_id='{convert_id}'") == "1", \
                "ASSERTION: promotion race created more or less than one student/link"
            assert query(f"SELECT count(*) FROM private.mutation_receipts WHERE operation_id IN ('{op_a}','{op_b}') "
                         f"AND command='promote_convert_to_student'") == "1", \
                "ASSERTION: failed competitor persisted a receipt"
            assert query(f"SELECT count(*) FROM public.ministry_students WHERE convert_id='{convert_id}' "
                         "AND promoted_at IS NOT NULL AND convert_snapshot->>'name' IS NOT NULL") == "1", \
                "ASSERTION: committed link lacks provenance"
        print("PASS: competing convert-to-student promotions serialize; one winner and one link receipt", flush=True)
    finally:
        for session in sessions:
            if session.process.poll() is None:
                session.process.kill()
                session.process.wait(timeout=5)
            session.output.close()
