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

    def review_payload(key, decision="approve", name=None):
        payload = {"id": key, "expected_revision": 1, "decision": decision}
        if decision == "approve":
            payload["draft"] = {
                "congregation_id": review_scope,
                "person": {"name": name or "Concurrent Review", "phone": None,
                           "birth_date": None, "address": None},
                "convert": {"landmark": "Square", "gender": "male",
                            "conversion_date": conversion_date,
                            "worship_type": "Regular service", "age": None},
            }
        return quote(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))

    def review_call(key, operation, uid, decision="approve", name=None):
        return ("BEGIN; SET LOCAL ROLE authenticated;\n"
                f"SELECT set_config('request.jwt.claim.sub','{uid}',true);\n"
                f"SELECT public.ieadpe_review_pending_intake('{operation}'::uuid,"
                f"{review_payload(key, decision, name)}::jsonb);")

    def review_expect(key, operation, uid, decision, expected):
        state = "insufficient_privilege" if expected == "forbidden" else "invalid_parameter_value"
        return ("BEGIN; SET LOCAL ROLE authenticated;\n"
                f"SELECT set_config('request.jwt.claim.sub','{uid}',true);\n"
                "DO $$ BEGIN\n"
                " BEGIN\n"
                f"  PERFORM public.ieadpe_review_pending_intake('{operation}'::uuid,"
                f"{review_payload(key, decision)}::jsonb);\n"
                f"  RAISE EXCEPTION 'ASSERTION: expected {expected} but review returned';\n"
                f" EXCEPTION WHEN {state} THEN\n"
                f"  IF SQLERRM<>'{expected}' THEN RAISE; END IF;\n"
                " END;\nEND $$;")

    def seed_review(key, name):
        draft_json = json.dumps({
            "congregation_id": review_scope,
            "person": {"name": name, "phone": None, "birth_date": None, "address": None},
            "convert": {"landmark": "Square", "gender": "male",
                        "conversion_date": conversion_date,
                        "worship_type": "Regular service", "age": None},
        }, ensure_ascii=False, separators=(",", ":"))
        draft_sql = quote(draft_json)
        query(f"""
            INSERT INTO private.public_intake_submissions(
             id,congregation_id,network_hash,draft,draft_digest,status,revision,created_at,expires_at)
            VALUES('{key}','{review_scope}',repeat('b',64),{draft_sql}::jsonb,
             encode(sha256(convert_to(({draft_sql}::jsonb)::text,'UTF8')),'hex'),
             'pending',1,private.public_intake_now(),private.public_intake_now()+interval '30 days');
        """)

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

        # T5 queue review uses the same actor-access mutex as grant changes and
        # canonical official registration. Seed two scoped reviewers and a global
        # manager through the normal identity/access tables.
        review_scope = "ea000000-0000-4000-8000-000000000002"
        reviewer_a = "ee000000-0000-4000-8000-000000000001"
        reviewer_b = "ee000000-0000-4000-8000-000000000002"
        global_reviewer = "ee000000-0000-4000-8000-000000000003"
        query(f"""
            INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
             ('{reviewer_a}','review-race-a@example.test',now()),
             ('{reviewer_b}','review-race-b@example.test',now()),
             ('{global_reviewer}','review-race-global@example.test',now());
            INSERT INTO public.congregations(id,name)
             VALUES('{review_scope}','Concurrent review scope');
            INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
             ('review-race-a@example.test','{reviewer_a}',
              'Membro da direção da campanha','{review_scope}'),
             ('review-race-b@example.test','{reviewer_b}',
              'Membro da direção da campanha','{review_scope}'),
             ('review-race-global@example.test','{global_reviewer}',
              'Membro da supervisão das campanhas',NULL);
        """)
        access_a = query(f"SELECT id FROM public.user_access WHERE user_id='{reviewer_a}'")
        access_b = query(f"SELECT id FROM public.user_access WHERE user_id='{reviewer_b}'")
        if not access_a or not access_b:
            raise AssertionError("ASSERTION: review race fixtures lack scoped grants")

        def review_revoke_call(uid, operation, access_id):
            return ("BEGIN; SET LOCAL ROLE authenticated;\n"
                    f"SELECT set_config('request.jwt.claim.sub','{uid}',true);\n"
                    f"SELECT public.ieadpe_revoke_access('{operation}'::uuid,"
                    f"'{{\"id\":\"{access_id}\"}}'::jsonb);")

        def wait_blocked(description, session, blocker_pid):
            wait_until(description, lambda: blocker_pid in
                       (session.state() or {}).get("blockers", []))

        # Two reviewers racing an identical approval return the same canonical
        # convert ID and create only one official person/convert pair.
        race_same = "f1000000-0000-4000-8000-000000000001"
        seed_review(race_same, "Concurrent Same Draft")
        first = Session("review_same_first", review_call(
            race_same, "f2000000-0000-4000-8000-000000000001", reviewer_a,
            name="Concurrent Same Draft"))
        wait_until("first review transaction", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("review_same_second", review_call(
            race_same, "f2000000-0000-4000-8000-000000000002", reviewer_b,
            name="Concurrent Same Draft"))
        wait_blocked("second reviewer waits on the pending-row lock", second, first_pid)
        first.finish()
        wait_until("second identical approval completes", lambda:
                   second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT status FROM private.public_intake_submissions WHERE id='{race_same}'") == "approved", \
            "ASSERTION: identical review race did not approve the pending item"
        assert query(f"SELECT count(*) FROM private.public_intake_decisions WHERE submission_id='{race_same}'") == "1", \
            "ASSERTION: identical review race created multiple decisions"
        assert query("SELECT count(*) FROM public.converts WHERE name='Concurrent Same Draft'") == "1", \
            "ASSERTION: identical review race created more than one official convert"
        assert query(f"""
            SELECT count(*) FROM private.mutation_receipts r
             WHERE r.command='review_pending_intake' AND
               ((r.actor_uid='{reviewer_a}' AND r.operation_id='f2000000-0000-4000-8000-000000000001') OR
                (r.actor_uid='{reviewer_b}' AND r.operation_id='f2000000-0000-4000-8000-000000000002')) AND
               r.result->>'official_convert_id'=(
                 SELECT official_convert_id::text FROM private.public_intake_decisions
                  WHERE submission_id='{race_same}')
        """) == "2", \
            "ASSERTION: concurrent reviewers did not receive the same canonical receipt result"
        print("PASS: two-reviewer identical approval creates one canonical result", flush=True)

        # A second reviewer cannot replace the first reviewer's corrected draft.
        race_conflict = "f1000000-0000-4000-8000-000000000002"
        seed_review(race_conflict, "Concurrent Correction")
        first = Session("review_conflict_first", review_call(
            race_conflict, "f2000000-0000-4000-8000-000000000003", reviewer_a,
            name="Concurrent Winner"))
        wait_until("first corrected review transaction", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("review_conflict_second", (
            "BEGIN; SET LOCAL ROLE authenticated;\n"
            f"SELECT set_config('request.jwt.claim.sub','{reviewer_b}',true);\n"
            "DO $$ BEGIN\n BEGIN\n"
            "  PERFORM public.ieadpe_review_pending_intake('f2000000-0000-4000-8000-000000000004'::uuid,"
            f"{review_payload(race_conflict, name='Concurrent Loser')}::jsonb);\n"
            "  RAISE EXCEPTION 'ASSERTION: conflicting correction was accepted';\n"
            " EXCEPTION WHEN invalid_parameter_value THEN\n"
            "  IF SQLERRM<>'operation_conflict' THEN RAISE; END IF;\n"
            " END;\nEND $$;"))
        wait_blocked("conflicting reviewer waits on the pending-row lock", second, first_pid)
        first.finish()
        wait_until("conflicting review is rejected", lambda:
                   second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT count(*) FROM private.public_intake_decisions WHERE submission_id='{race_conflict}'") == "1", \
            "ASSERTION: conflicting review created multiple decisions"
        assert query("SELECT count(*) FROM public.converts WHERE name IN ('Concurrent Winner','Concurrent Loser')") == "1", \
            "ASSERTION: conflicting correction changed or duplicated the canonical result"
        print("PASS: concurrent conflicting corrected draft is rejected", flush=True)

        # Approval and rejection serialize on the same pending row; the losing
        # outcome observes the committed decision and cannot overwrite it.
        race_outcome = "f1000000-0000-4000-8000-000000000003"
        seed_review(race_outcome, "Concurrent Outcome")
        first = Session("review_outcome_approve", review_call(
            race_outcome, "f2000000-0000-4000-8000-000000000005", reviewer_a,
            name="Concurrent Outcome"))
        wait_until("approval before rejection", lambda: first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        second = Session("review_outcome_reject", review_expect(
            race_outcome, "f2000000-0000-4000-8000-000000000006", reviewer_b,
            "reject", "operation_conflict"))
        wait_blocked("rejection waits behind approval", second, first_pid)
        first.finish()
        wait_until("losing rejection observes approval", lambda:
                   second.state().get("state") == "idle in transaction")
        second.finish()
        assert query(f"SELECT status FROM private.public_intake_submissions WHERE id='{race_outcome}'") == "approved", \
            "ASSERTION: losing rejection overwrote approval"
        assert query(f"SELECT outcome FROM private.public_intake_decisions WHERE submission_id='{race_outcome}'") == "approved", \
            "ASSERTION: outcome race recorded an unexpected decision"
        print("PASS: concurrent reject/approve permits exactly one outcome", flush=True)

        # A normal official create for the same actor waits on the canonical
        # actor-access lock held during review, then completes without deadlock.
        race_registration = "f1000000-0000-4000-8000-000000000004"
        seed_review(race_registration, "Review Contention")
        first = Session("review_normal_first", review_call(
            race_registration, "f2000000-0000-4000-8000-000000000007", reviewer_a,
            name="Review Contention"))
        wait_until("review lock held for normal registration", lambda:
                   first.state().get("state") == "idle in transaction")
        first_pid = first.state()["pid"]
        registration = {
            "congregation_id": review_scope,
            "person": {"name": "Normal Registration Contender", "phone": None,
                       "birth_date": None, "address": None},
            "convert": {"landmark": "Square", "gender": "female",
                        "conversion_date": conversion_date,
                        "worship_type": "Regular service", "age": None,
                        "photo_asset_id": None},
        }
        registration_sql = quote(json.dumps(registration, ensure_ascii=False,
                                            separators=(",", ":")))
        normal = Session("review_normal_create", (
            "BEGIN; SET LOCAL ROLE authenticated;\n"
            f"SELECT set_config('request.jwt.claim.sub','{reviewer_a}',true);\n"
            "SELECT public.ieadpe_create_convert('f2000000-0000-4000-8000-000000000008'::uuid,"
            f"{registration_sql}::jsonb);"))
        wait_blocked("normal registration waits on review actor lock", normal, first_pid)
        first.finish()
        wait_until("normal registration resumes after review", lambda:
                   normal.state().get("state") == "idle in transaction")
        normal.finish()
        assert query("SELECT count(*) FROM public.converts WHERE name IN ('Review Contention','Normal Registration Contender')") == "2", \
            "ASSERTION: review/registration contention lost a canonical operation"
        print("PASS: normal registration serializes with approval without deadlock", flush=True)

        # If revocation owns the reviewer access lock first, an in-flight review
        # waits, rechecks current scope after revocation commits, and writes none.
        race_revoke_first = "f1000000-0000-4000-8000-000000000005"
        seed_review(race_revoke_first, "Revocation Wins")
        revoker = Session("review_revoke_first", review_revoke_call(
            global_reviewer, "f3000000-0000-4000-8000-000000000001", access_b))
        wait_until("revocation transaction", lambda: revoker.state().get("state") == "idle in transaction")
        revoker_pid = revoker.state()["pid"]
        blocked_review = Session("review_after_revoke", review_expect(
            race_revoke_first, "f2000000-0000-4000-8000-000000000009", reviewer_b,
            "reject", "forbidden"))
        wait_blocked("review waits for concurrent access revocation", blocked_review, revoker_pid)
        revoker.finish()
        wait_until("review rechecks revoked grant", lambda:
                   blocked_review.state().get("state") == "idle in transaction")
        blocked_review.finish()
        assert query(f"SELECT status FROM private.public_intake_submissions WHERE id='{race_revoke_first}'") == "pending", \
            "ASSERTION: revoked reviewer changed pending state"
        assert query(f"SELECT count(*) FROM private.public_intake_decisions WHERE submission_id='{race_revoke_first}'") == "0", \
            "ASSERTION: revoked reviewer wrote a decision"
        assert query("SELECT count(*) FROM public.converts WHERE name='Revocation Wins'") == "0", \
            "ASSERTION: revoked reviewer created an official convert"
        print("PASS: revocation wins access-lock race without partial review", flush=True)

        # If approval owns the actor lock first, revocation waits and commits only
        # after the atomic canonical review. Replay then rechecks the revoked scope.
        race_review_first = "f1000000-0000-4000-8000-000000000006"
        seed_review(race_review_first, "Approval Wins")
        approval = Session("review_before_revoke", review_call(
            race_review_first, "f2000000-0000-4000-8000-000000000010", reviewer_a,
            name="Approval Wins"))
        wait_until("approval transaction before revoke", lambda:
                   approval.state().get("state") == "idle in transaction")
        approval_pid = approval.state()["pid"]
        revoker = Session("review_revoke_after", review_revoke_call(
            global_reviewer, "f3000000-0000-4000-8000-000000000002", access_a))
        wait_blocked("revocation waits for active review", revoker, approval_pid)
        approval.finish()
        wait_until("revocation resumes after committed approval", lambda:
                   revoker.state().get("state") == "idle in transaction")
        revoker.finish()
        assert query(f"SELECT status FROM private.public_intake_submissions WHERE id='{race_review_first}'") == "approved", \
            "ASSERTION: review that owned the access lock failed to commit"
        assert query("SELECT count(*) FROM public.converts WHERE name='Approval Wins'") == "1", \
            "ASSERTION: review-first revoke race did not create one canonical convert"
        replay = Session("review_revoked_replay", review_expect(
            race_review_first, "f2000000-0000-4000-8000-000000000010", reviewer_a,
            "approve", "forbidden"))
        wait_until("revoked replay rejects", lambda:
                   replay.state().get("state") == "idle in transaction")
        replay.finish()
        print("PASS: active review serializes before revocation and replay rechecks scope", flush=True)

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
