BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('94800000-0000-4000-8000-000000000001','follow-up@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('94800000-0000-4000-8000-000000000002','Follow-up'),
 ('94800000-0000-4000-8000-000000000014','Foreign Follow-up');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('follow-up@example.test','94800000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','94800000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','94800000-0000-4000-8000-000000000001',true);
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name) VALUES
 ('94800000-0000-4000-8000-000000000003','94800000-0000-4000-8000-000000000002','Enrolled Person','enrolled person'),
 ('94800000-0000-4000-8000-000000000004','94800000-0000-4000-8000-000000000002','Referral Only','referral only'),
 ('94800000-0000-4000-8000-000000000015','94800000-0000-4000-8000-000000000014','Foreign Convert','foreign convert');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
 congregation_id,person_id,last_visit_date,was_visited_once,visit_count)
 VALUES('94800000-0000-4000-8000-000000000005','follow-up-convert','Enrolled Person','Square','female',
  private.business_today()-120,'Culto regular','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000003',private.business_today()-60,true,2),
 ('94800000-0000-4000-8000-000000000006','follow-up-referral','Referral Only','Square','male',
  private.business_today()-20,'Culto regular','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000004',NULL,false,0),
 ('94800000-0000-4000-8000-000000000016','follow-up-foreign','Foreign Convert','Square','male',
  private.business_today()-20,'Culto regular','94800000-0000-4000-8000-000000000014',
  '94800000-0000-4000-8000-000000000015',NULL,false,0);
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name) VALUES
 ('94800000-0000-4000-8000-000000000007','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000003','Enrolled Person','enrolled person');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date) VALUES
 ('94800000-0000-4000-8000-000000000008','94800000-0000-4000-8000-000000000002','Class','class',private.business_today()-120);
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date) VALUES
 ('94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000007','94800000-0000-4000-8000-000000000008',private.business_today()-90);
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status) VALUES
 ('94800000-0000-4000-8000-000000000010','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-6,'finalized'),
 ('94800000-0000-4000-8000-000000000011','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-5,'open'),
 ('94800000-0000-4000-8000-000000000012','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-1,'canceled'),
 ('94800000-0000-4000-8000-000000000013','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-40,'finalized'),
 ('94800000-0000-4000-8000-000000000017','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-4,'finalized'),
 ('94800000-0000-4000-8000-000000000018','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-3,'finalized'),
 ('94800000-0000-4000-8000-000000000019','94800000-0000-4000-8000-000000000002',
  '94800000-0000-4000-8000-000000000008',private.business_today()-2,'finalized');
INSERT INTO public.ministry_session_roster(congregation_id,session_id,enrollment_id,student_id,student_name,updated_by)
 SELECT '94800000-0000-4000-8000-000000000002',id,'94800000-0000-4000-8000-000000000009',
  '94800000-0000-4000-8000-000000000007','Enrolled Person','94800000-0000-4000-8000-000000000001'
 FROM public.ministry_sessions WHERE id IN ('94800000-0000-4000-8000-000000000010',
  '94800000-0000-4000-8000-000000000011','94800000-0000-4000-8000-000000000012','94800000-0000-4000-8000-000000000013',
  '94800000-0000-4000-8000-000000000017','94800000-0000-4000-8000-000000000018','94800000-0000-4000-8000-000000000019');
INSERT INTO public.ministry_attendance(congregation_id,session_id,enrollment_id,student_id,status) VALUES
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000010','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','present'),
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000011','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','present'),
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000012','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','present'),
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000013','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','present'),
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000017','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','absent'),
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000018','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','excused'),
 ('94800000-0000-4000-8000-000000000002','94800000-0000-4000-8000-000000000019','94800000-0000-4000-8000-000000000009','94800000-0000-4000-8000-000000000007','unmarked');

DO $$ DECLARE detail jsonb; item jsonb; page jsonb; closed jsonb; canceled jsonb; BEGIN
 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','94800000-0000-4000-8000-000000000002','convert_id','94800000-0000-4000-8000-000000000005'));
 page:=public.ieadpe_ministry_list_converts(jsonb_build_object('congregation_id','94800000-0000-4000-8000-000000000002','limit',100));
 SELECT value INTO item FROM jsonb_array_elements(page->'items') value WHERE value->'convert'->>'id'='94800000-0000-4000-8000-000000000005';
 PERFORM pg_temp.assert_true(item=detail,'list and detail share the exact derived projection');
 PERFORM pg_temp.assert_true(detail->'convert'->>'effective_is_in_discipleship'='true' AND
  detail->'convert'->>'effective_discipleship_start_date'=(private.business_today()-90)::text,
  'active enrollment supplies effective state and verified start');
 PERFORM pg_temp.assert_true(detail->'convert'->>'latest_qualifying_lesson_date'=(private.business_today()-6)::text AND
  detail->'convert'->>'effective_follow_up_date'=(private.business_today()-6)::text,
  'only finalized present lesson contributes and latest actual contact wins');
 PERFORM pg_temp.assert_true(detail->'convert'->>'last_visit_date'=(private.business_today()-60)::text AND
  detail->'convert'->>'visit_count'='2' AND detail->'convert'->>'was_visited_once'='true',
  'attendance preserves raw visit history');
 BEGIN PERFORM public.ieadpe_transition_convert('94800000-0000-4000-8000-000000000021',
  '{"id":"94800000-0000-4000-8000-000000000005","action":"visit"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: recent qualifying lesson did not block an early visit';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 canceled:=public.ieadpe_ministry_cancel_session('94800000-0000-4000-8000-000000000022',
  jsonb_build_object('id','94800000-0000-4000-8000-000000000010','congregation_id','94800000-0000-4000-8000-000000000002','expected_revision',1));
 PERFORM pg_temp.assert_true(canceled->>'status'='canceled' AND
  public.ieadpe_ministry_cancel_session('94800000-0000-4000-8000-000000000022',
   jsonb_build_object('id','94800000-0000-4000-8000-000000000010','congregation_id','94800000-0000-4000-8000-000000000002','expected_revision',1))=canceled,
  'finalized cancellation retains the exact operation receipt');
 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','94800000-0000-4000-8000-000000000002','convert_id','94800000-0000-4000-8000-000000000005'));
 PERFORM pg_temp.assert_true(detail->'convert'->>'latest_qualifying_lesson_date'=(private.business_today()-40)::text AND
  (SELECT count(*)=1 FROM public.ministry_session_roster WHERE session_id='94800000-0000-4000-8000-000000000010') AND
  (SELECT count(*)=1 FROM public.ministry_attendance WHERE session_id='94800000-0000-4000-8000-000000000010'),
  'canceling finalized session removes only its projection contribution and keeps history');
 BEGIN PERFORM public.ieadpe_transition_convert('94800000-0000-4000-8000-000000000025',
  '{"id":"94800000-0000-4000-8000-000000000005","action":"start"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: manual start duplicated an active enrollment';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 UPDATE public.converts SET is_in_discipleship=true,discipleship_start_date=private.business_today()-100
  WHERE id='94800000-0000-4000-8000-000000000005';
 PERFORM public.ieadpe_transition_convert('94800000-0000-4000-8000-000000000026',
  '{"id":"94800000-0000-4000-8000-000000000005","action":"stop"}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT NOT is_in_discipleship FROM public.converts WHERE id='94800000-0000-4000-8000-000000000005') AND
  (SELECT status='active' FROM public.ministry_enrollments WHERE id='94800000-0000-4000-8000-000000000009'),
  'manual stop does not close active enrollment');
 PERFORM public.ieadpe_transition_convert('94800000-0000-4000-8000-000000000023',
  '{"id":"94800000-0000-4000-8000-000000000005","action":"visit"}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT visit_count=3 AND was_visited_once AND last_visit_date=private.business_today()
  FROM public.converts WHERE id='94800000-0000-4000-8000-000000000005'),
  'visit is allowed after effective contact becomes due and records a real visit');
 PERFORM public.ieadpe_transition_convert('94800000-0000-4000-8000-000000000024',
  '{"id":"94800000-0000-4000-8000-000000000005","action":"complete"}'::jsonb);
 PERFORM pg_temp.assert_true((SELECT is_discipleship_completed FROM public.converts WHERE id='94800000-0000-4000-8000-000000000005'),
  'verified active enrollment start permits explicit completion at day 90');
 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','94800000-0000-4000-8000-000000000002','convert_id','94800000-0000-4000-8000-000000000006'));
 PERFORM pg_temp.assert_true(detail->'convert'->>'effective_is_in_discipleship'='false' AND
  detail->'convert'->>'effective_discipleship_start_date' IS NULL AND
  detail->'convert'->>'effective_follow_up_date' IS NULL,
  'referral-only canonical person contributes no state or follow-up');
 UPDATE public.converts SET discipleship_start_date=private.business_today()-100
  WHERE id='94800000-0000-4000-8000-000000000006';
 BEGIN PERFORM public.ieadpe_transition_convert('94800000-0000-4000-8000-000000000027',
  '{"id":"94800000-0000-4000-8000-000000000006","action":"complete"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: stale manual start allowed completion while inactive';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_get_convert(jsonb_build_object(
  'congregation_id','94800000-0000-4000-8000-000000000014','convert_id','94800000-0000-4000-8000-000000000016'));
  RAISE EXCEPTION 'ASSERTION: foreign congregation convert was readable';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 closed:=public.ieadpe_ministry_close_enrollment('94800000-0000-4000-8000-000000000020',
  jsonb_build_object('id','94800000-0000-4000-8000-000000000009','congregation_id','94800000-0000-4000-8000-000000000002',
   'status','withdrawn','end_date',private.business_today(),'expected_revision',1));
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_close_enrollment('94800000-0000-4000-8000-000000000020',
  jsonb_build_object('id','94800000-0000-4000-8000-000000000009','congregation_id','94800000-0000-4000-8000-000000000002',
   'status','withdrawn','end_date',private.business_today(),'expected_revision',1))=closed,
  'enrollment close replays the exact receipt');
 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object('congregation_id','94800000-0000-4000-8000-000000000002','convert_id','94800000-0000-4000-8000-000000000005'));
 PERFORM pg_temp.assert_true(detail->'convert'->>'effective_is_in_discipleship'='false' AND
  detail->'convert'->>'effective_discipleship_start_date' IS NULL AND
  detail->'convert'->>'latest_qualifying_lesson_date'=(private.business_today()-40)::text,
  'closure removes only active contribution and retains historical contact');
END $$;
ROLLBACK;
