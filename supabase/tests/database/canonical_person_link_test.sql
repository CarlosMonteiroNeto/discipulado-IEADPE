BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF;
END $$;

INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('p1-staff@example.test','95100000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','95200000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','95100000-0000-4000-8000-000000000001',true);

DO $$
DECLARE
 linked_person uuid;
 unmatched_person uuid;
 deleted_person uuid;
 linked_student jsonb;
 unmatched_student jsonb;
 class_entry jsonb;
 person_result jsonb;
 saved jsonb;
 linked jsonb;
 replay jsonb;
 error_message text;
BEGIN
 SELECT person_id INTO linked_person FROM public.converts
  WHERE id='95300000-0000-4000-8000-000000000001';
 SELECT person_id INTO unmatched_person FROM public.converts
  WHERE id='95300000-0000-4000-8000-000000000002';
 SELECT person_id INTO deleted_person FROM public.converts
  WHERE id='95300000-0000-4000-8000-000000000003';

 PERFORM pg_temp.assert_true(linked_person IS NOT NULL AND
  linked_person<>'95300000-0000-4000-8000-000000000001'::uuid,
  'canonical person ID is distinct from its convert ID');
 PERFORM pg_temp.assert_true((SELECT count(*)=4 FROM public.ministry_people
  WHERE congregation_id='95200000-0000-4000-8000-000000000001'),
  'scoped and soft-deleted converts each receive a canonical person');
 PERFORM pg_temp.assert_true((SELECT count(*)=5 AND bool_and(revision=1)
  FROM public.converts WHERE congregation_id IS NOT NULL),
  'existing converts receive revision one');
 PERFORM pg_temp.assert_true((SELECT name=repeat('Overlong Legacy Convert ',10)||'Tail' AND
  length(name)>200 FROM public.converts
  WHERE id='95300000-0000-4000-8000-000000000005'),
  'migration preserves the overlong source convert name');
 PERFORM pg_temp.assert_true((SELECT p.name=repeat('Overlong Legacy Convert ',10)||'Tail' AND
  p.name=c.name AND length(p.name)>200
  FROM public.ministry_people p JOIN public.converts c ON c.person_id=p.id
  WHERE c.id='95300000-0000-4000-8000-000000000005'),
  'migration backfills the exact overlong canonical name');
 PERFORM pg_temp.assert_true((SELECT c.created_at='2020-01-02 03:04:05+00'::timestamptz AND
  c.updated_at='2020-02-03 04:05:06+00'::timestamptz AND
  p.created_at>c.created_at AND p.updated_at>c.updated_at
  FROM public.converts c JOIN public.ministry_people p ON p.id=c.person_id
  WHERE c.id='95300000-0000-4000-8000-000000000005'),
  'canonical timestamps use migration defaults while source convert timestamps remain unchanged');
 PERFORM pg_temp.assert_true(deleted_person IS NOT NULL,
  'soft-deleted convert keeps its person link');
 PERFORM pg_temp.assert_true((SELECT updated_by IS NULL AND revision=1
  FROM public.ministry_people WHERE id=linked_person),
  'migration does not invent canonical-person attribution');
 PERFORM pg_temp.assert_true((SELECT address->>'street'='Rua da Aurora' AND
  address->>'district' IS NULL AND phone IS NULL
  FROM public.ministry_people WHERE id=linked_person),
  'legacy convert contact fields map without normalization or invention');
 PERFORM pg_temp.assert_true((SELECT person_id=linked_person AND
  name='Legacy Student Snapshot' AND convert_id='95300000-0000-4000-8000-000000000001'
  FROM public.ministry_students WHERE id='95400000-0000-4000-8000-000000000001'),
  'same-scope explicit convert link backfills while preserving student lineage');
 PERFORM pg_temp.assert_true((SELECT person_id IS NULL FROM public.ministry_students
  WHERE id='95400000-0000-4000-8000-000000000002'),
  'same-name legacy student is not merged by name');
 PERFORM pg_temp.assert_true((SELECT person_id IS NULL FROM public.ministry_students
  WHERE id='95400000-0000-4000-8000-000000000003'),
  'cross-scope legacy convert link does not become a person link');
 PERFORM pg_temp.assert_true((SELECT count(*)=1 FROM public.ministry_enrollments
  WHERE id='95600000-0000-4000-8000-000000000001' AND
   student_id='95400000-0000-4000-8000-000000000001'),
  'migration preserves existing academic history');

 BEGIN
  UPDATE public.converts SET revision=0
   WHERE id='95300000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'ASSERTION: invalid convert revision accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  UPDATE public.converts SET congregation_id=NULL
   WHERE id='95300000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'ASSERTION: convert person link accepted with null congregation';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT congregation_id='95200000-0000-4000-8000-000000000001'::uuid
  FROM public.converts WHERE id='95300000-0000-4000-8000-000000000001'),
  'convert scope remains non-null when a person link exists');
 person_result:=public.ieadpe_ministry_list_students(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001','limit',100));
 PERFORM pg_temp.assert_true(jsonb_array_length(person_result->'items')=3 AND
  person_result->>'next_cursor' IS NULL,
  'student list accepts only its required request fields');

 BEGIN
  UPDATE public.ministry_people SET address=jsonb_build_object(
   'street',123,'district',NULL,'city',NULL,'postal_code',NULL,'state_code',NULL)
  WHERE id=linked_person;
  RAISE EXCEPTION 'ASSERTION: non-string address value accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  UPDATE public.ministry_people SET address=jsonb_build_object(
   'street','Rua A','district',NULL,'city',NULL,'postal_code',NULL)
  WHERE id=linked_person;
  RAISE EXCEPTION 'ASSERTION: incomplete address object accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 person_result:=public.ieadpe_ministry_get_person(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001','person_id',linked_person));
 PERFORM pg_temp.assert_true(person_result->>'person_revision'='1' AND
  person_result->'person'->>'name'='Canonical From Convert' AND
  person_result->'person'->'phone'='null'::jsonb AND
  person_result->'person'->'address'->>'street'='Rua da Aurora' AND
  person_result->'person'->'updated_by'='null'::jsonb AND
  (SELECT phone='(81) 99999-0001' FROM public.converts
   WHERE id='95300000-0000-4000-8000-000000000001'),
  'invalid legacy phone stays on its source and canonical attribution remains unknown');

 person_result:=public.ieadpe_ministry_list_people(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001','name_prefix',NULL,
  'limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true(jsonb_array_length(person_result->'items')=4 AND
  person_result->>'next_cursor' IS NULL,
  'people list is scoped and bounded');

 person_result:=public.ieadpe_ministry_list_students(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001','name_prefix',NULL,
  'limit',100,'cursor',NULL));
 SELECT value INTO linked_student FROM jsonb_array_elements(person_result->'items')
  WHERE value->>'id'='95400000-0000-4000-8000-000000000001';
 SELECT value INTO unmatched_student FROM jsonb_array_elements(person_result->'items')
  WHERE value->>'id'='95400000-0000-4000-8000-000000000002';
 PERFORM pg_temp.assert_true(linked_student->>'person_id'=linked_person::text AND
  linked_student->>'person_revision'='1' AND linked_student->>'revision'='1' AND
  linked_student->>'name'='Canonical From Convert' AND
  linked_student->'phone'='null'::jsonb AND
  linked_student->'address'->>'street'='Rua da Aurora' AND
  linked_student->>'link_state'='linked',
  'student projection joins canonical identity and independent revisions');
 PERFORM pg_temp.assert_true(unmatched_student->>'person_id' IS NULL AND
  unmatched_student->>'person_revision' IS NULL AND
  unmatched_student->>'name'='Unmatched Convert' AND
  unmatched_student->>'link_state'='unlinked',
  'unresolved student remains visible with its original snapshot');

 person_result:=public.ieadpe_ministry_list_class_students(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001',
  'class_id','95500000-0000-4000-8000-000000000001','limit',20,'cursor',NULL));
 class_entry:=person_result->'items'->0;
 PERFORM pg_temp.assert_true(jsonb_array_length(person_result->'items')=1 AND
  class_entry->'student'->>'person_id'=linked_person::text AND
  class_entry->'student'->>'revision'='1' AND
  class_entry->'student'->>'person_revision'='1' AND
  class_entry->'student'->>'name'='Canonical From Convert' AND
  class_entry->'enrollment'->>'id'='95600000-0000-4000-8000-000000000001',
  'class roster preserves enrollment and returns both independent student revisions');

 saved:=public.ieadpe_ministry_save_person(
  '95700000-0000-4000-8000-000000000001',
  jsonb_build_object('id',linked_person,'congregation_id','95200000-0000-4000-8000-000000000001',
   'expected_revision',1,'person',jsonb_build_object('name','Updated Canonical',
    'phone','   ','birth_date','1991-03-04','address',jsonb_build_object(
     'street','Rua Nova','district',NULL,'city',NULL,'postal_code',NULL,'state_code',NULL))));
 PERFORM pg_temp.assert_true(saved=jsonb_build_object('id',linked_person,'revision',2) AND
  (SELECT updated_by='95100000-0000-4000-8000-000000000001'::uuid
   FROM public.ministry_people WHERE id=linked_person) AND
  (SELECT revision=1 FROM public.ministry_students
   WHERE id='95400000-0000-4000-8000-000000000001'),
  'authenticated canonical edit records actor without changing student revision');
 person_result:=public.ieadpe_ministry_get_person(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001','person_id',linked_person));
 PERFORM pg_temp.assert_true(person_result->>'person_revision'='2' AND
  person_result->'person'->>'updated_by'='95100000-0000-4000-8000-000000000001' AND
  person_result->'person'->>'name'='Updated Canonical' AND
  person_result->'person'->>'phone'='   ',
  'saved person detail reflects actor, revision, and whitespace phone');
 person_result:=public.ieadpe_ministry_list_people(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001',
  'name_prefix',NULL,'limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true((SELECT value->>'phone'='   '
  FROM jsonb_array_elements(person_result->'items') WHERE value->>'id'=linked_person::text),
  'saved whitespace phone round-trips through people list');
 person_result:=public.ieadpe_ministry_list_students(jsonb_build_object(
  'congregation_id','95200000-0000-4000-8000-000000000001',
  'name_prefix',NULL,'limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true((SELECT value->>'phone'='   '
  FROM jsonb_array_elements(person_result->'items')
  WHERE value->>'id'='95400000-0000-4000-8000-000000000001'),
  'saved whitespace phone round-trips through active student projection');

 BEGIN
  PERFORM public.ieadpe_ministry_save_person(
   '95700000-0000-4000-8000-000000000002',
   jsonb_build_object('id',linked_person,'congregation_id','95200000-0000-4000-8000-000000000001',
    'expected_revision',1,'person',jsonb_build_object('name','Stale Person',
     'phone',NULL,'birth_date',NULL,'address',NULL)));
  RAISE EXCEPTION 'ASSERTION: stale person revision accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;

 linked:=public.ieadpe_ministry_link_student_person(
  '95700000-0000-4000-8000-000000000003',
  jsonb_build_object('congregation_id','95200000-0000-4000-8000-000000000001',
   'student_id','95400000-0000-4000-8000-000000000002','person_id',unmatched_person,
   'expected_student_revision',1,'expected_person_revision',1));
 PERFORM pg_temp.assert_true(linked=jsonb_build_object(
  'student_id','95400000-0000-4000-8000-000000000002','person_id',unmatched_person,
  'student_revision',2,'person_revision',1) AND
  (SELECT person_id=unmatched_person AND revision=2 FROM public.ministry_students
   WHERE id='95400000-0000-4000-8000-000000000002'),
  'explicit same-scope link increments only student revision');
 replay:=public.ieadpe_ministry_link_student_person(
  '95700000-0000-4000-8000-000000000003',
  jsonb_build_object('congregation_id','95200000-0000-4000-8000-000000000001',
   'student_id','95400000-0000-4000-8000-000000000002','person_id',unmatched_person,
   'expected_student_revision',1,'expected_person_revision',1));
 PERFORM pg_temp.assert_true(replay=linked,'exact person link retry replays its receipt');

 BEGIN
  PERFORM public.ieadpe_ministry_link_student_person(
   '95700000-0000-4000-8000-000000000004',
   jsonb_build_object('congregation_id','95200000-0000-4000-8000-000000000001',
    'student_id','95400000-0000-4000-8000-000000000002','person_id',unmatched_person,
    'expected_student_revision',1,'expected_person_revision',1));
  RAISE EXCEPTION 'ASSERTION: stale student revision accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;

 BEGIN
  PERFORM public.ieadpe_ministry_link_student_person(
   '95700000-0000-4000-8000-000000000005',
   jsonb_build_object('congregation_id','95200000-0000-4000-8000-000000000001',
    'student_id','95400000-0000-4000-8000-000000000003','person_id',unmatched_person,
    'expected_student_revision',1,'expected_person_revision',1));
  RAISE EXCEPTION 'ASSERTION: duplicate person/student link accepted';
 EXCEPTION WHEN SQLSTATE '22023' THEN
  GET STACKED DIAGNOSTICS error_message=MESSAGE_TEXT;
  PERFORM pg_temp.assert_true(error_message='person_link_conflict',
   'duplicate link returns the reviewed conflict message');
 END;
END $$;
ROLLBACK;
