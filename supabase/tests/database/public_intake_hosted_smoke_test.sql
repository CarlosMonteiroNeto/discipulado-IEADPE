BEGIN;
SET LOCAL statement_timeout='5s';
SET LOCAL lock_timeout='2s';
SET LOCAL idle_in_transaction_session_timeout='5s';
-- Minimal hosted T2 smoke: public catalog/privacy contracts and one run-owned
-- receive/replay pair. The runner requires two free pending slots before dispatch.
-- The accepted row, receipt, event and transaction-level locks all disappear
-- together at ROLLBACK. Rate and capacity boundaries remain local-only.

CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF;
END $$;

CREATE TEMP TABLE intake_smoke_scope(id uuid PRIMARY KEY);
INSERT INTO intake_smoke_scope(id)
 SELECT c.id FROM public.congregations c
 WHERE c.archived_at IS NULL ORDER BY c.id LIMIT 1;
GRANT SELECT ON intake_smoke_scope TO service_role;

SET LOCAL ROLE anon;
DO $$
DECLARE page jsonb; item jsonb;
BEGIN
 page:=public.ieadpe_public_congregations('{"limit":5,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(page ?& ARRAY['items','next_cursor'] AND
  page-ARRAY['items','next_cursor']='{}'::jsonb,
  'hosted smoke: catalog response has only the contract keys');
 FOR item IN SELECT * FROM jsonb_array_elements(page->'items') LOOP
  PERFORM pg_temp.assert_true(item ?& ARRAY['id','name'] AND
   item-ARRAY['id','name']='{}'::jsonb AND
   jsonb_typeof(item->'id')='string' AND jsonb_typeof(item->'name')='string',
   'hosted smoke: catalog exposes only UUID/name pairs');
 END LOOP;
END $$;
RESET ROLE;

SELECT pg_temp.assert_true(
 NOT has_table_privilege('anon','public.congregations','SELECT') AND
 has_table_privilege('authenticated','public.congregations','SELECT') AND
 has_function_privilege('anon','public.ieadpe_public_congregations(jsonb)','EXECUTE') AND
 has_function_privilege('authenticated','public.ieadpe_public_congregations(jsonb)','EXECUTE') AND
 NOT has_table_privilege('anon','private.public_intake_submissions','SELECT') AND
 NOT has_table_privilege('authenticated','private.public_intake_submissions','SELECT') AND
 NOT has_table_privilege('service_role','private.public_intake_submissions','SELECT') AND
 NOT has_table_privilege('anon','private.public_intake_receipts','SELECT') AND
 NOT has_table_privilege('authenticated','private.public_intake_receipts','SELECT') AND
 NOT has_table_privilege('service_role','private.public_intake_receipts','SELECT') AND
 NOT has_table_privilege('anon','private.public_intake_accepted_events','SELECT') AND
 NOT has_table_privilege('authenticated','private.public_intake_accepted_events','SELECT') AND
 NOT has_table_privilege('service_role','private.public_intake_accepted_events','SELECT') AND
 NOT has_table_privilege('anon','private.public_intake_decisions','SELECT') AND
 NOT has_table_privilege('authenticated','private.public_intake_decisions','SELECT') AND
 NOT has_table_privilege('service_role','private.public_intake_decisions','SELECT') AND
 NOT has_function_privilege('anon','public.ieadpe_receive_public_intake(jsonb)','EXECUTE') AND
 NOT has_function_privilege('authenticated','public.ieadpe_receive_public_intake(jsonb)','EXECUTE') AND
 has_function_privilege('service_role','public.ieadpe_receive_public_intake(jsonb)','EXECUTE'),
 'hosted smoke: queue tables and receive RPC remain server-private');

CREATE FUNCTION pg_temp.run_smoke() RETURNS text
LANGUAGE plpgsql AS $$
DECLARE scope_id uuid; submission_id uuid:='0f100000-0000-4000-8000-000000000001';
 draft jsonb; request jsonb; network_hash text; first_response jsonb; replay_response jsonb;
BEGIN
 SELECT s.id INTO scope_id FROM pg_temp.intake_smoke_scope s;
 IF scope_id IS NULL THEN RETURN 'T2_SMOKE_BLOCKED:active_congregation'; END IF;
 draft:=jsonb_build_object(
  'congregation_id',scope_id::text,
  'person',jsonb_build_object('name','Hosted T2 smoke','phone',NULL,
   'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Hosted smoke','gender','male',
   'conversion_date','2000-01-01',
   'worship_type','Hosted smoke','age',NULL));
 network_hash:=encode(sha256(convert_to(
  'public-intake-hosted-smoke:'||submission_id::text,'UTF8')),'hex');
 request:=jsonb_build_object('submission_id',submission_id::text,
  'network_hash',network_hash,'draft',draft);
 BEGIN
  first_response:=public.ieadpe_receive_public_intake(request);
  replay_response:=public.ieadpe_receive_public_intake(request);
 EXCEPTION
  WHEN lock_not_available THEN RETURN 'T2_SMOKE_BLOCKED:lock_timeout';
  WHEN invalid_parameter_value THEN
   IF SQLERRM IN ('capacity_full','intake_paused','rate_limited','operation_conflict') THEN
    RETURN 'T2_SMOKE_BLOCKED:'||SQLERRM;
   END IF;
   RAISE;
 END;
 PERFORM pg_temp.assert_true(first_response='{"status":"received"}'::jsonb AND
  replay_response='{"status":"received"}'::jsonb,
  'hosted smoke: one run-owned receive and its replay return the safe acknowledgment');
 RETURN 'T2_SMOKE_PASS';
END $$;
SET LOCAL ROLE service_role;
SELECT pg_temp.run_smoke();
RESET ROLE;
ROLLBACK;
