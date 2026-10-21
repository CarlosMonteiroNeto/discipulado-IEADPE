BEGIN;
CREATE FUNCTION pg_temp.fixture_date(day_offset integer) RETURNS date
LANGUAGE sql STABLE AS $$
 SELECT (now() AT TIME ZONE 'America/Recife')::date - 10 + day_offset
$$;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'ASSERTION: %', label;
 END IF;
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('96000000-0000-4000-8000-000000000001','roster-preview@example.test',now()),
 ('96000000-0000-4000-8000-000000000002','roster-preview-foreign@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('96000000-0000-4000-8000-000000000010','Roster Preview A'),
 ('96000000-0000-4000-8000-000000000011','Roster Preview B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('roster-preview@example.test','96000000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','96000000-0000-4000-8000-000000000010'),
 ('roster-preview-foreign@example.test','96000000-0000-4000-8000-000000000002',
  'Membro da direção da campanha','96000000-0000-4000-8000-000000000011');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('96000000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000010','ministry_staff',true),
 ('96000000-0000-4000-8000-000000000002','96000000-0000-4000-8000-000000000011','ministry_staff',true);
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,end_date,status,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000100','96000000-0000-4000-8000-000000000010','Preview A','preview a',pg_temp.fixture_date(-30),pg_temp.fixture_date(365),'active','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000101','96000000-0000-4000-8000-000000000011','Preview B','preview b',pg_temp.fixture_date(-30),pg_temp.fixture_date(365),'active','96000000-0000-4000-8000-000000000002');
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000201','96000000-0000-4000-8000-000000000010','Canonical Before Freeze','canonical before freeze','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000205','96000000-0000-4000-8000-000000000010','Closed Eligible','closed eligible','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000206','96000000-0000-4000-8000-000000000011','Foreign Person','foreign person','96000000-0000-4000-8000-000000000002');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000301','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000201','Legacy Snapshot Name','legacy snapshot name','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000302','96000000-0000-4000-8000-000000000010',NULL,'Legacy Preview Learner','legacy preview learner','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000303','96000000-0000-4000-8000-000000000010',NULL,'Starts Later','starts later','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000304','96000000-0000-4000-8000-000000000010',NULL,'Already Expired','already expired','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000305','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000205','Closed Snapshot','closed snapshot','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000306','96000000-0000-4000-8000-000000000011','96000000-0000-4000-8000-000000000206','Foreign Learner','foreign learner','96000000-0000-4000-8000-000000000002');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,end_date,status,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000401','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000301','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(-20),pg_temp.fixture_date(2),'completed','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000402','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000302','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(-20),pg_temp.fixture_date(2),'active','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000403','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000303','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(3),pg_temp.fixture_date(3),'active','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000404','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000304','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(-20),pg_temp.fixture_date(-1),'completed','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000405','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000305','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(0),pg_temp.fixture_date(2),'completed','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000406','96000000-0000-4000-8000-000000000011','96000000-0000-4000-8000-000000000306','96000000-0000-4000-8000-000000000101',pg_temp.fixture_date(-20),pg_temp.fixture_date(20),'active','96000000-0000-4000-8000-000000000002');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,roster_frozen,replaces_session_id,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000501','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(0),'open',false,NULL,'96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000502','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(1),'canceled',true,NULL,'96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000503','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(3),'open',true,NULL,'96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000504','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(4),'canceled',false,NULL,'96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000505','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(10),'open',false,NULL,'96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000506','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(1),'open',false,'96000000-0000-4000-8000-000000000502','96000000-0000-4000-8000-000000000001'),
 ('96000000-0000-4000-8000-000000000507','96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000100',pg_temp.fixture_date(2),'open',false,NULL,'96000000-0000-4000-8000-000000000001');
DO $$
BEGIN
 PERFORM pg_temp.assert_true(
  (SELECT session_date <= (now() AT TIME ZONE 'America/Recife')::date
   FROM public.ministry_sessions WHERE id='96000000-0000-4000-8000-000000000501'),
  'ordinary finalization date is not after Recife business date');
 PERFORM pg_temp.assert_true(
  (SELECT child.session_date <= (now() AT TIME ZONE 'America/Recife')::date
     AND child.session_date=parent.session_date
   FROM public.ministry_sessions child
   JOIN public.ministry_sessions parent ON parent.id=child.replaces_session_id
   WHERE child.id='96000000-0000-4000-8000-000000000506'
     AND parent.id='96000000-0000-4000-8000-000000000502'),
  'replacement finalization date is not future and matches its canceled parent');
 PERFORM pg_temp.assert_true(NOT EXISTS(
  SELECT 1 FROM public.ministry_sessions
  WHERE status <> 'canceled'
  GROUP BY class_id,session_date HAVING count(*) > 1),
  'fixture has no duplicate live class/date session keys');
 PERFORM pg_temp.assert_true((
  SELECT array_agg(id ORDER BY id)=ARRAY[
   '96000000-0000-4000-8000-000000000501','96000000-0000-4000-8000-000000000502',
   '96000000-0000-4000-8000-000000000503','96000000-0000-4000-8000-000000000504',
   '96000000-0000-4000-8000-000000000505','96000000-0000-4000-8000-000000000506',
   '96000000-0000-4000-8000-000000000507']::uuid[]
  FROM public.ministry_sessions WHERE id::text LIKE '96000000-0000-4000-8000-00000000050%'),
  'all seven date-topology fixtures remain present');
END $$;
INSERT INTO public.ministry_session_roster(congregation_id,session_id,enrollment_id,student_id,student_name,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000502','96000000-0000-4000-8000-000000000401','96000000-0000-4000-8000-000000000301','Parent Frozen Name','96000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_attendance(congregation_id,session_id,enrollment_id,student_id,status,updated_by) VALUES
 ('96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000502','96000000-0000-4000-8000-000000000401','96000000-0000-4000-8000-000000000301','present','96000000-0000-4000-8000-000000000001');

SELECT set_config('request.jwt.claim.sub','96000000-0000-4000-8000-000000000001',true);

DO $$
DECLARE ordinary jsonb; replacement jsonb; zero_preview jsonb; frozen_empty jsonb;
 terminal jsonb; marks jsonb; draft jsonb; finalized jsonb; replay jsonb;
 names text[]; ids text[]; revision_before integer; roster_before bigint;
 attendance_before bigint; receipts_before bigint; result_session jsonb;
 removed_assignment_count integer;
BEGIN
 PERFORM pg_temp.assert_true(
  has_function_privilege('authenticated','public.ieadpe_ministry_get_session_attendance(jsonb)','EXECUTE')
  AND NOT has_function_privilege('anon','public.ieadpe_ministry_get_session_attendance(jsonb)','EXECUTE'),
  'only authenticated keeps read RPC execution');

 ordinary:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000501'));
 PERFORM pg_temp.assert_true((SELECT count(*)=2 FROM jsonb_object_keys(ordinary)),'RPC envelope remains session and roster');
 PERFORM pg_temp.assert_true((SELECT count(*)=16 FROM jsonb_object_keys(ordinary->'session')),'all existing session fields remain');
 PERFORM pg_temp.assert_true((SELECT count(*)=4 FROM jsonb_object_keys((ordinary->'roster')->0)),'preview row keeps exact four-field shape');
 SELECT array_agg(row_value->>'enrollment_id' ORDER BY row_value->>'enrollment_id'),
        array_agg(row_value->>'student_name' ORDER BY row_value->>'enrollment_id')
  INTO ids,names FROM jsonb_array_elements(ordinary->'roster') row_value;
 PERFORM pg_temp.assert_true(ids=ARRAY[
  '96000000-0000-4000-8000-000000000401',
  '96000000-0000-4000-8000-000000000402',
  '96000000-0000-4000-8000-000000000405']::text[],
  'date-inclusive rows include closed eligible enrollment and exclude future/expired/foreign');
 PERFORM pg_temp.assert_true(names=ARRAY['Canonical Before Freeze','Legacy Preview Learner','Closed Eligible']::text[],
  'preview uses current canonical name and legacy fallback');
 PERFORM pg_temp.assert_true((SELECT bool_and(row_value->>'status'='unmarked') FROM jsonb_array_elements(ordinary->'roster') row_value),
  'preview starts wholly unmarked');
 PERFORM pg_temp.assert_true((ordinary->'session'->>'roster_frozen')::boolean IS FALSE,
  'preview does not freeze its session');
 SELECT revision INTO revision_before FROM public.ministry_sessions WHERE id='96000000-0000-4000-8000-000000000501';
 SELECT count(*) INTO roster_before FROM public.ministry_session_roster WHERE session_id='96000000-0000-4000-8000-000000000501';
 SELECT count(*) INTO attendance_before FROM public.ministry_attendance WHERE session_id='96000000-0000-4000-8000-000000000501';
 SELECT count(*) INTO receipts_before FROM private.mutation_receipts WHERE actor_uid='96000000-0000-4000-8000-000000000001';

 replacement:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000506'));
 SELECT array_agg(row_value->>'enrollment_id' ORDER BY row_value->>'enrollment_id') INTO ids
  FROM jsonb_array_elements(replacement->'roster') row_value;
 PERFORM pg_temp.assert_true(ids=ARRAY[
  '96000000-0000-4000-8000-000000000401',
  '96000000-0000-4000-8000-000000000402',
  '96000000-0000-4000-8000-000000000405']::text[],
  'replacement independently previews its date-eligible rows');
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM jsonb_array_elements(replacement->'roster') row_value
  WHERE row_value->>'status'<>'unmarked' OR row_value->>'student_name'='Parent Frozen Name'),
  'replacement does not copy predecessor snapshot or marks');

 zero_preview:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000505'));
 PERFORM pg_temp.assert_true(jsonb_array_length(zero_preview->'roster')=0,'zero eligible preview is empty');
 frozen_empty:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000503'));
 PERFORM pg_temp.assert_true(jsonb_array_length(frozen_empty->'roster')=0,'frozen-empty session stays empty');
 terminal:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000504'));
 PERFORM pg_temp.assert_true(jsonb_array_length(terminal->'roster')=0,'terminal-unfrozen session never synthesizes rows');

 PERFORM pg_temp.assert_true((SELECT revision=revision_before AND NOT roster_frozen FROM public.ministry_sessions
  WHERE id='96000000-0000-4000-8000-000000000501'),'read leaves revision and frozen flag unchanged');
 PERFORM pg_temp.assert_true((SELECT count(*)=roster_before FROM public.ministry_session_roster
  WHERE session_id='96000000-0000-4000-8000-000000000501'),'read writes no stored roster');
 PERFORM pg_temp.assert_true((SELECT count(*)=attendance_before FROM public.ministry_attendance
  WHERE session_id='96000000-0000-4000-8000-000000000501'),'read writes no attendance');
 PERFORM pg_temp.assert_true((SELECT count(*)=receipts_before FROM private.mutation_receipts
  WHERE actor_uid='96000000-0000-4000-8000-000000000001'),'read writes no mutation receipt');

 marks:=jsonb_build_object(
  '96000000-0000-4000-8000-000000000401','present',
  '96000000-0000-4000-8000-000000000402','unmarked',
  '96000000-0000-4000-8000-000000000405','absent');
 draft:=public.ieadpe_ministry_save_attendance('96000000-0000-4000-8000-000000000601',
  jsonb_build_object('congregation_id','96000000-0000-4000-8000-000000000010',
   'session_id','96000000-0000-4000-8000-000000000501','expected_revision',1,'marks',marks,'finalize',false));
 PERFORM pg_temp.assert_true(draft->>'status'='open' AND draft->>'roster_frozen'='true'
  AND draft->>'attendance_count'='3','first explicit draft freezes exactly the returned preview');
 ordinary:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000501'));
 PERFORM pg_temp.assert_true((ordinary->'session'->>'revision')::integer=2
  AND (ordinary->'session'->>'roster_frozen')::boolean,'fresh read confirms the acknowledged persisted draft');
 PERFORM pg_temp.assert_true((SELECT count(*)=3 FROM public.ministry_session_roster
  WHERE session_id='96000000-0000-4000-8000-000000000501'),'first save stores every eligible row');
 PERFORM pg_temp.assert_true((SELECT count(*)=3 FROM public.ministry_attendance
  WHERE session_id='96000000-0000-4000-8000-000000000501'),'first save stores every submitted mark');
 PERFORM pg_temp.assert_true((SELECT student_name='Canonical Before Freeze' FROM public.ministry_session_roster
  WHERE session_id='96000000-0000-4000-8000-000000000501' AND enrollment_id='96000000-0000-4000-8000-000000000401'),
  'first freeze snapshots current canonical name');
 UPDATE public.ministry_people SET name='Canonical After Freeze',normalized_name='canonical after freeze'
  WHERE id='96000000-0000-4000-8000-000000000201';
 PERFORM pg_temp.assert_true((SELECT student_name='Canonical Before Freeze' FROM public.ministry_session_roster
  WHERE session_id='96000000-0000-4000-8000-000000000501' AND enrollment_id='96000000-0000-4000-8000-000000000401'),
  'post-freeze rename preserves historical snapshot');
 marks:=jsonb_build_object(
  '96000000-0000-4000-8000-000000000401','present',
  '96000000-0000-4000-8000-000000000402','absent',
  '96000000-0000-4000-8000-000000000405','present');
 finalized:=public.ieadpe_ministry_save_attendance('96000000-0000-4000-8000-000000000602',
  jsonb_build_object('congregation_id','96000000-0000-4000-8000-000000000010',
   'session_id','96000000-0000-4000-8000-000000000501','expected_revision',2,'marks',marks,'finalize',true));
 replay:=public.ieadpe_ministry_save_attendance('96000000-0000-4000-8000-000000000602',
  jsonb_build_object('congregation_id','96000000-0000-4000-8000-000000000010',
   'session_id','96000000-0000-4000-8000-000000000501','expected_revision',2,'marks',marks,'finalize',true));
 PERFORM pg_temp.assert_true(finalized->>'status'='finalized' AND replay=finalized,
  'explicit finalization and exact replay use existing writer contract');
 PERFORM pg_temp.assert_true((public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000501'))->'roster'->0->>'student_name')='Canonical Before Freeze',
  'reopen keeps stored canonical snapshot after later rename');

 -- The child has its own eligible preview and no inherited roster/marks.
 replacement:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000506'));
 PERFORM pg_temp.assert_true((replacement->'roster'->0->>'student_name')='Canonical After Freeze'
  AND (SELECT count(*)=0 FROM public.ministry_session_roster WHERE session_id='96000000-0000-4000-8000-000000000506')
  AND (SELECT count(*)=0 FROM public.ministry_attendance WHERE session_id='96000000-0000-4000-8000-000000000506'),
  'replacement preview reflects current canonical identity without copying stored child data');
 marks:=jsonb_build_object(
  '96000000-0000-4000-8000-000000000401','present',
  '96000000-0000-4000-8000-000000000402','absent',
  '96000000-0000-4000-8000-000000000405','present');
 draft:=public.ieadpe_ministry_save_attendance('96000000-0000-4000-8000-000000000603',
  jsonb_build_object('congregation_id','96000000-0000-4000-8000-000000000010',
   'session_id','96000000-0000-4000-8000-000000000506','expected_revision',1,'marks',marks,'finalize',false));
 finalized:=public.ieadpe_ministry_save_attendance('96000000-0000-4000-8000-000000000604',
  jsonb_build_object('congregation_id','96000000-0000-4000-8000-000000000010',
   'session_id','96000000-0000-4000-8000-000000000506','expected_revision',2,'marks',marks,'finalize',true));
 PERFORM pg_temp.assert_true(draft->>'attendance_count'='3' AND finalized->>'status'='finalized',
  'independent replacement first-save can draft then finalize');

 -- The end date is inclusive: on the final eligible day all three rows remain visible.
 ordinary:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000507'));
 SELECT array_agg(row_value->>'enrollment_id' ORDER BY row_value->>'enrollment_id') INTO ids
  FROM jsonb_array_elements(ordinary->'roster') row_value;
 PERFORM pg_temp.assert_true(ids=ARRAY[
  '96000000-0000-4000-8000-000000000401',
  '96000000-0000-4000-8000-000000000402',
  '96000000-0000-4000-8000-000000000405']::text[],
  'upper date endpoint is inclusive before eligibility drift');

 -- Eligibility changes after preview. Obsolete exact IDs are rejected and the first-save transaction rolls back fully.
 marks:=jsonb_build_object(
  '96000000-0000-4000-8000-000000000401','present',
  '96000000-0000-4000-8000-000000000402','present',
  '96000000-0000-4000-8000-000000000405','present');
 SELECT count(*) INTO receipts_before FROM private.mutation_receipts WHERE actor_uid='96000000-0000-4000-8000-000000000001';
 UPDATE public.ministry_enrollments SET end_date=pg_temp.fixture_date(1),status='completed'
  WHERE id='96000000-0000-4000-8000-000000000402';
 BEGIN
  PERFORM public.ieadpe_ministry_save_attendance('96000000-0000-4000-8000-000000000605',
   jsonb_build_object('congregation_id','96000000-0000-4000-8000-000000000010',
    'session_id','96000000-0000-4000-8000-000000000507','expected_revision',1,'marks',marks,'finalize',false));
  RAISE EXCEPTION 'ASSERTION: obsolete preview unexpectedly froze';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  PERFORM pg_temp.assert_true(SQLERRM='roster_mismatch','eligibility drift is rejected as roster_mismatch');
 END;
 PERFORM pg_temp.assert_true((SELECT revision=1 AND NOT roster_frozen FROM public.ministry_sessions
  WHERE id='96000000-0000-4000-8000-000000000507'),'drift rejection rolls back session freeze and revision');
 PERFORM pg_temp.assert_true((SELECT count(*)=0 FROM public.ministry_session_roster WHERE session_id='96000000-0000-4000-8000-000000000507')
  AND (SELECT count(*)=0 FROM public.ministry_attendance WHERE session_id='96000000-0000-4000-8000-000000000507'),
  'drift rejection rolls back roster and marks');
 PERFORM pg_temp.assert_true((SELECT count(*)=receipts_before FROM private.mutation_receipts
  WHERE actor_uid='96000000-0000-4000-8000-000000000001'),'drift rejection writes no receipt');
 ordinary:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000507'));
 PERFORM pg_temp.assert_true(jsonb_array_length(ordinary->'roster')=2,
  'fresh authoritative read after drift exposes current eligibility');

 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
   'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000501'));
  RAISE EXCEPTION 'ASSERTION: anonymous preview exposed';
 EXCEPTION WHEN SQLSTATE '42501' THEN
  PERFORM pg_temp.assert_true(SQLERRM='unauthorized','anonymous preview denied');
 END;
 PERFORM set_config('request.jwt.claim.sub','96000000-0000-4000-8000-000000000002',true);
 BEGIN
  PERFORM public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
   'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000501'));
  RAISE EXCEPTION 'ASSERTION: foreign preview exposed';
 EXCEPTION WHEN SQLSTATE '42501' THEN
  PERFORM pg_temp.assert_true(SQLERRM='forbidden','foreign scope preview denied');
 END;
 PERFORM set_config('request.jwt.claim.sub','96000000-0000-4000-8000-000000000001',true);
 UPDATE public.ministry_grants SET active=false WHERE user_id='96000000-0000-4000-8000-000000000001';
 PERFORM pg_temp.assert_true(private.ministry_can_access('96000000-0000-4000-8000-000000000010'),
  'legacy ministry grant deactivation leaves canonical direction assignment effective');
 result_session:=public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
  'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000507'));
 PERFORM pg_temp.assert_true(jsonb_typeof(result_session)='object',
  'open-session preview remains readable while canonical assignment exists');
 DELETE FROM public.user_access
 WHERE user_id='96000000-0000-4000-8000-000000000001'
  AND user_email='roster-preview@example.test'
  AND role='Membro da direção da campanha'
  AND congregation_id='96000000-0000-4000-8000-000000000010';
 GET DIAGNOSTICS removed_assignment_count=ROW_COUNT;
 PERFORM pg_temp.assert_true(removed_assignment_count=1,
  'exactly the synthetic callers canonical direction assignment was removed');
 PERFORM pg_temp.assert_true(NOT EXISTS(
  SELECT FROM public.user_access
  WHERE user_id='96000000-0000-4000-8000-000000000001'
   AND user_email='roster-preview@example.test'
   AND role='Membro da direção da campanha'
   AND congregation_id='96000000-0000-4000-8000-000000000010'),
  'no matching canonical direction assignment remains');
 PERFORM pg_temp.assert_true(NOT private.is_global_manager()
  AND NOT private.ministry_can_access('96000000-0000-4000-8000-000000000010'),
  'same synthetic UID has no global-manager alternative or scope authority');
 BEGIN
  PERFORM public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
   'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000501'));
  RAISE EXCEPTION 'ASSERTION: revoked preview exposed';
 EXCEPTION WHEN SQLSTATE '42501' THEN
  PERFORM pg_temp.assert_true(SQLERRM='forbidden','revoked preview denied');
 END;
 BEGIN
  PERFORM public.ieadpe_ministry_get_session_attendance(jsonb_build_object(
   'congregation_id','96000000-0000-4000-8000-000000000010','session_id','96000000-0000-4000-8000-000000000507'));
  RAISE EXCEPTION 'ASSERTION: revoked open preview exposed';
 EXCEPTION WHEN SQLSTATE '42501' THEN
  PERFORM pg_temp.assert_true(SQLERRM='forbidden','revoked open preview denied');
 END;
END $$;

ROLLBACK;
