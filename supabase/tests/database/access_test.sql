-- A missing protected schema is an observable authorization failure.
DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname='converts' AND c.relrowsecurity) THEN
   RAISE EXCEPTION 'ASSERTION: converts must be protected by row level security';
 END IF;
END $$;
BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %', label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('00000000-0000-0000-0000-000000000001','admin@example.test',now(),'{}'),
 ('00000000-0000-0000-0000-000000000002','direction@example.test',now(),'{}'),
 ('00000000-0000-0000-0000-000000000003','supervision@example.test',now(),'{}'),
 ('00000000-0000-0000-0000-000000000004','registrar@example.test',now(),'{"role":"admin"}'),
 ('00000000-0000-0000-0000-000000000005','pending@example.test',null,'{"role":"admin","email_verified":true}');
INSERT INTO private.admin_allowlist VALUES ('00000000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES
 ('10000000-0000-0000-0000-000000000001','Synthetic A'),('10000000-0000-0000-0000-000000000002','Synthetic B');
INSERT INTO public.converts(internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id) VALUES
 ('legacy-not-uuid','Synthetic A','Synthetic landmark','male','2020-01-01','01 - Oração','10000000-0000-0000-0000-000000000001'),
 ('other','Synthetic B','Synthetic landmark','female','2020-01-01','01 - Oração','10000000-0000-0000-0000-000000000002'),
 ('unassigned','Synthetic C','Synthetic landmark','female','2020-01-01','01 - Oração',null);
INSERT INTO public.user_access(id,user_email,user_id,role,congregation_id) VALUES
 ('20000000-0000-0000-0000-000000000001','direction@example.test','00000000-0000-0000-0000-000000000002','Membro da direção da campanha','10000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000002','supervision@example.test','00000000-0000-0000-0000-000000000003','Membro da supervisão das campanhas',null),
 ('20000000-0000-0000-0000-000000000003','pending@example.test',null,'Membro da direção da campanha','10000000-0000-0000-0000-000000000002');
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM * FROM public.converts; RAISE EXCEPTION 'ASSERTION: anonymous read allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.converts),'registrar cannot enumerate converts');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'direction reads exactly assigned congregation');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.converts WHERE internal_id='other'),'direction cannot cross congregation');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
SELECT pg_temp.assert_true((SELECT count(*)=3 FROM public.converts),'supervision reads globally including unassigned');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
SELECT pg_temp.assert_true((public.ieadpe_get_scope()->>'is_admin')::boolean=false,'editable metadata cannot grant admin');
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_save_access(gen_random_uuid(),'{"user_email":"registrar@example.test","role":"Membro da supervisão das campanhas"}');
  RAISE EXCEPTION 'ASSERTION: registrar granted supervision';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO private.admin_allowlist VALUES(auth.uid()); RAISE EXCEPTION 'ASSERTION: allowlist write allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.user_access SET user_id=auth.uid(); RAISE EXCEPTION 'ASSERTION: direct grant write allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000005',true);
SELECT pg_temp.assert_true(public.ieadpe_get_scope()->'congregation_ids'='[]'::jsonb,'unverified email cannot bind pending grant');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.converts),'unverified pending grant cannot read');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT user_id IS NULL FROM public.user_access WHERE user_email='pending@example.test'),'unverified pending row stays unbound');
UPDATE auth.users SET email_confirmed_at=now() WHERE id='00000000-0000-0000-0000-000000000005';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.ieadpe_get_scope()->'congregation_ids'='["10000000-0000-0000-0000-000000000002"]'::jsonb,'verified email binds pending grant');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'verified bound user reads assigned scope');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true((public.ieadpe_get_scope()->>'is_admin')::boolean,'allowlisted UID grants admin');
SELECT public.ieadpe_revoke_access('30000000-0000-0000-0000-000000000001','{"id":"20000000-0000-0000-0000-000000000001"}');
SELECT pg_temp.assert_true(public.ieadpe_revoke_access('30000000-0000-0000-0000-000000000001','{"id":"20000000-0000-0000-0000-000000000001"}')->>'id'='20000000-0000-0000-0000-000000000001','revoke replay is idempotent');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.converts),'revoked access denies next read with same JWT UID');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true(
 public.ieadpe_save_access('30000000-0000-0000-0000-000000000002','{"user_email":" DIRECTION@example.test ","role":"Membro da direção da campanha","congregation_id":"10000000-0000-0000-0000-000000000001"}') =
 public.ieadpe_save_access('30000000-0000-0000-0000-000000000002','{"user_email":" DIRECTION@example.test ","role":"Membro da direção da campanha","congregation_id":"10000000-0000-0000-0000-000000000001"}'),
 'save retry returns same receipt');
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_revoke_access(gen_random_uuid(),'{"id":null}');
  RAISE EXCEPTION 'ASSERTION: null revoke target accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_save_access('30000000-0000-0000-0000-000000000002','{"user_email":"changed@example.test","role":"Membro da supervisão das campanhas"}');
  RAISE EXCEPTION 'ASSERTION: operation ID reused with changed payload';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_save_access(gen_random_uuid(),'{"user_email":"x@example.test","role":"admin"}');
  RAISE EXCEPTION 'ASSERTION: invalid role accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_save_access(gen_random_uuid(),'{"user_email":"x@example.test","role":"Membro da supervisão das campanhas","user_id":"00000000-0000-0000-0000-000000000004"}');
  RAISE EXCEPTION 'ASSERTION: client identity override accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.converts),'normalized verified save binds existing identity');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=5 FROM public.profiles),'profile trigger creates profiles');
SELECT pg_temp.assert_true((SELECT version>0 FROM private.access_versions WHERE user_id='00000000-0000-0000-0000-000000000002'),'access mutations advance target version');
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.ieadpe_get_scope()','EXECUTE'),'anonymous scope execution denied');
SELECT pg_temp.assert_true(NOT has_function_privilege('authenticated','private.change_access(text,uuid,jsonb)','EXECUTE'),'private mutation helper execution denied');
ROLLBACK;
