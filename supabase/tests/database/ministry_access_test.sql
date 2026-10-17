BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('81000000-0000-0000-0000-000000000001','ministry-staff@example.test',now()),
 ('81000000-0000-0000-0000-000000000002','ministry-supervisor@example.test',now()),
 ('81000000-0000-0000-0000-000000000003','campaign-only@example.test',now()),
 ('81000000-0000-0000-0000-000000000004','inactive-staff@example.test',now()),
 ('81000000-0000-0000-0000-000000000005','other-staff@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('82000000-0000-0000-0000-000000000001','Ministry A'),
 ('82000000-0000-0000-0000-000000000002','Ministry B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('campaign-only@example.test','81000000-0000-0000-0000-000000000003','Membro da direção da campanha','82000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('81000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','ministry_staff',true),
 ('81000000-0000-0000-0000-000000000002',NULL,'ministry_supervision',true),
 ('81000000-0000-0000-0000-000000000004','82000000-0000-0000-0000-000000000001','ministry_staff',false),
 ('81000000-0000-0000-0000-000000000005','82000000-0000-0000-0000-000000000002','ministry_staff',true);
INSERT INTO public.ministry_contacts(id,congregation_id,name,normalized_name,scope,role_code,legacy_firebase_id,updated_by) VALUES
 ('83000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','Ana','ana','congregation','teacher','firebase-contact-1','81000000-0000-0000-0000-000000000001'),
 ('83000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','Bia','bia','congregation',NULL,'firebase-contact-2','81000000-0000-0000-0000-000000000001'),
 ('83000000-0000-0000-0000-000000000003',NULL,'Supervisor','supervisor','supervision',NULL,'firebase-contact-3','81000000-0000-0000-0000-000000000002'),
 ('83000000-0000-0000-0000-000000000004','82000000-0000-0000-0000-000000000001','Carla','carla','congregation','campaignLeader','firebase-contact-4','81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,legacy_firebase_id,updated_by) VALUES
 ('84000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','Lia','lia','firebase-student-1','81000000-0000-0000-0000-000000000001'),
 ('84000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','Mia','mia','firebase-student-2','81000000-0000-0000-0000-000000000005'),
 ('84000000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000001','Nia','nia','firebase-student-3','81000000-0000-0000-0000-000000000001');

DO $$ BEGIN
 INSERT INTO public.ministry_role_slots(id,congregation_id,scope,role_code,contact_id,updated_by)
 VALUES('85000000-0000-0000-0000-000000000001',NULL,'supervision','campaignSupervisor','83000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000001');
 RAISE EXCEPTION 'ASSERTION: local contact assigned to supervision slot';
 EXCEPTION WHEN check_violation OR foreign_key_violation THEN NULL; END $$;
DO $$ BEGIN
 INSERT INTO public.ministry_role_slots(id,congregation_id,scope,role_code,contact_id,updated_by)
 VALUES('85000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000001','congregation','teacher','83000000-0000-0000-0000-000000000004','81000000-0000-0000-0000-000000000001');
 RAISE EXCEPTION 'ASSERTION: contact with different role assigned to slot';
 EXCEPTION WHEN check_violation OR foreign_key_violation THEN NULL; END $$;
INSERT INTO public.ministry_role_slots(id,congregation_id,scope,role_code,contact_id,updated_by)
VALUES('85000000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000001','congregation','teacher','83000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000001');
DO $$ BEGIN
 INSERT INTO public.ministry_role_slots(id,congregation_id,scope,role_code,contact_id,updated_by)
 VALUES('85000000-0000-0000-0000-000000000004',NULL,'supervision','campaignSupervisor','ffffffff-ffff-ffff-ffff-ffffffffffff','81000000-0000-0000-0000-000000000001');
 RAISE EXCEPTION 'ASSERTION: missing role contact accepted';
 EXCEPTION WHEN check_violation OR foreign_key_violation THEN NULL; END $$;
DO $$ BEGIN
 UPDATE public.ministry_contacts SET role_code='campaignLeader' WHERE id='83000000-0000-0000-0000-000000000001';
 RAISE EXCEPTION 'ASSERTION: assigned contact role changed without replacing slot';
 EXCEPTION WHEN check_violation THEN NULL; END $$;
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,teacher_contact_id,start_date,updated_by)
VALUES('86000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','Class One','class one','83000000-0000-0000-0000-000000000001','2026-10-01','81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by)
VALUES('87000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001','2026-10-01','81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by)
VALUES('87000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000003','86000000-0000-0000-0000-000000000001','2026-10-01','81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,roster_frozen,updated_by)
VALUES('88000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001','2026-10-17','finalized',true,'81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,roster_frozen,updated_by)
VALUES('88000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001','2026-10-16','open',false,'81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,roster_frozen,updated_by)
VALUES('88000000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001','2026-10-15','open',false,'81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_session_roster(id,congregation_id,session_id,enrollment_id,student_id,student_name,updated_by)
VALUES('89000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','Lia','81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_attendance(id,congregation_id,session_id,enrollment_id,student_id,status,updated_by)
VALUES('8a000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','present','81000000-0000-0000-0000-000000000001');

SELECT pg_temp.assert_true((SELECT count(*)=9 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname LIKE 'ministry_%' AND c.relkind='r' AND c.relrowsecurity),'RLS enabled on every ministry table');
SELECT pg_temp.assert_true((SELECT count(*)=3 FROM public.ministry_students),'legacy Firebase keys are separate from UUID primary keys');
SELECT pg_temp.assert_true(NOT has_table_privilege('anon','public.ministry_grants','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_contacts','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_role_slots','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_students','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_classes','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_enrollments','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_sessions','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_session_roster','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_attendance','SELECT') AND
 NOT has_table_privilege('anon','public.ministry_students','SELECT') AND
 NOT has_table_privilege('authenticated','public.ministry_students','SELECT') AND
 NOT has_table_privilege('authenticated','public.ministry_contacts','SELECT') AND
 NOT has_table_privilege('authenticated','public.ministry_grants','SELECT') AND
 NOT has_table_privilege('authenticated','public.ministry_session_roster','SELECT'),'ministry reads are exposed through bounded RPCs only');
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.ieadpe_ministry_list_directory(jsonb)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_ministry_list_class_students(jsonb)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_ministry_get_session_attendance(jsonb)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_ministry_get_enrollment_progress(jsonb)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_ministry_get_overview(jsonb)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_ministry_list_pending_sessions(jsonb)','EXECUTE'),'anonymous clients cannot call ministry read RPCs');
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM count(*) FROM public.ministry_contacts; RAISE EXCEPTION 'ASSERTION: anonymous contact read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM count(*) FROM public.ministry_session_roster; RAISE EXCEPTION 'ASSERTION: anonymous roster read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_pending_sessions('{"congregation_id":null,"limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: anonymous bounded ministry RPC accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.ministry_students','INSERT') AND NOT has_table_privilege('authenticated','public.ministry_attendance','UPDATE'),'ministry client role has no business write privilege');
SELECT pg_temp.assert_true((public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb)->'items'->0->>'name')='Ana','directory projects allowed contact and page one');
SELECT pg_temp.assert_true(public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb)->>'next_cursor' IS NOT NULL,'full page returns continuation');
DO $$ DECLARE response jsonb; BEGIN
 response:=public.ieadpe_ministry_list_class_students('{"congregation_id":"82000000-0000-0000-0000-000000000001","class_id":"86000000-0000-0000-0000-000000000001","limit":10,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=2 AND response->'items'->0->'student'->>'name'='Lia','class roster uses scoped capped student projection');
 response:=public.ieadpe_ministry_list_class_students('{"congregation_id":"82000000-0000-0000-0000-000000000001","class_id":"86000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=1 AND response->>'next_cursor' IS NOT NULL,'class roster page is bounded and returns continuation');
 response:=public.ieadpe_ministry_list_class_students(jsonb_set('{"congregation_id":"82000000-0000-0000-0000-000000000001","class_id":"86000000-0000-0000-0000-000000000001","limit":1}'::jsonb,'{cursor}',response->'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=1 AND response->'items'->0->'student'->>'name'='Nia' AND response->>'next_cursor' IS NULL,'class roster cursor resumes in stable order');
 response:=public.ieadpe_ministry_get_session_attendance('{"congregation_id":"82000000-0000-0000-0000-000000000001","session_id":"88000000-0000-0000-0000-000000000001"}'::jsonb);
 PERFORM pg_temp.assert_true(response->'session'->>'date'='2026-10-17' AND response->'roster'->0->>'status'='present','attendance read preserves frozen name and mark');
 response:=public.ieadpe_ministry_get_enrollment_progress('{"congregation_id":"82000000-0000-0000-0000-000000000001","enrollment_id":"87000000-0000-0000-0000-000000000001"}'::jsonb);
 PERFORM pg_temp.assert_true(response->>'present'='1' AND response->>'denominator'='1' AND (response->>'percentage')::numeric=1,'progress counts finalized attendance');
 response:=public.ieadpe_ministry_get_overview('{"congregation_id":"82000000-0000-0000-0000-000000000001"}'::jsonb);
 PERFORM pg_temp.assert_true(response->>'students'='2' AND response->>'classes'='1' AND response->>'open_sessions'='2','overview returns bounded scoped aggregates');
 response:=public.ieadpe_ministry_list_pending_sessions('{"congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=1 AND response->'items'->0->>'date'='2026-10-15' AND response->>'next_cursor' IS NOT NULL,'pending sessions applies server business-date cutoff and page bound');
 response:=public.ieadpe_ministry_list_pending_sessions(jsonb_set('{"congregation_id":"82000000-0000-0000-0000-000000000001","limit":1}'::jsonb,'{cursor}',response->'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=1 AND response->'items'->0->>'date'='2026-10-16' AND response->>'next_cursor' IS NULL,'pending session cursor resumes in stable order');
 BEGIN PERFORM public.ieadpe_ministry_list_class_students('{"congregation_id":"82000000-0000-0000-0000-000000000001","class_id":"86000000-0000-0000-0000-000000000001","limit":101,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: class roster page over limit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_students('{"congregation_id":"82000000-0000-0000-0000-000000000001","class_id":"86000000-0000-0000-0000-000000000001","limit":1.5,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: fractional class roster page accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_pending_sessions('{"congregation_id":"82000000-0000-0000-0000-000000000001","limit":101,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: pending session page over limit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_pending_sessions('{"congregation_id":"82000000-0000-0000-0000-000000000001","limit":1.5,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: fractional pending session page accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_get_overview('{"congregation_id":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: staff read global ministry overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_pending_sessions('{"congregation_id":null,"limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: staff listed global pending sessions'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
DO $$ DECLARE response jsonb; BEGIN
 response:=public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb);
 response:=public.ieadpe_ministry_list_directory(jsonb_set('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1}'::jsonb,'{cursor}',response->'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=1 AND response->>'next_cursor' IS NULL,'last page returns one remaining scoped contact and terminates');
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":10,"name_prefix":"zzz","cursor":null}'::jsonb)->'items')=0,'empty first page returns no items');
 BEGIN PERFORM public.ieadpe_ministry_list_directory(jsonb_set('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"name_prefix":"a"}'::jsonb,'{cursor}', (SELECT public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb)->'next_cursor'))); RAISE EXCEPTION 'ASSERTION: cursor reused under different filters'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"all","congregation_id":null,"limit":20,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: staff may list all'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"supervision","congregation_id":"82000000-0000-0000-0000-000000000001","limit":20,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: unsupported supervision filter accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN INSERT INTO public.ministry_students(congregation_id,name,normalized_name) VALUES('82000000-0000-0000-0000-000000000001','forged','forged'); RAISE EXCEPTION 'ASSERTION: direct business write accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000003',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.ministry_students','SELECT'),'campaign direction has no direct ministry table read');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000004',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.ministry_students','SELECT'),'inactive grant has no direct ministry table read');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000005',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: staff read another congregation contacts'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM count(*) FROM public.ministry_contacts; RAISE EXCEPTION 'ASSERTION: cross-congregation staff read contacts directly'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM count(*) FROM public.ministry_session_roster; RAISE EXCEPTION 'ASSERTION: cross-congregation staff read roster directly'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_get_session_attendance('{"congregation_id":"82000000-0000-0000-0000-000000000001","session_id":"88000000-0000-0000-0000-000000000001"}'::jsonb); RAISE EXCEPTION 'ASSERTION: cross-congregation staff read session roster RPC'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_directory('{"scope":"all","congregation_id":null,"limit":100,"cursor":null}'::jsonb)->'items')=4,'supervisor all-scope directory bounded projection');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":null,"limit":101,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: oversized page accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"all","congregation_id":"82000000-0000-0000-0000-000000000001","limit":20,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: all plus congregation accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
