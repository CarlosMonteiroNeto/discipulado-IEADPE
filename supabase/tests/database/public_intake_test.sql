BEGIN;
-- T2: names-only public catalog, private pending intake, strict draft validation,
-- digest receipts, rolling windows, capacity, pause and expiry.
-- Fixture clock overrides below are test-only; production uses server now().
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

CREATE FUNCTION pg_temp.expect_failure(statement text,expected_state text,expected_message text,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 BEGIN
  EXECUTE statement;
 EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE IS DISTINCT FROM expected_state OR
   (expected_message IS NOT NULL AND SQLERRM IS DISTINCT FROM expected_message) THEN
   RAISE EXCEPTION 'ASSERTION: % raised % (%) instead of % (%)',
    label,SQLSTATE,SQLERRM,expected_state,coalesce(expected_message,'any');
  END IF;
  RETURN;
 END;
 RAISE EXCEPTION 'ASSERTION: % was accepted',label;
END $$;

CREATE FUNCTION pg_temp.reject(request jsonb,expected_message text,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_receive_public_intake(request);
 EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE IS DISTINCT FROM '22023' OR SQLERRM IS DISTINCT FROM expected_message THEN
   RAISE EXCEPTION 'ASSERTION: % raised % (%) instead of 22023 (%)',
    label,SQLSTATE,SQLERRM,expected_message;
  END IF;
  RETURN;
 END;
 RAISE EXCEPTION 'ASSERTION: % was accepted',label;
END $$;

CREATE FUNCTION pg_temp.draft(congregation_id uuid,person_name text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object(
  'congregation_id',congregation_id::text,
  'person',jsonb_build_object('name',person_name,'phone',NULL,'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Praça Central','gender','male',
   'conversion_date',private.business_today()::text,'worship_type','Culto regular','age',NULL))
$$;

CREATE FUNCTION pg_temp.request(submission uuid,network text,draft jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
 SELECT jsonb_build_object('submission_id',submission::text,'network_hash',network,'draft',draft)
$$;

CREATE FUNCTION pg_temp.receive(submission uuid,network text,draft jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
 RETURN public.ieadpe_receive_public_intake(pg_temp.request(submission,network,draft));
END $$;

CREATE FUNCTION pg_temp.seed_event(submission uuid,scope uuid,network text,accepted timestamptz) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO private.public_intake_submissions(id,congregation_id,network_hash,draft,draft_digest,
  status,created_at,expires_at,payload_erased_at)
 VALUES(submission,scope,network,NULL,repeat('0',64),'expired',accepted,accepted+interval '1 second',accepted);
 INSERT INTO private.public_intake_accepted_events(submission_id,network_hash,accepted_at)
 VALUES(submission,network,accepted);
END $$;

CREATE FUNCTION pg_temp.seed_pending(submission uuid,scope uuid,network text,created timestamptz,expires timestamptz) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO private.public_intake_submissions(id,congregation_id,network_hash,draft,draft_digest,
  status,created_at,expires_at)
 VALUES(submission,scope,network,jsonb_build_object('congregation_id',scope::text),repeat('f',64),
  'pending',created,expires);
END $$;

CREATE FUNCTION pg_temp.reset_intake(clock_value timestamptz) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 TRUNCATE private.public_intake_decisions,private.public_intake_receipts,
  private.public_intake_accepted_events,private.public_intake_submissions CASCADE;
 UPDATE private.public_intake_settings SET enabled=true,hourly_network_limit=20,
  daily_network_limit=200,global_pending_limit=1000,pending_ttl=interval '30 days',
  receipt_retention=interval '30 days',decision_retention=interval '90 days';
 UPDATE pg_temp.intake_clock SET value=clock_value;
END $$;

-- Catalog fixtures: 103 active rows and one archived row. UUID order is the
-- public order; generated rows sort after the named fixtures.
INSERT INTO public.congregations(id,name) VALUES
 ('ba000000-0000-4000-8000-000000000001','Alpha'),
 ('ba000000-0000-4000-8000-000000000002','Beta'),
 ('ba000000-0000-4000-8000-000000000003','Archived');
INSERT INTO public.congregations(id,name)
 SELECT ('ba000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'Comunidade '||i
 FROM generate_series(100,200) i;
UPDATE public.congregations SET archived_at=now()
 WHERE id='ba000000-0000-4000-8000-000000000003';

CREATE TEMP TABLE catalog_expected(n bigint);
INSERT INTO catalog_expected
 SELECT count(*) FROM public.congregations WHERE archived_at IS NULL;
CREATE TEMP TABLE catalog_result(label text PRIMARY KEY,value jsonb);
GRANT ALL ON catalog_expected,catalog_result TO anon;

-- The public catalog is callable by anon and exposes exactly id/name.
SET LOCAL ROLE anon;
INSERT INTO catalog_result(label,value) VALUES('page1',
 public.ieadpe_public_congregations('{"limit":2,"cursor":null}'::jsonb));
INSERT INTO catalog_result(label,value) VALUES('max',
 public.ieadpe_public_congregations('{"limit":100,"cursor":null}'::jsonb));
INSERT INTO catalog_result(label,value) VALUES('after_archived',
 public.ieadpe_public_congregations('{"limit":2,"cursor":"ba000000-0000-4000-8000-000000000003"}'::jsonb));
RESET ROLE;

SELECT pg_temp.assert_true(
 (SELECT value ?& ARRAY['items','next_cursor'] AND value-ARRAY['items','next_cursor']='{}'::jsonb
  FROM catalog_result WHERE label='page1'),
 'catalog_is_names_only: exact response keys');
SELECT pg_temp.assert_true(
 (SELECT jsonb_array_length(value->'items')=2 AND value->>'next_cursor'='ba000000-0000-4000-8000-000000000002'
  FROM catalog_result WHERE label='page1'),
 'catalog_is_names_only: keyset page and cursor');
SELECT pg_temp.assert_true(
 (SELECT NOT EXISTS(SELECT FROM jsonb_array_elements(value->'items') item
   WHERE NOT item ?& ARRAY['id','name'] OR item-ARRAY['id','name']<>'{}'::jsonb)
  FROM catalog_result WHERE label='page1'),
 'catalog_is_names_only: item keys are exactly id and name');
SELECT pg_temp.assert_true(
 (SELECT jsonb_array_length(value->'items')=100 AND value->>'next_cursor' IS NOT NULL
  FROM catalog_result WHERE label='max'),
 'catalog_is_names_only: page size is bounded at 100');
SELECT pg_temp.assert_true(
 (SELECT NOT EXISTS(SELECT FROM jsonb_array_elements(value->'items') item
    WHERE item->>'name'='Archived' OR
     item->>'id'='ba000000-0000-4000-8000-000000000003')
  FROM catalog_result WHERE label='after_archived'),
 'catalog_is_names_only: archived congregations are absent');

SET LOCAL ROLE anon;
DO $$
DECLARE cursor_id uuid:=NULL; page jsonb; item jsonb; previous uuid; seen uuid[]:='{}';
 total integer:=0; pages integer:=0;
BEGIN
 LOOP
  page:=public.ieadpe_public_congregations(jsonb_build_object('limit',2,'cursor',cursor_id));
  PERFORM pg_temp.assert_true(page ?& ARRAY['items','next_cursor'] AND
   page-ARRAY['items','next_cursor']='{}'::jsonb,'catalog_is_names_only: every page has exact keys');
  FOR item IN SELECT * FROM jsonb_array_elements(page->'items') LOOP
   PERFORM pg_temp.assert_true(item ?& ARRAY['id','name'] AND
    item-ARRAY['id','name']='{}'::jsonb,'catalog_is_names_only: every item has exact keys');
   PERFORM pg_temp.assert_true(previous IS NULL OR (item->>'id')::uuid>previous,
    'catalog_is_names_only: strict ascending keyset traversal');
   PERFORM pg_temp.assert_true(NOT ((item->>'id')::uuid=ANY(seen)),
    'catalog_is_names_only: no duplicate item');
   previous:=(item->>'id')::uuid; seen:=seen||previous; total:=total+1;
  END LOOP;
  cursor_id:=nullif(page->>'next_cursor','')::uuid; pages:=pages+1;
  PERFORM pg_temp.assert_true(pages<=60,'catalog_is_names_only: pagination is bounded');
  EXIT WHEN cursor_id IS NULL;
 END LOOP;
 PERFORM pg_temp.assert_true(total=(SELECT n FROM catalog_expected),
  'catalog_is_names_only: every active congregation appears once');
 PERFORM pg_temp.assert_true(NOT ('ba000000-0000-4000-8000-000000000003'::uuid=ANY(seen)),
  'catalog_is_names_only: archived id never appears');
END $$;
RESET ROLE;

SET LOCAL ROLE anon;
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":0,"cursor":null}''::jsonb)',
 '22023','invalid_request','catalog rejects zero limit');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":101,"cursor":null}''::jsonb)',
 '22023','invalid_request','catalog rejects limit above 100');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":1.5,"cursor":null}''::jsonb)',
 '22023','invalid_request','catalog rejects non-integer limit');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":"2","cursor":null}''::jsonb)',
 '22023','invalid_request','catalog rejects string limit');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":2}''::jsonb)',
 '22023','invalid_request','catalog requires cursor key');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":2,"cursor":null,"offset":2}''::jsonb)',
 '22023','invalid_request','catalog rejects unknown keys');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''{"limit":2,"cursor":"not-a-uuid"}''::jsonb)',
 '22023','invalid_request','catalog rejects invalid cursor');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_public_congregations(''[]''::jsonb)',
 '22023','invalid_request','catalog rejects non-object request');
SELECT pg_temp.expect_failure('SELECT count(*) FROM public.congregations',
 '42501',NULL,'anon has no direct congregation read');
RESET ROLE;

SELECT pg_temp.assert_true(NOT has_table_privilege('anon','public.congregations','SELECT'),
 'catalog_is_names_only: anon has no table grant');
SELECT pg_temp.assert_true(NOT has_table_privilege('anon','public.congregations','INSERT'),
 'catalog_is_names_only: anon cannot write the catalog table');

-- Private queue names and defaults are the T5 contract.
SELECT pg_temp.assert_true(to_regclass('private.public_intake_settings') IS NOT NULL AND
 to_regclass('private.public_intake_submissions') IS NOT NULL AND
 to_regclass('private.public_intake_receipts') IS NOT NULL AND
 to_regclass('private.public_intake_accepted_events') IS NOT NULL AND
 to_regclass('private.public_intake_decisions') IS NOT NULL,
 'pending_intake_is_private: private queue tables exist');
SELECT pg_temp.assert_true(
 (SELECT enabled AND hourly_network_limit=20 AND daily_network_limit=200 AND
   global_pending_limit=1000 AND pending_ttl=interval '30 days' AND
   receipt_retention=interval '30 days' AND decision_retention=interval '90 days'
  FROM private.public_intake_settings),
 'pending_intake_is_private: approved default settings');
SELECT pg_temp.assert_true(has_function_privilege('service_role',
 'public.ieadpe_receive_public_intake(jsonb)','EXECUTE'),
 'pending_intake_is_private: only the server role calls intake');
SELECT pg_temp.assert_true(NOT has_function_privilege('anon',
 'public.ieadpe_receive_public_intake(jsonb)','EXECUTE') AND
 NOT has_function_privilege('authenticated',
 'public.ieadpe_receive_public_intake(jsonb)','EXECUTE'),
 'pending_intake_is_private: clients cannot call intake');
SELECT pg_temp.assert_true(NOT has_table_privilege('anon','private.public_intake_submissions','SELECT') AND
 NOT has_table_privilege('authenticated','private.public_intake_submissions','SELECT') AND
 NOT has_table_privilege('service_role','private.public_intake_submissions','SELECT'),
 'pending_intake_is_private: no direct queue read grant');

SET LOCAL ROLE anon;
SELECT pg_temp.expect_failure('SELECT count(*) FROM private.public_intake_submissions',
 '42501',NULL,'anon cannot read the pending queue');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_receive_public_intake(''{}''::jsonb)',
 '42501',NULL,'anon cannot call intake');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT pg_temp.expect_failure('SELECT count(*) FROM private.public_intake_submissions',
 '42501',NULL,'authenticated cannot read the pending queue');
SELECT pg_temp.expect_failure('SELECT public.ieadpe_receive_public_intake(''{}''::jsonb)',
 '42501',NULL,'authenticated cannot call intake');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT pg_temp.expect_failure('SELECT count(*) FROM private.public_intake_submissions',
 '42501',NULL,'server role has no direct queue table grant');
RESET ROLE;

CREATE TEMP TABLE intake_clock(value timestamptz NOT NULL);
INSERT INTO intake_clock VALUES(timestamptz '2026-10-25 12:00:00+00');
CREATE OR REPLACE FUNCTION private.public_intake_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT value FROM pg_temp.intake_clock $$;

-- Zero/negative limits and unsafe retention are rejected by constraints.
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET hourly_network_limit=0',
 '23514',NULL,'hourly limit rejects zero');
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET hourly_network_limit=-1',
 '23514',NULL,'hourly limit rejects negative');
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET daily_network_limit=0',
 '23514',NULL,'daily limit rejects zero');
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET global_pending_limit=-1',
 '23514',NULL,'global limit rejects negative');
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET pending_ttl=interval ''0''',
 '23514',NULL,'pending ttl rejects zero');
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET receipt_retention=interval ''29 days''',
 '23514',NULL,'receipt retention below 30 days is rejected');
SELECT pg_temp.expect_failure('UPDATE private.public_intake_settings SET decision_retention=interval ''89 days''',
 '23514',NULL,'decision retention below 90 days is rejected');

-- Strict intake request and canonical draft validation run before any write.
CREATE TEMP TABLE intake_fixture(label text PRIMARY KEY,draft jsonb);
INSERT INTO intake_fixture VALUES
 ('valid',pg_temp.draft('ba000000-0000-4000-8000-000000000001'::uuid,'Ana Silva')),
 ('valid_b',pg_temp.draft('ba000000-0000-4000-8000-000000000002'::uuid,'Bruno Costa'));
CREATE TEMP TABLE intake_dates(label text PRIMARY KEY,value text);
INSERT INTO intake_dates VALUES
 ('today',private.business_today()::text),
 ('future',(private.business_today()+1)::text);
CREATE TEMP TABLE intake_result(label text PRIMARY KEY,value jsonb);
GRANT SELECT ON intake_fixture,intake_dates TO service_role;
GRANT ALL ON intake_result TO service_role;

SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
SET LOCAL ROLE service_role;
DO $$
DECLARE d jsonb:=(SELECT draft FROM intake_fixture WHERE label='valid');
 r jsonb:=pg_temp.request('ce000000-0000-4000-8000-000000000001'::uuid,repeat('a',64),d);
 future text:=(SELECT value FROM intake_dates WHERE label='future');
BEGIN
 PERFORM pg_temp.reject(NULL::jsonb,'invalid_payload','intake rejects null request');
 PERFORM pg_temp.reject('[]'::jsonb,'invalid_payload','intake rejects non-object request');
 PERFORM pg_temp.reject('{}'::jsonb,'invalid_payload','intake rejects missing request keys');
 PERFORM pg_temp.reject(r||'{"extra":true}','invalid_payload','intake rejects unknown request key');
 PERFORM pg_temp.reject(jsonb_set(r,'{submission_id}','"not-a-uuid"'),
  'invalid_payload','intake rejects malformed submission id');
 PERFORM pg_temp.reject(jsonb_set(r,'{submission_id}','null'),
  'invalid_payload','intake rejects null submission id');
 PERFORM pg_temp.reject(jsonb_set(r,'{network_hash}','"ABC"'),
  'invalid_payload','intake rejects short network hash');
 PERFORM pg_temp.reject(jsonb_set(r,'{network_hash}',to_jsonb(repeat('A',64))),
  'invalid_payload','intake rejects uppercase network hash');
 PERFORM pg_temp.reject(jsonb_set(r,'{network_hash}','1'),
  'invalid_payload','intake rejects numeric network hash');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}','null'),
  'invalid_payload','intake rejects null draft');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}','[]'),
  'invalid_payload','intake rejects non-object draft');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',d||'{"status":"pending"}'),
  'invalid_payload','intake rejects draft status field');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',d||'{"created_at":"2026-10-25T00:00:00Z"}'),
  'invalid_payload','intake rejects client timestamp');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',d||'{"actor_id":"00000000-0000-4000-8000-000000000001"}'),
  'invalid_payload','intake rejects actor field');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',d-'congregation_id'),
  'invalid_payload','intake requires congregation id');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',d-'person'),
  'invalid_payload','intake requires person');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',d-'convert'),
  'invalid_payload','intake requires convert');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person}',(d->'person')-'name')),
  'invalid_payload','intake requires person name');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert}',(d->'convert')-'gender')),
  'invalid_payload','intake requires gender');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,photo_asset_id}','null')),
  'invalid_payload','intake rejects person photo reference');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,photo_asset_id}','null')),
  'invalid_payload','intake rejects convert photo reference');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,photo_bytes}','"x"')),
  'invalid_payload','intake rejects photo bytes');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,unknown}','1')),
  'invalid_payload','intake rejects unknown person key');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,unknown}','1')),
  'invalid_payload','intake rejects unknown convert key');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person}',(d->'person')||'{"actor_id":"x"}')),
  'invalid_payload','intake rejects person actor field');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,name}','"   "')),
  'invalid_payload','intake rejects blank name');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,name}','" Ana"')),
  'invalid_payload','intake rejects untrimmed name');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,name}',to_jsonb(repeat('a',201)))),
  'invalid_payload','intake rejects name over 200 characters');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,name}','1')),
  'invalid_payload','intake rejects numeric name');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,phone}','"11999999999"')),
  'invalid_payload','intake rejects non-canonical phone');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,phone}','"+0123"')),
  'invalid_payload','intake rejects phone with zero country code');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,phone}','"+1234567890123456"')),
  'invalid_payload','intake rejects phone over 15 digits');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,phone}','1')),
  'invalid_payload','intake rejects numeric phone');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,birth_date}','"31/12/1990"')),
  'invalid_payload','intake rejects non-ISO birth date');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,birth_date}','"1990-13-01"')),
  'invalid_payload','intake rejects impossible birth date');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,birth_date}','"1990-02-30"')),
  'invalid_payload','intake rejects invalid birth day');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,birth_date}','1')),
  'invalid_payload','intake rejects numeric birth date');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,address}','{"street":"Rua A"}')),
  'invalid_payload','intake rejects incomplete address');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,address}',
  '{"street":"Rua A","district":"Centro","city":"Recife","postal_code":"50000-000","state_code":"PE","extra":1}')),
  'invalid_payload','intake rejects unknown address key');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person,address}','"Rua A"')),
  'invalid_payload','intake rejects string address');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,landmark}','"   "')),
  'invalid_payload','intake rejects blank landmark');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,landmark}','" Praça"')),
  'invalid_payload','intake rejects untrimmed landmark');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,gender}','"other"')),
  'invalid_payload','intake rejects unknown gender');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,worship_type}','"   "')),
  'invalid_payload','intake rejects blank worship type');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,worship_type}','" Culto"')),
  'invalid_payload','intake rejects untrimmed worship type');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,conversion_date}',to_jsonb(future))),
  'invalid_payload','intake rejects future conversion date');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,conversion_date}','"2026-13-01"')),
  'invalid_payload','intake rejects impossible conversion date');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,conversion_date}','1')),
  'invalid_payload','intake rejects numeric conversion date');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,age}','-1')),
  'invalid_payload','intake rejects negative age');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,age}','151')),
  'invalid_payload','intake rejects age over 150');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,age}','1.5')),
  'invalid_payload','intake rejects fractional age');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,age}','"30"')),
  'invalid_payload','intake rejects string age');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert,age}','151.0')),
  'invalid_payload','intake rejects out-of-range fractional age');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{congregation_id}','"not-a-uuid"')),
  'invalid_payload','intake rejects malformed congregation id');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{congregation_id}','"ba000000-0000-4000-8000-000000000099"')),
  'invalid_payload','intake rejects unknown congregation');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{congregation_id}','"ba000000-0000-4000-8000-000000000003"')),
  'invalid_payload','intake rejects archived congregation');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{person}','[]')),
  'invalid_payload','intake rejects non-object person');
 PERFORM pg_temp.reject(jsonb_set(r,'{draft}',jsonb_set(d,'{convert}','[]')),
  'invalid_payload','intake rejects non-object convert');
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM private.public_intake_submissions) AND
 NOT EXISTS(SELECT FROM private.public_intake_receipts) AND
 NOT EXISTS(SELECT FROM private.public_intake_accepted_events),
 'pending_intake_is_private: every rejected request leaves no queue, receipt or event');

-- Accepted submissions for any active congregation; no official rows are written.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES
 ('v1',pg_temp.receive('ca000000-0000-4000-8000-000000000001'::uuid,repeat('1',64),
  (SELECT draft FROM intake_fixture WHERE label='valid'))),
 ('v2',pg_temp.receive('ca000000-0000-4000-8000-000000000002'::uuid,repeat('2',64),
  (SELECT draft FROM intake_fixture WHERE label='valid_b')));
RESET ROLE;

SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='v1')
 AND (SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='v2'),
 'pending_intake_is_private: exact accepted response');
SELECT pg_temp.assert_true(
 (SELECT count(*)=2 AND bool_and(status='pending' AND revision=1 AND payload_erased_at IS NULL)
  FROM private.public_intake_submissions),
 'pending_intake_is_private: two pending rows with initial revision');
SELECT pg_temp.assert_true(
 (SELECT s.congregation_id='ba000000-0000-4000-8000-000000000001' AND
   s.network_hash=repeat('1',64) AND s.draft=(SELECT draft FROM intake_fixture WHERE label='valid') AND
   s.draft_digest=encode(sha256(convert_to(s.draft::text,'UTF8')),'hex') AND
   s.created_at=timestamptz '2026-10-25 12:00:00+00' AND
   s.expires_at=timestamptz '2026-11-24 12:00:00+00'
  FROM private.public_intake_submissions s WHERE s.id='ca000000-0000-4000-8000-000000000001'::uuid),
 'pending_intake_is_private: canonical draft, digest, network and 30-day expiry');
SELECT pg_temp.assert_true(
 (SELECT s.congregation_id='ba000000-0000-4000-8000-000000000002'
  FROM private.public_intake_submissions s WHERE s.id='ca000000-0000-4000-8000-000000000002'::uuid),
 'pending_intake_is_private: intake accepts another active congregation');
SELECT pg_temp.assert_true(
 (SELECT count(*)=2 AND bool_and(to_jsonb(r)-ARRAY['submission_id','draft_digest','created_at','expires_at']='{}'::jsonb
   AND r.expires_at=r.created_at+interval '30 days')
  FROM private.public_intake_receipts r),
 'pending_intake_is_private: receipts are digest-only and expire');
SELECT pg_temp.assert_true(
 (SELECT count(*)=2 AND bool_and(to_jsonb(e)-ARRAY['submission_id','network_hash','accepted_at']='{}'::jsonb)
  FROM private.public_intake_accepted_events e),
 'pending_intake_is_private: accepted events carry only network hash metadata');
SELECT pg_temp.assert_true(
 NOT EXISTS(SELECT FROM public.converts) AND NOT EXISTS(SELECT FROM public.ministry_people) AND
 NOT EXISTS(SELECT FROM private.mutation_receipts) AND NOT EXISTS(SELECT FROM public.photo_assets),
 'pending_intake_is_private: intake writes no official or photo rows');
SELECT pg_temp.assert_true(
 (SELECT NOT (to_jsonb(r)::text ILIKE '%Ana Silva%') FROM private.public_intake_receipts r
  WHERE r.submission_id='ca000000-0000-4000-8000-000000000001'::uuid) AND
 (SELECT NOT (to_jsonb(e)::text ILIKE '%Ana Silva%') FROM private.public_intake_accepted_events e
  WHERE e.submission_id='ca000000-0000-4000-8000-000000000001'::uuid),
 'pending_intake_is_private: receipts and events contain no PII');

-- Replays never consume a second slot; changed payload conflicts.
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES
 ('replay',pg_temp.receive('ca000000-0000-4000-8000-000000000001'::uuid,repeat('1',64),
  (SELECT draft FROM intake_fixture WHERE label='valid'))),
 ('replay_other_network',pg_temp.receive('ca000000-0000-4000-8000-000000000001'::uuid,repeat('9',64),
  (SELECT draft FROM intake_fixture WHERE label='valid'))),
 ('replay_active_b',pg_temp.receive('ca000000-0000-4000-8000-000000000001'::uuid,repeat('1',64),
  (SELECT draft FROM intake_fixture WHERE label='valid')));
SELECT pg_temp.reject(pg_temp.request('ca000000-0000-4000-8000-000000000001'::uuid,repeat('1',64),
 jsonb_set((SELECT draft FROM intake_fixture WHERE label='valid'),'{person,name}','"Changed"'::jsonb)),
 'operation_conflict','pending_intake_is_private: changed payload conflicts');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT bool_and(value='{"status":"received"}'::jsonb)
 FROM intake_result WHERE label IN ('replay','replay_other_network','replay_active_b')),
 'pending_intake_is_private: identical replay returns the safe acknowledgment');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM private.public_intake_submissions) AND
 (SELECT count(*)=2 FROM private.public_intake_receipts) AND
 (SELECT count(*)=2 FROM private.public_intake_accepted_events),
 'pending_intake_is_private: replay creates no row and consumes no slot');

-- Pause blocks new submissions but never blocks an earlier acknowledgement.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('pause_seed',pg_temp.receive('cb000000-0000-4000-8000-000000000001'::uuid,
 repeat('4',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
RESET ROLE;
UPDATE private.public_intake_settings SET enabled=false;
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('pause_replay',pg_temp.receive('cb000000-0000-4000-8000-000000000001'::uuid,
 repeat('4',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
SELECT pg_temp.reject(pg_temp.request('cb000000-0000-4000-8000-000000000002'::uuid,
 repeat('4',64),(SELECT draft FROM intake_fixture WHERE label='valid')),
 'intake_paused','pending_intake_is_private: pause rejects a new submission');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='pause_replay')
 AND (SELECT count(*)=1 FROM private.public_intake_submissions),
 'pending_intake_is_private: pause does not block replay');
UPDATE private.public_intake_settings SET enabled=true,global_pending_limit=1;
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('capacity_replay',pg_temp.receive('cb000000-0000-4000-8000-000000000001'::uuid,
 repeat('4',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
SELECT pg_temp.reject(pg_temp.request('cb000000-0000-4000-8000-000000000003'::uuid,
 repeat('4',64),(SELECT draft FROM intake_fixture WHERE label='valid')),
 'capacity_full','pending_intake_is_private: full capacity rejects a new submission');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='capacity_replay')
 AND (SELECT count(*)=1 FROM private.public_intake_submissions),
 'pending_intake_is_private: full capacity does not block replay');
UPDATE private.public_intake_settings SET global_pending_limit=1000;

-- Expiry frees capacity at exactly the 30-day boundary and clears the payload.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('expiry_seed',pg_temp.receive('cc000000-0000-4000-8000-000000000001'::uuid,
 repeat('c',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
RESET ROLE;
UPDATE private.public_intake_settings SET global_pending_limit=1;
UPDATE intake_clock SET value=timestamptz '2026-11-24 11:59:59+00';
SET LOCAL ROLE service_role;
SELECT pg_temp.reject(pg_temp.request('cc000000-0000-4000-8000-000000000002'::uuid,
 repeat('d',64),(SELECT draft FROM intake_fixture WHERE label='valid')),
 'capacity_full','expiry: active item still counts before 30 days');
RESET ROLE;
UPDATE intake_clock SET value=timestamptz '2026-11-24 12:00:00+00';
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('expiry_new',pg_temp.receive('cc000000-0000-4000-8000-000000000002'::uuid,
 repeat('d',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
INSERT INTO intake_result VALUES('expiry_replay',pg_temp.receive('cc000000-0000-4000-8000-000000000001'::uuid,
 repeat('c',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
RESET ROLE;
SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='expiry_new'),
 'expiry: exact boundary frees the global slot');
SELECT pg_temp.assert_true(
 (SELECT status='expired' AND draft IS NULL AND payload_erased_at=timestamptz '2026-11-24 12:00:00+00'
  FROM private.public_intake_submissions WHERE id='cc000000-0000-4000-8000-000000000001'::uuid),
 'expiry: expired payload is erased by bounded opportunistic cleanup');
SELECT pg_temp.assert_true(
 NOT EXISTS(SELECT FROM private.public_intake_submissions s
  WHERE s.id='cc000000-0000-4000-8000-000000000001'::uuid AND s.status='pending' AND
   s.expires_at>private.public_intake_now()),
 'expiry: expired submits are not actionable');
SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='expiry_replay')
 AND (SELECT count(*)=2 FROM private.public_intake_submissions)
 AND (SELECT count(*)=1 FROM private.public_intake_accepted_events),
 'expiry: replay after expiry still returns the safe acknowledgment without a new row or event');
UPDATE private.public_intake_settings SET global_pending_limit=1000;

-- Bounded cleanup is limited per call and retains pending retry receipts.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
INSERT INTO private.public_intake_submissions(id,congregation_id,network_hash,draft,draft_digest,
 status,created_at,expires_at)
SELECT ('c2000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'ba000000-0000-4000-8000-000000000001'::uuid,repeat('e',64),
 pg_temp.draft('ba000000-0000-4000-8000-000000000001'::uuid,'Expired '||i),repeat('1',64),
 'pending',timestamptz '2026-09-24 12:00:00+00',timestamptz '2026-10-24 12:00:00+00'
FROM generate_series(1,105) i;
DO $$ DECLARE n integer; BEGIN
 n:=private.public_intake_cleanup();
 PERFORM pg_temp.assert_true(n=100,'cleanup: one call expires at most 100 rows');
 PERFORM pg_temp.assert_true((SELECT count(*)=100 FROM private.public_intake_submissions
  WHERE status='expired' AND draft IS NULL AND payload_erased_at=timestamptz '2026-10-25 12:00:00+00'),
  'cleanup: first bounded batch erases payloads');
 n:=private.public_intake_cleanup();
 PERFORM pg_temp.assert_true(n=5,'cleanup: next call expires the remainder');
 PERFORM pg_temp.assert_true((SELECT bool_and(status='expired' AND draft IS NULL)
  FROM private.public_intake_submissions),
  'cleanup: all expired payloads are erased');
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at)
 VALUES('cf000000-0000-4000-8000-000000000001','intake-reviewer@example.test',now());
INSERT INTO private.public_intake_decisions(submission_id,outcome,reviewer_uid,decided_at,retained_until)
 SELECT 'c2000000-0000-4000-8000-000000000001'::uuid,'rejected',
  'cf000000-0000-4000-8000-000000000001'::uuid,timestamptz '2026-07-26 12:00:00+00',
  timestamptz '2026-10-25 11:59:59+00';
INSERT INTO private.public_intake_decisions(submission_id,outcome,reviewer_uid,decided_at,retained_until)
 SELECT 'c2000000-0000-4000-8000-000000000002'::uuid,'rejected',
  'cf000000-0000-4000-8000-000000000001'::uuid,timestamptz '2026-10-25 12:00:00+00',
  timestamptz '2026-10-26 12:00:00+00';
SELECT private.public_intake_cleanup();
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM private.public_intake_decisions WHERE
 submission_id='c2000000-0000-4000-8000-000000000002'::uuid) AND
 NOT EXISTS(SELECT FROM private.public_intake_decisions WHERE
  submission_id='c2000000-0000-4000-8000-000000000001'::uuid),
 'cleanup: decision metadata expires after its retention');

-- Receipt cleanup keeps pending retry safety and falls back to the digest.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('receipt_seed',pg_temp.receive('cd000000-0000-4000-8000-000000000001'::uuid,
 repeat('f',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
INSERT INTO intake_result VALUES('receipt_pending',pg_temp.receive('cd000000-0000-4000-8000-000000000002'::uuid,
 repeat('0',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
RESET ROLE;
UPDATE private.public_intake_submissions SET status='rejected',draft=NULL,
 payload_erased_at=timestamptz '2026-10-25 12:00:00+00'
 WHERE id='cd000000-0000-4000-8000-000000000001'::uuid;
UPDATE private.public_intake_receipts SET created_at=timestamptz '2026-09-24 12:00:00+00',
 expires_at=timestamptz '2026-10-25 11:59:59+00'
 WHERE submission_id IN ('cd000000-0000-4000-8000-000000000001'::uuid,
  'cd000000-0000-4000-8000-000000000002'::uuid);
SELECT private.public_intake_cleanup();
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM private.public_intake_receipts WHERE
 submission_id='cd000000-0000-4000-8000-000000000001'::uuid) AND
 EXISTS(SELECT FROM private.public_intake_receipts WHERE
  submission_id='cd000000-0000-4000-8000-000000000002'::uuid),
 'cleanup: expired receipts go only after a decision, pending retry receipt remains');
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('receipt_fallback',pg_temp.receive('cd000000-0000-4000-8000-000000000001'::uuid,
 repeat('f',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
RESET ROLE;
SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='receipt_fallback')
 AND (SELECT count(*)=2 FROM private.public_intake_submissions)
 AND (SELECT count(*)=2 FROM private.public_intake_accepted_events),
 'cleanup: digest fallback preserves retry safety after receipt expiry');

-- Accepted-event hashes are bounded for the one-day window.
SELECT pg_temp.seed_event('ce000000-0000-4000-8000-000000000010'::uuid,
 'ba000000-0000-4000-8000-000000000001'::uuid,repeat('2',64),
 timestamptz '2026-10-22 12:00:00+00');
SELECT private.public_intake_cleanup();
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM private.public_intake_accepted_events
 WHERE submission_id='ce000000-0000-4000-8000-000000000010'::uuid),
 'cleanup: accepted-event hashes older than the rolling window are removed');

-- Rolling hour: accept 20, reject 21, then roll exactly one hour.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
SET LOCAL ROLE service_role;
DO $$
DECLARE d jsonb:=(SELECT draft FROM intake_fixture WHERE label='valid'); i integer;
BEGIN
 FOR i IN 1..20 LOOP
  PERFORM pg_temp.assert_true(pg_temp.receive(
   ('c1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,repeat('5',64),d)
   ='{"status":"received"}'::jsonb,'rolling hour: accepted submission '||i);
 END LOOP;
 PERFORM pg_temp.reject(pg_temp.request('c1000000-0000-4000-8000-000000000021'::uuid,
  repeat('5',64),d),'rate_limited','rolling hour: 21st is rejected');
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=20 FROM private.public_intake_submissions) AND
 (SELECT count(*)=20 FROM private.public_intake_accepted_events),
 'rolling hour: exactly 20 accepted slots');
UPDATE intake_clock SET value=timestamptz '2026-10-25 13:00:00+00';
SET LOCAL ROLE service_role;
INSERT INTO intake_result VALUES('hour_roll',pg_temp.receive('c1000000-0000-4000-8000-000000000021'::uuid,
 repeat('5',64),(SELECT draft FROM intake_fixture WHERE label='valid')));
RESET ROLE;
SELECT pg_temp.assert_true((SELECT value='{"status":"received"}'::jsonb FROM intake_result WHERE label='hour_roll')
 AND (SELECT count(*)=1 FROM private.public_intake_accepted_events e
  WHERE e.network_hash=repeat('5',64) AND e.accepted_at>timestamptz '2026-10-25 12:00:00+00'),
 'rolling hour: an event exactly one hour old is outside the window');

-- Exact rolling-hour boundaries: -1s and 0 are excluded, +1s is included.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
DO $$ DECLARE i integer; BEGIN
 FOR i IN 1..20 LOOP
  PERFORM pg_temp.seed_event(('c3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('6',64),
   timestamptz '2026-10-25 12:00:00+00'-interval '1 hour'-interval '1 second');
  PERFORM pg_temp.seed_event(('c3100000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('7',64),
   timestamptz '2026-10-25 12:00:00+00'-interval '1 hour');
  PERFORM pg_temp.seed_event(('c3200000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('8',64),
   timestamptz '2026-10-25 12:00:00+00'-interval '1 hour'+interval '1 second');
 END LOOP;
END $$;
SET LOCAL ROLE service_role;
DO $$
DECLARE d jsonb:=(SELECT draft FROM intake_fixture WHERE label='valid');
BEGIN
 PERFORM pg_temp.assert_true(pg_temp.receive('c3300000-0000-4000-8000-000000000001'::uuid,
  repeat('6',64),d)='{"status":"received"}'::jsonb,
  'rolling hour: events older than 1 hour are outside');
 PERFORM pg_temp.reject(pg_temp.request('c3300000-0000-4000-8000-000000000002'::uuid,
  repeat('8',64),d),'rate_limited','rolling hour: event 1 second inside counts');
 PERFORM pg_temp.assert_true(pg_temp.receive('c3300000-0000-4000-8000-000000000003'::uuid,
  repeat('7',64),d)='{"status":"received"}'::jsonb,
  'rolling hour: event exactly 1 hour old is outside');
END $$;
RESET ROLE;

-- Rolling day: 199 accepted, 200th accepted, 201st rejected, with exact boundary.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
UPDATE private.public_intake_settings SET hourly_network_limit=1000,daily_network_limit=200;
DO $$ DECLARE i integer; BEGIN
 FOR i IN 1..199 LOOP
  PERFORM pg_temp.seed_event(('c4000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('b',64),
   timestamptz '2026-10-25 10:00:00+00');
 END LOOP;
 FOR i IN 1..200 LOOP
  PERFORM pg_temp.seed_event(('c4100000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('c',64),
   timestamptz '2026-10-24 12:00:00+00');
  PERFORM pg_temp.seed_event(('c4200000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('d',64),
   timestamptz '2026-10-24 12:00:01+00');
  PERFORM pg_temp.seed_event(('c4300000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'ba000000-0000-4000-8000-000000000001'::uuid,repeat('e',64),
   timestamptz '2026-10-24 12:00:00+00'+interval '1 minute');
 END LOOP;
END $$;
SET LOCAL ROLE service_role;
DO $$
DECLARE d jsonb:=(SELECT draft FROM intake_fixture WHERE label='valid');
BEGIN
 PERFORM pg_temp.assert_true(pg_temp.receive('c4400000-0000-4000-8000-000000000001'::uuid,
  repeat('b',64),d)='{"status":"received"}'::jsonb,'rolling day: 200th accepted');
 PERFORM pg_temp.reject(pg_temp.request('c4400000-0000-4000-8000-000000000002'::uuid,
  repeat('b',64),d),'rate_limited','rolling day: 201st rejected');
 PERFORM pg_temp.assert_true(pg_temp.receive('c4400000-0000-4000-8000-000000000003'::uuid,
  repeat('c',64),d)='{"status":"received"}'::jsonb,
  'rolling day: event exactly 1 day old is outside');
 PERFORM pg_temp.reject(pg_temp.request('c4400000-0000-4000-8000-000000000004'::uuid,
  repeat('d',64),d),'rate_limited','rolling day: event 1 second inside counts');
 PERFORM pg_temp.reject(pg_temp.request('c4400000-0000-4000-8000-000000000005'::uuid,
  repeat('e',64),d),'rate_limited','rolling day: event later inside the day counts');
END $$;
RESET ROLE;

-- Global capacity: the 1000th active pending is accepted, the 1001st is not.
SELECT pg_temp.reset_intake(timestamptz '2026-10-25 12:00:00+00');
UPDATE private.public_intake_settings SET hourly_network_limit=1000,daily_network_limit=1000,
 global_pending_limit=1000;
INSERT INTO private.public_intake_submissions(id,congregation_id,network_hash,draft,draft_digest,
 status,created_at,expires_at)
SELECT ('d1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'ba000000-0000-4000-8000-000000000001'::uuid,repeat('3',64),
 pg_temp.draft('ba000000-0000-4000-8000-000000000001'::uuid,'Seed '||i),repeat('2',64),
 'pending',timestamptz '2026-10-25 12:00:00+00',timestamptz '2026-11-24 12:00:00+00'
FROM generate_series(1,999) i;
SET LOCAL ROLE service_role;
DO $$
DECLARE d jsonb:=(SELECT draft FROM intake_fixture WHERE label='valid');
BEGIN
 PERFORM pg_temp.assert_true(pg_temp.receive('d2000000-0000-4000-8000-000000000001'::uuid,
  repeat('4',64),d)='{"status":"received"}'::jsonb,'global capacity: 1000th accepted');
 PERFORM pg_temp.reject(pg_temp.request('d2000000-0000-4000-8000-000000000002'::uuid,
  repeat('5',64),d),'capacity_full','global capacity: 1001st rejected');
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=1000 FROM private.public_intake_submissions
 WHERE status='pending' AND expires_at>private.public_intake_now()),
 'global capacity: exactly 1000 active pending rows, no overshoot');

ROLLBACK;
