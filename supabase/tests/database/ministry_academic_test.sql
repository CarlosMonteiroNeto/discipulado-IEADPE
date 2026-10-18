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
 VALUES('94000000-0000-0000-0000-000000000060','94000000-0000-0000-0000-000000000006','Academic B Class','academic b class','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000004','94000000-0000-0000-0000-000000000002','Learner A','learner a','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000005','94000000-0000-0000-0000-000000000002','Learner B','learner b','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000061','94000000-0000-0000-0000-000000000006','Academic B Learner A','academic b learner a','94000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000062','94000000-0000-0000-0000-000000000006','Academic B Learner B','academic b learner b','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000063','94000000-0000-0000-0000-000000000006',
  '94000000-0000-0000-0000-000000000061','94000000-0000-0000-0000-000000000060','2026-01-01','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,updated_by)
 VALUES('94000000-0000-0000-0000-000000000064','94000000-0000-0000-0000-000000000006',
  '94000000-0000-0000-0000-000000000060','2026-10-17','94000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,updated_by)
 SELECT ('94000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000002',
  'Capacity Learner '||n,'capacity learner '||n,'94000000-0000-0000-0000-000000000001' FROM generate_series(1001,1101) n;
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,status,end_date,updated_by)
 SELECT ('94100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000002',
  ('94000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'94000000-0000-0000-0000-000000000020','2026-01-01','completed','2026-06-01',
  '94000000-0000-0000-0000-000000000001' FROM generate_series(1001,1099) n;
SELECT set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE result jsonb; replay jsonb; class_result jsonb; BEGIN
 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000030',
  '{"id":"94000000-0000-0000-0000-000000000030","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Command Class","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='1','class create starts revision');
 class_result:=public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000031',
  '{"id":"94000000-0000-0000-0000-000000000030","congregation_id":"94000000-0000-0000-0000-000000000002","name":"Command Class Updated","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null,"expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='2','class update increments revision');
 class_result:=public.ieadpe_ministry_set_class_status('94000000-0000-0000-0000-000000000032',
  '{"id":"94000000-0000-0000-0000-000000000030","congregation_id":"94000000-0000-0000-0000-000000000002","status":"completed","expected_revision":2}'::jsonb);
 PERFORM pg_temp.assert_true(class_result->>'revision'='3' AND (SELECT status='completed' FROM public.ministry_classes WHERE id='94000000-0000-0000-0000-000000000030'),'class status is revisioned');
 BEGIN PERFORM public.ieadpe_ministry_save_class('94000000-0000-0000-0000-000000000070',
  '{"id":"94000000-0000-0000-0000-000000000070","congregation_id":"94000000-0000-0000-0000-000000000006","name":"Command Class","teacher_contact_id":null,"start_date":"2026-01-01","end_date":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction created a class in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 result:=public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000011',
  '{"id":"94000000-0000-0000-0000-000000000011","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","student_id":"94000000-0000-0000-0000-000000000004","start_date":"2026-01-01"}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'revision'='1','enrollment created');
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000071',
  '{"id":"94000000-0000-0000-0000-000000000071","congregation_id":"94000000-0000-0000-0000-000000000006","class_id":"94000000-0000-0000-0000-000000000060","student_id":"94000000-0000-0000-0000-000000000062","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction enrolled a student in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000014',
  '{"id":"94000000-0000-0000-0000-000000000014","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000003","student_id":"94000000-0000-0000-0000-000000000005","start_date":"2026-01-01"}'::jsonb);
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000017',
  '{"id":"94000000-0000-0000-0000-000000000017","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000040","student_id":"94000000-0000-0000-0000-000000000004","start_date":"2026-01-01"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: second active enrollment accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000021',
  '{"id":"94000000-0000-0000-0000-000000000021","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000020","student_id":"94000000-0000-0000-0000-000000001100","start_date":"2026-01-01"}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT count(*)=100 FROM public.ministry_enrollments WHERE class_id='94000000-0000-0000-0000-000000000020'),'99 to 100 historical enrollments allowed');
 BEGIN PERFORM public.ieadpe_ministry_enroll_student('94000000-0000-0000-0000-000000000022',
  '{"id":"94000000-0000-0000-0000-000000000022","congregation_id":"94000000-0000-0000-0000-000000000002","class_id":"94000000-0000-0000-0000-000000000020","student_id":"94000000-0000-0000-0000-000000001101","start_date":"2026-01-01"}'::jsonb);
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
