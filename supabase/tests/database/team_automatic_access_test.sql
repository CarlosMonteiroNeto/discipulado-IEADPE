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

-- Team membership owns the access lifecycle: the e-mail is the only input.
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES ('f1000000-0000-4000-8000-000000000004','moved@example.test',now());
SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000005',jsonb_build_object('id','f4000000-0000-4000-8000-000000000001','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','name','New Member','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','moved@example.test','expected_revision',1));
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.ministry_contacts c JOIN public.user_access ua ON ua.id=c.user_access_id WHERE c.id='f4000000-0000-4000-8000-000000000001' AND ua.user_email='moved@example.test' AND ua.user_id='f1000000-0000-4000-8000-000000000004'),'changing the e-mail moves the linked access to the verified account');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.user_access WHERE user_email='person@example.test' AND congregation_id='f2000000-0000-4000-8000-000000000001'),'the previous local grant is moved, not duplicated');

SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000006',jsonb_build_object('id','f4000000-0000-4000-8000-000000000001','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','name','New Member','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email',NULL,'expected_revision',2));
SELECT pg_temp.assert_true((SELECT user_access_id IS NULL FROM public.ministry_contacts WHERE id='f4000000-0000-4000-8000-000000000001'),'clearing the e-mail unlinks the member');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.user_access WHERE user_email='moved@example.test'),'clearing the e-mail deletes the grant');
SELECT pg_temp.assert_true((SELECT archived_at IS NULL FROM public.ministry_contacts WHERE id='f4000000-0000-4000-8000-000000000001'),'clearing the e-mail keeps the member active');

SELECT public.ieadpe_ministry_save_contact('f3000000-0000-4000-8000-000000000007',jsonb_build_object('id','f4000000-0000-4000-8000-000000000001','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','name','New Member','role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','person@example.test','expected_revision',3));
INSERT INTO public.ministry_role_slots(scope,congregation_id,role_code,contact_id,updated_by) VALUES ('congregation','f2000000-0000-4000-8000-000000000001','teacher','f4000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001');
SELECT public.ieadpe_ministry_set_contact_archived('f3000000-0000-4000-8000-000000000008',jsonb_build_object('id','f4000000-0000-4000-8000-000000000001','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','archived',true,'expected_revision',4));
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.ministry_role_slots WHERE role_code='teacher' AND congregation_id='f2000000-0000-4000-8000-000000000001' AND contact_id IS NULL),'inactivation releases assigned role slot');
SELECT pg_temp.assert_true((SELECT user_access_id IS NULL FROM public.ministry_contacts WHERE id='f4000000-0000-4000-8000-000000000001'),'inactive member loses the access link');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.user_access WHERE user_email='person@example.test' AND congregation_id='f2000000-0000-4000-8000-000000000001'),'inactive member loses the grant');
SELECT pg_temp.assert_true((SELECT archived_at IS NOT NULL FROM public.ministry_contacts WHERE id='f4000000-0000-4000-8000-000000000001'),'inactive member stays in the directory');

SELECT public.ieadpe_ministry_set_contact_archived('f3000000-0000-4000-8000-000000000009',jsonb_build_object('id','f4000000-0000-4000-8000-000000000001','scope','congregation','congregation_id','f2000000-0000-4000-8000-000000000001','archived',false,'expected_revision',5));
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.ministry_contacts c JOIN public.user_access ua ON ua.id=c.user_access_id WHERE c.id='f4000000-0000-4000-8000-000000000001' AND ua.user_email='person@example.test' AND ua.user_id='f1000000-0000-4000-8000-000000000002'),'reactivation restores the grant');
INSERT INTO public.ministry_contacts(id,scope,congregation_id,name,normalized_name,email,archived_at,updated_by) VALUES ('f4000000-0000-4000-8000-000000000005','congregation','f2000000-0000-4000-8000-000000000001','Old','old','old@example.test',now(),'f1000000-0000-4000-8000-000000000001');
INSERT INTO public.user_access(user_email,role,congregation_id) VALUES ('old@example.test','Membro da direção da campanha','f2000000-0000-4000-8000-000000000001');
SELECT private.ministry_sync_contact_access('f4000000-0000-4000-8000-000000000005');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.user_access WHERE user_email='old@example.test'),'inactive legacy unlinked grant is removed');
ROLLBACK;
