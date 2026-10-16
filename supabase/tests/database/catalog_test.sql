BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('00000000-0000-0000-0000-000000000001','admin@example.test',now(),'{}'),
 ('00000000-0000-0000-0000-000000000002','manager@example.test',now(),'{}'),
 ('00000000-0000-0000-0000-000000000003','pending@example.test',null,'{"role":"admin"}'),
 ('00000000-0000-0000-0000-000000000004','registrar@example.test',now(),'{}');
INSERT INTO private.admin_allowlist VALUES('00000000-0000-0000-0000-000000000001');
INSERT INTO public.user_access(user_email,user_id,role) VALUES
 ('manager@example.test','00000000-0000-0000-0000-000000000002','Membro da supervisão das campanhas');
INSERT INTO public.congregations(id,name) VALUES
 ('10000000-0000-0000-0000-000000000001','Sede'),('10000000-0000-0000-0000-000000000002','Água');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id) VALUES
 ('20000000-0000-0000-0000-000000000001','legacy','Synthetic','Praça','male','2020-01-01','Oração','10000000-0000-0000-0000-000000000001');
INSERT INTO public.convert_events(convert_id,congregation_id,event_type,event_date) VALUES
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','visit','2020-01-02');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SELECT public.ieadpe_archive_congregation('30000000-0000-0000-0000-000000000001','{"id":"10000000-0000-0000-0000-000000000001"}');
SELECT pg_temp.assert_true((SELECT archived_at IS NOT NULL FROM public.congregations WHERE id='10000000-0000-0000-0000-000000000001'),'archive changes catalog state');
SELECT pg_temp.assert_true((SELECT congregation_id='10000000-0000-0000-0000-000000000001' FROM public.converts WHERE internal_id='legacy'),'archive retains legacy convert reference');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.convert_events WHERE congregation_id='10000000-0000-0000-0000-000000000001'),'archive retains event reference');
SELECT pg_temp.assert_true(public.ieadpe_archive_congregation('30000000-0000-0000-0000-000000000001','{"id":"10000000-0000-0000-0000-000000000001"}')='{"id":"10000000-0000-0000-0000-000000000001"}'::jsonb,'archive retry returns only original id');
DO $$ DECLARE response jsonb; BEGIN
 response:=public.ieadpe_save_congregation('30000000-0000-0000-0000-000000000002','{"name":"  Nova  "}');
 PERFORM pg_temp.assert_true((SELECT name='Nova' FROM public.congregations WHERE id=(response->>'id')::uuid),'save trims and creates catalog');
 PERFORM pg_temp.assert_true(response=public.ieadpe_save_congregation('30000000-0000-0000-0000-000000000002','{"name":"  Nova  "}'),'save replay same id');
 PERFORM public.ieadpe_save_congregation(gen_random_uuid(),jsonb_build_object('id',response->>'id','name','Renomeada'));
 PERFORM pg_temp.assert_true((SELECT name='Renomeada' FROM public.congregations WHERE id=(response->>'id')::uuid),'rename changes existing catalog');
 BEGIN PERFORM public.ieadpe_save_congregation('30000000-0000-0000-0000-000000000002','{"name":"Different"}');
 RAISE EXCEPTION 'ASSERTION: mismatched replay accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{}');
 RAISE EXCEPTION 'ASSERTION: missing name accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{"name":12}');
 RAISE EXCEPTION 'ASSERTION: numeric name accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{"name":"  "}');
 RAISE EXCEPTION 'ASSERTION: blank name accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{"name":"X","archived_at":null}');
 RAISE EXCEPTION 'ASSERTION: protected field accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_archive_congregation(gen_random_uuid(),'{"id":null}');
 RAISE EXCEPTION 'ASSERTION: null archive accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_archive_congregation(gen_random_uuid(),'{"id":"10000000-0000-0000-0000-000000000002","name":"X"}');
 RAISE EXCEPTION 'ASSERTION: archive extra key accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{"id":"10000000-0000-0000-0000-000000000001","name":"Archived"}');
 RAISE EXCEPTION 'ASSERTION: archived rename accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_create_convert(gen_random_uuid(),'{"name":"New","landmark":"Praça","gender":"male","conversion_date":"2020-01-01","worship_type":"Oração","congregation_id":"10000000-0000-0000-0000-000000000001"}');
 RAISE EXCEPTION 'ASSERTION: new archived selection accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),'{"id":"20000000-0000-0000-0000-000000000001","name":"Edited"}');
 RAISE EXCEPTION 'ASSERTION: established archived edit rule bypassed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_access(gen_random_uuid(),'{"user_email":"pending@example.test","role":"Membro da direção da campanha","congregation_id":"10000000-0000-0000-0000-000000000001"}');
 RAISE EXCEPTION 'ASSERTION: grant selecting archived congregation accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_save_access(gen_random_uuid(),'{"user_email":"pending@example.test","role":"admin"}');
 RAISE EXCEPTION 'ASSERTION: manager created admin'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
-- Pending grants bind only after a trusted email confirmation and once per UID.
SELECT public.ieadpe_save_access(gen_random_uuid(),'{"user_email":" PENDING@example.test ","role":"Membro da direção da campanha","congregation_id":"10000000-0000-0000-0000-000000000002"}');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
SELECT pg_temp.assert_true(public.ieadpe_get_scope()->'congregation_ids'='[]'::jsonb,'unverified pending identity denied');
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=now() WHERE id='00000000-0000-0000-0000-000000000003';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_get_scope()->'congregation_ids')=1,'verified email binds pending grant');
RESET ROLE;
DO $$ DECLARE before_version bigint; BEGIN
 SELECT version INTO before_version FROM private.access_versions WHERE user_id='00000000-0000-0000-0000-000000000003';
 PERFORM public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true((SELECT version=before_version FROM private.access_versions WHERE user_id='00000000-0000-0000-0000-000000000003'),'binding happens once');
END $$;
-- A second active direction grant coexists with the first.
INSERT INTO public.congregations(id,name) VALUES('10000000-0000-0000-0000-000000000003','Outra');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SELECT public.ieadpe_save_access(gen_random_uuid(),'{"user_email":"pending@example.test","role":"Membro da direção da campanha","congregation_id":"10000000-0000-0000-0000-000000000003"}');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_get_scope()->'congregation_ids')=2,'multiple direction grants coexist');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{"name":"Forbidden"}');
 RAISE EXCEPTION 'ASSERTION: direction edited catalog'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_archive_congregation(gen_random_uuid(),'{"id":"10000000-0000-0000-0000-000000000002"}');
 RAISE EXCEPTION 'ASSERTION: registrar archived catalog'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.congregations SET name='Bypass';
 RAISE EXCEPTION 'ASSERTION: direct catalog write allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- A committed receipt cannot resurrect revoked management authority.
RESET ROLE;
DELETE FROM public.user_access WHERE user_id='00000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_archive_congregation('30000000-0000-0000-0000-000000000001','{"id":"10000000-0000-0000-0000-000000000001"}');
 RAISE EXCEPTION 'ASSERTION: replay after revocation allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_save_congregation(gen_random_uuid(),'{"name":"Anon"}');
 RAISE EXCEPTION 'ASSERTION: anonymous command allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
