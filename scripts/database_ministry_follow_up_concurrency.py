"""Exercise finalization/cancellation serialization on independent PostgreSQL sessions."""
import json
import os
import subprocess
import tempfile
import time


def check_ministry_follow_up_concurrency(psql, connection):
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
            raw = query("SELECT row_to_json(s) FROM (SELECT pid,state,wait_event_type,wait_event,pg_blocking_pids(pid) AS blockers "
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

    def wait_for(description, predicate, diagnostic=None):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(.05)
        detail = f"; last state: {diagnostic()}" if diagnostic else ""
        raise AssertionError("Timed out waiting for " + description + detail)

    actors = ["94900000-0000-4000-8000-000000000001", "94900000-0000-4000-8000-000000000011"]
    emails = ["follow-up-race-a@example.test", "follow-up-race-b@example.test"]
    scope = "94900000-0000-4000-8000-000000000002"
    class_ids = ["94900000-0000-4000-8000-000000000003", "94900000-0000-4000-8000-000000000004"]
    student_ids = ["94900000-0000-4000-8000-000000000005", "94900000-0000-4000-8000-000000000006"]
    enrollment_ids = ["94900000-0000-4000-8000-000000000007", "94900000-0000-4000-8000-000000000008"]
    session_ids = ["94900000-0000-4000-8000-000000000009", "94900000-0000-4000-8000-000000000010"]
    query(f"""
      INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
       ('{actors[0]}','{emails[0]}',now()),('{actors[1]}','{emails[1]}',now());
      INSERT INTO public.congregations(id,name) VALUES('{scope}','Follow-up race');
      INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
       VALUES('{emails[0]}','{actors[0]}','Membro da direção da campanha','{scope}'),
             ('{emails[1]}','{actors[1]}','Membro da direção da campanha','{scope}');
      INSERT INTO public.ministry_grants(user_id,congregation_id,role)
       VALUES('{actors[0]}','{scope}','ministry_staff'),('{actors[1]}','{scope}','ministry_staff');
      INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by) VALUES
       ('{class_ids[0]}','{scope}','Race A','race a','2026-01-01','{actors[0]}'),
       ('{class_ids[1]}','{scope}','Race B','race b','2026-01-01','{actors[0]}');
      INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,updated_by) VALUES
       ('{student_ids[0]}','{scope}','Learner A','learner a','{actors[0]}'),
       ('{student_ids[1]}','{scope}','Learner B','learner b','{actors[0]}');
      INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
       ('{enrollment_ids[0]}','{scope}','{student_ids[0]}','{class_ids[0]}','2026-01-01','{actors[0]}'),
       ('{enrollment_ids[1]}','{scope}','{student_ids[1]}','{class_ids[1]}','2026-01-01','{actors[0]}');
      INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,updated_by) VALUES
       ('{session_ids[0]}','{scope}','{class_ids[0]}','2026-10-18','{actors[0]}'),
       ('{session_ids[1]}','{scope}','{class_ids[1]}','2026-10-18','{actors[0]}');
    """)

    assert query(f"SELECT count(*) FROM public.ministry_grants WHERE user_id IN ('{actors[0]}','{actors[1]}') AND congregation_id='{scope}' AND active") == "2"
    assert query(f"SELECT count(*) FROM private.access_versions WHERE user_id IN ('{actors[0]}','{actors[1]}')") == "2"

    def auth(actor):
        return f"BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{actor}',true);"

    def finalize(index):
        op = f"94900000-0000-4000-8000-{index + 20:012d}"
        payload = json.dumps(dict(congregation_id=scope, session_id=session_ids[index], expected_revision=1,
                                  marks={enrollment_ids[index]: "present"}, finalize=True))
        return f"SELECT public.ieadpe_ministry_save_attendance('{op}','{payload}'::jsonb);"

    def cancel(index):
        op = f"94900000-0000-4000-8000-{index + 30:012d}"
        payload = json.dumps(dict(id=session_ids[index], congregation_id=scope, expected_revision=1))
        return f"SELECT public.ieadpe_ministry_cancel_session('{op}','{payload}'::jsonb);"

    try:
        # Distinct actors have distinct access_versions lock rows. Thus a Lock
        # wait on the first PID after each command enters is class/session
        # serialization, not both commands contending on one actor's access lock.
        # Finalization holds the class lock first; cancellation then sees the new revision.
        first = Session("followup_finalize_first", auth(actors[0]) + finalize(0))
        wait_for("finalization lock", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("followup_cancel_second", auth(actors[1]) + f"DO $$ BEGIN BEGIN {cancel(0)} RAISE EXCEPTION 'ASSERTION: expected stale cancel'; EXCEPTION WHEN serialization_failure THEN NULL; END; END $$;")
        wait_for("cancel blocked by finalization class/session locks after independent actor access locks", lambda: (
            (state := second.state()).get("wait_event_type") == "Lock" and
            first_pid in state.get("blockers", [])), second.state)
        first.finish()
        wait_for("cancel resumes after finalization", lambda: second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT status FROM public.ministry_sessions WHERE id='{session_ids[0]}'") == "finalized"
        marks = json.dumps({enrollment_ids[0]: "absent"})
        query(auth(actors[1]) + f"""
          DO $$ BEGIN
            BEGIN PERFORM public.ieadpe_ministry_save_attendance('94900000-0000-4000-8000-000000000051',
              '{{"congregation_id":"{scope}","session_id":"{session_ids[0]}","expected_revision":2,"marks":{marks},"finalize":false}}'::jsonb);
              RAISE EXCEPTION 'ASSERTION: finalized session accepted a current draft';
            EXCEPTION WHEN SQLSTATE '23514' THEN IF SQLERRM<>'session_finalized' THEN RAISE; END IF; END;
            BEGIN PERFORM public.ieadpe_ministry_save_attendance('94900000-0000-4000-8000-000000000052',
              '{{"congregation_id":"{scope}","session_id":"{session_ids[0]}","expected_revision":2,"marks":{marks},"finalize":true}}'::jsonb);
              RAISE EXCEPTION 'ASSERTION: finalized session accepted a current finalize';
            EXCEPTION WHEN SQLSTATE '23514' THEN IF SQLERRM<>'session_finalized' THEN RAISE; END IF; END;
            BEGIN PERFORM public.ieadpe_ministry_save_attendance('94900000-0000-4000-8000-000000000053',
              '{{"congregation_id":"{scope}","session_id":"{session_ids[0]}","expected_revision":1,"marks":{marks},"finalize":false}}'::jsonb);
              RAISE EXCEPTION 'ASSERTION: finalized session accepted a stale draft';
            EXCEPTION WHEN SQLSTATE '23514' THEN IF SQLERRM<>'session_finalized' THEN RAISE; END IF; END;
            BEGIN PERFORM public.ieadpe_ministry_save_attendance('94900000-0000-4000-8000-000000000054',
              '{{"congregation_id":"{scope}","session_id":"{session_ids[0]}","expected_revision":1,"marks":{marks},"finalize":true}}'::jsonb);
              RAISE EXCEPTION 'ASSERTION: finalized session accepted a stale finalize';
            EXCEPTION WHEN SQLSTATE '23514' THEN IF SQLERRM<>'session_finalized' THEN RAISE; END IF; END;
          END $$; COMMIT;""")
        assert query(f"SELECT status||':'||revision||':'||(SELECT count(*) FROM public.ministry_attendance WHERE session_id='{session_ids[0]}')::text "
                     f"FROM public.ministry_sessions WHERE id='{session_ids[0]}'") == "finalized:2:1"
        query(auth(actors[0]) + f"SELECT public.ieadpe_ministry_cancel_session('94900000-0000-4000-8000-000000000041',"
              f"'{{\"id\":\"{session_ids[0]}\",\"congregation_id\":\"{scope}\",\"expected_revision\":2}}'::jsonb); COMMIT;")
        assert query(f"SELECT status||':'||(SELECT count(*) FROM public.ministry_attendance WHERE session_id='{session_ids[0]}')::text "
                     f"FROM public.ministry_sessions WHERE id='{session_ids[0]}'") == "canceled:1"

        # Cancellation holds the class lock first; the waiting finalization cannot add marks.
        first = Session("followup_cancel_first", auth(actors[0]) + cancel(1))
        wait_for("cancellation lock", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("followup_finalize_second", auth(actors[1]) + f"DO $$ BEGIN BEGIN {finalize(1)} RAISE EXCEPTION 'ASSERTION: expected terminal canceled finalize'; EXCEPTION WHEN SQLSTATE '23514' THEN IF SQLERRM<>'session_canceled' THEN RAISE; END IF; END; END $$;")
        wait_for("finalize blocked by cancellation class/session locks after independent actor access locks", lambda: (
            (state := second.state()).get("wait_event_type") == "Lock" and
            first_pid in state.get("blockers", [])), second.state)
        first.finish()
        wait_for("finalize resumes after cancellation", lambda: second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT status||':'||(SELECT count(*) FROM public.ministry_attendance WHERE session_id='{session_ids[1]}')::text "
                     f"FROM public.ministry_sessions WHERE id='{session_ids[1]}'") == "canceled:0"
        print("PASS: finalization/cancellation lock order, revision checks, and retained history", flush=True)
    finally:
        for session in reversed(sessions):
            if session.process.poll() is None:
                session.process.terminate()
                session.process.wait(timeout=5)
            session.process.stdin.close()
            session.output.close()
