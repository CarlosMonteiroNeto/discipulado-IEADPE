BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF;
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('99100000-0000-4000-8000-000000000001','p2-staff@example.test',now()),
 ('99100000-0000-4000-8000-000000000002','p2-global@example.test',now()),
 ('99100000-0000-4000-8000-000000000003','p2-other@example.test',now()),
 ('99100000-0000-4000-8000-000000000004','p2-registrar@example.test',now()),
 ('99100000-0000-4000-8000-000000000005','p2-scoped@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('99200000-0000-4000-8000-000000000001','P2 Scope A'),
 ('99200000-0000-4000-8000-000000000002','P2 Scope B'),
 ('99200000-0000-4000-8000-000000000003','P2 Archived Scope');
UPDATE public.congregations SET archived_at=now()
 WHERE id='99200000-0000-4000-8000-000000000003';
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('p2-staff@example.test','99100000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','99200000-0000-4000-8000-000000000001'),
 ('p2-global@example.test','99100000-0000-4000-8000-000000000002',
  'Membro da supervisão das campanhas',NULL),
 ('p2-other@example.test','99100000-0000-4000-8000-000000000003',
  'Membro da direção da campanha','99200000-0000-4000-8000-000000000002'),
 ('p2-scoped@example.test','99100000-0000-4000-8000-000000000005',
  'Membro da direção da campanha','99200000-0000-4000-8000-000000000001');

SELECT set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000001',true);
DO $$
DECLARE
 registration jsonb;
 replay jsonb;
 convert_result jsonb;
 edited jsonb;
 page jsonb;
 detail jsonb;
 student_id uuid:='99300000-0000-4000-8000-000000000001';
 registration_person_uuid uuid:='99400000-0000-4000-8000-000000000001';
 long_convert_id uuid:='99300000-0000-4000-8000-000000000002';
 long_person_id uuid:='99400000-0000-4000-8000-000000000002';
 unscoped_id uuid:='99300000-0000-4000-8000-000000000003';
 long_name text:=repeat('Legacy Canonical Person ',10)||'Tail';
 registration_payload jsonb:=jsonb_build_object(
  'id','99300000-0000-4000-8000-000000000001',
  'person_id','99400000-0000-4000-8000-000000000001',
  'congregation_id','99200000-0000-4000-8000-000000000001',
  'person',jsonb_build_object('name','Ana Silva','phone',NULL,'birth_date','1990-02-28',
   'address',jsonb_build_object('street','Rua A','district',NULL,'city','Recife',
    'postal_code',NULL,'state_code','PE')),
  'academic',jsonb_build_object('education','Médio','marital_status',NULL,
   'new_convert',false,'water_baptized',NULL,'wants_baptism',true));
 person_payload jsonb;
 convert_payload jsonb;
 long_edit jsonb;
BEGIN
 registration:=public.ieadpe_ministry_register_student(
  '99500000-0000-4000-8000-000000000001',registration_payload);
 PERFORM pg_temp.assert_true(registration=jsonb_build_object(
  'id',student_id,'person_id',registration_person_uuid,'revision',1,'person_revision',1),
  'student registration returns exact independent IDs and revisions');
 PERFORM pg_temp.assert_true((SELECT s.person_id=registration_person_uuid AND s.revision=1
  FROM public.ministry_students s WHERE s.id=student_id) AND
  (SELECT p.name='Ana Silva' AND p.revision=1 AND p.phone IS NULL AND p.birth_date='1990-02-28'
   AND p.address->>'street'='Rua A' FROM public.ministry_people p WHERE p.id=registration_person_uuid),
  'registration creates canonical person and student in the requested congregation');
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.converts c WHERE c.person_id=registration_person_uuid) AND
  NOT EXISTS(SELECT FROM public.convert_events),
  'student registration creates no convert or conversion event');
 replay:=public.ieadpe_ministry_register_student(
  '99500000-0000-4000-8000-000000000001',registration_payload);
 PERFORM pg_temp.assert_true(replay=registration,
  'exact student registration retry returns its original receipt');
 BEGIN
  PERFORM public.ieadpe_ministry_register_student(
   '99500000-0000-4000-8000-000000000001',
   jsonb_set(registration_payload,'{person,name}','"Changed Payload"'::jsonb));
  RAISE EXCEPTION 'ASSERTION: changed payload reused a registration operation ID';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_register_student(
   '99500000-0000-4000-8000-000000000002',
   registration_payload||jsonb_build_object('conversion_date','2026-10-01'));
  RAISE EXCEPTION 'ASSERTION: student registration accepted conversion data';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 PERFORM public.ieadpe_ministry_save_student(
  '99500000-0000-4000-8000-000000000003',jsonb_build_object(
   'id',student_id,'congregation_id','99200000-0000-4000-8000-000000000001',
   'education','Superior','marital_status',NULL,'new_convert',false,
   'water_baptized',NULL,'wants_baptism',true,'expected_revision',1));
 PERFORM pg_temp.assert_true((SELECT name='Ana Silva' AND revision=2 AND
  education='Superior' FROM public.ministry_students WHERE id=student_id) AND
  (SELECT p.revision=1 AND p.name='Ana Silva' FROM public.ministry_people p WHERE p.id=registration_person_uuid),
  'academic save changes only the student extension');
 BEGIN
  PERFORM public.ieadpe_ministry_save_student(
   '99500000-0000-4000-8000-000000000004',jsonb_build_object(
    'id',student_id,'congregation_id','99200000-0000-4000-8000-000000000001',
    'name','Must Not Rename Person','expected_revision',2));
  RAISE EXCEPTION 'ASSERTION: academic save accepted shared identity fields';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 convert_payload:=jsonb_build_object(
  'congregation_id','99200000-0000-4000-8000-000000000001',
  'person',jsonb_build_object('name','Convert Person','phone','+5511999990000',
   'birth_date',NULL,'address',jsonb_build_object('street','Rua B','district',NULL,
    'city',NULL,'postal_code',NULL,'state_code',NULL)),
  'convert',jsonb_build_object('landmark','Perto da praça','gender','female',
   'conversion_date',private.business_today(),'worship_type','Culto regular',
   'age',NULL,'photo_asset_id',NULL));
 convert_result:=public.ieadpe_create_convert(
  '99500000-0000-4000-8000-000000000005',convert_payload);
 PERFORM pg_temp.assert_true(convert_result ?& ARRAY['id','person_id','revision','person_revision'] AND
  (convert_result->>'revision')::integer=1 AND
  (convert_result->>'person_revision')::integer=1 AND
  convert_result->>'id'<>convert_result->>'person_id',
  'convert create returns its distinct convert and person IDs and revisions');
 person_payload:=convert_payload->'person';
 -- The write response does not echo the convert object; read the exact current fields.
 SELECT jsonb_build_object('landmark',landmark,'gender',gender,
  'conversion_date',conversion_date,'worship_type',worship_type,'age',age,
  'photo_asset_id',photo_asset_id) INTO convert_payload
 FROM public.converts WHERE id=(convert_result->>'id')::uuid;
 convert_payload:=jsonb_build_object(
  'id',convert_result->>'id','congregation_id','99200000-0000-4000-8000-000000000001',
  'expected_revision',1,'expected_person_revision',1,'person',person_payload,
  'convert',jsonb_set(convert_payload,'{landmark}','"Perto do mercado"'::jsonb));
 edited:=public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000006',convert_payload);
 PERFORM pg_temp.assert_true(edited->>'revision'='2' AND
  edited->>'person_revision'='1' AND edited->>'person_id'=convert_result->>'person_id',
  'convert edit preserves independent person revision when identity is unchanged');
 PERFORM pg_temp.assert_true(public.ieadpe_edit_convert(
  '99500000-0000-4000-8000-000000000006',convert_payload)=edited,
  'exact convert edit retry returns its receipt');
 BEGIN
  PERFORM public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000006',
   jsonb_set(convert_payload,'{convert,landmark}','"Changed"'::jsonb));
  RAISE EXCEPTION 'ASSERTION: changed convert payload reused an operation ID';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name)
 VALUES(long_person_id,'99200000-0000-4000-8000-000000000001',long_name,lower(long_name));
 INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
  congregation_id,age,last_visit_date,created_by,person_id,revision)
 VALUES(long_convert_id,long_convert_id::text,long_name,'Legacy point','male',
  private.business_today(),'Culto regular','99200000-0000-4000-8000-000000000001',NULL,
  private.business_today(),'99100000-0000-4000-8000-000000000001',long_person_id,1);
 person_payload:=jsonb_build_object('name',long_name,'phone',NULL,'birth_date',NULL,'address',NULL);
 SELECT jsonb_build_object('landmark',landmark,'gender',gender,
  'conversion_date',conversion_date,'worship_type',worship_type,'age',age,
  'photo_asset_id',photo_asset_id) INTO convert_payload
 FROM public.converts WHERE id=long_convert_id;
 long_edit:=jsonb_build_object('id',long_convert_id,'congregation_id','99200000-0000-4000-8000-000000000001',
  'expected_revision',1,'expected_person_revision',1,'person',person_payload,
  'convert',jsonb_set(convert_payload,'{landmark}','"Unrelated edit"'::jsonb));
 edited:=public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000007',long_edit);
 PERFORM pg_temp.assert_true(edited->>'revision'='2' AND edited->>'person_revision'='1' AND
  (SELECT name=long_name AND revision=1 FROM public.ministry_people WHERE id=long_person_id),
  'unchanged overlong canonical name round-trips without a person revision write');
 BEGIN
  PERFORM public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000008',
   jsonb_set(long_edit,'{person,name}',to_jsonb(repeat('Too Long ',30))));
  RAISE EXCEPTION 'ASSERTION: changed overlong canonical name was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
  congregation_id,age,last_visit_date,created_by,revision)
 VALUES(unscoped_id,unscoped_id::text,'Unlinked Legacy','Old point','female',
  private.business_today(),'Culto regular',NULL,NULL,private.business_today(),
  '99100000-0000-4000-8000-000000000001',1);
 page:=public.ieadpe_ministry_list_converts(jsonb_build_object(
  'congregation_id','99200000-0000-4000-8000-000000000001','name_prefix',NULL,
  'limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')>=2 AND
  EXISTS(SELECT FROM jsonb_array_elements(page->'items') item
   WHERE item->'convert'->>'id'=long_convert_id::text AND
    item->'person'->>'name'=long_name AND item->>'person_revision'='1' AND
    item->'legacy_identity'='null'::jsonb),
  'convert list joins canonical identity and keeps the overlong value unchanged');
 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object(
  'congregation_id','99200000-0000-4000-8000-000000000001',
  'convert_id',long_convert_id));
 PERFORM pg_temp.assert_true(detail->'person'->>'name'=long_name AND
  detail->>'person_revision'='1' AND detail->'convert'->>'revision'='2',
  'convert detail joins independent canonical and convert revisions');
 BEGIN
  PERFORM public.ieadpe_ministry_list_converts(jsonb_build_object(
   'congregation_id',NULL,'name_prefix',NULL,'limit',10,'cursor',NULL));
  RAISE EXCEPTION 'ASSERTION: local direction used a global convert list';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_convert(jsonb_build_object(
   'congregation_id',NULL,'convert_id',unscoped_id));
  RAISE EXCEPTION 'ASSERTION: local direction read an unscoped convert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 PERFORM set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000002',true);
 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object(
  'congregation_id',NULL,'convert_id',unscoped_id));
 PERFORM pg_temp.assert_true(detail->'person'='null'::jsonb AND
  detail->>'person_revision' IS NULL AND
  detail->'legacy_identity'->>'name'='Unlinked Legacy' AND
  detail->'legacy_identity'->>'address' IS NULL,
  'global manager can detail-read null-scope legacy identity snapshot');

END $$;

SELECT set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000004',true);
DO $$
DECLARE
 scope_id uuid:='99200000-0000-4000-8000-000000000001';
 create_payload jsonb:=jsonb_build_object(
  'congregation_id','99200000-0000-4000-8000-000000000001',
  'person',jsonb_build_object('name','Registrar Created','phone',NULL,
   'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Near the square','gender','female',
   'conversion_date',private.business_today(),'worship_type','Culto regular',
   'age',NULL,'photo_asset_id',NULL));
BEGIN
 -- Approved policy: authentication alone no longer permits official creation.
 BEGIN
  PERFORM public.ieadpe_create_convert(
   '99500000-0000-4000-8000-000000000011',create_payload);
  RAISE EXCEPTION 'ASSERTION: no-grant registrar created a convert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.converts c
  WHERE c.name='Registrar Created' AND c.congregation_id=scope_id),
  'no-grant registrar creates no official convert');

 BEGIN
  PERFORM public.ieadpe_ministry_list_converts(jsonb_build_object(
   'congregation_id',scope_id,'name_prefix',NULL,'limit',10,'cursor',NULL));
  RAISE EXCEPTION 'ASSERTION: registrar read the protected convert list';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_convert(jsonb_build_object(
   'congregation_id',scope_id,
   'convert_id','99300000-0000-4000-8000-000000000002'));
  RAISE EXCEPTION 'ASSERTION: registrar read a saved convert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_register_student(
   '99500000-0000-4000-8000-000000000012',jsonb_build_object(
    'id','99300000-0000-4000-8000-000000000011',
    'person_id','99400000-0000-4000-8000-000000000011',
    'congregation_id',scope_id,
    'person',jsonb_build_object('name','Registrar Student'),
    'academic',jsonb_build_object('new_convert',false)));
  RAISE EXCEPTION 'ASSERTION: registrar registered a student';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000013',
   jsonb_build_object('id','99300000-0000-4000-8000-000000000002',
    'congregation_id',scope_id,
    'expected_revision',1,'expected_person_revision',1,
    'person',create_payload->'person','convert',create_payload->'convert'));
  RAISE EXCEPTION 'ASSERTION: registrar edited a saved convert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000005',true);
DO $$
DECLARE
 scope_id uuid:='99200000-0000-4000-8000-000000000001';
 created jsonb;
 create_payload jsonb:=jsonb_build_object(
  'congregation_id','99200000-0000-4000-8000-000000000001',
  'person',jsonb_build_object('name','Registrar Created','phone',NULL,
   'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Near the square','gender','female',
   'conversion_date',private.business_today(),'worship_type','Culto regular',
   'age',NULL,'photo_asset_id',NULL));
BEGIN
 -- A local direction grant permits immediate official creation in its scope.
 created:=public.ieadpe_create_convert(
  '99500000-0000-4000-8000-000000000015',create_payload);
 PERFORM pg_temp.assert_true(created ?& ARRAY['id','person_id','revision','person_revision'] AND
  created-ARRAY['id','person_id','revision','person_revision']='{}'::jsonb AND
  (created->>'revision')::integer=1 AND (created->>'person_revision')::integer=1 AND
  created->>'id'<>created->>'person_id' AND
  (SELECT c.congregation_id=scope_id AND c.name='Registrar Created' AND
   c.created_by='99100000-0000-4000-8000-000000000005' AND
   p.congregation_id=scope_id AND p.name='Registrar Created' AND p.revision=1
   FROM public.converts c JOIN public.ministry_people p ON p.id=c.person_id
   WHERE c.id=(created->>'id')::uuid),
  'scoped direction creates one canonical convert in its active congregation');

 create_payload:=jsonb_set(create_payload,'{congregation_id}',
  to_jsonb('99200000-0000-4000-8000-000000000003'::text));
 BEGIN
  PERFORM public.ieadpe_create_convert(
   '99500000-0000-4000-8000-000000000014',create_payload);
  RAISE EXCEPTION 'ASSERTION: scoped direction created a convert in an archived congregation';
 EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.converts c
  WHERE c.name='Registrar Created' AND c.congregation_id='99200000-0000-4000-8000-000000000003'),
  'scoped direction cannot create in an archived congregation');
END $$;

DO $$
DECLARE
 long_convert_id uuid:='99300000-0000-4000-8000-000000000002';
 retry_payload jsonb;
 archived_edit jsonb;
 person_payload jsonb;
 convert_payload jsonb;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000002',true);
 PERFORM public.ieadpe_archive_congregation('99500000-0000-4000-8000-000000000010',
  jsonb_build_object('id','99200000-0000-4000-8000-000000000001'));
 PERFORM set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000001',true);

 SELECT jsonb_build_object('name',p.name,'phone',p.phone,'birth_date',p.birth_date,
  'address',p.address) INTO person_payload
 FROM public.ministry_people p JOIN public.converts c ON c.person_id=p.id
 WHERE c.id=long_convert_id;
 SELECT jsonb_build_object('landmark',c.landmark,'gender',c.gender,
  'conversion_date',c.conversion_date,'worship_type',c.worship_type,'age',c.age,
  'photo_asset_id',c.photo_asset_id) INTO convert_payload
 FROM public.converts c WHERE c.id=long_convert_id;
 retry_payload:=jsonb_build_object('id',long_convert_id,
  'congregation_id','99200000-0000-4000-8000-000000000001',
  'expected_revision',1,'expected_person_revision',1,
  'person',person_payload,'convert',convert_payload);
 BEGIN
  PERFORM public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000007',retry_payload);
  RAISE EXCEPTION 'ASSERTION: archived congregation edit retry returned its receipt';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 archived_edit:=jsonb_set(retry_payload,'{expected_revision}',to_jsonb(2));
 archived_edit:=jsonb_set(archived_edit,'{convert,landmark}',to_jsonb('Must Not Save'::text));
 BEGIN
  PERFORM public.ieadpe_edit_convert('99500000-0000-4000-8000-000000000009',archived_edit);
  RAISE EXCEPTION 'ASSERTION: archived congregation accepted a new convert edit';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT c.revision=2 AND c.landmark='Unrelated edit' AND
  p.revision=1 AND p.name=repeat('Legacy Canonical Person ',10)||'Tail' AND
  p.normalized_name=lower(p.name) AND p.phone IS NULL AND p.birth_date IS NULL AND p.address IS NULL
  FROM public.converts c JOIN public.ministry_people p ON p.id=c.person_id
  WHERE c.id=long_convert_id),
  'archived edit retry and new edit leave convert and canonical person unchanged');
END $$;
-- Supervisors can register students in an active congregation without a local grant.
SELECT set_config('request.jwt.claim.sub','99100000-0000-4000-8000-000000000002',true);
DO $$
DECLARE result jsonb;
BEGIN
 result:=public.ieadpe_ministry_register_student(
  '99500000-0000-4000-8000-000000000090', jsonb_build_object(
   'id','99300000-0000-4000-8000-000000000090',
   'person_id','99400000-0000-4000-8000-000000000090',
   'congregation_id','99200000-0000-4000-8000-000000000002',
   'person',jsonb_build_object('name','Aluno Supervisor Sintetico','phone',NULL,'birth_date',NULL,
    'address',jsonb_build_object('street',NULL,'district',NULL,'city',NULL,'postal_code',NULL,'state_code',NULL)),
   'academic',jsonb_build_object('education',NULL,'marital_status',NULL,'new_convert',false,'water_baptized',NULL,'wants_baptism',NULL)));
 PERFORM pg_temp.assert_true(result->>'id'='99300000-0000-4000-8000-000000000090' AND
  EXISTS(SELECT FROM public.ministry_students WHERE id='99300000-0000-4000-8000-000000000090'
   AND congregation_id='99200000-0000-4000-8000-000000000002'),
  'supervisor registers student in chosen active congregation');
END $$;
ROLLBACK;
