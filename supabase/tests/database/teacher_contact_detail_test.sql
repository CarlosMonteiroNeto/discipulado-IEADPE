BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF;
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('ab100000-0000-4000-8000-000000000001','teacher-staff-a@example.test',now()),
 ('ab100000-0000-4000-8000-000000000002','teacher-global@example.test',now()),
 ('ab100000-0000-4000-8000-000000000003','teacher-staff-b@example.test',now()),
 ('ab100000-0000-4000-8000-000000000004','teacher-registrar@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('ab200000-0000-4000-8000-000000000001','Teacher Scope A'),
 ('ab200000-0000-4000-8000-000000000002','Teacher Scope B'),
 ('ab200000-0000-4000-8000-000000000003','Teacher Archived Scope');
UPDATE public.congregations SET archived_at=now()
 WHERE id='ab200000-0000-4000-8000-000000000003';
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('teacher-staff-a@example.test','ab100000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','ab200000-0000-4000-8000-000000000001'),
 ('teacher-global@example.test','ab100000-0000-4000-8000-000000000002',
  'Membro da supervisão das campanhas',NULL),
 ('teacher-staff-b@example.test','ab100000-0000-4000-8000-000000000003',
  'Membro da direção da campanha','ab200000-0000-4000-8000-000000000002');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('ab100000-0000-4000-8000-000000000001','ab200000-0000-4000-8000-000000000001','ministry_staff',true),
 ('ab100000-0000-4000-8000-000000000002',NULL,'ministry_supervision',true),
 ('ab100000-0000-4000-8000-000000000003','ab200000-0000-4000-8000-000000000002','ministry_staff',true);
INSERT INTO public.ministry_contacts(id,congregation_id,scope,name,normalized_name,role_code,
 phone_e164,birth_date,updated_by)
VALUES
 ('ab300000-0000-4000-8000-000000000001','ab200000-0000-4000-8000-000000000001',
  'congregation','Teacher One','teacher one','teacher','+5511888880001','1980-04-03',
  'ab100000-0000-4000-8000-000000000001'),
 ('ab300000-0000-4000-8000-000000000002','ab200000-0000-4000-8000-000000000001',
  'congregation','Other Contact','other contact','campaignLeader',NULL,NULL,
  'ab100000-0000-4000-8000-000000000001'),
 ('ab300000-0000-4000-8000-000000000003','ab200000-0000-4000-8000-000000000002',
  'congregation','Teacher Two','teacher two','teacher',NULL,NULL,
  'ab100000-0000-4000-8000-000000000003'),
 ('ab300000-0000-4000-8000-000000000004','ab200000-0000-4000-8000-000000000001',
  'congregation','Archived Teacher','archived teacher','teacher',NULL,NULL,
  'ab100000-0000-4000-8000-000000000001');
UPDATE public.ministry_contacts SET archived_at=now()
 WHERE id='ab300000-0000-4000-8000-000000000004';

SELECT set_config('request.jwt.claim.sub','ab100000-0000-4000-8000-000000000001',true);
DO $$
DECLARE detail jsonb; saved jsonb;
BEGIN
 detail:=public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
  'congregation_id','ab200000-0000-4000-8000-000000000001',
  'contact_id','ab300000-0000-4000-8000-000000000001'));
 PERFORM pg_temp.assert_true(detail ? 'contact' AND
  (SELECT count(*)=6 FROM jsonb_object_keys(detail->'contact')) AND
  detail->'contact'->>'name'='Teacher One' AND
  detail->'contact'->>'birth_date'='1980-04-03' AND
  detail->'contact'->>'revision'='1' AND
  NOT (detail->'contact' ? 'email') AND NOT (detail->'contact' ? 'access'),
  'teacher detail returns only the six bounded contact fields');
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000001',
   'contact_id','ab300000-0000-4000-8000-000000000001','extra','no'));
  RAISE EXCEPTION 'ASSERTION: teacher detail accepted an unknown key';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000001',
   'contact_id','ab300000-0000-4000-8000-000000000002'));
  RAISE EXCEPTION 'ASSERTION: non-teacher contact detail was returned';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000001',
   'contact_id','ab300000-0000-4000-8000-000000000004'));
  RAISE EXCEPTION 'ASSERTION: archived teacher contact detail was returned';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Exercise the existing save_contact command with the bounded read's current
 -- revision and nullable birth date included in the phone-only edit.
 saved:=public.ieadpe_ministry_save_contact(
  'ab400000-0000-4000-8000-000000000001',jsonb_build_object(
   'id','ab300000-0000-4000-8000-000000000001','scope','congregation',
   'congregation_id','ab200000-0000-4000-8000-000000000001','name','Teacher One',
   'role_code','teacher','phone_e164','+5511888880002',
   'birth_date',detail->'contact'->>'birth_date','email',NULL,'expected_revision',
   (detail->'contact'->>'revision')::integer));
 PERFORM pg_temp.assert_true(saved->>'revision'='2' AND
  (SELECT phone_e164='+5511888880002' AND birth_date='1980-04-03' AND email IS NULL
   AND revision=2
   FROM public.ministry_contacts WHERE id='ab300000-0000-4000-8000-000000000001'),
  'phone-only teacher edit preserves birth date with the fetched revision');
 BEGIN
  PERFORM public.ieadpe_ministry_save_contact(
   'ab400000-0000-4000-8000-000000000002',jsonb_build_object(
    'id','ab300000-0000-4000-8000-000000000001','scope','congregation',
    'congregation_id','ab200000-0000-4000-8000-000000000001','name','Stale Edit',
    'role_code','teacher','phone_e164','+5511888880099','birth_date','1980-04-03',
    'email',NULL,'expected_revision',1));
  RAISE EXCEPTION 'ASSERTION: stale teacher edit overwrote current contact';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT name='Teacher One' AND phone_e164='+5511888880002'
  AND revision=2 FROM public.ministry_contacts WHERE id='ab300000-0000-4000-8000-000000000001'),
  'stale contact edit leaves the current teacher data unchanged');

 -- The normal scoped command remains the sole write path for teacher creation.
 saved:=public.ieadpe_ministry_save_contact(
  'ab400000-0000-4000-8000-000000000003',jsonb_build_object(
   'id','ab300000-0000-4000-8000-000000000005','scope','congregation',
   'congregation_id','ab200000-0000-4000-8000-000000000001','name','New Teacher',
   'role_code','teacher','phone_e164',NULL,'birth_date',NULL,'email',NULL));
 PERFORM pg_temp.assert_true(saved->>'revision'='1' AND
  (SELECT scope='congregation' AND congregation_id='ab200000-0000-4000-8000-000000000001'
   AND role_code='teacher' AND archived_at IS NULL
   FROM public.ministry_contacts WHERE id='ab300000-0000-4000-8000-000000000005'),
  'teacher creation is a same-congregation contact with the fixed teacher role');
END $$;

SELECT set_config('request.jwt.claim.sub','ab100000-0000-4000-8000-000000000003',true);
DO $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000002',
   'contact_id','ab300000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: cross-scope contact ID was returned';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','ab100000-0000-4000-8000-000000000001',true);
DO $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000002',
   'contact_id','ab300000-0000-4000-8000-000000000003'));
  RAISE EXCEPTION 'ASSERTION: staff read outside its assigned congregation';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','ab100000-0000-4000-8000-000000000002',true);
DO $$
DECLARE detail jsonb;
BEGIN
 detail:=public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
  'congregation_id','ab200000-0000-4000-8000-000000000002',
  'contact_id','ab300000-0000-4000-8000-000000000003'));
 PERFORM pg_temp.assert_true(detail->'contact'->>'name'='Teacher Two',
  'global ministry manager can detail-read a teacher in an active congregation');
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000003',
   'contact_id','ab300000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: global manager read a contact in an archived congregation';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','ab100000-0000-4000-8000-000000000004',true);
DO $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000001',
   'contact_id','ab300000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: registration-only user read teacher detail';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

RESET request.jwt.claim.sub;
DO $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_get_teacher_contact(jsonb_build_object(
   'congregation_id','ab200000-0000-4000-8000-000000000001',
   'contact_id','ab300000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: anonymous user read teacher detail';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

ROLLBACK;
