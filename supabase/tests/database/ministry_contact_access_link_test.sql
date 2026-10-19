BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF;
END $$;

SELECT pg_temp.assert_true(
 EXISTS(SELECT FROM information_schema.columns WHERE table_schema='public'
   AND table_name='ministry_contacts' AND column_name='email' AND is_nullable='YES') AND
 EXISTS(SELECT FROM information_schema.columns WHERE table_schema='public'
   AND table_name='ministry_contacts' AND column_name='user_access_id' AND is_nullable='YES') AND
 to_regprocedure('public.ieadpe_ministry_save_contact_with_access(uuid,jsonb)') IS NOT NULL,
 'nullable contact email, unique access link, and atomic save RPC are installed');

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('e1000000-0000-4000-8000-000000000001','direction@example.test',now()),
 ('e1000000-0000-4000-8000-000000000002','manager@example.test',now()),
 ('e1000000-0000-4000-8000-000000000003','member-old@example.test',now()),
 ('e1000000-0000-4000-8000-000000000004','member-new@example.test',now()),
 ('e1000000-0000-4000-8000-000000000005','unconfirmed@example.test',NULL),
 ('e1000000-0000-4000-8000-000000000006','teacher-only@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('e2000000-0000-4000-8000-000000000001','Access A'),
 ('e2000000-0000-4000-8000-000000000002','Access B');
INSERT INTO public.user_access(id,user_email,user_id,role,congregation_id) VALUES
 ('e3000000-0000-4000-8000-000000000001','direction@example.test',
  'e1000000-0000-4000-8000-000000000001','Membro da direção da campanha',
  'e2000000-0000-4000-8000-000000000001'),
 ('e3000000-0000-4000-8000-000000000002','manager@example.test',
  'e1000000-0000-4000-8000-000000000002','Membro da supervisão das campanhas',NULL);
INSERT INTO public.ministry_contacts(id,congregation_id,scope,name,normalized_name,role_code,updated_by) VALUES
 ('e4000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001',
  'congregation','Directory Only','directory only','teacher','e1000000-0000-4000-8000-000000000001'),
 ('e4000000-0000-4000-8000-000000000002','e2000000-0000-4000-8000-000000000002',
  'congregation','Other Scope','other scope','teacher','e1000000-0000-4000-8000-000000000001');

SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
SELECT pg_temp.assert_true(
 (SELECT jsonb_array_length(response->'items')=1 AND
    response->'items'->0->>'email' IS NULL AND
    response->'items'->0->>'revision'='1' AND
    response->'items'->0 ? 'user_access_id' AND
    response->'items'->0->'user_access_id'='null'::jsonb
  FROM (SELECT public.ieadpe_ministry_list_directory(
   '{"scope":"congregation","congregation_id":"e2000000-0000-4000-8000-000000000001","limit":20,"cursor":null}'::jsonb) response) q),
 'directory-only contact returns null email, contact revision, and null access link');
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_list_directory(
   '{"scope":"all","congregation_id":null,"limit":20,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: contact role title granted global directory access';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE created jsonb; replay jsonb; detail jsonb; access_id uuid; directory jsonb;
        failed_contact uuid:='e4000000-0000-4000-8000-000000000099';
BEGIN
 -- A mismatched pair is rejected before either side is written.
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access(
   'e5000000-0000-4000-8000-000000000099',jsonb_build_object(
    'id',failed_contact,'scope','congregation','congregation_id','e2000000-0000-4000-8000-000000000001',
    'name','Must Not Save','role_code','teacher','phone_e164',NULL,'birth_date',NULL,
    'email','first@example.test','access',jsonb_build_object('user_email','second@example.test',
     'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001')));
  RAISE EXCEPTION 'ASSERTION: mismatched contact/access email pair was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.ministry_contacts WHERE id=failed_contact) AND
  NOT EXISTS(SELECT FROM public.user_access WHERE user_email IN ('first@example.test','second@example.test')),
  'failed contact/access save leaves both tables unchanged');

 created:=public.ieadpe_ministry_save_contact_with_access(
  'e5000000-0000-4000-8000-000000000001',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Linked Teacher',
   'role_code','teacher','phone_e164','+5511888880001','birth_date','1982-03-04',
   'email',' Member-Old@Example.Test ',
   'access',jsonb_build_object('user_email',' member-old@example.test ',
    'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001')));
 access_id:=(created->>'access_id')::uuid;
 replay:=public.ieadpe_ministry_save_contact_with_access(
  'e5000000-0000-4000-8000-000000000001',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Linked Teacher',
   'role_code','teacher','phone_e164','+5511888880001','birth_date','1982-03-04',
   'email',' Member-Old@Example.Test ',
   'access',jsonb_build_object('user_email',' member-old@example.test ',
    'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001')));
 PERFORM pg_temp.assert_true(created=replay AND created->>'revision'='1' AND
  (SELECT user_id IS NULL AND user_email='member-old@example.test' AND
    (SELECT email FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003')=user_email
   FROM public.user_access WHERE id=access_id),
  'creation atomically links a normalized pending access assignment and exact replay is stable');
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access(
   'e5000000-0000-4000-8000-000000000001',jsonb_set(
    jsonb_build_object('id','e4000000-0000-4000-8000-000000000003','scope','congregation',
     'congregation_id','e2000000-0000-4000-8000-000000000001','name','Changed','role_code','teacher',
     'phone_e164','+5511888880001','birth_date','1982-03-04','email','member-old@example.test',
     'access',jsonb_build_object('user_email','member-old@example.test','role','Membro da direção da campanha',
      'congregation_id','e2000000-0000-4000-8000-000000000001')),'{name}','"Changed"'));
  RAISE EXCEPTION 'ASSERTION: changed payload reused an operation receipt';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- A same-email match is never selected by email alone.
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access(
   'e5000000-0000-4000-8000-000000000002',jsonb_build_object(
    'id','e4000000-0000-4000-8000-000000000004','scope','congregation',
    'congregation_id','e2000000-0000-4000-8000-000000000001','name','Duplicate Email',
    'role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','member-old@example.test',
    'access',jsonb_build_object('user_email','member-old@example.test','role','Membro da direção da campanha',
     'congregation_id','e2000000-0000-4000-8000-000000000001')));
   RAISE EXCEPTION 'ASSERTION: same-email assignment was silently reused';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000004'),
  'same-email/no-ID conflict creates no contact');

 detail:=public.ieadpe_ministry_get_contact(jsonb_build_object('scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000001','contact_id','e4000000-0000-4000-8000-000000000003'));
 PERFORM pg_temp.assert_true((SELECT count(*)=2 FROM jsonb_object_keys(detail)) AND
  (SELECT count(*)=15 FROM jsonb_object_keys(detail->'contact')) AND
  (SELECT count(*)=5 FROM jsonb_object_keys(detail->'access')) AND detail->'contact'->>'revision'='1' AND
  detail->'contact'->>'user_access_id'=access_id::text AND detail->'access'->>'id'=access_id::text AND
  detail->'access'->>'user_email'='member-old@example.test' AND detail->'access'->'user_id'='null'::jsonb,
  'global detail returns exact contact and access projections');
 directory:=public.ieadpe_ministry_list_directory(
  '{"scope":"congregation","congregation_id":"e2000000-0000-4000-8000-000000000001","limit":20,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT item->>'user_access_id'=access_id::text AND item->>'email'='member-old@example.test'
  FROM jsonb_array_elements(directory->'items') item WHERE item->>'id'='e4000000-0000-4000-8000-000000000003'),
  'global directory exposes only the linked assignment ID with matching email');
END $$;

SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE detail jsonb; saved jsonb;
BEGIN
 detail:=public.ieadpe_ministry_get_contact(jsonb_build_object('scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000001','contact_id','e4000000-0000-4000-8000-000000000003'));
 PERFORM pg_temp.assert_true(detail->'contact'->'user_access_id'='null'::jsonb AND detail->'access'='null'::jsonb,
  'local contact detail never reveals linked assignment identity or access data');
  BEGIN
   PERFORM public.ieadpe_ministry_save_contact('e5000000-0000-4000-8000-000000000004',jsonb_build_object(
    'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
    'congregation_id','e2000000-0000-4000-8000-000000000001','name','Missing Email Key',
    'role_code','teacher','phone_e164','+5511888880002','birth_date','1982-03-04',
    'expected_revision',1));
   RAISE EXCEPTION 'ASSERTION: save_contact accepted an omitted email key';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 saved:=public.ieadpe_ministry_save_contact('e5000000-0000-4000-8000-000000000003',jsonb_build_object(
  'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000001','name','Linked Teacher Edited',
  'role_code','teacher','phone_e164','+5511888880002','birth_date','1982-03-04',
  'email','member-old@example.test','expected_revision',1));
 PERFORM pg_temp.assert_true(saved->>'revision'='2' AND
  (SELECT email='member-old@example.test' AND name='Linked Teacher Edited' AND revision=2
   FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003'),
  'local direction can edit non-email contact fields with the returned revision');
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact('e5000000-0000-4000-8000-000000000004',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Must Stay',
   'role_code','teacher','phone_e164','+5511888880002','birth_date','1982-03-04',
   'email','other@example.test','expected_revision',2));
  RAISE EXCEPTION 'ASSERTION: local direction changed the linked email';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access('e5000000-0000-4000-8000-000000000005',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','expected_revision',2,'scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Direction Cannot Grant',
   'role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','member-old@example.test',
   'access',jsonb_build_object('user_email','member-old@example.test','role','Membro da direção da campanha',
    'congregation_id','e2000000-0000-4000-8000-000000000001')));
  RAISE EXCEPTION 'ASSERTION: direction granted access';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_revoke_contact_access('e5000000-0000-4000-8000-000000000006',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','expected_revision',2));
  RAISE EXCEPTION 'ASSERTION: direction revoked access';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_contact(jsonb_build_object('scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000002','contact_id','e4000000-0000-4000-8000-000000000002'));
  RAISE EXCEPTION 'ASSERTION: contact detail crossed congregation scope';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact('e5000000-0000-4000-8000-000000000007',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Stale Edit',
   'role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email','member-old@example.test',
   'expected_revision',1));
  RAISE EXCEPTION 'ASSERTION: stale contact revision was accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000003',true);
DO $$
DECLARE scope jsonb;
BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["e2000000-0000-4000-8000-000000000001"]'::jsonb AND
  (SELECT user_id='e1000000-0000-4000-8000-000000000003' FROM public.user_access
   WHERE id=(SELECT user_access_id FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003')),
  'verified Auth email binds the matching pending linked assignment');
END $$;

SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE access_id uuid; detail jsonb; unchanged jsonb; reassigned jsonb; saved jsonb;
        replay_payload jsonb; saved_update jsonb; replayed_update jsonb; revoked_update jsonb;
        error_text text;
BEGIN
 SELECT user_access_id INTO access_id FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003';
 detail:=public.ieadpe_ministry_get_contact(jsonb_build_object('scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000001','contact_id','e4000000-0000-4000-8000-000000000003'));
 PERFORM pg_temp.assert_true(detail->'access'->>'user_id'='e1000000-0000-4000-8000-000000000003',
  'global detail reveals the bound verified Auth identity');

 -- A caller must explicitly identify the linked access row for reassignment.
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access('e5000000-0000-4000-8000-000000000008',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','expected_revision',2,'scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Linked Teacher Edited',
   'role_code','teacher','phone_e164','+5511888880002','birth_date','1982-03-04','email','member-new@example.test',
   'access',jsonb_build_object('user_email','member-new@example.test','role','Membro da direção da campanha',
    'congregation_id','e2000000-0000-4000-8000-000000000001')));
  RAISE EXCEPTION 'ASSERTION: email reassignment inferred the linked access ID';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access('e5000000-0000-4000-8000-000000000009',jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','expected_revision',2,'scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Linked Teacher Edited',
   'role_code','teacher','phone_e164','+5511888880002','birth_date','1982-03-04','email','unconfirmed@example.test',
   'access',jsonb_build_object('id',access_id,'user_email','unconfirmed@example.test',
    'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001')));
  RAISE EXCEPTION 'ASSERTION: reassignment accepted an unverified Auth email';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT email='member-old@example.test' AND revision=2
  FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003') AND
  (SELECT user_email='member-old@example.test' AND user_id='e1000000-0000-4000-8000-000000000003'
   FROM public.user_access WHERE id=access_id),'failed reassignments changed neither linked row');

 reassigned:=public.ieadpe_ministry_save_contact_with_access('e5000000-0000-4000-8000-000000000010',jsonb_build_object(
  'id','e4000000-0000-4000-8000-000000000003','expected_revision',2,'scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000001','name','Linked Teacher Edited',
  'role_code','teacher','phone_e164','+5511888880002','birth_date','1982-03-04','email','member-new@example.test',
  'access',jsonb_build_object('id',access_id,'user_email',' Member-New@Example.Test ',
   'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001')));
 PERFORM pg_temp.assert_true(reassigned->>'revision'='3' AND reassigned->>'access_id'=access_id::text AND
  (SELECT email='member-new@example.test' AND revision=3 FROM public.ministry_contacts
   WHERE id='e4000000-0000-4000-8000-000000000003') AND
  (SELECT user_email='member-new@example.test' AND user_id='e1000000-0000-4000-8000-000000000004'
   FROM public.user_access WHERE id=access_id),
  'explicit verified reassignment updates both email fields and binds the selected Auth user atomically');

 BEGIN
  PERFORM public.ieadpe_save_access('e5000000-0000-4000-8000-000000000011',jsonb_build_object(
   'id',access_id,'user_email','member-new@example.test','role','Membro da direção da campanha',
   'congregation_id','e2000000-0000-4000-8000-000000000002'));
  RAISE EXCEPTION 'ASSERTION: direct access RPC changed the linked assignment scope';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT congregation_id='e2000000-0000-4000-8000-000000000001'
  FROM public.user_access WHERE id=access_id),'direct linked access mutation fails closed');

  replay_payload:=jsonb_build_object(
   'id','e4000000-0000-4000-8000-000000000003','expected_revision',3,'scope','congregation',
   'congregation_id','e2000000-0000-4000-8000-000000000001','name','Replay After Revoke',
   'role_code','teacher','phone_e164','+5511888880003','birth_date','1982-03-04',
   'email','member-new@example.test',
   'access',jsonb_build_object('user_email','member-new@example.test',
    'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001'));
  saved_update:=public.ieadpe_ministry_save_contact_with_access(
   'e5000000-0000-4000-8000-000000000016',replay_payload);
  PERFORM pg_temp.assert_true(saved_update->>'revision'='4' AND saved_update->>'access_id'=access_id::text,
   'linked update may retain its current assignment without resubmitting the access ID');
  revoked_update:=public.ieadpe_ministry_revoke_contact_access(
   'e5000000-0000-4000-8000-000000000017',jsonb_build_object(
    'id','e4000000-0000-4000-8000-000000000003','scope','congregation',
    'congregation_id','e2000000-0000-4000-8000-000000000001','expected_revision',4));
  replayed_update:=public.ieadpe_ministry_save_contact_with_access(
   'e5000000-0000-4000-8000-000000000016',replay_payload);
  PERFORM pg_temp.assert_true(replayed_update=saved_update AND revoked_update->>'revision'='5' AND
   NOT EXISTS(SELECT FROM public.user_access WHERE id=access_id) AND
   (SELECT user_access_id IS NULL AND revision=5 AND name='Replay After Revoke' AND
     phone_e164='+5511888880003' FROM public.ministry_contacts
    WHERE id='e4000000-0000-4000-8000-000000000003'),
   'exact update replay after a separate revoke returns its stored result without reapplying');
  BEGIN
   PERFORM public.ieadpe_ministry_save_contact_with_access(
    'e5000000-0000-4000-8000-000000000016',jsonb_set(replay_payload,'{name}','"Changed Replay"'));
   RAISE EXCEPTION 'ASSERTION: changed contact-access payload reused a receipt';
  EXCEPTION WHEN invalid_parameter_value THEN
   GET STACKED DIAGNOSTICS error_text = MESSAGE_TEXT;
   IF error_text<>'operation_conflict' THEN
    RAISE EXCEPTION 'ASSERTION: expected operation_conflict for changed payload, got %',error_text;
   END IF;
  END;
  BEGIN
   PERFORM public.ieadpe_ministry_save_contact('e5000000-0000-4000-8000-000000000016',jsonb_build_object(
    'id','e4000000-0000-4000-8000-000000000003','expected_revision',3,'scope','congregation',
    'congregation_id','e2000000-0000-4000-8000-000000000001','name','Replay After Revoke',
    'role_code','teacher','phone_e164','+5511888880003','birth_date','1982-03-04',
    'email','member-new@example.test'));
   RAISE EXCEPTION 'ASSERTION: a different command reused a receipt';
  EXCEPTION WHEN invalid_parameter_value THEN
   GET STACKED DIAGNOSTICS error_text = MESSAGE_TEXT;
   IF error_text<>'operation_conflict' THEN
    RAISE EXCEPTION 'ASSERTION: expected operation_conflict for changed command, got %',error_text;
   END IF;
  END;
END $$;

-- Teacher history is a normal class reference and survives revocation.
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,teacher_contact_id,start_date,updated_by)
VALUES ('e6000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001',
 'Historical Class','historical class','e4000000-0000-4000-8000-000000000003','2026-10-01',
 'e1000000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE access_id uuid; scope jsonb;
BEGIN
 SELECT user_access_id INTO access_id FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003';
 PERFORM pg_temp.assert_true(access_id IS NULL AND
   (SELECT user_access_id IS NULL AND revision=5 AND role_code='teacher' AND archived_at IS NULL
   FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000003') AND
  (SELECT teacher_contact_id='e4000000-0000-4000-8000-000000000003' FROM public.ministry_classes
   WHERE id='e6000000-0000-4000-8000-000000000001'),
  'the earlier revoke preserves teacher contact history');
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='[]'::jsonb,
  'revoked assignment no longer grants congregation access');
END $$;

-- A verified user retains one independent linked assignment per congregation.
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE a jsonb; b jsonb; scope jsonb; access_b uuid;
BEGIN
 a:=public.ieadpe_ministry_save_contact_with_access('e5000000-0000-4000-8000-000000000013',jsonb_build_object(
  'id','e4000000-0000-4000-8000-000000000005','scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000001','name','Member A','role_code','teacher',
  'phone_e164',NULL,'birth_date',NULL,'email','member-new@example.test',
  'access',jsonb_build_object('user_email','member-new@example.test','role','Membro da direção da campanha',
   'congregation_id','e2000000-0000-4000-8000-000000000001')));
 b:=public.ieadpe_ministry_save_contact_with_access('e5000000-0000-4000-8000-000000000014',jsonb_build_object(
  'id','e4000000-0000-4000-8000-000000000006','scope','congregation',
  'congregation_id','e2000000-0000-4000-8000-000000000002','name','Member B','role_code','teacher',
  'phone_e164',NULL,'birth_date',NULL,'email','member-new@example.test',
  'access',jsonb_build_object('user_email','member-new@example.test','role','Membro da direção da campanha',
   'congregation_id','e2000000-0000-4000-8000-000000000002')));
 access_b:=(b->>'access_id')::uuid;
END $$;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000004',true);
DO $$
DECLARE scope jsonb;
BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["e2000000-0000-4000-8000-000000000001", "e2000000-0000-4000-8000-000000000002"]'::jsonb AND
  (SELECT count(*)=2 AND count(DISTINCT user_access_id)=2 FROM public.ministry_contacts
   WHERE id IN ('e4000000-0000-4000-8000-000000000005','e4000000-0000-4000-8000-000000000006')),
  'same verified Auth user binds separate access rows to separate congregation contacts');
END $$;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE access_b uuid; revoked jsonb;
BEGIN
 SELECT user_access_id INTO access_b FROM public.ministry_contacts WHERE id='e4000000-0000-4000-8000-000000000006';
 revoked:=public.ieadpe_revoke_access('e5000000-0000-4000-8000-000000000015',jsonb_build_object('id',access_b));
 PERFORM pg_temp.assert_true(revoked->>'id'=access_b::text AND
  NOT EXISTS(SELECT FROM public.user_access WHERE id=access_b) AND
  (SELECT user_access_id IS NULL AND revision=2 FROM public.ministry_contacts
   WHERE id='e4000000-0000-4000-8000-000000000006'),
  'direct access revoke clears the linked contact and increments its revision before deletion');
END $$;

-- Authorization remains current even when a successful receipt is available.
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 PERFORM public.ieadpe_revoke_access('e5000000-0000-4000-8000-000000000018',
  jsonb_build_object('id','e3000000-0000-4000-8000-000000000002'));
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact_with_access(
   'e5000000-0000-4000-8000-000000000016',jsonb_build_object(
    'id','e4000000-0000-4000-8000-000000000003','expected_revision',3,'scope','congregation',
    'congregation_id','e2000000-0000-4000-8000-000000000001','name','Replay After Revoke',
    'role_code','teacher','phone_e164','+5511888880003','birth_date','1982-03-04',
    'email','member-new@example.test',
    'access',jsonb_build_object('user_email','member-new@example.test',
     'role','Membro da direção da campanha','congregation_id','e2000000-0000-4000-8000-000000000001')));
  RAISE EXCEPTION 'ASSERTION: revoked global manager received a stored operation result';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
