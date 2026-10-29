BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('f1000000-0000-4000-8000-000000000001','leader@example.test',now()),
 ('f1000000-0000-4000-8000-000000000002','person@example.test',now());
INSERT INTO public.congregations(id,name) VALUES ('f2000000-0000-4000-8000-000000000001','Local A'),('f2000000-0000-4000-8000-000000000002','Local B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('leader@example.test','f1000000-0000-4000-8000-000000000001','Membro da direção da campanha','f2000000-0000-4000-8000-000000000001'),
 ('person@example.test','f1000000-0000-4000-8000-000000000002','Membro da direção da campanha','f2000000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000001',jsonb_build_object('id','f4000000-0000-4000-8000-000000000001','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','name','New Member','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','person@example.test'));
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.ministry_contacts c JOIN public.user_access ua ON ua.id=c.user_access_id WHERE c.id='f4000000-0000-4000-8000-000000000001' AND ua.user_id='f1000000-0000-4000-8000-000000000002' AND ua.congregation_id='f2000000-0000-4000-8000-000000000001'), 'saving team email grants and links local access');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.user_access WHERE user_email='person@example.test'), 'other congregation grant preserved');
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000002',true);
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_get_scope()->'congregation_ids')=2,'verified account sees both grants');
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact(gen_random_uuid(),jsonb_build_object('id',gen_random_uuid(),'scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000002','name','Forbidden','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','other@example.test'));
  RAISE EXCEPTION 'ASSERTION: foreign congregation granted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact(gen_random_uuid(),jsonb_build_object('id',gen_random_uuid(),'scope','supervision','congregation_id',NULL,'name','Forbidden','role_code','campaignSupervisor','phone_e164',NULL,'birth_date',NULL,'email','other@example.test'));
  RAISE EXCEPTION 'ASSERTION: local user granted supervision';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000002',jsonb_build_object('id','f4000000-0000-4000-8000-000000000002','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','name','Pending','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','pending@example.test'));
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.user_access WHERE user_email='pending@example.test' AND user_id IS NULL),'unverified email stays pending');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES('legacy@example.test',NULL,'Membro da direção da campanha','f2000000-0000-4000-8000-000000000001');
SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000003',jsonb_build_object('id','f4000000-0000-4000-8000-000000000003','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','name','Legacy','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','legacy@example.test'));
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.user_access WHERE user_email='legacy@example.test') AND EXISTS(SELECT FROM public.user_access u JOIN public.ministry_contacts c ON c.user_access_id=u.id WHERE u.user_email='legacy@example.test'),'matching legacy grant is linked, not duplicated');
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES ('f1000000-0000-4000-8000-000000000003','supervisor@example.test',now());
INSERT INTO private.admin_allowlist(user_id) VALUES ('f1000000-0000-4000-8000-000000000001');
SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000004',jsonb_build_object('id','f4000000-0000-4000-8000-000000000004','scope','supervision','congregation_id',NULL,'name','Supervisor','role_code','campaignSupervisor','phone_e164',NULL,'birth_date',NULL,'email','supervisor@example.test'));
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000003',true);
SELECT pg_temp.assert_true((public.ieadpe_get_scope()->>'is_supervision')::boolean,'supervision contact grants verified supervisor global scope');
ROLLBACK;
