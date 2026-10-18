BEGIN;
-- This predecessor command scenario needs an open reporting window on every host day.
-- The dedicated weekly fixture separately proves closed-window rejection.
CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT CASE WHEN private.report_week(now()) IS NULL THEN now()-interval '1 day' ELSE now() END $$;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('50000000-0000-0000-0000-000000000001','registrar@example.test',now());
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true(public.ieadpe_create_convert(gen_random_uuid(),
 '{"name":"Synthetic","landmark":"Square","gender":"male","conversion_date":"2020-01-01","worship_type":"01 - Oração"}') ? 'id',
 'authenticated registration returns a persisted ID');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'registration persists exactly one convert');
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('50000000-0000-0000-0000-000000000002','manager@example.test',now()),
 ('50000000-0000-0000-0000-000000000003','direction@example.test',now());
INSERT INTO private.admin_allowlist VALUES('50000000-0000-0000-0000-000000000002');
INSERT INTO public.congregations(id,name) VALUES
 ('51000000-0000-0000-0000-000000000001','Synthetic A'),('51000000-0000-0000-0000-000000000002','Synthetic B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('direction@example.test','50000000-0000-0000-0000-000000000003','Membro da direção da campanha','51000000-0000-0000-0000-000000000001');
CREATE TEMP TABLE result(value jsonb);
GRANT ALL ON result TO authenticated;
SET LOCAL ROLE authenticated;
INSERT INTO result SELECT public.ieadpe_create_convert('52000000-0000-0000-0000-000000000001',
 '{"name":"Synthetic","landmark":"Square","gender":"female","conversion_date":"2020-01-01","worship_type":"01 - Oração","age":0,"congregation_id":"51000000-0000-0000-0000-000000000001"}');
SELECT pg_temp.assert_true((SELECT value FROM result)=public.ieadpe_create_convert('52000000-0000-0000-0000-000000000001',
 '{"age":0,"name":"Synthetic","landmark":"Square","gender":"female","conversion_date":"2020-01-01","worship_type":"01 - Oração","congregation_id":"51000000-0000-0000-0000-000000000001"}'),'canonical retry returns original result');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.converts),'registrar cannot enumerate even after creation');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM result,jsonb_object_keys(value)),'create result contains ID only');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.converts),'retry creates no second record');
SELECT pg_temp.assert_true((SELECT worship_type=U&'01 - Ora\00e7\00e3o' AND gender='female'
 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)), 'source wire values survive UTF-8 SQL fixtures exactly');
SELECT pg_temp.assert_true((SELECT last_visit_date=conversion_date AND visit_count=0 AND NOT was_visited_once
 AND NOT is_in_discipleship AND NOT is_discipleship_completed AND NOT is_deviated
 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)), 'server initializes source lifecycle fields');
SET LOCAL ROLE authenticated;
DO $$ DECLARE bad jsonb; base jsonb:='{"name":"Synthetic","landmark":"Square","gender":"male","conversion_date":"2020-01-01","worship_type":"01 - Oração"}'; BEGIN
 FOR bad IN SELECT unnest(ARRAY[
 '{"name":" "}'::jsonb,'{"name":"\t"}','{"name":"Synthetic\n"}','{"landmark":"\n"}','{"worship_type":"\r"}',
 '{"name":"\u00a0"}','{"landmark":"\ufeffSquare"}',
 '{"landmark":null}','{"gender":"other"}','{"age":151}','{"age":-1}','{"age":"12"}',
 '{"phone":12}','{"address":{}}','{"created_by":null}','{"visit_count":1}','{"last_visit_date":"2020-01-01"}',
 '{"photo_url":"https://example.test/x"}','{"internal_id":"override"}','{"conversion_date":"2999-01-01"}']) LOOP
  BEGIN PERFORM public.ieadpe_create_convert(gen_random_uuid(),base||bad);
   RAISE EXCEPTION 'ASSERTION: invalid source/server field accepted: %',bad;
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
 BEGIN PERFORM public.ieadpe_create_convert('52000000-0000-0000-0000-000000000001',base);
  RAISE EXCEPTION 'ASSERTION: changed operation payload accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object('id',(SELECT value->>'id' FROM result),'name','Denied'));
  RAISE EXCEPTION 'ASSERTION: registrar edited protected record'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),(SELECT value FROM result)||'{"congregation_id":"51000000-0000-0000-0000-000000000002"}');
  RAISE EXCEPTION 'ASSERTION: direction moved outside authorized destination'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- Another actor may use the same operation ID without receiving the registrar receipt.
SELECT public.ieadpe_edit_convert('52000000-0000-0000-0000-000000000001',(SELECT value FROM result)||'{"name":"Other actor"}');
SELECT public.ieadpe_edit_convert('52000000-0000-0000-0000-000000000002',(SELECT value FROM result)||'{"name":"Updated"}');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_delete_convert('52000000-0000-0000-0000-000000000002',(SELECT value FROM result));
  RAISE EXCEPTION 'ASSERTION: same actor operation reused across commands'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;
DELETE FROM public.user_access WHERE user_id='50000000-0000-0000-0000-000000000003';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_edit_convert('52000000-0000-0000-0000-000000000002',(SELECT value FROM result)||'{"name":"Updated"}');
  RAISE EXCEPTION 'ASSERTION: revoked direction replayed receipt'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
SELECT public.ieadpe_edit_convert(gen_random_uuid(),(SELECT value FROM result)||'{"congregation_id":"51000000-0000-0000-0000-000000000002","conversion_date":"2020-01-08"}');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT conversion_count=0 FROM private.congregation_week_guards WHERE congregation_id='51000000-0000-0000-0000-000000000001' AND week_start='2019-12-30'),'move decrements old week');
SELECT pg_temp.assert_true((SELECT conversion_count=1 FROM private.congregation_week_guards WHERE congregation_id='51000000-0000-0000-0000-000000000002' AND week_start='2020-01-06'),'move increments destination week');
SELECT pg_temp.assert_true((SELECT age=0 FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)),'age zero preserved');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('direction@example.test','50000000-0000-0000-0000-000000000003','Membro da direção da campanha','51000000-0000-0000-0000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),(SELECT value FROM result)||'{"congregation_id":"51000000-0000-0000-0000-000000000001"}');
  RAISE EXCEPTION 'ASSERTION: move into authorized scope bypassed old scope'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
RESET ROLE;
SELECT pg_temp.assert_true(private.report_week('2026-10-19 00:00:00+00')='2026-10-12','Sunday after 20:00 Sao Paulo opens completed week');
SELECT pg_temp.assert_true(private.report_week('2026-10-18 22:59:59+00') IS NULL,'Sunday before 20:00 closes fresh confirmation');
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_delete_convert('52000000-0000-0000-0000-000000000003',(SELECT value FROM result));
SELECT pg_temp.assert_true(public.ieadpe_delete_convert('52000000-0000-0000-0000-000000000003',(SELECT value FROM result))=(SELECT value FROM result),'delete replay returns original ID');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT deleted_at IS NOT NULL AND internal_id=id::text FROM public.converts WHERE id=(SELECT (value->>'id')::uuid FROM result)),'tombstone retains unique internal ID');
SELECT pg_temp.assert_true((SELECT conversion_count=0 FROM private.congregation_week_guards WHERE congregation_id='51000000-0000-0000-0000-000000000002' AND week_start='2020-01-06'),'delete decrements destination guard');
DO $$ BEGIN
 BEGIN INSERT INTO public.converts(internal_id,name,landmark,gender,conversion_date,worship_type)
 SELECT value->>'id','Duplicate','Square','male','2020-01-01','01 - Oração' FROM result;
 RAISE EXCEPTION 'ASSERTION: tombstone internal ID reused'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
-- Latest completed week comes from server time; clients cannot choose a week.
DO $$ DECLARE report_a jsonb; report_b jsonb; created jsonb; wk date:=private.report_week(private.weekly_now());
 payload jsonb; before_receipts bigint; BEGIN
 PERFORM set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000003',true);
 report_a:=public.ieadpe_confirm_zero('52000000-0000-0000-0000-000000000004',
  '{"congregation_id":"51000000-0000-0000-0000-000000000001"}');
 BEGIN PERFORM public.ieadpe_confirm_zero(gen_random_uuid(),
  '{"congregation_id":"51000000-0000-0000-0000-000000000002"}');
  RAISE EXCEPTION 'ASSERTION: direction confirmed another scope'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000002',true);
 report_b:=public.ieadpe_confirm_zero('52000000-0000-0000-0000-000000000005',
  '{"congregation_id":"51000000-0000-0000-0000-000000000002"}');
 payload:=jsonb_build_object('name','Weekly','landmark','Square','gender','male','conversion_date',wk,
  'worship_type','01 - Oração','congregation_id','51000000-0000-0000-0000-000000000001');
 created:=public.ieadpe_create_convert(gen_random_uuid(),payload);
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.weekly_reports WHERE id=(report_a->>'id')::uuid),
  'create atomically removes matching zero report');
 PERFORM public.ieadpe_edit_convert(gen_random_uuid(),created||'{"congregation_id":"51000000-0000-0000-0000-000000000002"}');
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.weekly_reports WHERE id=(report_b->>'id')::uuid),
  'scope move atomically removes destination zero report');
 SELECT count(*) INTO before_receipts FROM private.mutation_receipts;
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),created||'{"conversion_date":"2999-01-01"}');
  RAISE EXCEPTION 'ASSERTION: future edit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT conversion_date=wk FROM public.converts WHERE id=(created->>'id')::uuid)
  AND (SELECT count(*)=before_receipts FROM private.mutation_receipts),'rejected edit leaves record and receipts unchanged');
 PERFORM public.ieadpe_delete_convert(gen_random_uuid(),created);
 PERFORM pg_temp.assert_true((SELECT conversion_count=0 FROM private.congregation_week_guards
  WHERE congregation_id='51000000-0000-0000-0000-000000000002' AND week_start=wk),'weekly delete restores count zero');
END $$;
ROLLBACK;
