"""Race public-intake limits with real database sessions and a fixture clock."""
import hashlib
import json
import os
import subprocess
import tempfile
import time


def check_public_intake_concurrency(psql, connection):
    sessions = []
    environment = dict(os.environ, PGCLIENTENCODING="UTF8")

    def command():
        return [psql, "-X", "--no-password", "-qAt", "-v", "ON_ERROR_STOP=1",
                "-d", connection]

    def query(sql):
        result = subprocess.run(command(), input=sql, capture_output=True,
                                text=True, encoding="utf-8", env=environment, timeout=60)
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
            self.process.wait(timeout=30)
            if self.process.returncode:
                self.output.seek(0)
                raise AssertionError(self.name + ": " + self.output.read().decode("utf-8"))

    def wait_until(description, predicate):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            result = predicate()
            if result:
                return result
            time.sleep(0.05)
        raise AssertionError("Timed out waiting for " + description)

    def quote(value):
        return "'" + value.replace("'", "''") + "'"

    def network(label):
        return hashlib.sha256(label.encode("utf-8")).hexdigest()

    scope = "ea000000-0000-4000-8000-000000000001"
    conversion_date = query("SELECT private.business_today()")
    draft = {
        "congregation_id": scope,
        "person": {"name": "Concurrent Intake", "phone": None,
                   "birth_date": None, "address": None},
        "convert": {"landmark": "Square", "gender": "male",
                    "conversion_date": conversion_date,
                    "worship_type": "Regular service", "age": None},
    }

    def request(key, network_hash):
        return quote(json.dumps({
            "submission_id": key,
            "network_hash": network_hash,
            "draft": draft,
        }, ensure_ascii=False, separators=(",", ":")))

    def accepted_call(key, network_hash):
        return ("BEGIN; SET LOCAL ROLE service_role;\n"
                "DO $$ DECLARE response jsonb; BEGIN\n"
                f" response:=public.ieadpe_receive_public_intake({request(key, network_hash)}::jsonb);\n"
                " IF response<>'{\"status\":\"received\"}'::jsonb THEN\n"
                "  RAISE EXCEPTION 'ASSERTION: unexpected intake response %',response;\n"
                " END IF;\nEND $$;")

    def call_or_rate_limited(key, network_hash):
        return ("BEGIN; SET LOCAL ROLE service_role;\n"
                "DO $$ BEGIN\n"
                " BEGIN\n"
                f"  PERFORM public.ieadpe_receive_public_intake({request(key, network_hash)}::jsonb);\n"
                " EXCEPTION WHEN invalid_parameter_value THEN\n"
                "  IF SQLERRM<>'rate_limited' THEN RAISE; END IF;\n"
                "  RETURN;\n"
                " END;\nEND $$;")

    def call_expecting(key, network_hash, expected):
        return ("BEGIN; SET LOCAL ROLE service_role;\n"
                "DO $$ BEGIN\n"
                " BEGIN\n"
                f"  PERFORM public.ieadpe_receive_public_intake({request(key, network_hash)}::jsonb);\n"
                "  RAISE EXCEPTION 'ASSERTION: expected " + expected + " but intake accepted';\n"
                " EXCEPTION WHEN invalid_parameter_value THEN\n"
                f"  IF SQLERRM<>'{expected}' THEN RAISE; END IF;\n"
                " END;\nEND $$;")

    def reset(hourly=20, daily=200, global_limit=1000):
        query(f"""
            TRUNCATE private.public_intake_decisions,private.public_intake_receipts,
             private.public_intake_accepted_events,private.public_intake_submissions CASCADE;
            UPDATE private.public_intake_settings SET enabled=true,
             hourly_network_limit={hourly},daily_network_limit={daily},
             global_pending_limit={global_limit},pending_ttl=interval '30 days',
             receipt_retention=interval '30 days',decision_retention=interval '90 days';
        """)

    def finish_holders(pending, description):
        while pending:
            holder = wait_until(description, lambda: next((
                session for session in pending
                if session.state().get("state") == "idle in transaction"
                and not session.state().get("blockers")), None))
            holder.finish()
            pending.remove(holder)

    try:
        query(f"""
            INSERT INTO public.congregations(id,name) VALUES('{scope}','Concurrent intake');
            CREATE OR REPLACE FUNCTION private.public_intake_now() RETURNS timestamptz
            LANGUAGE sql STABLE SET search_path='' AS $$
             SELECT timestamptz '2026-10-25 12:00:00+00' $$;
        """)

        # Last global slot: two different networks race the capacity advisory lock.
        reset(hourly=1000, daily=1000, global_limit=1)
        first = Session("intake_capacity_first", accepted_call(
            "eb000000-0000-4000-8000-000000000001", network("capacity-first")))
        wait_until("first capacity holder", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("intake_capacity_second", call_expecting(
            "eb000000-0000-4000-8000-000000000002", network("capacity-second"),
            "capacity_full"))
        wait_until("second blocked on the capacity lock",
                   lambda: first_pid in second.state().get("blockers", []))
        first.finish()
        wait_until("second rejects after the last slot commits",
                   lambda: second.state().get("state") == "idle in transaction")
        second.finish()
        assert query("SELECT count(*) FROM private.public_intake_submissions") == "1", \
            "ASSERTION: the last global slot admitted more than one row"
        assert query("SELECT count(*) FROM private.public_intake_accepted_events") == "1", \
            "ASSERTION: rejected capacity attempt created an accepted event"
        assert query("SELECT count(*) FROM private.public_intake_receipts") == "1", \
            "ASSERTION: rejected capacity attempt created a receipt"
        print("PASS: public intake serializes the last global capacity slot", flush=True)

        # 21 same-network submissions: exactly 20 accepted, one rate limited.
        reset()
        same_network = network("same-network")
        racers = [Session(f"intake_hour_{index:02d}", call_or_rate_limited(
            f"ec000000-0000-4000-8000-{index:012d}", same_network))
            for index in range(1, 22)]
        wait_until("same-network contention",
                   lambda: any(racer.state().get("blockers") for racer in racers))
        finish_holders(racers, "same-network lock holder")
        assert query("SELECT count(*) FROM private.public_intake_submissions") == "20", \
            "ASSERTION: same-network race did not stop at 20"
        assert query("SELECT count(*) FROM private.public_intake_accepted_events") == "20", \
            "ASSERTION: same-network race over-counted accepted events"
        assert query("SELECT count(*) FROM private.public_intake_receipts") == "20", \
            "ASSERTION: same-network race over-counted receipts"
        print("PASS: 21 same-network racers accept exactly 20 and reject one", flush=True)

        # Identical-key retries create one row even with only one global slot.
        reset(hourly=1000, daily=1000, global_limit=1)
        key = "ed000000-0000-4000-8000-000000000001"
        retries = [Session(f"intake_retry_{index:02d}", accepted_call(
            key, network(f"retry-network-{index}"))) for index in range(1, 9)]
        wait_until("identical-key contention",
                   lambda: any(retry.state().get("blockers") for retry in retries))
        finish_holders(retries, "identical-key lock holder")
        assert query("SELECT count(*) FROM private.public_intake_submissions") == "1", \
            "ASSERTION: identical-key retries created more than one submission"
        assert query("SELECT count(*) FROM private.public_intake_accepted_events") == "1", \
            "ASSERTION: identical-key retries consumed more than one slot"
        assert query("SELECT count(*) FROM private.public_intake_receipts") == "1", \
            "ASSERTION: identical-key retries created more than one receipt"
        print("PASS: identical-key retries create one row and one receipt", flush=True)

        reset()
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
