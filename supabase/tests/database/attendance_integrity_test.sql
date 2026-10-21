BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('95000000-0000-4000-8000-000000000001','attendance-integrity@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('95000000-0000-4000-8000-000000000010','Integrity A'),
 ('95000000-0000-4000-8000-000000000011','Integrity B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('attendance-integrity@example.test','95000000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','95000000-0000-4000-8000-000000000010');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('95000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000010','ministry_staff',true);
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,end_date,status,updated_by) VALUES
 ('95000000-0000-4000-8000-000000000100','95000000-0000-4000-8000-000000000010','Integrity Active','integrity active','2026-01-01','2026-12-31','active','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000101','95000000-0000-4000-8000-000000000010','Integrity Completed','integrity completed','2026-01-01','2026-12-31','completed','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000102','95000000-0000-4000-8000-000000000010','Integrity Archived','integrity archived','2026-01-01','2026-12-31','archived','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000103','95000000-0000-4000-8000-000000000011','Integrity Foreign','integrity foreign','2026-01-01','2026-12-31','active','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000104','95000000-0000-4000-8000-000000000010','Integrity Lineage','integrity lineage','2026-01-01','2026-12-31','active','95000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('95000001-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000010','Learner One','learner one','95000000-0000-4000-8000-000000000001'),
 ('95000001-0000-4000-8000-000000000002','95000000-0000-4000-8000-000000000010','Learner Two','learner two','95000000-0000-4000-8000-000000000001'),
 ('95000001-0000-4000-8000-000000000003','95000000-0000-4000-8000-000000000010','Learner Three','learner three','95000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by) VALUES
 ('95000000-0000-4000-8000-000000000201','95000000-0000-4000-8000-000000000010','95000001-0000-4000-8000-000000000001','Learner One','learner one','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000202','95000000-0000-4000-8000-000000000010','95000001-0000-4000-8000-000000000002','Learner Two','learner two','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000203','95000000-0000-4000-8000-000000000010','95000001-0000-4000-8000-000000000003','Learner Three','learner three','95000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
 ('95000000-0000-4000-8000-000000000301','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000201','95000000-0000-4000-8000-000000000100','2026-01-01','95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000302','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000202','95000000-0000-4000-8000-000000000104','2026-01-01','95000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,roster_frozen,updated_by) VALUES
 ('95000000-0000-4000-8000-000000000400','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000100','2026-10-15','open',false,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000401','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000100','2026-10-16','open',false,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000402','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000101','2026-10-15','finalized',true,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000403','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000102','2026-10-15','finalized',true,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000404','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000104','2026-10-10','open',false,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000405','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000104','2026-10-11','open',false,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000406','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000100','2025-12-31','canceled',false,'95000000-0000-4000-8000-000000000001'),
 ('95000000-0000-4000-8000-000000000407','95000000-0000-4000-8000-000000000011','95000000-0000-4000-8000-000000000103','2026-10-10','canceled',false,'95000000-0000-4000-8000-000000000001');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
 congregation_id,person_id,last_visit_date,was_visited_once,visit_count)
 VALUES('95000000-0000-4000-8000-000000000500','integrity-convert','Learner One','Square','female',
  '2026-01-01','Culto regular','95000000-0000-4000-8000-000000000010',
  '95000001-0000-4000-8000-000000000001','2026-10-16',true,1);

SELECT set_config('request.jwt.claim.sub','95000000-0000-4000-8000-000000000001',true);

-- 1. Finalized attendance is immutable for NEW operations, independent of finalize and revision.
DO $$
DECLARE result jsonb; replay jsonb; receipts_before integer; roster_before integer; marks_before jsonb;
 session_before jsonb; projection_before text; stale_projection text;
BEGIN
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000501',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='finalized' AND result->>'revision'='2','initial finalization succeeds');
 replay:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000501',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(replay=result,'exact finalization replay returns the original receipt');
 SELECT count(*) INTO receipts_before FROM private.mutation_receipts WHERE actor_uid='95000000-0000-4000-8000-000000000001';
 SELECT count(*) INTO roster_before FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000400';
 SELECT jsonb_agg(jsonb_build_object('enrollment_id',enrollment_id,'status',status,'revision',revision) ORDER BY enrollment_id)
  INTO marks_before FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000400';
 SELECT jsonb_build_object('status',status,'revision',revision,'roster_frozen',roster_frozen)
  INTO session_before FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000400';
 SELECT public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','convert_id','95000000-0000-4000-8000-000000000500'))->'convert'->>'effective_follow_up_date'
  INTO projection_before;

 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000502',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":2,"marks":{"95000000-0000-4000-8000-000000000301":"absent"},"finalize":false}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: finalized session edited with finalize=false'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='session_finalized','finalize=false reports session_finalized'); END;
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000503',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":2,"marks":{"95000000-0000-4000-8000-000000000301":"excused"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: finalized session edited with finalize=true'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='session_finalized','finalize=true reports session_finalized'); END;
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000504',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"absent"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale finalized session edit accepted'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='session_finalized','stale revision still reports terminal session_finalized'); END;
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000505',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"absent"},"finalize":false}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale finalized session draft accepted'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='session_finalized','stale draft reports terminal session_finalized'); END;

 PERFORM pg_temp.assert_true((SELECT status='present' AND revision=1 FROM public.ministry_attendance
  WHERE session_id='95000000-0000-4000-8000-000000000400' AND enrollment_id='95000000-0000-4000-8000-000000000301'),
  'rejected finalized operations preserve marks and mark revision');
 PERFORM pg_temp.assert_true((SELECT count(*)=roster_before FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000400'),
  'rejected finalized operations preserve roster');
 PERFORM pg_temp.assert_true((SELECT jsonb_build_object('status',status,'revision',revision,'roster_frozen',roster_frozen)=session_before
  FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000400'),'rejected finalized operations preserve session state');
 PERFORM pg_temp.assert_true((SELECT count(*)=receipts_before FROM private.mutation_receipts WHERE actor_uid='95000000-0000-4000-8000-000000000001'),
  'rejected finalized operations write no receipt');
 SELECT public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','convert_id','95000000-0000-4000-8000-000000000500'))->'convert'->>'effective_follow_up_date'
  INTO stale_projection;
 PERFORM pg_temp.assert_true(stale_projection=projection_before,'rejected finalized operations preserve derived follow-up facts');

 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000501',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"absent"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: changed payload reused finalization receipt'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='operation_conflict','changed payload conflicts'); END;
END $$;

DELETE FROM public.user_access WHERE user_id='95000000-0000-4000-8000-000000000001'
 AND congregation_id='95000000-0000-4000-8000-000000000010';
SELECT pg_temp.assert_true(private.ministry_can_access('95000000-0000-4000-8000-000000000010') IS FALSE,
 'removed scope access denies Ministry access');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000501',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: revoked authority replayed a receipt'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='forbidden','revoked authority denies exact replay'); END;
END $$;
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('attendance-integrity@example.test','95000000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','95000000-0000-4000-8000-000000000010');
DO $$ BEGIN
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000501',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present"},"finalize":true}'::jsonb)=
  (SELECT result FROM private.mutation_receipts WHERE operation_id='95000000-0000-4000-8000-000000000501'),
  'restored authority still replays the original finalization receipt');
END $$;

-- 2. Cancellation keeps history, removes only derived contribution, and later saves are terminal.
DO $$
DECLARE result jsonb; roster_before integer; marks_before jsonb; projection_before text; projection_after text;
BEGIN
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000510',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000401","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='finalized','second finalized lesson succeeds');
 SELECT count(*) INTO roster_before FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000401';
 SELECT jsonb_agg(jsonb_build_object('enrollment_id',enrollment_id,'status',status) ORDER BY enrollment_id)
  INTO marks_before FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000401';
 projection_before:=public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','convert_id','95000000-0000-4000-8000-000000000500'))->'convert'->>'latest_qualifying_lesson_date';
 PERFORM pg_temp.assert_true(projection_before='2026-10-16','latest finalized presence contributes before cancellation');
 result:=public.ieadpe_ministry_cancel_session('95000000-0000-4000-8000-000000000511',
  '{"id":"95000000-0000-4000-8000-000000000401","congregation_id":"95000000-0000-4000-8000-000000000010","expected_revision":2}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='canceled' AND result->>'revision'='3','confirmed cancellation succeeds');
 PERFORM pg_temp.assert_true((SELECT count(*)=roster_before FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000401'),
  'cancellation retains the original roster');
 PERFORM pg_temp.assert_true((SELECT jsonb_agg(jsonb_build_object('enrollment_id',enrollment_id,'status',status) ORDER BY enrollment_id)
  FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000401')=marks_before,
  'cancellation retains the original marks');
 projection_after:=public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','convert_id','95000000-0000-4000-8000-000000000500'))->'convert'->>'latest_qualifying_lesson_date';
 PERFORM pg_temp.assert_true(projection_after='2026-10-15','cancellation removes only that session from derived presence');
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','convert_id','95000000-0000-4000-8000-000000000500'))->'convert'->>'effective_follow_up_date'='2026-10-16',
  'authentic visit history remains effective after session cancellation');
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000512',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000401","expected_revision":3,"marks":{"95000000-0000-4000-8000-000000000301":"absent"},"finalize":false}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: canceled session accepted a new draft'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='session_canceled','canceled session reports session_canceled'); END;
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000513',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000401","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"absent"},"finalize":true}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale canceled session edit accepted'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='session_canceled','stale cancelled edit reports terminal session_canceled'); END;
 PERFORM pg_temp.assert_true((SELECT status='canceled' AND revision=3 FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000401') AND
  (SELECT status='present' FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000401'),
  'rejected canceled operations preserve session state and marks');
END $$;

-- 3. Replacement creation validates only a canceled same-scope/class/date predecessor without a child.
DO $$
DECLARE result jsonb; created jsonb; predecessor_roster integer; child_roster integer;
BEGIN
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000520',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000404","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000302":"present"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='finalized','lineage predecessor is finalized before cancellation');
 PERFORM public.ieadpe_ministry_cancel_session('95000000-0000-4000-8000-000000000521',
  '{"id":"95000000-0000-4000-8000-000000000404","congregation_id":"95000000-0000-4000-8000-000000000010","expected_revision":2}'::jsonb);
 INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
  ('95000000-0000-4000-8000-000000000303','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000203','95000000-0000-4000-8000-000000000104','2026-10-01','95000000-0000-4000-8000-000000000001');
 SELECT count(*) INTO predecessor_roster FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000404';

 created:=public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000522',
  '{"id":"95000000-0000-4000-8000-000000000410","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Replacement","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb);
 PERFORM pg_temp.assert_true(created->>'id'='95000000-0000-4000-8000-000000000410' AND created->>'status'='open' AND
  (SELECT replaces_session_id='95000000-0000-4000-8000-000000000404' FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000410'),
  'canceled predecessor creates one linked replacement');
 SELECT count(*) INTO child_roster FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000410';
 PERFORM pg_temp.assert_true(child_roster=0 AND predecessor_roster=1,
  'replacement starts without copied roster or marks');
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000523',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000410","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000302":"absent","95000000-0000-4000-8000-000000000303":"present"},"finalize":true}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='finalized' AND result->>'attendance_count'='2',
  'replacement first save freezes the normal eligible roster');
 PERFORM pg_temp.assert_true((SELECT count(*)=2 FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000410') AND
  (SELECT count(*)=1 AND bool_and(enrollment_id='95000000-0000-4000-8000-000000000302') FROM public.ministry_session_roster WHERE session_id='95000000-0000-4000-8000-000000000404'),
  'replacement roster may differ while the original remains frozen');
 PERFORM pg_temp.assert_true((SELECT status='present' FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000404' AND enrollment_id='95000000-0000-4000-8000-000000000302') AND
  (SELECT status='absent' FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000410' AND enrollment_id='95000000-0000-4000-8000-000000000302') AND
  (SELECT status='present' FROM public.ministry_attendance WHERE session_id='95000000-0000-4000-8000-000000000410' AND enrollment_id='95000000-0000-4000-8000-000000000303'),
  'replacement never copies original marks');
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000522',
  '{"id":"95000000-0000-4000-8000-000000000410","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Replacement","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb)=created,
  'exact create replay remains valid after the replacement later changes state');
END $$;

-- 4. Linkage is unique, immutable, restrictive and prevents forks/self-links.
DO $$
BEGIN
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000530',
  '{"id":"95000000-0000-4000-8000-000000000411","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Fork","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: second direct replacement accepted'; EXCEPTION WHEN SQLSTATE '23505' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_conflict','duplicate direct replacement is a conflict'); END;
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000531',
  '{"id":"95000000-0000-4000-8000-000000000412","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-11","topic":"Open predecessor","replaces_session_id":"95000000-0000-4000-8000-000000000405"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: open session accepted as a predecessor'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','non-canceled predecessor is invalid'); END;
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000532',
  '{"id":"95000000-0000-4000-8000-000000000413","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000100","date":"2026-10-10","topic":"Wrong class","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: mismatched class accepted as a predecessor'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','class mismatch is invalid'); END;
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000533',
  '{"id":"95000000-0000-4000-8000-000000000414","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-11","topic":"Wrong date","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: mismatched date accepted as a predecessor'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','date mismatch is invalid'); END;
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000534',
  '{"id":"95000000-0000-4000-8000-000000000415","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Foreign","replaces_session_id":"95000000-0000-4000-8000-000000000407"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: foreign predecessor accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','foreign predecessor is invalid'); END;
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000535',
  '{"id":"95000000-0000-4000-8000-000000000404","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Self","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: self-link accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','self-link is invalid'); END;
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000536',
  '{"id":"95000000-0000-4000-8000-000000000416","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000100","date":"2025-12-31","topic":"Period","replaces_session_id":"95000000-0000-4000-8000-000000000406"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: out-of-period replacement accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','out-of-period replacement is invalid'); END;

 BEGIN UPDATE public.ministry_sessions SET replaces_session_id='95000000-0000-4000-8000-000000000405'
  WHERE id='95000000-0000-4000-8000-000000000410';
  RAISE EXCEPTION 'ASSERTION: replacement linkage was rewritten'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','linkage rewrite is rejected'); END;
 BEGIN UPDATE public.ministry_sessions SET replaces_session_id=NULL
  WHERE id='95000000-0000-4000-8000-000000000410';
  RAISE EXCEPTION 'ASSERTION: replacement linkage was cleared'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','linkage clearing is rejected'); END;
 BEGIN INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,replaces_session_id,updated_by)
  VALUES('95000000-0000-4000-8000-000000000420','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000104','2026-10-12','95000000-0000-4000-8000-000000000420','95000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'ASSERTION: self-link row inserted'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,replaces_session_id,updated_by)
  VALUES('95000000-0000-4000-8000-000000000421','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000104','2026-10-12','95000000-0000-4000-8000-000000000404','95000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'ASSERTION: duplicate link row inserted'; EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN DELETE FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000404';
  RAISE EXCEPTION 'ASSERTION: predecessor deleted with a child'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 PERFORM pg_temp.assert_true((SELECT replaces_session_id='95000000-0000-4000-8000-000000000404' FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000410'),
  'failed linkage rewrites leave the original link intact');
 PERFORM pg_temp.assert_true((SELECT count(*)=1 FROM public.ministry_sessions WHERE replaces_session_id='95000000-0000-4000-8000-000000000404'),
  'failed fork attempts leave exactly one direct child');
END $$;

-- 5. Completed/archived history stays readable and cancellable; replacement stays blocked.
DO $$
DECLARE detail jsonb; page jsonb;
BEGIN
 page:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','class_id','95000000-0000-4000-8000-000000000101','limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true(page->'items'->0->>'status'='finalized','completed class history remains readable');
 detail:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id','95000000-0000-4000-8000-000000000402'));
 PERFORM pg_temp.assert_true(detail->'session'->>'status'='finalized','completed class session detail remains readable');
 PERFORM public.ieadpe_ministry_cancel_session('95000000-0000-4000-8000-000000000540',
  '{"id":"95000000-0000-4000-8000-000000000402","congregation_id":"95000000-0000-4000-8000-000000000010","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT status='canceled' FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000402'),
  'completed class history remains cancellable');
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000541',
  '{"id":"95000000-0000-4000-8000-000000000430","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000101","date":"2026-10-15","topic":"Completed replacement","replaces_session_id":"95000000-0000-4000-8000-000000000402"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: replacement created in a completed class'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='class_not_active','completed class blocks replacements'); END;

 PERFORM public.ieadpe_ministry_cancel_session('95000000-0000-4000-8000-000000000542',
  '{"id":"95000000-0000-4000-8000-000000000403","congregation_id":"95000000-0000-4000-8000-000000000010","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT status='canceled' FROM public.ministry_sessions WHERE id='95000000-0000-4000-8000-000000000403'),
  'archived class history remains cancellable');
 BEGIN PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000543',
  '{"id":"95000000-0000-4000-8000-000000000431","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000102","date":"2026-10-15","topic":"Archived replacement","replaces_session_id":"95000000-0000-4000-8000-000000000403"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: replacement created in an archived class'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='class_not_active','archived class blocks replacements'); END;
END $$;

-- 6. Detail/summary expose authoritative direct-child linkage across pages and cancellation.
DO $$
DECLARE chain jsonb; page1 jsonb; page2 jsonb; page3 jsonb; result jsonb;
BEGIN
 result:=public.ieadpe_ministry_cancel_session('95000000-0000-4000-8000-000000000550',
  '{"id":"95000000-0000-4000-8000-000000000410","congregation_id":"95000000-0000-4000-8000-000000000010","expected_revision":2}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='canceled','replacement can itself be canceled to form a chain');
 result:=public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000551',
  '{"id":"95000000-0000-4000-8000-000000000411","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Chain","replaces_session_id":"95000000-0000-4000-8000-000000000410"}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'id'='95000000-0000-4000-8000-000000000411','canceled child can be replaced by the next chain link');
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000522',
  '{"id":"95000000-0000-4000-8000-000000000410","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000104","date":"2026-10-10","topic":"Replacement","replaces_session_id":"95000000-0000-4000-8000-000000000404"}'::jsonb)=
  jsonb_build_object('id','95000000-0000-4000-8000-000000000410','revision',1,'status','open'),
  'exact create replay survives cancellation and grandchild creation');

 chain:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id','95000000-0000-4000-8000-000000000404'));
 PERFORM pg_temp.assert_true(chain->'session'->>'status'='canceled' AND chain->'session'->>'replaces_session_id' IS NULL AND
  chain->'session'->>'replacement_session_id'='95000000-0000-4000-8000-000000000410','parent detail exposes its direct child');
 chain:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id','95000000-0000-4000-8000-000000000410'));
 PERFORM pg_temp.assert_true(chain->'session'->>'status'='canceled' AND
  chain->'session'->>'replaces_session_id'='95000000-0000-4000-8000-000000000404' AND
  chain->'session'->>'replacement_session_id'='95000000-0000-4000-8000-000000000411','canceled middle detail exposes both links');
 chain:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id','95000000-0000-4000-8000-000000000411'));
 PERFORM pg_temp.assert_true(chain->'session'->>'replaces_session_id'='95000000-0000-4000-8000-000000000410' AND
  chain->'session'->>'replacement_session_id' IS NULL,'chain tail detail has no child');

 page1:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','class_id','95000000-0000-4000-8000-000000000104','limit',1,'cursor',NULL));
 page2:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','class_id','95000000-0000-4000-8000-000000000104','limit',1,'cursor',page1->>'next_cursor'));
 page3:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','class_id','95000000-0000-4000-8000-000000000104','limit',1,'cursor',page2->>'next_cursor'));
 PERFORM pg_temp.assert_true(page1->'items'->0->>'id'='95000000-0000-4000-8000-000000000404' AND
  page1->'items'->0->>'replacement_session_id'='95000000-0000-4000-8000-000000000410','summary parent sees a child on a later page');
 PERFORM pg_temp.assert_true(page2->'items'->0->>'id'='95000000-0000-4000-8000-000000000410' AND
  page2->'items'->0->>'status'='canceled' AND
  page2->'items'->0->>'replaces_session_id'='95000000-0000-4000-8000-000000000404' AND
  page2->'items'->0->>'replacement_session_id'='95000000-0000-4000-8000-000000000411','canceled middle sees a child on the next page');
 PERFORM pg_temp.assert_true(page3->'items'->0->>'id'='95000000-0000-4000-8000-000000000411' AND
  page3->'items'->0->>'replacement_session_id' IS NULL,'summary tail has no inferred child');
END $$;

-- 7. Exact response envelopes are strict and nullable; historical rows decode null.
DO $$
DECLARE detail jsonb; page jsonb; item jsonb; keys text[];
BEGIN
 detail:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id','95000000-0000-4000-8000-000000000402'));
 PERFORM pg_temp.assert_true(detail->'session' ?& ARRAY['replaces_session_id','replacement_session_id'],'detail includes nullable linkage keys');
 PERFORM pg_temp.assert_true(detail->'session'->'replaces_session_id'='null'::jsonb AND detail->'session'->'replacement_session_id'='null'::jsonb,
  'historical detail returns null linkage');
 page:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','class_id','95000000-0000-4000-8000-000000000101','limit',100,'cursor',NULL));
 SELECT value INTO item FROM jsonb_array_elements(page->'items') value WHERE value->>'id'='95000000-0000-4000-8000-000000000402';
 PERFORM pg_temp.assert_true(item ?& ARRAY['replaces_session_id','replacement_session_id'] AND
  item->'replaces_session_id'='null'::jsonb AND item->'replacement_session_id'='null'::jsonb,'historical summary returns null linkage');
 PERFORM pg_temp.assert_true((SELECT bool_and(value ?& ARRAY['id','class_id','congregation_id','date','topic','status','revision','replaces_session_id','replacement_session_id'] AND
  value-ARRAY['id','class_id','congregation_id','date','topic','status','revision','replaces_session_id','replacement_session_id']='{}'::jsonb)
  FROM jsonb_array_elements(page->'items') value),'summary keeps an exact bounded key set');
END $$;

-- 8. Frozen roster, future-date finalization and invalid roster remain server enforced.
DO $$
DECLARE result jsonb; future_session uuid:='95000000-0000-4000-8000-000000000440';
BEGIN
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000560',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000400","expected_revision":2,"marks":{},"finalize":false}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: incomplete roster accepted on a finalized session'; EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;
 PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000561',
  jsonb_build_object('id',future_session,'congregation_id','95000000-0000-4000-8000-000000000010','class_id','95000000-0000-4000-8000-000000000100','date',private.business_today()+1,'topic','Future'));
 BEGIN PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000562',
  jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id',future_session,'expected_revision',1,
   'marks',jsonb_build_object('95000000-0000-4000-8000-000000000301','present'),'finalize',true));
  RAISE EXCEPTION 'ASSERTION: future session finalized before its business date'; EXCEPTION WHEN SQLSTATE '23514' THEN PERFORM pg_temp.assert_true(SQLERRM='attendance_incomplete','future finalization keeps the business-date guard'); END;
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000563',
  jsonb_build_object('congregation_id','95000000-0000-4000-8000-000000000010','session_id',future_session,'expected_revision',1,
   'marks',jsonb_build_object('95000000-0000-4000-8000-000000000301','present'),'finalize',false));
 PERFORM pg_temp.assert_true(result->>'status'='open' AND result->>'attendance_count'='1','future draft with exact roster is allowed');
END $$;

-- 9. First freeze snapshots the current same-scope canonical person name and never rewrites it.
DO $$
DECLARE result jsonb; person uuid:='95000000-0000-4000-8000-000000000600';
BEGIN
 INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
  (person,'95000000-0000-4000-8000-000000000010','Canonical Original','canonical original','95000000-0000-4000-8000-000000000001');
 INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by) VALUES
  ('95000000-0000-4000-8000-000000000204','95000000-0000-4000-8000-000000000010',person,'Compatibility One','compatibility one','95000000-0000-4000-8000-000000000001');
 INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
  ('95000000-0000-4000-8000-000000000304','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000204','95000000-0000-4000-8000-000000000100','2026-01-01','95000000-0000-4000-8000-000000000001');

 -- A rename before the first freeze is captured by that session's frozen roster.
 PERFORM public.ieadpe_ministry_save_person('95000000-0000-4000-8000-000000000570',
  jsonb_build_object('id',person,'congregation_id','95000000-0000-4000-8000-000000000010','expected_revision',1,
   'person',jsonb_build_object('name','Canonical Renamed','phone',NULL,'birth_date',NULL,'address',NULL)));
 PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000571',
  '{"id":"95000000-0000-4000-8000-000000000450","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000100","date":"2026-10-17","topic":"Canonical freeze"}'::jsonb);
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000572',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000450","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present","95000000-0000-4000-8000-000000000304":"present"},"finalize":false}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='open','rename-before-freeze session saves');
 PERFORM pg_temp.assert_true((SELECT student_name='Canonical Renamed' FROM public.ministry_session_roster
  WHERE session_id='95000000-0000-4000-8000-000000000450' AND enrollment_id='95000000-0000-4000-8000-000000000304'),
  'first freeze captures the current canonical person name');

 -- A later rename never rewrites an already frozen label.
 PERFORM public.ieadpe_ministry_save_person('95000000-0000-4000-8000-000000000573',
  jsonb_build_object('id',person,'congregation_id','95000000-0000-4000-8000-000000000010','expected_revision',2,
   'person',jsonb_build_object('name','Canonical Later','phone',NULL,'birth_date',NULL,'address',NULL)));
 PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000574',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000450","expected_revision":2,"marks":{"95000000-0000-4000-8000-000000000301":"present","95000000-0000-4000-8000-000000000304":"absent"},"finalize":false}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT student_name='Canonical Renamed' FROM public.ministry_session_roster
  WHERE session_id='95000000-0000-4000-8000-000000000450' AND enrollment_id='95000000-0000-4000-8000-000000000304'),
  'rename-after-freeze preserves the frozen label');

 -- A different session first frozen after the rename sees the latest canonical name.
 PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000575',
  '{"id":"95000000-0000-4000-8000-000000000451","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000100","date":"2026-10-18","topic":"Canonical latest"}'::jsonb);
 PERFORM public.ieadpe_ministry_save_person('95000000-0000-4000-8000-000000000576',
  jsonb_build_object('id',person,'congregation_id','95000000-0000-4000-8000-000000000010','expected_revision',3,
   'person',jsonb_build_object('name','Canonical Before Freeze','phone',NULL,'birth_date',NULL,'address',NULL)));
 PERFORM public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000577',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000451","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present","95000000-0000-4000-8000-000000000304":"present"},"finalize":false}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT student_name='Canonical Before Freeze' FROM public.ministry_session_roster
  WHERE session_id='95000000-0000-4000-8000-000000000451' AND enrollment_id='95000000-0000-4000-8000-000000000304'),
  'each new session freeze resolves the latest canonical name');

 -- Unlinked legacy students keep the compatibility snapshot as the fallback label.
 INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,updated_by) VALUES
  ('95000000-0000-4000-8000-000000000205','95000000-0000-4000-8000-000000000010','Legacy Learner','legacy learner','95000000-0000-4000-8000-000000000001');
 INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
  ('95000000-0000-4000-8000-000000000305','95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000205','95000000-0000-4000-8000-000000000100','2026-01-01','95000000-0000-4000-8000-000000000001');
 PERFORM public.ieadpe_ministry_create_session('95000000-0000-4000-8000-000000000578',
  '{"id":"95000000-0000-4000-8000-000000000452","congregation_id":"95000000-0000-4000-8000-000000000010","class_id":"95000000-0000-4000-8000-000000000100","date":"2026-10-19","topic":"Legacy fallback"}'::jsonb);
 result:=public.ieadpe_ministry_save_attendance('95000000-0000-4000-8000-000000000579',
  '{"congregation_id":"95000000-0000-4000-8000-000000000010","session_id":"95000000-0000-4000-8000-000000000452","expected_revision":1,"marks":{"95000000-0000-4000-8000-000000000301":"present","95000000-0000-4000-8000-000000000304":"present","95000000-0000-4000-8000-000000000305":"present"},"finalize":false}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'attendance_count'='3','legacy and linked students share the normal eligible roster');
 PERFORM pg_temp.assert_true((SELECT student_name='Legacy Learner' FROM public.ministry_session_roster
  WHERE session_id='95000000-0000-4000-8000-000000000452' AND enrollment_id='95000000-0000-4000-8000-000000000305'),
  'unlinked legacy student falls back to its compatibility name');
END $$;

ROLLBACK;
