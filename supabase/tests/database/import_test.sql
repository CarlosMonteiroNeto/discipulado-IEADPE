BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('16000000-0000-0000-0000-000000000001','import-manager@example.test',now()),
 ('16000000-0000-0000-0000-000000000002','import-registrar@example.test',now());
INSERT INTO private.admin_allowlist VALUES('16000000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES ('16000000-0000-0000-0000-000000000003','Synthetic import'),
 ('16000000-0000-0000-0000-000000000004','Ambiguous'),('16000000-0000-0000-0000-000000000005','Ambiguous');
INSERT INTO public.weekly_reports(congregation_id,week_start,confirmed_by_email) VALUES
 ('16000000-0000-0000-0000-000000000003','2020-01-06','synthetic@example.test');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),'{}');
 RAISE EXCEPTION 'ASSERTION: registrar imported'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE response jsonb; p jsonb:='{"internal_id":"legacy-16","name":"Synthetic","landmark":"Praça","gender":"male","conversion_date":"2020-01-07","worship_type":"Oração","congregation_name":"Synthetic import","age":0,"visit_count":4,"was_visited_once":true,"last_visit_date":"2020-02-01","is_in_discipleship":true,"discipleship_start_date":null}'; BEGIN
 response:=public.ieadpe_import_convert('16000000-0000-0000-0000-000000000006',p);
 PERFORM pg_temp.assert_true(response->>'status'='created','new row committed');
 PERFORM pg_temp.assert_true(response=public.ieadpe_import_convert('16000000-0000-0000-0000-000000000006',p),'uncertain retry reconciles same receipt');
 PERFORM pg_temp.assert_true(public.ieadpe_import_convert(gen_random_uuid(),p)->>'status'='duplicate','reimport skips stable legacy ID');
 PERFORM pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'one legacy row');
 PERFORM pg_temp.assert_true((SELECT age=0 AND visit_count=4 AND was_visited_once AND last_visit_date='2020-02-01' AND discipleship_start_date IS NULL FROM public.converts),'historical state and missing eligibility start preserved');
 PERFORM pg_temp.assert_true((SELECT count(*)=0 FROM public.convert_events),'no invented historical events');
 BEGIN PERFORM public.ieadpe_transition_convert(gen_random_uuid(),jsonb_build_object('id',response->>'id','action','complete'));
 RAISE EXCEPTION 'ASSERTION: missing historical start bypassed eligibility'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT count(*)=0 FROM public.weekly_reports),'new import invalidates zero report');
 BEGIN PERFORM public.ieadpe_import_convert('16000000-0000-0000-0000-000000000006',p||'{"name":"Changed"}');
 RAISE EXCEPTION 'ASSERTION: changed retry accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),p||'{"internal_id":"ambiguous","congregation_name":"Ambiguous"}');
 RAISE EXCEPTION 'ASSERTION: ambiguous congregation accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),p||'{"internal_id":"invalid","created_by":"16000000-0000-0000-0000-000000000002"}');
 RAISE EXCEPTION 'ASSERTION: actor override accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),p||'{"internal_id":"invalid-date","last_visit_date":"9999-01-01"}');
 RAISE EXCEPTION 'ASSERTION: invalid historical date accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 response:=public.ieadpe_import_convert(gen_random_uuid(),p||'{"internal_id":"unknown","congregation_name":"Unknown"}');
 PERFORM pg_temp.assert_true(response->>'warning'='unknown_congregation','unknown congregation warns');
 PERFORM pg_temp.assert_true((SELECT congregation_id IS NULL FROM public.converts WHERE internal_id='unknown'),'unknown maps null');
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT conversion_count=1 FROM private.congregation_week_guards),'only new scoped row increments guard');
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_delete_convert(gen_random_uuid(),jsonb_build_object('id',(SELECT id FROM public.converts WHERE internal_id='legacy-16')));
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.ieadpe_import_convert(gen_random_uuid(),'{"internal_id":"legacy-16"}')->>'status'='tombstone','tombstones never resurrect');
RESET ROLE;
-- A downstream failure rolls back row, receipt, count and zero invalidation together.
CREATE FUNCTION pg_temp.fail_import() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NEW.operation_id='16000000-0000-0000-0000-000000000009'::uuid THEN
  PERFORM pg_temp.assert_true(EXISTS(SELECT FROM public.converts WHERE internal_id='rollback-16'),'new row visible before forced receipt failure');
  PERFORM pg_temp.assert_true((SELECT conversion_count=1 FROM private.congregation_week_guards),'guard increment visible before forced receipt failure');
  PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.weekly_reports),'zero report removed before forced receipt failure');
  RAISE EXCEPTION 'forced failure' USING ERRCODE='23514';
 END IF; RETURN NEW; END $$;
CREATE TRIGGER test_import_rollback AFTER INSERT ON private.mutation_receipts FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_import();
INSERT INTO public.weekly_reports(congregation_id,week_start,confirmed_by_email) VALUES
 ('16000000-0000-0000-0000-000000000003','2020-01-06','synthetic@example.test');
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_import_convert('16000000-0000-0000-0000-000000000009','{"internal_id":"rollback-16","name":"Synthetic","landmark":"Praça","gender":"female","conversion_date":"2020-01-07","worship_type":"Oração","congregation_name":"Synthetic import"}');
 RAISE EXCEPTION 'ASSERTION: forced rollback did not fail'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.converts WHERE internal_id='rollback-16'),'failed row absent');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM private.mutation_receipts WHERE operation_id='16000000-0000-0000-0000-000000000009'),'failed receipt absent');
SELECT pg_temp.assert_true((SELECT conversion_count=0 FROM private.congregation_week_guards),'failed import preserves guard');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.weekly_reports),'failed import preserves zero report');
-- Normal edits can move the conversion date without changing historical clocks.
SET LOCAL ROLE authenticated;
DO $$ DECLARE source_id uuid; imported jsonb; p jsonb; BEGIN
 source_id:=(public.ieadpe_create_convert(gen_random_uuid(),'{"name":"Synthetic edited date","landmark":"Square","gender":"male","conversion_date":"2020-01-01","worship_type":"Prayer"}')->>'id')::uuid;
 PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object('id',source_id,'conversion_date','2021-01-01'));
 SELECT jsonb_build_object('internal_id','edited-history-copy','name',name,'landmark',landmark,'gender',gender,
  'conversion_date',conversion_date,'worship_type',worship_type,'last_visit_date',last_visit_date,
  'discipleship_start_date',discipleship_start_date) INTO p FROM public.converts WHERE id=source_id;
 PERFORM pg_temp.assert_true(p->>'last_visit_date'='2020-01-01','existing edit retains earlier historical visit');
 BEGIN imported:=public.ieadpe_import_convert(gen_random_uuid(),p);
 EXCEPTION WHEN invalid_parameter_value THEN RAISE EXCEPTION 'ASSERTION: valid edited conversion history rejected'; END;
 PERFORM pg_temp.assert_true(imported->>'status'='created','edited history imports');
 PERFORM pg_temp.assert_true((SELECT last_visit_date='2020-01-01' AND conversion_date='2021-01-01' FROM public.converts WHERE internal_id='edited-history-copy'),'import preserves edited historical clock');
END $$;
RESET ROLE;
DELETE FROM private.admin_allowlist WHERE user_id='16000000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_import_convert('16000000-0000-0000-0000-000000000006','{}');
 RAISE EXCEPTION 'ASSERTION: revoked manager replayed receipt'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.ieadpe_import_convert(uuid,jsonb)','EXECUTE'),'anonymous import denied');
ROLLBACK;
