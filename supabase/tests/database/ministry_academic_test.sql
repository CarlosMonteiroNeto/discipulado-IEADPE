BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES('94000000-0000-0000-0000-000000000001','academic-staff@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('94000000-0000-0000-0000-000000000002','Academic A'),
 ('94000000-0000-0000-0000-000000000006','Academic B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
 VALUES('academic-staff@example.test','94000000-0000-0000-0000-000000000001','Membro da direção da campanha','94000000-0000-0000-0000-000000000002');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES('94000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000002','ministry_staff',true);
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000003','94000000-0000-0000-0000-000000000002','Academic Class','academic class','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000020','94000000-0000-0000-0000-000000000002','Capacity Class','capacity class','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000040','94000000-0000-0000-0000-000000000002','Other Class','other class','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000050','94000000-0000-0000-0000-000000000002','Empty Enrollment Class','empty enrollment class','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000060','94000000-0000-0000-0000-000000000006','Academic B Class','academic b class','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_contacts(id,congregation_id,name,normalized_name,scope,role_code,updated_by,archived_at) VALUES
 ('94000000-0000-0000-0000-000000000100','94000000-0000-0000-0000-000000000002','Local Teacher','local teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',NULL),
 ('94000000-0000-0000-0000-000000000101','94000000-0000-0000-0000-000000000002','Local Assistant','local assistant','congregation','congregationAssistant','94000000-0000-0000-0000-000000000001',NULL),
 ('94000000-0000-0000-0000-000000000102','94000000-0000-0000-0000-000000000006','Foreign Teacher','foreign teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',NULL),
 ('94000000-0000-0000-0000-000000000103','94000000-0000-0000-0000-000000000002','Archived Teacher','archived teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',now()),
 ('94000000-0000-0000-0000-000000000104','94000000-0000-0000-0000-000000000002','Archive Lifecycle Teacher','archive lifecycle teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',NULL),
 ('94000000-0000-0000-0000-000000000105','94000000-0000-0000-0000-000000000002','Role Change Teacher','role change teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',NULL),
 ('94000000-0000-0000-0000-000000000106','94000000-0000-0000-0000-000000000002','Archive Retry Teacher','archive retry teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',NULL),
 ('94000000-0000-0000-0000-000000000107','94000000-0000-0000-0000-000000000002','Role Retry Teacher','role retry teacher','congregation','teacher','94000000-0000-0000-0000-000000000001',NULL);
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,teacher_contact_id,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000085','94000000-0000-0000-0000-000000000002','Archived Teacher Lifecycle','archived teacher lifecycle','2026-01-01','94000000-0000-0000-0000-000000000104','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000086','94000000-0000-0000-0000-000000000002','Role Changed Teacher Lifecycle','role changed teacher lifecycle','2026-01-01','94000000-0000-0000-0000-000000000105','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000080','94000000-0000-0000-0000-000000000002','Open Session Class','open session class','2026-01-01','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000081','94000000-0000-0000-0000-000000000002','Active Enrollment Class','active enrollment class','2026-01-01','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000082','94000000-0000-0000-0000-000000000002','Completed History Class','completed history class','2026-01-01','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000083','94000000-0000-0000-0000-000000000002','Archived Class','archived class','2026-01-01','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000084','94000000-0000-0000-0000-000000000002','Empty Transition Class','empty transition class','2026-01-01','94000000-0000-0000-0000-000000000001');
UPDATE public.ministry_classes SET status='completed' WHERE id='94000000-0000-0000-0000-000000000082';
UPDATE public.ministry_classes SET status='archived' WHERE id='94000000-0000-0000-0000-000000000083';
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('94000001-0000-0000-0000-000000000004','94000000-0000-0000-0000-000000000002','Learner A','learner a','94000000-0000-0000-0000-000000000001'),
 ('94000001-0000-0000-0000-000000000005','94000000-0000-0000-0000-000000000002','Learner B','learner b','94000000-0000-0000-0000-000000000001'),
 ('94000001-0000-0000-0000-000000000066','94000000-0000-0000-0000-000000000002','Lifecycle Learner','lifecycle learner','94000000-0000-0000-0000-000000000001'),
 ('94000001-0000-0000-0000-000000000061','94000000-0000-0000-0000-000000000006','Academic B Learner A','academic b learner a','94000000-0000-0000-0000-000000000001'),
 ('94000001-0000-0000-0000-000000000062','94000000-0000-0000-0000-000000000006','Academic B Learner B','academic b learner b','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('94000001-0000-0000-0000-000000000063','94000000-0000-0000-0000-000000000002','First Class Learner','first class learner','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000004','94000000-0000-0000-0000-000000000002','94000001-0000-0000-0000-000000000004','Learner A','learner a','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000005','94000000-0000-0000-0000-000000000002','94000001-0000-0000-0000-000000000005','Learner B','learner b','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000066','94000000-0000-0000-0000-000000000002','94000001-0000-0000-0000-000000000066','Lifecycle Learner','lifecycle learner','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000061','94000000-0000-0000-0000-000000000006','94000001-0000-0000-0000-000000000061','Academic B Learner A','academic b learner a','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000062','94000000-0000-0000-0000-000000000006','94000001-0000-0000-0000-000000000062','Academic B Learner B','academic b learner b','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000063','94000000-0000-0000-0000-000000000006',
  '94000000-0000-0000-0000-000000000061','94000000-0000-0000-0000-000000000060','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,status,end_date,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000087','94000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000066','94000000-0000-0000-0000-000000000081','2026-01-01','active',NULL,'94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000088','94000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004','94000000-0000-0000-0000-000000000082','2026-01-01','completed','2026-06-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000064','94000000-0000-0000-0000-000000000006',
  '94000000-0000-0000-0000-000000000060','2026-10-17','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000086','94000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000080','2026-02-01','open','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000089','94000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000082','2026-02-01','finalized','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by)
 SELECT ('94010000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000002',
  'Capacity Learner '||n,'capacity learner '||n,'94000000-0000-0000-0000-000000000001' FROM generate_series(1001,1101) n;
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by)
 SELECT ('94000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000002',
  ('94010000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
  'Capacity Learner '||n,'capacity learner '||n,'94000000-0000-0000-0000-000000000001' FROM generate_series(1001,1101) n;
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,status,end_date,updated_by)
 SELECT ('94100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000002',
  ('94000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000020','2026-01-01','completed','2026-06-01',
  '94000000-0000-0000-0000-000000000001' FROM generate_series(1001,1099) n;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE result jsonb; replay jsonb; class_result jsonb; class_list jsonb; class_row jsonb; BEGIN
 result:=public.ieadpe_ministry_set_contact_archived('94000000-0000-0000-0000-000000000130',
  '{"id":"94000000-0000-0000-0000-000000000104","scope":"congregation","congregation_id":"94000000-0000-0000-0000-000000000002","archived":true,"expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'revision'='2','assigned teacher can be archived without deleting its historical class reference');
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000131',
  '{"id":"94000000-0000-0000-0000-000000000085","congregation_id":"94000000-0000-0000-0000-000000000002","status":"archived","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2' AND
  (SELECT status='archived' AND teacher_contact_id='94000000-0000-0000-0000-000000000104' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000085'),
  'active class can archive while preserving its archived teacher reference');
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000132',
  '{"id":"94000000-0000-0000-0000-000000000085","congregation_id":"94000000-0000-0000-0000-000000000002","status":"active","expected_revision":2}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='3' AND
  (SELECT status='active' AND teacher_contact_id='94000000-0000-0000-0000-000000000104' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000085'),
  'archived class can reactivate while preserving its archived teacher reference');

 result:=public.ieadpe_ministry_save_contact('94000000-0000-0000-0000-000000000133',
  '{"id":"94000000-0000-0000-0000-000000000105","scope":"congregation","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Role Change Teacher","role_code":"congregationAssistant","phone_e164":null,"birth_date":null,"email":null,"expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'revision'='2','assigned teacher can lose teacher role while preserving its historical class reference');
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000134',
  '{"id":"94000000-0000-0000-0000-000000000086","congregation_id":"94000000-0000-0000-0000-000000000002","status":"completed","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2' AND
  (SELECT status='completed' AND teacher_contact_id='94000000-0000-0000-0000-000000000105' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000086'),
  'active class can complete after its assigned contact loses the teacher role');
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000135',
  '{"id":"94000000-0000-0000-0000-000000000086","congregation_id":"94000000-0000-0000-0000-000000000002","status":"archived","expected_revision":2}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='3' AND
  (SELECT status='archived' AND teacher_contact_id='94000000-0000-0000-0000-000000000105' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000086'),
  'completed class can archive after its assigned contact loses the teacher role');
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000136',
  '{"id":"94000000-0000-0000-0000-000000000040","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Other Class","teacher_contact_id":"94000000-0000-0000-0000-000000000104","start_date":"2026-01-01","end_date":null,"expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived teacher assigned to a class'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000137',
  '{"id":"94000000-0000-0000-0000-000000000040","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Other Class","teacher_contact_id":"94000000-0000-0000-0000-000000000105","start_date":"2026-01-01","end_date":null,"expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: non-teacher contact assigned to a class'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000138',
  '{"id":"94000000-0000-0000-0000-000000000138","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Archive Retry Class","teacher_contact_id":"94000000-0000-0000-0000-000000000106","start_date":"2026-01-01","end_date":null}'::jsonb);
 result:=public.ieadpe_ministry_set_contact_archived('94000000-0000-0000-0000-000000000139',
  '{"id":"94000000-0000-0000-0000-000000000106","scope":"congregation","congregation_id":"94000000-0000-0000-0000-000000000002","archived":true,"expected_revision":1}'::jsonb);
 replay:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000138',
  '{"id":"94000000-0000-0000-0000-000000000138","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Archive Retry Class","teacher_contact_id":"94000000-0000-0000-0000-000000000106","start_date":"2026-01-01","end_date":null}'::jsonb);
 PERFORM pg_temp.assert_true(replay=class_result,'class save receipt replays after selected teacher is archived');

 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000140',
  '{"id":"94000000-0000-0000-0000-000000000140","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Role Retry Class","teacher_contact_id":"94000000-0000-0000-0000-000000000107","start_date":"2026-01-01","end_date":null}'::jsonb);
 result:=public.ieadpe_ministry_save_contact('94000000-0000-0000-0000-000000000141',
  '{"id":"94000000-0000-0000-0000-000000000107","scope":"congregation","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Role Retry Teacher","role_code":"congregationAssistant","phone_e164":null,"birth_date":null,"email":null,"expected_revision":1}'::jsonb);
 replay:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000140',
  '{"id":"94000000-0000-0000-0000-000000000140","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Role Retry Class","teacher_contact_id":"94000000-0000-0000-0000-000000000107","start_date":"2026-01-01","end_date":null}'::jsonb);
 PERFORM pg_temp.assert_true(replay=class_result,'class save receipt replays after selected contact loses teacher role');

 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000030',
  '{"id":"94000000-0000-0000-0000-000000000030","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Command Class","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='1','class create starts revision');
 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000031',
  '{"id":"94000000-0000-0000-0000-000000000030","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Command Class Updated","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null,"expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2','class update increments revision');
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000032',
  '{"id":"94000000-0000-0000-0000-000000000084","congregation_id":"94000000-0000-0000-0000-000000000002","status":"completed","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2' AND (SELECT status='completed' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000084'),'class status is revisioned');
 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000090',
  '{"id":"94000000-0000-0000-0000-000000000090","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Teacher Class","teacher_contact_id":"94000000-0000-0000-0000-000000000100","start_date":"2026-01-01","end_date":null}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='1','active same-congregation teacher can be assigned');
 class_list:=public.ieadpe_ministry_list_classes('{"congregation_id":"94000000-0000-0000-0000-000000000002","status":null,"limit":100,"cursor":null}'::jsonb);
 SELECT item INTO class_row FROM jsonb_array_elements(class_list->'items') item WHERE item->>'id'='94000000-0000-0000-0000-000000000090';
 PERFORM pg_temp.assert_true(class_row=jsonb_build_object('id','94000000-0000-0000-0000-000000000090','name','Teacher Class','status','active',
  'start_date','2026-01-01','end_date',NULL,'revision',1,'teacher_contact_id','94000000-0000-0000-0000-000000000100'),
  'class list returns the assigned teacher UUID in its bounded summary only');
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000091',
  '{"id":"94000000-0000-0000-0000-000000000091","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Nonteacher Class","teacher_contact_id":"94000000-0000-0000-0000-000000000101","start_date":"2026-01-01","end_date":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: non-teacher contact accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000092',
  '{"id":"94000000-0000-0000-0000-000000000092","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Foreign Teacher Class","teacher_contact_id":"94000000-0000-0000-0000-000000000102","start_date":"2026-01-01","end_date":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: foreign teacher contact accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000093',
  '{"id":"94000000-0000-0000-0000-000000000093","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Archived Teacher Class","teacher_contact_id":"94000000-0000-0000-0000-000000000103","start_date":"2026-01-01","end_date":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived teacher contact accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000094',
  '{"id":"94000000-0000-0000-0000-000000000090","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Stale Teacher Class","teacher_contact_id":"94000000-0000-0000-0000-000000000100","start_date":"2026-01-01","end_date":null,"expected_revision":7}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale class revision accepted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT revision=1 AND name='Teacher Class' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000090'),'stale class save leaves current class unchanged');
 BEGIN PERFORM public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000095',
  '{"id":"94000000-0000-0000-0000-000000000080","congregation_id":"94000000-0000-0000-0000-000000000002","status":"completed","expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: class completed with an open session'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000096',
  '{"id":"94000000-0000-0000-0000-000000000081","congregation_id":"94000000-0000-0000-0000-000000000002","status":"completed","expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: class completed with an active enrollment'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000097',
  '{"id":"94000000-0000-0000-0000-000000000080","congregation_id":"94000000-0000-0000-0000-000000000002","status":"archived","expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: class archived with session history'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000098',
  '{"id":"94000000-0000-0000-0000-000000000081","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Frozen Dates","teacher_contact_id":null,"start_date":"2026-02-01","end_date":null,"expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: class dates changed after enrollment history'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000110',
  '{"id":"94000000-0000-0000-0000-000000000082","congregation_id":"94000000-0000-0000-0000-000000000002","status":"active","expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: completed class reopened'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000099',
  '{"id":"94000000-0000-0000-0000-000000000082","congregation_id":"94000000-0000-0000-0000-000000000002","status":"archived","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2' AND (SELECT status='archived' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000082') AND
  (SELECT count(*)=1 FROM public.ministry_enrollments WHERE class_id='94000000-0000-0000-0000-000000000082') AND
  (SELECT count(*)=1 FROM public.ministry_sessions WHERE class_id='94000000-0000-0000-0000-000000000082'),
  'completed-to-archived preserves enrollment and session history');
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000111',
  '{"id":"94000000-0000-0000-0000-000000000082","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Edited Completed","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null,"expected_revision":2}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: completed class details edited'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000112',
  '{"id":"94000000-0000-0000-0000-000000000083","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Edited Archived","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null,"expected_revision":1}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived class details edited'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000113',
  '{"id":"94000000-0000-0000-0000-000000000083","congregation_id":"94000000-0000-0000-0000-000000000002","status":"active","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2' AND (SELECT status='active' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000083'),
  'archived class can reactivate through its supported transition');
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000070',
  '{"id":"94000000-0000-0000-0000-000000000070","congregation_id":"94000000-0000-0000-0000-000000000006","name":"Command Class","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction created a class in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 result:=public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000011',
  '{"id":"94000000-0000-0000-0000-000000000011","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","person_id":"94000001-0000-0000-0000-000000000004","start_date":"2026-01-01"}'::jsonb);
 PERFORM pg_temp.assert_true(result=jsonb_build_object('id','94000000-0000-0000-0000-000000000011',
  'student_id','94000000-0000-0000-0000-000000000004','person_id','94000001-0000-0000-0000-000000000004',
  'revision',1,'student_revision',1),'enrollment returns both linked IDs and revisions');
 replay:=public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000011',
  '{"id":"94000000-0000-0000-0000-000000000011","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","person_id":"94000001-0000-0000-0000-000000000004","start_date":"2026-01-01"}'::jsonb);
 PERFORM pg_temp.assert_true(replay=result,'enrollment retry returns its exact receipt');
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000011',
  '{"id":"94000000-0000-0000-0000-000000000011","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","person_id":"94000001-0000-0000-0000-000000000005","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: changed enrollment payload reused a receipt'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 result:=public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000074',
  '{"id":"94000000-0000-0000-0000-000000000074","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000050","person_id":"94000001-0000-0000-0000-000000000063","start_date":"2026-01-01"}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'student_id' IS NOT NULL AND
  (SELECT person_id='94000001-0000-0000-0000-000000000063' AND congregation_id='94000000-0000-0000-0000-000000000002'
   FROM public.ministry_students WHERE id=(result->>'student_id')::uuid) AND
  (SELECT count(*)=1 FROM public.ministry_enrollments WHERE class_id='94000000-0000-0000-0000-000000000050'),
  'first enrollment in an empty class atomically creates a same-scope academic extension');
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000075',
  '{"id":"94000000-0000-0000-0000-000000000075","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000050","person_id":"94000001-0000-0000-0000-000000000061","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: foreign congregation person enrolled'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000071',
  '{"id":"94000000-0000-0000-0000-000000000071","congregation_id":"94000000-0000-0000-0000-000000000006","class_id":"94000000-0000-0000-0000-000000000060","person_id":"94000001-0000-0000-0000-000000000062","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction enrolled a student in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000014',
  '{"id":"94000000-0000-0000-0000-000000000014","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","person_id":"94000001-0000-0000-0000-000000000005","start_date":"2026-01-01"}'::jsonb);
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000017',
  '{"id":"94000000-0000-0000-0000-000000000017","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000040","person_id":"94000001-0000-0000-0000-000000000004","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: second active enrollment accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000021',
  '{"id":"94000000-0000-0000-0000-000000000021","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000020","person_id":"94010000-0000-0000-0000-000000001100","start_date":"2026-01-01"}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT count(*)=100 FROM public.ministry_enrollments WHERE class_id='94000000-0000-0000-0000-000000000020'),'99 to 100 historical enrollments allowed');
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000022',
  '{"id":"94000000-0000-0000-0000-000000000022","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000020","person_id":"94010000-0000-0000-0000-000000001101","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: enrollment 101 exceeded capacity'; EXCEPTION WHEN check_violation OR invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT count(*)=100 FROM public.ministry_enrollments WHERE class_id='94000000-0000-0000-0000-000000000020'),'capacity rejection left no enrollment');
 result:=public.ieadpe_ministry_create_session('94000000-0000-0000-0000-000000000012',
  '{"id":"94000000-0000-0000-0000-000000000012","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","date":"2026-10-16","topic":"Lesson"}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='open','session created');
 BEGIN PERFORM public.ieadpe_ministry_create_session('94000000-0000-0000-0000-000000000072',
  '{"id":"94000000-0000-0000-0000-000000000072","congregation_id":"94000000-0000-0000-0000-000000000006","class_id":"94000000-0000-0000-0000-000000000060","date":"2026-10-16","topic":"Lesson"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction created a session in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000073',
  '{"congregation_id":"94000000-0000-0000-0000-000000000006","session_id":"94000000-0000-0000-0000-000000000064","expected_revision":1,"marks":{"94000000-0000-0000-0000-000000000063":"present"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction saved attendance in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 result:=public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000013',
  '{"congregation_id":"94000000-0000-0000-0000-000000000002","session_id":"94000000-0000-0000-0000-000000000012","expected_revision":1,"marks":{"94000000-0000-0000-0000-000000000011":"present","94000000-0000-0000-0000-000000000014":"excused"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='finalized' AND result->>'attendance_count'='2','attendance finalized atomically');
 replay:=public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000013',
  '{"congregation_id":"94000000-0000-0000-0000-000000000002","session_id":"94000000-0000-0000-0000-000000000012","expected_revision":1,"marks":{"94000000-0000-0000-0000-000000000011":"present","94000000-0000-0000-0000-000000000014":"excused"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(replay=result,'attendance retry replays exact receipt');
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000018',
  '{"congregation_id":"94000000-0000-0000-0000-000000000002","session_id":"94000000-0000-0000-0000-000000000012","expected_revision":1,"marks":{"94000000-0000-0000-0000-000000000011":"present","94000000-0000-0000-0000-000000000014":"excused"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale attendance revision accepted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000025',
  '{"congregation_id":"94000000-0000-0000-0000-000000000002","session_id":"94000000-0000-0000-0000-000000000012","expected_revision":2,"marks":{"94000000-0000-0000-0000-000000000011":"absent","94000000-0000-0000-0000-000000000014":"excused"},"finalize":false}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: finalized session edited without finalize flag'; EXCEPTION WHEN check_violation OR invalid_parameter_value THEN NULL; END;
 replay:=public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000026',
  '{"congregation_id":"94000000-0000-0000-0000-000000000002","session_id":"94000000-0000-0000-0000-000000000012","expected_revision":2,"marks":{"94000000-0000-0000-0000-000000000011":"absent","94000000-0000-0000-0000-000000000014":"excused"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(replay->>'status'='finalized' AND replay->>'revision'='3' AND
  (SELECT status='finalized' AND revision=3 FROM public.ministry_sessions WHERE id='94000000-0000-0000-0000-000000000012') AND
  (SELECT status='absent' AND revision=2 FROM public.ministry_attendance WHERE session_id='94000000-0000-0000-0000-000000000012' AND enrollment_id='94000000-0000-0000-0000-000000000011'),
  'finalized correction retains finalized state and increments revisions');
 PERFORM pg_temp.assert_true((public.ieadpe_ministry_get_enrollment_progress('{"congregation_id":"94000000-0000-0000-0000-000000000002","enrollment_id":"94000000-0000-0000-0000-000000000014"}'::jsonb)->>'denominator')::integer=0,'excused attendance excluded from denominator');
 PERFORM pg_temp.assert_true((public.ieadpe_ministry_get_enrollment_progress('{"congregation_id":"94000000-0000-0000-0000-000000000002","enrollment_id":"94000000-0000-0000-0000-000000000014"}'::jsonb)->'percentage')='null'::jsonb,'zero denominator returns null percentage');
 PERFORM pg_temp.assert_true((public.ieadpe_ministry_get_enrollment_progress('{"congregation_id":"94000000-0000-0000-0000-000000000002","enrollment_id":"94000000-0000-0000-0000-000000000011"}'::jsonb)->>'percentage')::numeric=0,'corrected absent mark changes progress');
 result:=public.ieadpe_ministry_close_enrollment('94000000-0000-0000-0000-000000000019',
  '{"id":"94000000-0000-0000-0000-000000000014","congregation_id":"94000000-0000-0000-0000-000000000002","status":"completed","end_date":"2026-10-16","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'revision'='2','close enrollment increments revision');
 PERFORM pg_temp.assert_true((SELECT count(*)=1 AND bool_and(status='completed' AND end_date='2026-10-16')
  FROM public.ministry_enrollments WHERE id='94000000-0000-0000-0000-000000000014'),
  'closing enrollment preserves the historical row and records its end state');
 BEGIN PERFORM public.ieadpe_ministry_create_session('94000000-0000-0000-0000-000000000015',
  '{"id":"94000000-0000-0000-0000-000000000015","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","date":"2026-10-16","topic":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: duplicate class date session accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM public.ieadpe_ministry_create_session('94000000-0000-0000-0000-000000000023',
  '{"id":"94000000-0000-0000-0000-000000000023","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000040","date":"2026-10-17","topic":null}'::jsonb);
 result:=public.ieadpe_ministry_cancel_session('94000000-0000-0000-0000-000000000024',
  '{"id":"94000000-0000-0000-0000-000000000023","congregation_id":"94000000-0000-0000-0000-000000000002","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='canceled' AND (SELECT status='canceled' FROM public.ministry_sessions WHERE id='94000000-0000-0000-0000-000000000023'),'session cancellation is revisioned');
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('94000000-0000-0000-0000-000000000016',
  '{"congregation_id":"94000000-0000-0000-0000-000000000002","session_id":"94000000-0000-0000-0000-000000000012","expected_revision":3,"marks":{"94000000-0000-0000-0000-000000000011":"present"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: wrong frozen roster accepted'; EXCEPTION WHEN check_violation OR invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT revision=3 AND status='finalized' FROM public.ministry_sessions WHERE id='94000000-0000-0000-0000-000000000012'),'invalid attendance leaves session untouched');
END $$;
ROLLBACK;
