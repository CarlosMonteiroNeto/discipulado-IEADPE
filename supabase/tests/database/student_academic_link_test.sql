BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF;
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('aa100000-0000-4000-8000-000000000001','student-staff-a@example.test',now()),
 ('aa100000-0000-4000-8000-000000000002','student-global@example.test',now()),
 ('aa100000-0000-4000-8000-000000000003','student-staff-b@example.test',now()),
 ('aa100000-0000-4000-8000-000000000004','student-registrar@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('aa200000-0000-4000-8000-000000000001','Student Scope A'),
 ('aa200000-0000-4000-8000-000000000002','Student Scope B'),
 ('aa200000-0000-4000-8000-000000000003','Student Archived Scope');
UPDATE public.congregations SET archived_at=now()
 WHERE id='aa200000-0000-4000-8000-000000000003';
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('student-staff-a@example.test','aa100000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','aa200000-0000-4000-8000-000000000001'),
 ('student-global@example.test','aa100000-0000-4000-8000-000000000002',
  'Membro da supervisão das campanhas',NULL),
 ('student-staff-b@example.test','aa100000-0000-4000-8000-000000000003',
  'Membro da direção da campanha','aa200000-0000-4000-8000-000000000002');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('aa100000-0000-4000-8000-000000000001','aa200000-0000-4000-8000-000000000001','ministry_staff',true),
 ('aa100000-0000-4000-8000-000000000002',NULL,'ministry_supervision',true),
 ('aa100000-0000-4000-8000-000000000003','aa200000-0000-4000-8000-000000000002','ministry_staff',true);

INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,phone,birth_date,address)
VALUES
 ('aa300000-0000-4000-8000-000000000001','aa200000-0000-4000-8000-000000000001',
  'Canonical Student','canonical student','+5511999990001','1992-03-04',
  '{"street":"Rua A","district":null,"city":"Recife","postal_code":null,"state_code":"PE"}'),
 ('aa300000-0000-4000-8000-000000000002','aa200000-0000-4000-8000-000000000001',
  'Convert Person','convert person','+5511999990002','1985-06-07',NULL),
 ('aa300000-0000-4000-8000-000000000003','aa200000-0000-4000-8000-000000000001',
  'Other Canonical','other canonical','+5511999990003',NULL,NULL),
 ('aa300000-0000-4000-8000-000000000004','aa200000-0000-4000-8000-000000000002',
  'Scope B Person','scope b person',NULL,NULL,NULL),
 ('aa300000-0000-4000-8000-000000000005','aa200000-0000-4000-8000-000000000001',
  'Unlinked Convert Person','unlinked convert person',NULL,NULL,NULL),
 ('aa300000-0000-4000-8000-000000000006','aa200000-0000-4000-8000-000000000001',
  'Existing Convert Person','existing convert person','+5511999990006',NULL,NULL),
 ('aa300000-0000-4000-8000-000000000007','aa200000-0000-4000-8000-000000000001',
  'Enrollment Create Person','enrollment create person','+5511999990007','1999-11-12',NULL);
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,
 phone_e164,birth_date,address,education,marital_status,new_convert,water_baptized,wants_baptism,updated_by)
VALUES
 ('aa400000-0000-4000-8000-000000000001','aa200000-0000-4000-8000-000000000001',
  'aa300000-0000-4000-8000-000000000001','Snapshot Name','snapshot name',NULL,NULL,NULL,
  'Médio','Solteiro',false,NULL,true,'aa100000-0000-4000-8000-000000000001'),
 ('aa400000-0000-4000-8000-000000000002','aa200000-0000-4000-8000-000000000001',
  NULL,'Legacy Student','legacy student',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
  'aa100000-0000-4000-8000-000000000001'),
 ('aa400000-0000-4000-8000-000000000003','aa200000-0000-4000-8000-000000000002',
  'aa300000-0000-4000-8000-000000000004','Scope B Student','scope b student',NULL,NULL,NULL,
  NULL,NULL,NULL,NULL,NULL,'aa100000-0000-4000-8000-000000000003'),
 ('aa400000-0000-4000-8000-000000000004','aa200000-0000-4000-8000-000000000001',
  'aa300000-0000-4000-8000-000000000003','Other Canonical','other canonical',NULL,NULL,NULL,
  NULL,NULL,NULL,NULL,NULL,'aa100000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
VALUES
 ('aa500000-0000-4000-8000-000000000001','aa200000-0000-4000-8000-000000000001',
  'Class A','class a',private.business_today(),'aa100000-0000-4000-8000-000000000001'),
 ('aa500000-0000-4000-8000-000000000002','aa200000-0000-4000-8000-000000000002',
  'Class B','class b',private.business_today(),'aa100000-0000-4000-8000-000000000003');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
 congregation_id,age,last_visit_date,created_by,person_id,revision)
VALUES
 ('aa600000-0000-4000-8000-000000000001','student-convert-new','Convert Person','Near the square',
  'female',private.business_today(),'Culto regular','aa200000-0000-4000-8000-000000000001',NULL,
  private.business_today(),'aa100000-0000-4000-8000-000000000001',
  'aa300000-0000-4000-8000-000000000006',1),
 ('aa600000-0000-4000-8000-000000000002','student-convert-existing','Convert Person','Near the school',
  'female',private.business_today(),'Culto regular','aa200000-0000-4000-8000-000000000001',NULL,
  private.business_today(),'aa100000-0000-4000-8000-000000000001',
  'aa300000-0000-4000-8000-000000000002',1),
 ('aa600000-0000-4000-8000-000000000003','student-convert-conflict','Convert Person','Near the river',
  'female',private.business_today(),'Culto regular','aa200000-0000-4000-8000-000000000001',NULL,
  private.business_today(),'aa100000-0000-4000-8000-000000000001',
  'aa300000-0000-4000-8000-000000000005',1),
 ('aa600000-0000-4000-8000-000000000004','student-convert-unlinked','Unlinked Convert','Near the market',
  'female',private.business_today(),'Culto regular','aa200000-0000-4000-8000-000000000001',NULL,
  private.business_today(),'aa100000-0000-4000-8000-000000000001',NULL,1);

SELECT set_config('request.jwt.claim.sub','aa100000-0000-4000-8000-000000000001',true);
DO $$
DECLARE detail jsonb; enrollment jsonb; first_enrollment jsonb; replay jsonb; promoted jsonb; linked jsonb;
 student_page jsonb; archived_result jsonb; error_text text;
BEGIN
 detail:=public.ieadpe_ministry_get_student(jsonb_build_object(
  'congregation_id','aa200000-0000-4000-8000-000000000001',
  'student_id','aa400000-0000-4000-8000-000000000001'));
 PERFORM pg_temp.assert_true(detail ? 'student' AND
  (SELECT count(*)=20 FROM jsonb_object_keys(detail->'student')) AND
  detail->'student'->>'person_id'='aa300000-0000-4000-8000-000000000001' AND
  detail->'student'->>'name'='Canonical Student' AND
  detail->'student'->>'phone_e164'='+5511999990001' AND
  detail->'student'->>'education'='Médio' AND
  detail->'student'->>'revision'='1' AND
  detail->'student'->>'person_revision'='1' AND
  detail->'student'->>'link_state'='linked',
  'student detail returns an exact scoped projection with canonical identity and separate revisions');
 detail:=public.ieadpe_ministry_get_student(jsonb_build_object(
  'congregation_id','aa200000-0000-4000-8000-000000000001',
  'student_id','aa400000-0000-4000-8000-000000000002'));
 PERFORM pg_temp.assert_true(detail->'student'->>'name'='Legacy Student' AND
  detail->'student'->>'link_state'='unlinked' AND detail->'student'->'person_revision'='null'::jsonb,
  'unlinked legacy student detail retains its academic identity snapshot');
 BEGIN
  PERFORM public.ieadpe_ministry_get_student(jsonb_build_object(
   'congregation_id','aa200000-0000-4000-8000-000000000002',
   'student_id','aa400000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: out-of-scope detail returned a student';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_student(jsonb_build_object(
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'student_id','aa400000-0000-4000-8000-000000000001','extra','no'));
  RAISE EXCEPTION 'ASSERTION: student detail accepted an unknown key';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 enrollment:=public.ieadpe_ministry_enroll_student(
  'aa700000-0000-4000-8000-000000000001',jsonb_build_object(
   'id','aa800000-0000-4000-8000-000000000001',
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'class_id','aa500000-0000-4000-8000-000000000001',
   'person_id','aa300000-0000-4000-8000-000000000001',
   'start_date',private.business_today()));
 PERFORM pg_temp.assert_true(enrollment ?& ARRAY['id','student_id','person_id','revision','student_revision'] AND
  enrollment->>'person_id'='aa300000-0000-4000-8000-000000000001' AND
  enrollment->>'student_id'='aa400000-0000-4000-8000-000000000001' AND
  enrollment->>'student_revision'='1' AND
  (SELECT count(*)=1 FROM public.ministry_students s
   WHERE s.person_id='aa300000-0000-4000-8000-000000000001'),
  'enrollment reuses the one same-scope academic extension for its canonical person');
 first_enrollment:=enrollment;
 BEGIN
  PERFORM public.ieadpe_ministry_set_student_archived(
   'aa710000-0000-4000-8000-000000000001',jsonb_build_object(
    'id','aa400000-0000-4000-8000-000000000001',
    'congregation_id','aa200000-0000-4000-8000-000000000001',
    'archived',true,'expected_revision',1));
  RAISE EXCEPTION 'ASSERTION: actively enrolled student was archived';
 EXCEPTION WHEN check_violation THEN
  GET STACKED DIAGNOSTICS error_text=MESSAGE_TEXT;
  IF error_text<>'active_enrollment' THEN RAISE; END IF;
 END;
 enrollment:=public.ieadpe_ministry_enroll_student(
  'aa700000-0000-4000-8000-000000000007',jsonb_build_object(
   'id','aa800000-0000-4000-8000-000000000007',
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'class_id','aa500000-0000-4000-8000-000000000001',
   'person_id','aa300000-0000-4000-8000-000000000007',
   'start_date',private.business_today()));
 PERFORM pg_temp.assert_true(enrollment->>'person_id'='aa300000-0000-4000-8000-000000000007' AND
  (SELECT person_id='aa300000-0000-4000-8000-000000000007' AND
   name='Enrollment Create Person' AND phone_e164='+5511999990007' AND birth_date='1999-11-12'
   FROM public.ministry_students WHERE id=(enrollment->>'student_id')::uuid),
  'enrollment creates a same-scope academic extension from canonical identity');
 replay:=public.ieadpe_ministry_enroll_student(
  'aa700000-0000-4000-8000-000000000001',jsonb_build_object(
   'id','aa800000-0000-4000-8000-000000000001',
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'class_id','aa500000-0000-4000-8000-000000000001',
   'person_id','aa300000-0000-4000-8000-000000000001',
   'start_date',private.business_today()));
 PERFORM pg_temp.assert_true(replay=first_enrollment,
  'enrollment retry returns its original linked student and enrollment');
 BEGIN
  PERFORM public.ieadpe_ministry_enroll_student(
   'aa700000-0000-4000-8000-000000000002',jsonb_build_object(
    'id','aa800000-0000-4000-8000-000000000002',
    'congregation_id','aa200000-0000-4000-8000-000000000001',
    'class_id','aa500000-0000-4000-8000-000000000002',
    'person_id','aa300000-0000-4000-8000-000000000006',
    'start_date',private.business_today()));
  RAISE EXCEPTION 'ASSERTION: cross-scope class enrollment succeeded';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.ministry_enrollments
  WHERE id='aa800000-0000-4000-8000-000000000002') AND NOT EXISTS(
   SELECT FROM public.ministry_students WHERE person_id='aa300000-0000-4000-8000-000000000006'),
  'failed enrollment rolls back its linked academic extension and receipt');

 promoted:=public.ieadpe_promote_convert_to_student(
  'aa900000-0000-4000-8000-000000000001',jsonb_build_object(
   'convert_id','aa600000-0000-4000-8000-000000000001',
   'congregation_id','aa200000-0000-4000-8000-000000000001','student_id',NULL));
 PERFORM pg_temp.assert_true(promoted ?& ARRAY['convert_id','student_id','person_id','congregation_id','status'] AND
  promoted->>'person_id'='aa300000-0000-4000-8000-000000000006' AND
  promoted->>'status'='linked' AND
  (SELECT person_id='aa300000-0000-4000-8000-000000000006' AND convert_id='aa600000-0000-4000-8000-000000000001' AND
    name='Existing Convert Person' AND revision=1 FROM public.ministry_students
   WHERE id=(promoted->>'student_id')::uuid),
  'new promotion links the convert academic row to the same canonical person without name matching');
 replay:=public.ieadpe_promote_convert_to_student(
  'aa900000-0000-4000-8000-000000000001',jsonb_build_object(
   'convert_id','aa600000-0000-4000-8000-000000000001',
   'congregation_id','aa200000-0000-4000-8000-000000000001','student_id',NULL));
 PERFORM pg_temp.assert_true(replay=promoted,
  'promotion retry returns its original explicit canonical link');

 linked:=public.ieadpe_promote_convert_to_student(
  'aa900000-0000-4000-8000-000000000002',jsonb_build_object(
   'convert_id','aa600000-0000-4000-8000-000000000002',
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'student_id','aa400000-0000-4000-8000-000000000002','expected_student_revision',1));
 PERFORM pg_temp.assert_true(linked->>'student_id'='aa400000-0000-4000-8000-000000000002' AND
  linked->>'person_id'='aa300000-0000-4000-8000-000000000002' AND
  (SELECT person_id='aa300000-0000-4000-8000-000000000002' AND revision=2 AND
   convert_id='aa600000-0000-4000-8000-000000000002' FROM public.ministry_students
   WHERE id='aa400000-0000-4000-8000-000000000002'),
  'explicit link attaches a same-scope unlinked student and advances its revision');
 archived_result:=public.ieadpe_ministry_set_student_archived(
  'aa710000-0000-4000-8000-000000000002',jsonb_build_object(
   'id','aa400000-0000-4000-8000-000000000004',
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'archived',true,'expected_revision',1));
 student_page:=public.ieadpe_ministry_list_students(jsonb_build_object(
  'congregation_id','aa200000-0000-4000-8000-000000000001','limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true(archived_result->>'revision'='2' AND EXISTS(
  SELECT FROM jsonb_array_elements(student_page->'items') AS entries(item)
  WHERE item->>'id'='aa400000-0000-4000-8000-000000000004'
   AND item->>'archived_at' IS NOT NULL),
  'archived students remain discoverable in the bounded list for restore');
 archived_result:=public.ieadpe_ministry_set_student_archived(
  'aa710000-0000-4000-8000-000000000003',jsonb_build_object(
   'id','aa400000-0000-4000-8000-000000000004',
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'archived',false,'expected_revision',2));
 detail:=public.ieadpe_ministry_get_student(jsonb_build_object(
  'congregation_id','aa200000-0000-4000-8000-000000000001',
  'student_id','aa400000-0000-4000-8000-000000000004'));
 PERFORM pg_temp.assert_true(archived_result->>'revision'='3' AND
  detail->'student'->'archived_at'='null'::jsonb,
  'restoring an archived student advances the revision and keeps its history readable');
 BEGIN
  PERFORM public.ieadpe_promote_convert_to_student(
   'aa900000-0000-4000-8000-000000000003',jsonb_build_object(
    'convert_id','aa600000-0000-4000-8000-000000000003',
    'congregation_id','aa200000-0000-4000-8000-000000000001',
    'student_id','aa400000-0000-4000-8000-000000000004','expected_student_revision',3));
  RAISE EXCEPTION 'ASSERTION: promotion merged different canonical people';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_promote_convert_to_student(
   'aa900000-0000-4000-8000-000000000004',jsonb_build_object(
    'convert_id','aa600000-0000-4000-8000-000000000003',
    'congregation_id','aa200000-0000-4000-8000-000000000001',
    'student_id','aa400000-0000-4000-8000-000000000004','expected_student_revision',2));
  RAISE EXCEPTION 'ASSERTION: stale promotion revision overwrote an academic link';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_promote_convert_to_student(
   'aa900000-0000-4000-8000-000000000005',jsonb_build_object(
    'convert_id','aa600000-0000-4000-8000-000000000003',
    'congregation_id','aa200000-0000-4000-8000-000000000001',
    'student_id','aa400000-0000-4000-8000-000000000004'));
  RAISE EXCEPTION 'ASSERTION: existing-student promotion omitted its revision';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_promote_convert_to_student(
   'aa900000-0000-4000-8000-000000000006',jsonb_build_object(
    'convert_id','aa600000-0000-4000-8000-000000000004',
    'congregation_id','aa200000-0000-4000-8000-000000000001','student_id',NULL));
  RAISE EXCEPTION 'ASSERTION: promotion fabricated a canonical person';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','aa100000-0000-4000-8000-000000000003',true);
DO $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_get_student(jsonb_build_object(
   'congregation_id','aa200000-0000-4000-8000-000000000002',
   'student_id','aa400000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: cross-scope student ID returned a record';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','aa100000-0000-4000-8000-000000000002',true);
DO $$
DECLARE detail jsonb;
BEGIN
 detail:=public.ieadpe_ministry_get_student(jsonb_build_object(
  'congregation_id','aa200000-0000-4000-8000-000000000002',
  'student_id','aa400000-0000-4000-8000-000000000003'));
 PERFORM pg_temp.assert_true(detail->'student'->>'name'='Scope B Person',
  'global ministry manager can read a student in an active congregation');
 BEGIN
  PERFORM public.ieadpe_ministry_get_student(jsonb_build_object(
   'congregation_id','aa200000-0000-4000-8000-000000000003',
   'student_id','aa400000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: global manager read an archived congregation';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','aa100000-0000-4000-8000-000000000004',true);
DO $$
BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_get_student(jsonb_build_object(
   'congregation_id','aa200000-0000-4000-8000-000000000001',
   'student_id','aa400000-0000-4000-8000-000000000001'));
  RAISE EXCEPTION 'ASSERTION: registration-only user read student detail';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

ROLLBACK;
