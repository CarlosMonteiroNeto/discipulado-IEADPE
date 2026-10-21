BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('17000000-0000-0000-0000-000000000001','revision-manager@example.test',now()),
 ('17000000-0000-0000-0000-000000000002','revision-registrar@example.test',now());
INSERT INTO private.admin_allowlist VALUES
 ('17000000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES
 ('17000000-0000-0000-0000-000000000003','Revision import');
-- Canonical person used only to prove an existing duplicate keeps its link.
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name) VALUES
 ('17000000-0000-0000-0000-000000000004','17000000-0000-0000-0000-000000000003',
  'Linked legacy','linked legacy');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
 congregation_id,revision,person_id,updated_at) VALUES
 ('17000000-0000-0000-0000-000000000005','legacy-linked','Linked legacy','Square','male',
  '2019-12-01','Prayer','17000000-0000-0000-0000-000000000003',7,
  '17000000-0000-0000-0000-000000000004','2020-01-01 00:00:00+00'),
 ('17000000-0000-0000-0000-000000000006','legacy-tombstone','Tombstoned legacy','Square','female',
  '2019-12-02','Prayer','17000000-0000-0000-0000-000000000003',4,NULL,'2020-01-02 00:00:00+00');
UPDATE public.converts SET deleted_at='2020-01-03 00:00:00+00' WHERE internal_id='legacy-tombstone';
-- A confirmed zero report for the imported conversion week must be invalidated once.
INSERT INTO public.weekly_reports(congregation_id,week_start,confirmed_by_email) VALUES
 ('17000000-0000-0000-0000-000000000003','2020-01-06','synthetic@example.test');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),'{}');
 RAISE EXCEPTION 'ASSERTION: non-manager imported'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE response jsonb; replay jsonb; linked_before timestamptz; p jsonb:='{"internal_id":"revision-new","name":"Synthetic revision","landmark":"Praça","gender":"female","conversion_date":"2020-01-07","worship_type":"Oração","congregation_name":"Revision import","age":0,"visit_count":2,"was_visited_once":true,"last_visit_date":"2020-01-08","is_in_discipleship":false,"discipleship_start_date":null}'; BEGIN
 -- Accepted legacy import initializes the mandatory revision without client input.
 response:=public.ieadpe_import_convert('17000000-0000-0000-0000-000000000007',p);
 PERFORM pg_temp.assert_true(response->>'status'='created','new legacy import committed');
 PERFORM pg_temp.assert_true((SELECT revision=1 FROM public.converts WHERE internal_id='revision-new'),'new import revision defaults to one');
 PERFORM pg_temp.assert_true((SELECT person_id IS NULL FROM public.converts WHERE internal_id='revision-new'),'new import stays unlinked');
 PERFORM pg_temp.assert_true((SELECT deleted_at IS NULL FROM public.converts WHERE internal_id='revision-new'),'new import is live');
 PERFORM pg_temp.assert_true((SELECT visit_count=2 AND last_visit_date='2020-01-08' FROM public.converts WHERE internal_id='revision-new'),'imported historical state preserved');
 -- Exact lost-response replay returns the original receipt without touching the row.
 replay:=public.ieadpe_import_convert('17000000-0000-0000-0000-000000000007',p);
 PERFORM pg_temp.assert_true(replay=response,'lost-response replay returns exact receipt result');
 -- A fresh operation for the same legacy ID reports duplicate and changes nothing.
 response:=public.ieadpe_import_convert('17000000-0000-0000-0000-000000000008',p);
 PERFORM pg_temp.assert_true(response->>'status'='duplicate','same legacy ID reports duplicate');
 PERFORM pg_temp.assert_true((SELECT revision=1 AND person_id IS NULL FROM public.converts WHERE internal_id='revision-new'),'duplicate keeps revision and null person link');
 -- An existing linked row keeps its revision, person link and timestamps.
 SELECT updated_at INTO linked_before FROM public.converts WHERE internal_id='legacy-linked';
 response:=public.ieadpe_import_convert('17000000-0000-0000-0000-000000000009',p||'{"internal_id":"legacy-linked"}');
 PERFORM pg_temp.assert_true(response->>'status'='duplicate','linked legacy ID reports duplicate');
 PERFORM pg_temp.assert_true((SELECT revision=7 AND person_id='17000000-0000-0000-0000-000000000004' AND updated_at=linked_before FROM public.converts WHERE internal_id='legacy-linked'),'duplicate preserves existing revision, person link and timestamp');
 -- A deleted legacy ID stays a tombstone with its prior revision.
 response:=public.ieadpe_import_convert('17000000-0000-0000-0000-000000000020',p||'{"internal_id":"legacy-tombstone"}');
 PERFORM pg_temp.assert_true(response->>'status'='tombstone','deleted legacy ID reports tombstone');
 -- Client-supplied revision and person_id remain outside the accepted payload.
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),p||'{"internal_id":"revision-client","revision":9}');
 RAISE EXCEPTION 'ASSERTION: client revision accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_import_convert(gen_random_uuid(),p||'{"internal_id":"person-client","person_id":"17000000-0000-0000-0000-000000000004"}');
 RAISE EXCEPTION 'ASSERTION: client person accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.converts WHERE internal_id IN ('revision-client','person-client')),'rejected client identity fields leave no row');
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT revision=4 AND person_id IS NULL AND deleted_at='2020-01-03 00:00:00+00' FROM public.converts WHERE internal_id='legacy-tombstone'),'tombstone preserves revision, link and deletion');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.weekly_reports),'created import invalidates confirmed zero');
SELECT pg_temp.assert_true((SELECT conversion_count=1 FROM private.congregation_week_guards),'create increments counter and duplicate preserves it');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM private.mutation_receipts WHERE operation_id='17000000-0000-0000-0000-000000000007'),'replay keeps one receipt');
SELECT pg_temp.assert_true((SELECT NOT (result ? 'name' OR result ? 'phone' OR result ? 'address') FROM private.mutation_receipts WHERE operation_id='17000000-0000-0000-0000-000000000007'),'receipt contains no imported personal values');
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.ieadpe_import_convert(uuid,jsonb)','EXECUTE'),'anonymous import denied');
ROLLBACK;
