BEGIN;

-- T2 private public-intake queue. Shared contracts:
--   public.ieadpe_public_congregations(jsonb) -> jsonb  (anon/authenticated)
--   public.ieadpe_receive_public_intake(jsonb) -> jsonb (service_role only)
-- T5 consumes these private owners and state names without recreating them:
--   private.public_intake_settings          single operator row
--   private.public_intake_submissions       pending/approved/rejected/expired rows
--   private.public_intake_receipts          digest-only idempotency receipts
--   private.public_intake_accepted_events   accepted network hash/time counters
--   private.public_intake_decisions         minimal 90-day decision metadata
-- A SHA-256 draft digest and the 64-hex HMAC network hash are server-private
-- metadata, not anonymized public data. No raw address or personal payload is
-- stored in receipts, accepted events or decision metadata.

-- Server instant for rolling windows and TTLs. Fixture tests may replace this
-- private function to control the clock; clients have no execute grant.
CREATE FUNCTION private.public_intake_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT now() $$;

CREATE TABLE private.public_intake_settings (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 enabled boolean NOT NULL DEFAULT true,
 hourly_network_limit integer NOT NULL DEFAULT 20 CHECK(hourly_network_limit>0),
 daily_network_limit integer NOT NULL DEFAULT 200 CHECK(daily_network_limit>0),
 global_pending_limit integer NOT NULL DEFAULT 1000 CHECK(global_pending_limit>0),
 pending_ttl interval NOT NULL DEFAULT interval '30 days'
  CHECK(extract(year from pending_ttl)=0 AND extract(month from pending_ttl)=0 AND
        extract(hour from pending_ttl)=0 AND extract(minute from pending_ttl)=0 AND
        extract(second from pending_ttl)=0 AND
        pending_ttl=interval '30 days'),
 receipt_retention interval NOT NULL DEFAULT interval '30 days'
  CHECK(receipt_retention=interval '30 days'),
 decision_retention interval NOT NULL DEFAULT interval '90 days'
  CHECK(extract(year from decision_retention)=0 AND extract(month from decision_retention)=0 AND
        extract(hour from decision_retention)=0 AND extract(minute from decision_retention)=0 AND
        extract(second from decision_retention)=0 AND
        decision_retention=interval '90 days'),
 updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO private.public_intake_settings DEFAULT VALUES;

CREATE TABLE private.public_intake_submissions (
 id uuid PRIMARY KEY,
 congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 network_hash text NOT NULL CHECK(network_hash~'^[0-9a-f]{64}$'),
 draft jsonb CHECK(draft IS NULL OR jsonb_typeof(draft)='object'),
 draft_digest text NOT NULL CHECK(draft_digest~'^[0-9a-f]{64}$'),
 status text NOT NULL DEFAULT 'pending'
  CHECK(status IN ('pending','approved','rejected','expired')),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0),
 created_at timestamptz NOT NULL DEFAULT private.public_intake_now(),
 expires_at timestamptz NOT NULL,
 payload_erased_at timestamptz,
 CHECK(expires_at>created_at),
 CHECK((draft IS NULL)=(payload_erased_at IS NOT NULL)),
 CHECK(status<>'pending' OR draft IS NOT NULL)
);
CREATE INDEX public_intake_submissions_actionable
 ON private.public_intake_submissions(created_at,id) WHERE status='pending';
CREATE INDEX public_intake_submissions_scope
 ON private.public_intake_submissions(congregation_id,created_at,id);
CREATE INDEX public_intake_submissions_network
 ON private.public_intake_submissions(network_hash,created_at);
CREATE INDEX public_intake_submissions_expiry
 ON private.public_intake_submissions(expires_at,id) WHERE status='pending';

CREATE TABLE private.public_intake_receipts (
 submission_id uuid PRIMARY KEY REFERENCES private.public_intake_submissions(id),
 draft_digest text NOT NULL CHECK(draft_digest~'^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT private.public_intake_now(),
 expires_at timestamptz NOT NULL,
 CHECK(expires_at>created_at)
);
CREATE INDEX public_intake_receipts_expiry ON private.public_intake_receipts(expires_at,submission_id);

CREATE TABLE private.public_intake_accepted_events (
 submission_id uuid PRIMARY KEY REFERENCES private.public_intake_submissions(id),
 network_hash text NOT NULL CHECK(network_hash~'^[0-9a-f]{64}$'),
 accepted_at timestamptz NOT NULL DEFAULT private.public_intake_now()
);
CREATE INDEX public_intake_events_network ON private.public_intake_accepted_events(network_hash,accepted_at);
CREATE INDEX public_intake_events_time ON private.public_intake_accepted_events(accepted_at,submission_id);

CREATE TABLE private.public_intake_decisions (
 submission_id uuid PRIMARY KEY REFERENCES private.public_intake_submissions(id),
 outcome text NOT NULL CHECK(outcome IN ('approved','rejected')),
 reviewer_uid uuid NOT NULL REFERENCES auth.users(id),
 official_convert_id uuid REFERENCES public.converts(id),
 decided_at timestamptz NOT NULL DEFAULT private.public_intake_now(),
 retained_until timestamptz NOT NULL,
 CHECK(retained_until>decided_at),
 CHECK(outcome<>'approved' OR official_convert_id IS NOT NULL)
);
CREATE INDEX public_intake_decisions_retention ON private.public_intake_decisions(retained_until,submission_id);

ALTER TABLE private.public_intake_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.public_intake_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.public_intake_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.public_intake_accepted_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.public_intake_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.public_intake_settings,private.public_intake_submissions,
 private.public_intake_receipts,private.public_intake_accepted_events,
 private.public_intake_decisions FROM PUBLIC,anon,authenticated,service_role;

COMMENT ON TABLE private.public_intake_settings IS
 'T2 single-row operator settings: enabled, 20/hour/network, 200/day/network, 1000 active pending, 30-day pending TTL, >=30-day receipts, >=90-day decisions.';
COMMENT ON TABLE private.public_intake_submissions IS
 'T2/T5 pending queue. status pending is actionable only while expires_at>server now(); expired rows never count or approve.';
COMMENT ON TABLE private.public_intake_receipts IS
 'T2 digest-only receipt: same submission id + canonical draft digest replays without a new slot; no PII.';
COMMENT ON TABLE private.public_intake_accepted_events IS
 'T2 accepted-submission counters keyed by 64-hex HMAC network hash; rolling server-now windows only.';
COMMENT ON TABLE private.public_intake_decisions IS
 'T5 minimal decision metadata retained 90 days; contains reviewer/official ids, never the submission payload.';
COMMENT ON COLUMN private.public_intake_submissions.draft_digest IS
 'Server-private SHA-256 of the canonical jsonb draft; not anonymized public data.';
COMMENT ON COLUMN private.public_intake_submissions.revision IS
 'Optimistic revision for T5 review/approval; starts at 1.';

-- Bounded opportunistic retention. It expires at most 100 submissions and
-- deletes at most 100 expired receipts, old accepted events and old decisions
-- per call. Operators can call it manually; no scheduler is introduced.
CREATE FUNCTION private.public_intake_cleanup() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE at_time timestamptz:=private.public_intake_now(); expired integer;
BEGIN
 UPDATE private.public_intake_submissions s
 SET status='expired',draft=NULL,payload_erased_at=at_time
 WHERE s.id IN (
  SELECT x.id FROM private.public_intake_submissions x
  WHERE x.status='pending' AND x.expires_at<=at_time
  ORDER BY x.expires_at,x.id LIMIT 100 FOR UPDATE OF x SKIP LOCKED);
 GET DIAGNOSTICS expired=ROW_COUNT;
 DELETE FROM private.public_intake_receipts r
 WHERE r.submission_id IN (
  SELECT x.submission_id FROM private.public_intake_receipts x
  JOIN private.public_intake_submissions s ON s.id=x.submission_id
  WHERE x.expires_at<=at_time AND s.status<>'pending'
  ORDER BY x.expires_at,x.submission_id LIMIT 100);
 DELETE FROM private.public_intake_accepted_events e
 WHERE e.submission_id IN (
  SELECT x.submission_id FROM private.public_intake_accepted_events x
  WHERE x.accepted_at<=at_time-interval '2 days'
  ORDER BY x.accepted_at,x.submission_id LIMIT 100);
 DELETE FROM private.public_intake_decisions d
 WHERE d.submission_id IN (
  SELECT x.submission_id FROM private.public_intake_decisions x
  WHERE x.retained_until<=at_time
  ORDER BY x.retained_until,x.submission_id LIMIT 100);
 RETURN expired;
END $$;

-- Canonical intake draft validator. It mirrors the create branch of
-- private.convert_registration_command exactly: trimmed nonempty name <=200,
-- canonical phone, ISO birth/conversion dates, conversion <= business_today(),
-- age 0..150, the shared address predicate, and an active congregation. Unknown
-- keys (including every photo reference) are rejected, so this validator is not
-- looser than the final T5 create authority.
CREATE FUNCTION private.public_intake_draft_valid(draft jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; person_data jsonb; convert_data jsonb; person_name text;
 phone_text text; birth date; conversion_date date; age_value integer;
 trim_chars CONSTANT text:=U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF draft IS NULL OR jsonb_typeof(draft)<>'object' OR
  draft-ARRAY['congregation_id','person','convert']<>'{}'::jsonb OR
  NOT draft ?& ARRAY['congregation_id','person','convert'] OR
  jsonb_typeof(draft->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(draft->'person') IS DISTINCT FROM 'object' OR
  jsonb_typeof(draft->'convert') IS DISTINCT FROM 'object' THEN RETURN false; END IF;
 BEGIN scope_id:=(draft->>'congregation_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RETURN false; END;
 IF NOT EXISTS(SELECT FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL) THEN
  RETURN false; END IF;
 person_data:=draft->'person'; convert_data:=draft->'convert';
 IF person_data-ARRAY['name','phone','birth_date','address']<>'{}'::jsonb OR
  NOT person_data ? 'name' OR jsonb_typeof(person_data->'name') IS DISTINCT FROM 'string' OR
  (person_data ? 'phone' AND jsonb_typeof(person_data->'phone') NOT IN ('string','null')) OR
  (person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date') NOT IN ('string','null')) OR
  (person_data ? 'address' AND jsonb_typeof(person_data->'address') NOT IN ('object','null')) OR
  (person_data ? 'address' AND NOT private.ministry_registration_address_valid(person_data->'address')) THEN
  RETURN false; END IF;
 person_name:=btrim(person_data->>'name',trim_chars); phone_text:=person_data->>'phone';
 IF person_name='' OR person_data->>'name'<>person_name OR length(person_name)>200 OR
  (phone_text IS NOT NULL AND phone_text!~'^\+[1-9][0-9]{1,14}$') THEN RETURN false; END IF;
 IF person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date')='string' THEN
  IF person_data->>'birth_date'!~'^\d{4}-\d{2}-\d{2}$' THEN RETURN false; END IF;
  BEGIN birth:=(person_data->>'birth_date')::date;
  EXCEPTION WHEN OTHERS THEN RETURN false; END;
 END IF;
 IF convert_data-ARRAY['landmark','gender','conversion_date','worship_type','age']<>'{}'::jsonb OR
  NOT convert_data ?& ARRAY['landmark','gender','conversion_date','worship_type'] OR
  jsonb_typeof(convert_data->'landmark') IS DISTINCT FROM 'string' OR
  jsonb_typeof(convert_data->'gender') IS DISTINCT FROM 'string' OR
  jsonb_typeof(convert_data->'conversion_date') IS DISTINCT FROM 'string' OR
  jsonb_typeof(convert_data->'worship_type') IS DISTINCT FROM 'string' OR
  (convert_data ? 'age' AND jsonb_typeof(convert_data->'age') NOT IN ('number','null')) THEN
  RETURN false; END IF;
 IF btrim(convert_data->>'landmark',trim_chars)='' OR
  convert_data->>'landmark'<>btrim(convert_data->>'landmark',trim_chars) OR
  convert_data->>'gender' NOT IN ('male','female') OR
  btrim(convert_data->>'worship_type',trim_chars)='' OR
  convert_data->>'worship_type'<>btrim(convert_data->>'worship_type',trim_chars) OR
  convert_data->>'conversion_date'!~'^\d{4}-\d{2}-\d{2}$' OR
  (convert_data ? 'age' AND convert_data->'age'<>'null'::jsonb AND
   (convert_data->'age')::text!~'^[0-9]+$') THEN RETURN false; END IF;
 BEGIN
  conversion_date:=(convert_data->>'conversion_date')::date;
  age_value:=CASE WHEN convert_data ? 'age' AND convert_data->'age'<>'null'::jsonb
   THEN (convert_data->>'age')::integer ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR
  numeric_value_out_of_range THEN RETURN false; END;
 IF conversion_date>private.business_today() OR
  (age_value IS NOT NULL AND age_value NOT BETWEEN 0 AND 150) THEN RETURN false; END IF;
 RETURN true;
END $$;

-- Names-only catalog. Keyset order is UUID ascending; a strict id>cursor bound
-- makes looping traversal impossible. Request/response fields are exact.
CREATE FUNCTION public.ieadpe_public_congregations(request jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE page_limit integer; after_id uuid; page_items jsonb; next_id uuid;
BEGIN
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['limit','cursor'] OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request->>'limit')!~'^[0-9]+$' OR
  jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN page_limit:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(request->'cursor')='string' THEN
  BEGIN after_id:=(request->>'cursor')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
   RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 END IF;
 WITH candidates AS (
  SELECT c.id,c.name FROM public.congregations c
  WHERE c.archived_at IS NULL AND (after_id IS NULL OR c.id>after_id)
  ORDER BY c.id LIMIT page_limit
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) ORDER BY p.id),'[]'::jsonb)
 INTO page_items FROM candidates p;
 IF jsonb_array_length(page_items)=page_limit THEN
  next_id:=(page_items->-1->>'id')::uuid;
  IF NOT EXISTS(SELECT FROM public.congregations c
   WHERE c.archived_at IS NULL AND c.id>next_id) THEN next_id:=NULL; END IF;
 END IF;
 RETURN jsonb_build_object('items',page_items,'next_cursor',next_id);
END $$;

-- Server-only intake. Failure messages are private typed codes mapped by T3:
-- invalid_payload, operation_conflict, intake_paused, rate_limited,
-- capacity_full, intake_unavailable. No client timestamp, actor or rate value
-- is accepted. Lock order is submission key -> network -> global capacity, and
-- all windows use the server instant.
CREATE FUNCTION public.ieadpe_receive_public_intake(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE submission_key uuid; network_key text; draft jsonb; scope_id uuid; digest text;
 at_time timestamptz; settings private.public_intake_settings%ROWTYPE;
 receipt private.public_intake_receipts%ROWTYPE;
 existing private.public_intake_submissions%ROWTYPE;
 hourly_count integer; daily_count integer; active_count integer;
BEGIN
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['submission_id','network_hash','draft']<>'{}'::jsonb OR
  NOT request ?& ARRAY['submission_id','network_hash','draft'] OR
  jsonb_typeof(request->'submission_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'network_hash') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'draft') IS DISTINCT FROM 'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN submission_key:=(request->>'submission_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 network_key:=request->>'network_hash';
 IF network_key!~'^[0-9a-f]{64}$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 draft:=request->'draft';
 digest:=encode(sha256(convert_to(draft::text,'UTF8')),'hex');
 PERFORM pg_advisory_xact_lock(711039003,hashtext(submission_key::text));
 SELECT * INTO receipt FROM private.public_intake_receipts r
  WHERE r.submission_id=submission_key;
 IF FOUND THEN
  IF receipt.draft_digest<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('status','received');
 END IF;
 SELECT * INTO existing FROM private.public_intake_submissions s WHERE s.id=submission_key;
 IF FOUND THEN
  IF existing.draft_digest<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('status','received');
 END IF;
 IF NOT private.public_intake_draft_valid(draft) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 scope_id:=(draft->>'congregation_id')::uuid;
 at_time:=private.public_intake_now();
 PERFORM private.public_intake_cleanup();
 SELECT * INTO settings FROM private.public_intake_settings WHERE singleton FOR SHARE;
 IF settings.singleton IS NULL THEN
  RAISE EXCEPTION 'intake_unavailable' USING ERRCODE='22023'; END IF;
 IF NOT settings.enabled THEN
  RAISE EXCEPTION 'intake_paused' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(711039004,hashtext(network_key));
 SELECT count(*) INTO hourly_count FROM private.public_intake_accepted_events e
  WHERE e.network_hash=network_key AND e.accepted_at>at_time-interval '1 hour' AND
   e.accepted_at<=at_time;
 SELECT count(*) INTO daily_count FROM private.public_intake_accepted_events e
  WHERE e.network_hash=network_key AND e.accepted_at>at_time-interval '1 day' AND
   e.accepted_at<=at_time;
 IF hourly_count>=settings.hourly_network_limit OR daily_count>=settings.daily_network_limit THEN
  RAISE EXCEPTION 'rate_limited' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(711039005,0);
 SELECT count(*) INTO active_count FROM private.public_intake_submissions s
  WHERE s.status='pending' AND s.expires_at>at_time;
 IF active_count>=settings.global_pending_limit THEN
  RAISE EXCEPTION 'capacity_full' USING ERRCODE='22023'; END IF;
 INSERT INTO private.public_intake_submissions(id,congregation_id,network_hash,draft,draft_digest,
  status,revision,created_at,expires_at)
 VALUES(submission_key,scope_id,network_key,draft,digest,'pending',1,at_time,
  at_time+settings.pending_ttl);
 INSERT INTO private.public_intake_accepted_events(submission_id,network_hash,accepted_at)
 VALUES(submission_key,network_key,at_time);
 INSERT INTO private.public_intake_receipts(submission_id,draft_digest,created_at,expires_at)
 VALUES(submission_key,digest,at_time,at_time+settings.receipt_retention);
 RETURN jsonb_build_object('status','received');
END $$;

REVOKE ALL ON FUNCTION private.public_intake_now(),private.public_intake_cleanup(),
 private.public_intake_draft_valid(jsonb) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.ieadpe_public_congregations(jsonb)
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.ieadpe_public_congregations(jsonb) TO anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_receive_public_intake(jsonb)
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.ieadpe_receive_public_intake(jsonb) TO service_role;

COMMENT ON FUNCTION public.ieadpe_public_congregations(jsonb) IS
 'T2 public names-only active congregation catalog. Request {limit,cursor}; response {items:[{id,name}],next_cursor}; UUID keyset ascending.';
COMMENT ON FUNCTION public.ieadpe_receive_public_intake(jsonb) IS
 'T2 server-only strict intake. Request {submission_id,network_hash,draft}; response {status:received}. Replay is digest-bound and never consumes a second slot.';

COMMIT;
