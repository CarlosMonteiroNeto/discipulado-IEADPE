"""Exercise academic capacity and attendance/enrollment races using independent PostgreSQL sessions."""
import json
import os
import subprocess
import tempfile
import time


def check_ministry_academic_concurrency(psql, connection):
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

    actor = "97000000-0000-0000-0000-000000000001"
    scope = "97000000-0000-0000-0000-000000000002"
    cap_class = "97000000-0000-0000-0000-000000000003"
    query(f"""
      INSERT INTO auth.users(id,email,email_confirmed_at) VALUES('{actor}','academic-race@example.test',now());
      INSERT INTO public.congregations(id,name) VALUES('{scope}','Academic race');
      INSERT INTO public.ministry_grants(user_id,congregation_id,role) VALUES('{actor}','{scope}','ministry_staff');
      INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
       VALUES('{cap_class}','{scope}','Capacity Race','capacity race','2026-01-01','{actor}');
      INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,updated_by)
       SELECT ('97000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'{scope}','Learner '||n,'learner '||n,'{actor}'
       FROM generate_series(1,105) n;
      INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,end_date,status,updated_by)
       SELECT ('97100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'{scope}',
        ('97000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'{cap_class}','2026-01-01','2026-06-01','completed','{actor}'
       FROM generate_series(1,99) n;
    """)
    auth = f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{actor}',true);"
    def enroll(operation, clazz, student):
        return f"public.ieadpe_ministry_enroll_student('{operation}','{{\"id\":\"{operation}\",\"congregation_id\":\"{scope}\",\"class_id\":\"{clazz}\",\"student_id\":\"{student}\",\"start_date\":\"2026-01-01\"}}'::jsonb)"

    try:
        first_student = "97000000-0000-0000-0000-000000000100"
        second_student = "97000000-0000-0000-0000-000000000101"
        first = Session("ministry_capacity_first", auth + "SELECT " + enroll("97200000-0000-0000-0000-000000000001", cap_class, first_student) + ";")
        wait_for("first capacity claim", lambda: first.state().get("state") == "idle in transaction")
        pid = first.state()["pid"]
        second = Session("ministry_capacity_second", auth + f"""
          DO $$ BEGIN BEGIN PERFORM {enroll('97200000-0000-0000-0000-000000000002',cap_class,second_student)};
           RAISE EXCEPTION 'ASSERTION: capacity race allowed enrollment 101';
           EXCEPTION WHEN invalid_parameter_value THEN NULL; END; END $$;
        """)
        wait_for("second capacity claim waits on class", lambda: pid in second.state().get("blockers", []))
        first.finish()
        wait_for("capacity loser rechecks count", lambda: second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT count(*) FROM public.ministry_enrollments WHERE class_id='{cap_class}'") == "100"

        for index, enrollment_first in enumerate((True, False), start=1):
            roster_first_student = f"97000000-0000-0000-0000-{index + 101:012d}"
            roster_second_student = f"97000000-0000-0000-0000-{index + 103:012d}"
            clazz = f"97000000-0000-0000-0000-{index + 10:012d}"
            base_enrollment = f"97000000-0000-0000-0000-{index + 20:012d}"
            session_id = f"97000000-0000-0000-0000-{index + 30:012d}"
            new_enrollment = f"97000000-0000-0000-0000-{index + 40:012d}"
            query(f"""
              INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
               VALUES('{clazz}','{scope}','Roster Race {index}','roster race {index}','2026-01-01','{actor}');
              INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by)
               VALUES('{base_enrollment}','{scope}','{roster_first_student}','{clazz}','2026-01-01','{actor}');
            """)
            query(auth + f"SELECT public.ieadpe_ministry_create_session('{session_id}', '{{\"id\":\"{session_id}\",\"congregation_id\":\"{scope}\",\"class_id\":\"{clazz}\",\"date\":\"2026-10-16\",\"topic\":null}}'::jsonb); COMMIT;")
            attendance_marks = ({base_enrollment: "present", new_enrollment: "absent"} if enrollment_first
                                else {base_enrollment: "present"})
            attendance_op = f"97200000-0000-0000-0000-{index + 50:012d}"
            attendance_payload = json.dumps(dict(congregation_id=scope, session_id=session_id,
                                                  expected_revision=1, marks=attendance_marks, finalize=True))
            enrollment_sql = "SELECT " + enroll(new_enrollment, clazz, roster_second_student) + ";"
            attendance_sql = f"SELECT public.ieadpe_ministry_save_attendance('{attendance_op}','{attendance_payload}'::jsonb);"
            first_kind = "enroll" if enrollment_first else "attendance"
            first_sql, second_sql = (enrollment_sql, attendance_sql) if enrollment_first else (attendance_sql, enrollment_sql)
            first = Session(f"ministry_{first_kind}_first_{index}", auth + first_sql)
            wait_for("first roster lock", lambda: first.state().get("state") == "idle in transaction")
            pid = first.state()["pid"]
            second_kind = "attendance" if enrollment_first else "enroll"
            second = Session(f"ministry_{second_kind}_second_{index}", auth + second_sql)
            wait_for("second roster operation waits for class lock", lambda: pid in second.state().get("blockers", []))
            first.finish()
            wait_for("second roster operation resumes", lambda: second.state().get("state") == "idle in transaction")
            second.finish()
            expected = "2" if enrollment_first else "1"
            assert query(f"SELECT count(*) FROM public.ministry_session_roster WHERE session_id='{session_id}'") == expected
        print("PASS: class cap race and both enrollment/roster-freeze serialization orders", flush=True)
    finally:
        for session in reversed(sessions):
            if session.process.poll() is None:
                session.process.terminate()
                session.process.wait(timeout=5)
            session.process.stdin.close()
            session.output.close()
