BEGIN;
CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT CASE WHEN private.report_week(now()) IS NULL THEN now()-interval '1 day' ELSE now() END $$;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('70000000-0000-0000-0000-000000000001','optional-worship@example.test',now());
INSERT INTO private.admin_allowlist(user_id) VALUES('70000000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES
 ('71000000-0000-0000-0000-000000000001','Optional Worship');
SELECT set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);

CREATE TEMP TABLE created(value jsonb);
GRANT ALL ON created TO authenticated;
SET LOCAL ROLE authenticated;
INSERT INTO created SELECT public.ieadpe_create_convert(
 '72000000-0000-0000-0000-000000000001',
 '{"congregation_id":"71000000-0000-0000-0000-000000000001",
   "person":{"name":"No worship selected"},
   "convert":{"landmark":"Square","gender":"female","conversion_date":"2020-01-01","worship_type":null}}');
SELECT pg_temp.assert_true((SELECT value ? 'id' FROM created),'optional worship create returns ID');
SELECT pg_temp.assert_true(public.ieadpe_create_convert(
 '72000000-0000-0000-0000-000000000001',
 '{"congregation_id":"71000000-0000-0000-0000-000000000001",
   "person":{"name":"No worship selected"},
   "convert":{"landmark":"Square","gender":"female","conversion_date":"2020-01-01","worship_type":null}}')=(SELECT value FROM created),
 'retry with identical null worship payload returns the original result');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT worship_type IS NULL FROM public.converts
 WHERE id=(SELECT (value->>'id')::uuid FROM created)),'null worship persisted');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'null worship retry creates one convert');

SET LOCAL ROLE authenticated;
SELECT public.ieadpe_edit_convert('72000000-0000-0000-0000-000000000002',jsonb_build_object(
 'id',(SELECT value->>'id' FROM created),
 'congregation_id','71000000-0000-0000-0000-000000000001',
 'expected_revision',1,'expected_person_revision',1,
 'person',jsonb_build_object('name','No worship selected'),
 'convert',jsonb_build_object('landmark','Square','gender','female','conversion_date','2020-01-01','worship_type',NULL)));
RESET ROLE;
SELECT pg_temp.assert_true((SELECT worship_type IS NULL AND revision=2 FROM public.converts
 WHERE id=(SELECT (value->>'id')::uuid FROM created)),'edit may retain or set worship to null');

-- Missing worship_type is also valid for compatible callers. Non-null strings
-- retain their exact historical value; empty strings and other JSON types fail.
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; candidate jsonb; bad_value jsonb; BEGIN
 p:='{"congregation_id":"71000000-0000-0000-0000-000000000001",
  "person":{"name":"Legacy worship"},
  "convert":{"landmark":"Square","gender":"male","conversion_date":"2020-01-02","worship_type":"Culto antigo"}}';
 PERFORM public.ieadpe_create_convert('72000000-0000-0000-0000-000000000003',p);
 FOR bad_value IN SELECT unnest(ARRAY['""'::jsonb,'"   "'::jsonb,'"\t"'::jsonb,
  U&'"\00a0"'::jsonb,'17'::jsonb]) LOOP
  candidate:=jsonb_set(p,'{convert,worship_type}',bad_value);
  BEGIN
   PERFORM public.ieadpe_create_convert(gen_random_uuid(),candidate);
   RAISE EXCEPTION 'ASSERTION: invalid worship value accepted: %',bad_value;
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT worship_type='Culto antigo' FROM public.converts
 WHERE person_id=(SELECT id FROM public.ministry_people WHERE name='Legacy worship')),'existing worship string is preserved');

-- The legacy command is retained for old clients, with the same validation,
-- authorization, receipt replay and guard behavior.
SELECT pg_temp.assert_true((private.convert_command('create_convert',
 '72000000-0000-0000-0000-000000000004',
 '{"name":"Legacy RPC","landmark":"Square","gender":"male","conversion_date":"2020-01-03","worship_type":null,"congregation_id":"71000000-0000-0000-0000-000000000001"}') ? 'id'),
 'legacy create command accepts null worship');
SELECT pg_temp.assert_true(private.convert_command('create_convert',
 '72000000-0000-0000-0000-000000000004',
 '{"name":"Legacy RPC","landmark":"Square","gender":"male","conversion_date":"2020-01-03","worship_type":null,"congregation_id":"71000000-0000-0000-0000-000000000001"}')=
 (SELECT result FROM private.mutation_receipts WHERE operation_id='72000000-0000-0000-0000-000000000004'),
 'legacy create retry replays its receipt');
SELECT pg_temp.assert_true((SELECT (c.revision=1) FROM public.converts c
 JOIN private.mutation_receipts r ON r.result->>'id'=c.id::text
 WHERE r.operation_id='72000000-0000-0000-0000-000000000004'),
 'legacy create initializes revision to the schema default');
CREATE FUNCTION pg_temp.legacy_rejects_invalid_worship(value jsonb) RETURNS boolean
LANGUAGE plpgsql AS $$
BEGIN
 PERFORM private.convert_command('create_convert',gen_random_uuid(),jsonb_build_object(
  'name','Invalid legacy','landmark','Square','gender','male','conversion_date','2020-01-03',
  'worship_type',value,'congregation_id','71000000-0000-0000-0000-000000000001'));
 RETURN false;
EXCEPTION WHEN invalid_parameter_value THEN RETURN true;
END $$;
SELECT pg_temp.assert_true(pg_temp.legacy_rejects_invalid_worship(value),
 'legacy command rejects blank and non-string worship')
FROM (VALUES ('""'::jsonb),('"   "'::jsonb),('"\t"'::jsonb),
 (U&'"\00a0"'::jsonb),('17'::jsonb)) AS invalid(value);

CREATE TEMP TABLE imported(value jsonb);
GRANT ALL ON imported TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ DECLARE response jsonb; p jsonb; omitted jsonb; bad jsonb; BEGIN
 p:='{"internal_id":"optional-worship-import","name":"Imported","landmark":"Square","gender":"female","conversion_date":"2020-01-04","worship_type":null,"congregation_name":"Optional Worship"}';
 response:=public.ieadpe_import_convert('72000000-0000-0000-0000-000000000005',p);
 PERFORM pg_temp.assert_true(response->>'status'='created','import accepts explicit null worship');
 INSERT INTO imported VALUES(response);
 omitted:=p-'worship_type'||jsonb_build_object('internal_id','optional-worship-import-omitted');
 response:=public.ieadpe_import_convert('72000000-0000-0000-0000-000000000007',omitted);
 PERFORM pg_temp.assert_true(response->>'status'='created','import accepts omitted worship key');
 INSERT INTO imported VALUES(response);
 response:=public.ieadpe_import_convert('72000000-0000-0000-0000-000000000006',
  p||'{"internal_id":"optional-worship-import-old","worship_type":"Culto antigo"}');
 INSERT INTO imported VALUES(response);
 FOR bad IN SELECT unnest(ARRAY['""'::jsonb,'"   "'::jsonb,'"\t"'::jsonb,
  U&'"\00a0"'::jsonb,'17'::jsonb]) LOOP
  BEGIN
   PERFORM public.ieadpe_import_convert(gen_random_uuid(),
    jsonb_set(p,'{internal_id}','"invalid-worship-import"'::jsonb)||jsonb_build_object('worship_type',bad));
   RAISE EXCEPTION 'ASSERTION: importer accepted invalid worship value: %',bad;
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT worship_type IS NULL FROM public.converts WHERE internal_id='optional-worship-import'),
 'import persists explicit null worship');
SELECT pg_temp.assert_true((SELECT worship_type IS NULL FROM public.converts WHERE internal_id='optional-worship-import-omitted'),
 'import persists omitted worship key as null');
SELECT pg_temp.assert_true((SELECT worship_type='Culto antigo' FROM public.converts WHERE internal_id='optional-worship-import-old'),
 'import preserves existing worship string');
DO $$ BEGIN
 BEGIN
  INSERT INTO public.converts(internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id)
   VALUES('invalid-empty-worship','Invalid','Square','male','2020-01-05','','71000000-0000-0000-0000-000000000001');
  RAISE EXCEPTION 'ASSERTION: table constraint accepted an empty worship string';
 EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
ROLLBACK;
