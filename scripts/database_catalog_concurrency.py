"""Exercise archive versus selection in both commit orders with actual database sessions."""
import json
import os
import subprocess
import tempfile
import time


def check_catalog_concurrency(psql, connection):
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

    registrar = "54000000-0000-0000-0000-000000000001"
    manager = "54000000-0000-0000-0000-000000000002"
    scope = "54000000-0000-0000-0000-000000000003"
    query(f"""
        INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
        ('{registrar}','catalog-race-registrar@example.test',now()),
        ('{manager}','catalog-race-manager@example.test',now());
        INSERT INTO private.admin_allowlist VALUES('{manager}');
        INSERT INTO public.congregations(id,name) VALUES('{scope}','Synthetic catalog race');
        INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
        ('catalog-race-registrar@example.test','{registrar}',
         'Membro da direção da campanha','{scope}');
    """)
    assert query(f"SELECT count(*) FROM public.user_access WHERE user_id='{registrar}' AND role='Membro da direção da campanha' AND congregation_id='{scope}'") == "1"

    def authenticated(actor):
        return ("BEGIN; SET LOCAL ROLE authenticated; "
                f"SELECT set_config('request.jwt.claim.sub','{actor}',true);")

    def archive(operation):
        return authenticated(manager) + f"SELECT public.ieadpe_archive_congregation('{operation}','{{\"id\":\"{scope}\"}}'::jsonb);"

    def selection(kind, operation):
        payload = (dict(congregation_id=scope,
                        person=dict(name="Synthetic catalog race"),
                        convert=dict(landmark="Square", gender="male",
                                     conversion_date="2026-01-01", worship_type="01 - Oração"))
                   if kind == "create_convert" else dict(user_email="catalog-race-grant@example.test",
                        role="Membro da direção da campanha", congregation_id=scope))
        return f"public.ieadpe_{kind}('{operation}','{json.dumps(payload, ensure_ascii=False)}'::jsonb)"

    try:
        for index, kind in enumerate(["create_convert", "save_access"]):
            operation = f"54000000-0000-0000-0000-{index + 10:012d}"
            archived = Session(f"ieadpe_archive_first_{index}", archive(operation))
            wait_until("archive holds catalog lock", lambda: archived.state().get("state") == "idle in transaction")
            blocker = archived.state()["pid"]
            attempted = Session(f"ieadpe_selection_second_{index}", authenticated(registrar if index == 0 else manager) + f"""
              DO $$ BEGIN
                BEGIN PERFORM {selection(kind, f'54000000-0000-0000-0000-{index + 20:012d}')};
                  RAISE EXCEPTION 'ASSERTION: selected archived congregation';
                EXCEPTION WHEN invalid_parameter_value THEN NULL;
                END;
              END $$;
            """)
            wait_until("selection waits for archive", lambda: blocker in attempted.state().get("blockers", []))
            archived.finish()
            wait_until("selection revalidates after archive", lambda: attempted.state().get("state") == "idle in transaction")
            attempted.finish()
            assert query("SELECT count(*) FROM public.converts") == "0"
            if index == 0:
                assert query(f"SELECT count(*) FROM public.user_access WHERE user_id='{registrar}' AND role='Membro da direção da campanha' AND congregation_id='{scope}'") == "1"
            else:
                assert query("SELECT count(*) FROM public.user_access") == "0"
            assert query(f"SELECT count(*) FROM public.user_access WHERE user_id='{manager}'") == "0"
            query(f"UPDATE public.congregations SET archived_at=NULL WHERE id='{scope}'")

            selected = Session(f"ieadpe_selection_first_{index}", authenticated(registrar if index == 0 else manager) +
                               "SELECT " + selection(kind, f"54000000-0000-0000-0000-{index + 30:012d}") + ";")
            wait_until("selection holds catalog share lock", lambda: selected.state().get("state") == "idle in transaction")
            blocker = selected.state()["pid"]
            archived = Session(f"ieadpe_archive_second_{index}", archive(f"54000000-0000-0000-0000-{index + 40:012d}"))
            wait_until("archive waits for selection", lambda: blocker in archived.state().get("blockers", []))
            selected.finish()
            wait_until("archive proceeds after selection commit", lambda: archived.state().get("state") == "idle in transaction")
            archived.finish()
            table = "converts" if index == 0 else "user_access"
            assert query(f"SELECT count(*) FROM public.{table} WHERE congregation_id='{scope}'") == "1"
            query(f"TRUNCATE public.converts CASCADE; DELETE FROM public.user_access; UPDATE public.congregations SET archived_at=NULL WHERE id='{scope}'")
        print("PASS: archive/create and archive/grant wait and revalidate in both commit orders", flush=True)
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
