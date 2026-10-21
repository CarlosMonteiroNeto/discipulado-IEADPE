BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('91000000-0000-0000-0000-000000000001','registry-staff@example.test',now()),
 ('91000000-0000-0000-0000-000000000002','registry-supervisor@example.test',now()),
 ('91000000-0000-0000-0000-000000000003','registry-other@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('92000000-0000-0000-0000-000000000001','Registry A'),
 ('92000000-0000-0000-0000-000000000002','Registry B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('registry-staff@example.test','91000000-0000-0000-0000-000000000001','Membro da direção da campanha','92000000-0000-0000-0000-000000000001'),
 ('registry-supervisor@example.test','91000000-0000-0000-0000-000000000002','Membro da supervisão das campanhas',NULL),
 ('registry-other@example.test','91000000-0000-0000-0000-000000000003','Membro da direção da campanha','92000000-0000-0000-0000-000000000002');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','ministry_staff',true),
 ('91000000-0000-0000-0000-000000000001',NULL,'ministry_supervision',true),
 ('91000000-0000-0000-0000-000000000002',NULL,'ministry_supervision',true),
 ('91000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','ministry_staff',true);
SELECT set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE created jsonb; updated jsonb; student jsonb; BEGIN
 created:=public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000001',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Teacher One","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb);
 PERFORM pg_temp.assert_true(created='{"id":"93000000-0000-0000-0000-000000000001","revision":1}'::jsonb,'contact create has minimal revision result');
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000001',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Teacher One","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb)=created,'contact create replay returns exact receipt');
 DELETE FROM public.user_access WHERE user_id='91000000-0000-0000-0000-000000000001'
  AND role='Membro da direção da campanha' AND congregation_id='92000000-0000-0000-0000-000000000001';
 BEGIN PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000001',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Teacher One","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: revoked actor received replay'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
  VALUES('registry-staff@example.test','91000000-0000-0000-0000-000000000001',
   'Membro da direção da campanha','92000000-0000-0000-0000-000000000001');
 BEGIN PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000001',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Other","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: changed operation replay accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 updated:=public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000002',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Teacher One Updated","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null,"expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(updated->>'revision'='2','contact update increments revision');
 BEGIN PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000009',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Stale Update","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null,"expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale contact revision accepted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000010',
  '{"id":"93000000-0000-0000-0000-000000000010","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Teacher Two","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb);
 INSERT INTO public.ministry_role_slots(id,congregation_id,scope,role_code,contact_id,updated_by)
  VALUES('93000000-0000-0000-0000-000000000020','92000000-0000-0000-0000-000000000001','congregation','teacher','93000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001');
 updated:=public.ieadpe_ministry_replace_role_holder('93000000-0000-0000-0000-000000000011',
  '{"scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","role_code":"teacher","previous_contact_id":"93000000-0000-0000-0000-000000000001","previous_expected_revision":2,"id":"93000000-0000-0000-0000-000000000010","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(updated='{"id":"93000000-0000-0000-0000-000000000010","revision":2,"previous_contact_id":"93000000-0000-0000-0000-000000000001","previous_revision":3}'::jsonb,'role replacement revisions both contacts');
 PERFORM pg_temp.assert_true((SELECT contact_id='93000000-0000-0000-0000-000000000010' FROM public.ministry_role_slots WHERE id='93000000-0000-0000-0000-000000000020'),'role slot now points to replacement holder');
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_replace_role_holder('93000000-0000-0000-0000-000000000011',
  '{"scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","role_code":"teacher","previous_contact_id":"93000000-0000-0000-0000-000000000001","previous_expected_revision":2,"id":"93000000-0000-0000-0000-000000000010","expected_revision":1}'::jsonb)=updated,'role replacement replay returns exact receipt');
 BEGIN PERFORM public.ieadpe_ministry_set_contact_archived('93000000-0000-0000-0000-000000000021',
  '{"id":"93000000-0000-0000-0000-000000000010","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","archived":true,"expected_revision":2}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: assigned contact archive accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 student:=public.ieadpe_ministry_register_student('93000000-0000-0000-0000-000000000003',
  '{"id":"93000000-0000-0000-0000-000000000003","person_id":"93000000-0000-0000-0000-000000000007","congregation_id":"92000000-0000-0000-0000-000000000001","person":{"name":"Student One"},"academic":{"water_baptized":null,"wants_baptism":null}}'::jsonb);
 PERFORM pg_temp.assert_true(student->>'id'='93000000-0000-0000-0000-000000000003' AND student->>'revision'='1',
  'direction can create a student in its assigned congregation');
 PERFORM pg_temp.assert_true((SELECT water_baptized IS NULL AND wants_baptism IS NULL FROM public.ministry_students WHERE id='93000000-0000-0000-0000-000000000003'),'nullable baptism answers preserved');
 INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
  VALUES('93000000-0000-0000-0000-000000000030','92000000-0000-0000-0000-000000000001','Registry Class','registry class','2026-10-01','91000000-0000-0000-0000-000000000001');
 INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by)
  VALUES('93000000-0000-0000-0000-000000000031','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000003','93000000-0000-0000-0000-000000000030','2026-10-01','91000000-0000-0000-0000-000000000001');
 BEGIN PERFORM public.ieadpe_ministry_set_student_archived('93000000-0000-0000-0000-000000000032',
  '{"id":"93000000-0000-0000-0000-000000000003","congregation_id":"92000000-0000-0000-0000-000000000001","archived":true,"expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: student with active enrollment archived'; EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.ministry_enrollments SET status='completed',end_date='2026-10-16' WHERE id='93000000-0000-0000-0000-000000000031';
 updated:=public.ieadpe_ministry_set_student_archived('93000000-0000-0000-0000-000000000033',
  '{"id":"93000000-0000-0000-0000-000000000003","congregation_id":"92000000-0000-0000-0000-000000000001","archived":true,"expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(updated->>'revision'='2' AND (SELECT archived_at IS NOT NULL FROM public.ministry_students WHERE id='93000000-0000-0000-0000-000000000003'),'student archive is historical and revisioned');
 updated:=public.ieadpe_ministry_set_student_archived('93000000-0000-0000-0000-000000000034',
  '{"id":"93000000-0000-0000-0000-000000000003","congregation_id":"92000000-0000-0000-0000-000000000001","archived":false,"expected_revision":2}'::jsonb);
 PERFORM pg_temp.assert_true(updated->>'revision'='3' AND (SELECT archived_at IS NULL FROM public.ministry_students WHERE id='93000000-0000-0000-0000-000000000003'),'student restore preserves row and increments revision');
 PERFORM public.ieadpe_ministry_set_contact_archived('93000000-0000-0000-0000-000000000004',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","archived":true,"expected_revision":3}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT archived_at IS NOT NULL AND revision=4 FROM public.ministry_contacts WHERE id='93000000-0000-0000-0000-000000000001'),'contact archive retains history and increments revision');
 BEGIN PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000035',
  '{"id":"93000000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Cannot Edit Archived","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null,"expected_revision":4}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived contact edit accepted';
 EXCEPTION WHEN invalid_parameter_value THEN
  PERFORM pg_temp.assert_true(SQLERRM='contact_archived',
   'archived contact edit reports contact_archived, got '||SQLERRM); END;
END $$;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_save_student('93000000-0000-0000-0000-000000000005',
  '{"id":"93000000-0000-0000-0000-000000000003","congregation_id":"92000000-0000-0000-0000-000000000001","water_baptized":true,"wants_baptism":true,"expected_revision":3}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: contradictory baptism answers accepted'; EXCEPTION WHEN check_violation OR invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_register_student('93000000-0000-0000-0000-000000000006',
  '{"id":"93000000-0000-0000-0000-000000000006","person_id":"93000000-0000-0000-0000-000000000008","congregation_id":"92000000-0000-0000-0000-000000000002","person":{"name":"Cross scope"},"academic":{}}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction created a student in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000007',
  '{"id":"93000000-0000-0000-0000-000000000007","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Unknown","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null,"unexpected":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: unknown contact payload key accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.ministry_students),'invalid student transactions roll back');
SELECT set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000002',true);
SELECT pg_temp.assert_true(public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000036',
 '{"id":"93000000-0000-0000-0000-000000000036","scope":"supervision","congregation_id":null,"name":"Supervisor Contact","role_code":"campaignSupervisor","phone_e164":null,"birth_date":null,"email":null}'::jsonb)->>'revision'='1','supervision contact uses global supervisor authority');
SELECT set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_save_contact('93000000-0000-0000-0000-000000000008',
  '{"id":"93000000-0000-0000-0000-000000000008","scope":"congregation","congregation_id":"92000000-0000-0000-0000-000000000001","name":"Wrong scope","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: cross congregation contact create accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
