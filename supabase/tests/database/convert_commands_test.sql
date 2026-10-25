BEGIN;
-- This predecessor command scenario needs an open reporting window on every host day.
-- The dedicated weekly fixture separately proves closed-window rejection.
CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT CASE WHEN private.report_week(now()) IS NULL THEN now()-interval '1 day' ELSE now() END $$;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('50000000-0000-0000-0000-000000000001','registrar@example.test',now()),
 ('50000000-0000-0000-0000-000000000002','manager@example.test',now()),
 ('50000000-0000-0000-0000-000000000003','direction@example.test',now());
INSERT INTO private.admin_allowlist VALUES('50000000-0000-0000-0000-000000000002');
INSERT INTO public.congregations(id,name) VALUES
 ('51000000-0000-0000-0000-000000000001','Synthetic A'),
 ('51000000-0000-0000-0000-000000000002','Synthetic B'),
 ('51000000-0000-0000-0000-000000000003','Synthetic Registrar');
-- Approved policy: immediate creation requires matching authority. The local
-- direction fixture covers both created scopes; the no-grant registrar keeps
-- the read-denial and receipt-isolation assertions below.
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('direction@example.test','50000000-0000-0000-0000-000000000003','Membro da direção da campanha','51000000-0000-0000-0000-000000000001'),
 ('direction@example.test','50000000-0000-0000-0000-000000000003','Membro da direção da campanha','51000000-0000-0000-0000-000000000003');
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
-- Keep the scoped smoke create outside A/B so the weekly guard assertions
-- below still isolate the convert whose date is moved within its own scope.
SELECT pg_temp.assert_true(public.ieadpe_create_convert(gen_random_uuid(),
 '{"congregation_id":"51000000-0000-0000-0000-000000000003",
   "person":{"name":"Synthetic","phone":null,"birth_date":null,"address":null},
   "convert":{"landmark":"Square","gender":"male","conversion_date":"2020-01-01","worship_type":"01 - Oração"}}') ? 'id',
 'scoped registration returns a persisted ID');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'registration persists exactly one convert');
CREATE TEMP TABLE result(value jsonb);
CREATE TEMP TABLE request(value jsonb);
CREATE TEMP TABLE last_edit(value jsonb);
GRANT ALL ON result,request,last_edit TO authenticated;
SET LOCAL ROLE authenticated;
INSERT INTO request VALUES(jsonb_build_object(
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'person',jsonb_build_object('name','Synthetic','phone',NULL,'birth_date',NULL,'address',NULL),
 'convert',jsonb_build_object('landmark','Square','gender','female','conversion_date','2020-01-01',
  'worship_type','01 - Oração','age',0,'photo_asset_id',NULL)));
INSERT INTO result SELECT public.ieadpe_create_convert('52000000-0000-0000-0000-000000000001',
 (SELECT value FROM request));
SELECT pg_temp.assert_true((SELECT value FROM result)=public.ieadpe_create_convert('52000000-0000-0000-0000-000000000001',
 jsonb_build_object('convert',(SELECT value->'convert' FROM request),
  'person',(SELECT value->'person' FROM request),
  'congregation_id',(SELECT value->>'congregation_id' FROM request))),
 'canonical retry returns original result');
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.converts),'no-grant registrar cannot enumerate even after authorized creation');
SELECT pg_temp.assert_true((SELECT value ?& ARRAY['id','person_id','revision','person_revision']
 AND value-ARRAY['id','person_id','revision','person_revision']='{}'::jsonb
 AND (value->>'revision')::integer=1 AND (value->>'person_revision')::integer=1
 AND value->>'id'<>value->>'person_id' FROM result),
 'create result contains exact typed IDs and revisions');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.converts),'retry creates no second record');
SELECT pg_temp.assert_true((SELECT worship_type=U&'01 - Ora\00e7\00e3o' AND gender='female'
 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)), 'source wire values survive UTF-8 SQL fixtures exactly');
SELECT pg_temp.assert_true((SELECT last_visit_date=conversion_date AND visit_count=0 AND NOT was_visited_once
 AND NOT is_in_discipleship AND NOT is_discipleship_completed AND NOT is_deviated
 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)), 'server initializes source lifecycle fields');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
DO $$ DECLARE bad jsonb; base jsonb:=jsonb_build_object(
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'person',jsonb_build_object('name','Synthetic','phone',NULL,'birth_date',NULL,'address',NULL),
 'convert',jsonb_build_object('landmark','Square','gender','male','conversion_date','2020-01-01',
  'worship_type','01 - Oração')); BEGIN
 FOR bad IN SELECT unnest(ARRAY[
  jsonb_set(base,'{person,name}','" "'::jsonb),
  jsonb_set(base,'{person,name}','"\t"'::jsonb),
  jsonb_set(base,'{person,name}','"Synthetic\n"'::jsonb),
  jsonb_set(base,'{convert,landmark}','"\n"'::jsonb),
  jsonb_set(base,'{convert,worship_type}','"\r"'::jsonb),
  jsonb_set(base,'{person,name}','"\u00a0"'::jsonb),
  jsonb_set(base,'{convert,landmark}','"\ufeffSquare"'::jsonb),
  jsonb_set(base,'{convert,landmark}','null'::jsonb),
  jsonb_set(base,'{convert,gender}','"other"'::jsonb),
  jsonb_set(base,'{convert,age}','151'::jsonb),
  jsonb_set(base,'{convert,age}','-1'::jsonb),
  jsonb_set(base,'{convert,age}','"12"'::jsonb),
  jsonb_set(base,'{person,phone}','12'::jsonb),
  jsonb_set(base,'{person,address}','{}'::jsonb),
  base||jsonb_build_object('created_by',NULL),
  base||jsonb_build_object('visit_count',1),
  base||jsonb_build_object('last_visit_date','2020-01-01'),
  base||jsonb_build_object('photo_url','https://example.test/x'),
  base||jsonb_build_object('internal_id','override'),
  jsonb_set(base,'{convert,conversion_date}','"2999-01-01"'::jsonb)]) LOOP
  BEGIN PERFORM public.ieadpe_create_convert(gen_random_uuid(),bad);
   RAISE EXCEPTION 'ASSERTION: invalid source/server field accepted: %',bad;
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
 BEGIN PERFORM public.ieadpe_create_convert('52000000-0000-0000-0000-000000000001',base);
  RAISE EXCEPTION 'ASSERTION: changed operation payload accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object(
  'id',(SELECT value->>'id' FROM result),
  'congregation_id','51000000-0000-0000-0000-000000000001',
  'expected_revision',1,'expected_person_revision',1,
  'person',jsonb_set((SELECT value->'person' FROM request),'{name}','"Denied"'::jsonb),
  'convert',(SELECT value->'convert' FROM request)));
  RAISE EXCEPTION 'ASSERTION: no-grant registrar edited protected record'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object(
  'id',(SELECT value->>'id' FROM result),
  'congregation_id','51000000-0000-0000-0000-000000000002',
  'expected_revision',1,'expected_person_revision',1,
  'person',(SELECT value->'person' FROM request),
  'convert',(SELECT value->'convert' FROM request)));
  RAISE EXCEPTION 'ASSERTION: direction moved outside authorized destination'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- Another actor may use the same operation ID without receiving the direction receipt.
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
SELECT public.ieadpe_edit_convert('52000000-0000-0000-0000-000000000001',jsonb_build_object(
 'id',(SELECT value->>'id' FROM result),
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'expected_revision',1,'expected_person_revision',1,
 'person',jsonb_set((SELECT value->'person' FROM request),'{name}','"Other actor"'::jsonb),
 'convert',(SELECT value->'convert' FROM request)));
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
UPDATE request SET value=jsonb_build_object(
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'person',jsonb_set(value->'person','{name}','"Updated"'::jsonb),
 'convert',value->'convert');
INSERT INTO last_edit VALUES(jsonb_build_object(
 'id',(SELECT value->>'id' FROM result),
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'expected_revision',2,'expected_person_revision',2,
 'person',(SELECT value->'person' FROM request),
 'convert',(SELECT value->'convert' FROM request)));
SELECT public.ieadpe_edit_convert('52000000-0000-0000-0000-000000000002',(SELECT value FROM last_edit));
UPDATE request SET value=jsonb_build_object(
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'person',value->'person','convert',value->'convert');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_delete_convert('52000000-0000-0000-0000-000000000002',
  jsonb_build_object('id',(SELECT value->>'id' FROM result)));
  RAISE EXCEPTION 'ASSERTION: same actor operation reused across commands'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;
DELETE FROM public.user_access WHERE user_id='50000000-0000-0000-0000-000000000003';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_edit_convert('52000000-0000-0000-0000-000000000002',(SELECT value FROM last_edit));
  RAISE EXCEPTION 'ASSERTION: revoked direction replayed receipt'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
SELECT public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object(
 'id',(SELECT value->>'id' FROM result),
 'congregation_id','51000000-0000-0000-0000-000000000001',
 'expected_revision',3,'expected_person_revision',3,
 'person',(SELECT value->'person' FROM request),
 'convert',jsonb_set((SELECT value->'convert' FROM request),'{conversion_date}','"2020-01-08"'::jsonb)));
RESET ROLE;
CREATE TEMP TABLE receipt_baseline(value bigint);
INSERT INTO receipt_baseline SELECT count(*) FROM private.mutation_receipts;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object(
  'id',(SELECT value->>'id' FROM result),
  'congregation_id','51000000-0000-0000-0000-000000000002',
  'expected_revision',4,'expected_person_revision',3,
  'person',(SELECT value->'person' FROM request),
  'convert',jsonb_set((SELECT value->'convert' FROM request),'{conversion_date}','"2020-01-08"'::jsonb)));
  RAISE EXCEPTION 'ASSERTION: cross-congregation edit accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=(SELECT value FROM receipt_baseline) FROM private.mutation_receipts),
 'rejected cross-scope edit inserts no mutation receipt');
SELECT pg_temp.assert_true((SELECT conversion_count=0 FROM private.congregation_week_guards WHERE congregation_id='51000000-0000-0000-0000-000000000001' AND week_start='2019-12-30'),'date move decrements old week');
SELECT pg_temp.assert_true((SELECT conversion_count=1 FROM private.congregation_week_guards WHERE congregation_id='51000000-0000-0000-0000-000000000001' AND week_start='2020-01-06'),'date move increments destination week');
SELECT pg_temp.assert_true((SELECT congregation_id='51000000-0000-0000-0000-000000000001' AND revision=4
 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)),'rejected retarget keeps the convert in its original scope');
SELECT pg_temp.assert_true((SELECT age=0 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)),'age zero preserved');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('direction@example.test','50000000-0000-0000-0000-000000000003','Membro da direção da campanha','51000000-0000-0000-0000-000000000001');
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
RESET ROLE;
SELECT pg_temp.assert_true(private.report_week('2026-10-19 00:00:00+00')='2026-10-12','Sunday after 20:00 Sao Paulo opens completed week');
SELECT pg_temp.assert_true(private.report_week('2026-10-18 22:59:59+00') IS NULL,'Sunday before 20:00 closes fresh confirmation');
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_delete_convert('52000000-0000-0000-0000-000000000003',
 jsonb_build_object('id',(SELECT value->>'id' FROM result)));
SELECT pg_temp.assert_true(public.ieadpe_delete_convert('52000000-0000-0000-0000-000000000003',
 jsonb_build_object('id',(SELECT value->>'id' FROM result)))=jsonb_build_object('id',(SELECT value->>'id' FROM result)),
 'delete replay returns original ID');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT deleted_at IS NOT NULL AND internal_id=id::text FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)),'tombstone retains unique internal ID');
SELECT pg_temp.assert_true((SELECT conversion_count=0 FROM private.congregation_week_guards WHERE congregation_id='51000000-0000-0000-0000-000000000001' AND week_start='2020-01-06'),'delete decrements moved week guard');
DO $$ BEGIN
 BEGIN INSERT INTO public.converts(internal_id,name,landmark,gender,conversion_date,worship_type)
 SELECT value->>'id','Duplicate','Square','male','2020-01-01','01 - Oração' FROM result;
 RAISE EXCEPTION 'ASSERTION: tombstone internal ID reused'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
-- Latest completed week comes from server time; clients cannot choose a week.
DO $$ DECLARE report_a jsonb; report_b jsonb; created jsonb; wk date:=private.report_week(private.weekly_now());
 payload jsonb; edit_payload jsonb; before_receipts bigint; BEGIN
 PERFORM set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
 report_a:=public.ieadpe_confirm_zero('52000000-0000-0000-0000-000000000004',
  '{"congregation_id":"51000000-0000-0000-0000-000000000001"}');
 BEGIN PERFORM public.ieadpe_confirm_zero(gen_random_uuid(),
  '{"congregation_id":"51000000-0000-0000-0000-000000000002"}');
  RAISE EXCEPTION 'ASSERTION: direction confirmed another scope'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
 report_b:=public.ieadpe_confirm_zero('52000000-0000-0000-0000-000000000005',
  '{"congregation_id":"51000000-0000-0000-0000-000000000002"}');
 payload:=jsonb_build_object(
  'congregation_id','51000000-0000-0000-0000-000000000001',
  'person',jsonb_build_object('name','Weekly','phone',NULL,'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Square','gender','male','conversion_date',wk,
   'worship_type','01 - Oração','age',NULL,'photo_asset_id',NULL));
 created:=public.ieadpe_create_convert(gen_random_uuid(),payload);
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.weekly_reports WHERE id=(report_a->>'id')::uuid),
  'create atomically removes matching zero report');
 PERFORM pg_temp.assert_true(EXISTS(SELECT FROM public.weekly_reports WHERE id=(report_b->>'id')::uuid),
  'unrelated scope report is preserved');
 SELECT count(*) INTO before_receipts FROM private.mutation_receipts;
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object(
  'id',created->>'id','congregation_id','51000000-0000-0000-0000-000000000001',
  'expected_revision',1,'expected_person_revision',1,'person',payload->'person',
  'convert',jsonb_set(payload->'convert','{conversion_date}','"2999-01-01"'::jsonb)));
  RAISE EXCEPTION 'ASSERTION: future edit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT conversion_date=wk FROM public.converts WHERE id=(created->>'id')::uuid)
  AND (SELECT count(*)=before_receipts FROM private.mutation_receipts),'rejected edit leaves record and receipts unchanged');
 PERFORM public.ieadpe_delete_convert(gen_random_uuid(),jsonb_build_object('id',created->>'id'));
 payload:=jsonb_build_object(
  'congregation_id','51000000-0000-0000-0000-000000000002',
  'person',jsonb_build_object('name','Weekly B','phone',NULL,'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Square','gender','female','conversion_date',wk-7,
   'worship_type','01 - Oração','age',NULL,'photo_asset_id',NULL));
 created:=public.ieadpe_create_convert(gen_random_uuid(),payload);
 PERFORM pg_temp.assert_true(EXISTS(SELECT FROM public.weekly_reports WHERE id=(report_b->>'id')::uuid),
  'different-week create preserves matching zero report');
 edit_payload:=jsonb_build_object('id',created->>'id',
  'congregation_id','51000000-0000-0000-0000-000000000002',
  'expected_revision',1,'expected_person_revision',1,'person',payload->'person',
  'convert',jsonb_set(payload->'convert','{conversion_date}',to_jsonb(wk::text)));
 PERFORM public.ieadpe_edit_convert(gen_random_uuid(),edit_payload);
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.weekly_reports WHERE id=(report_b->>'id')::uuid),
  'date move atomically removes destination zero report');
 PERFORM public.ieadpe_delete_convert(gen_random_uuid(),jsonb_build_object('id',created->>'id'));
 PERFORM pg_temp.assert_true((SELECT coalesce(sum(conversion_count),0)=0 FROM private.congregation_week_guards
  WHERE congregation_id IN ('51000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002')
   AND week_start=wk),'weekly delete restores count zero');
END $$;
ROLLBACK;
