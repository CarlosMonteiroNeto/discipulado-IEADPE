BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.assert_sqlstate(statement text,expected_state text,expected_message text,label text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 EXECUTE statement;
 RAISE EXCEPTION 'ASSERTION: % accepted the operation',label;
EXCEPTION WHEN OTHERS THEN
 IF SQLSTATE=expected_state AND SQLERRM=expected_message THEN RETURN; END IF;
 RAISE EXCEPTION 'ASSERTION: % raised %/% instead of %/%',label,SQLSTATE,SQLERRM,expected_state,expected_message;
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('5a000000-0000-4000-8000-000000000001','enrollment-staff@example.test',now()),
 ('5a000000-0000-4000-8000-000000000002','enrollment-peer@example.test',now()),
 ('5a000000-0000-4000-8000-000000000003','enrollment-other@example.test',now()),
 ('5a000000-0000-4000-8000-000000000004','enrollment-revoked@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('5b000000-0000-4000-8000-000000000001','Enrollment A'),
 ('5b000000-0000-4000-8000-000000000002','Enrollment B'),
 ('5b000000-0000-4000-8000-000000000003','Enrollment A2');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('enrollment-staff@example.test','5a000000-0000-4000-8000-000000000001','Membro da direção da campanha','5b000000-0000-4000-8000-000000000001'),
 ('enrollment-staff@example.test','5a000000-0000-4000-8000-000000000001','Membro da direção da campanha','5b000000-0000-4000-8000-000000000003'),
 ('enrollment-peer@example.test','5a000000-0000-4000-8000-000000000002','Membro da direção da campanha','5b000000-0000-4000-8000-000000000001'),
 ('enrollment-other@example.test','5a000000-0000-4000-8000-000000000003','Membro da direção da campanha','5b000000-0000-4000-8000-000000000002'),
 ('enrollment-revoked@example.test','5a000000-0000-4000-8000-000000000004','Membro da direção da campanha','5b000000-0000-4000-8000-000000000001');
DELETE FROM public.user_access WHERE user_id='5a000000-0000-4000-8000-000000000004';

INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by) VALUES
 ('5c000000-0000-4000-8000-000000000001','5b000000-0000-4000-8000-000000000001','Active Class','active class','2026-01-01','5a000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000002','5b000000-0000-4000-8000-000000000001','Completed Class','completed class','2026-01-01','5a000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000003','5b000000-0000-4000-8000-000000000001','Withdrawn Class','withdrawn class','2026-01-01','5a000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000004','5b000000-0000-4000-8000-000000000001','Pagination Class','pagination class','2025-01-01','5a000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000005','5b000000-0000-4000-8000-000000000001','Peer Class','peer class','2026-01-01','5a000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000006','5b000000-0000-4000-8000-000000000002','Foreign Class','foreign class','2026-01-01','5a000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000007','5b000000-0000-4000-8000-000000000003','Second Scope Class','second scope class','2026-01-01','5a000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('5d500000-0000-4000-8000-000000000001','5b000000-0000-4000-8000-000000000001','History Learner','history learner','5a000000-0000-4000-8000-000000000001'),
 ('5d500000-0000-4000-8000-000000000002','5b000000-0000-4000-8000-000000000001','Peer Learner','peer learner','5a000000-0000-4000-8000-000000000001'),
 ('5d500000-0000-4000-8000-000000000003','5b000000-0000-4000-8000-000000000001','Paged Learner','paged learner','5a000000-0000-4000-8000-000000000001'),
 ('5d500000-0000-4000-8000-000000000004','5b000000-0000-4000-8000-000000000003','Second Scope Learner','second scope learner','5a000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by) VALUES
 ('5d000000-0000-4000-8000-000000000001','5b000000-0000-4000-8000-000000000001','5d500000-0000-4000-8000-000000000001','History Learner','history learner','5a000000-0000-4000-8000-000000000001'),
 ('5d000000-0000-4000-8000-000000000002','5b000000-0000-4000-8000-000000000001','5d500000-0000-4000-8000-000000000002','Peer Learner','peer learner','5a000000-0000-4000-8000-000000000001'),
 ('5d000000-0000-4000-8000-000000000003','5b000000-0000-4000-8000-000000000002',NULL,'Foreign Learner','foreign learner','5a000000-0000-4000-8000-000000000001'),
 ('5d000000-0000-4000-8000-000000000004','5b000000-0000-4000-8000-000000000001','5d500000-0000-4000-8000-000000000003','Paged Learner','paged learner','5a000000-0000-4000-8000-000000000001'),
 ('5d000000-0000-4000-8000-000000000005','5b000000-0000-4000-8000-000000000003','5d500000-0000-4000-8000-000000000004','Second Scope Learner','second scope learner','5a000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,end_date,status,updated_by) VALUES
 ('5e000000-0000-4000-8000-000000000001','5b000000-0000-4000-8000-000000000001','5d000000-0000-4000-8000-000000000001','5c000000-0000-4000-8000-000000000001','2026-03-01',NULL,'active','5a000000-0000-4000-8000-000000000001'),
 ('5e000000-0000-4000-8000-000000000002','5b000000-0000-4000-8000-000000000001','5d000000-0000-4000-8000-000000000001','5c000000-0000-4000-8000-000000000002','2026-02-01','2026-02-28','completed','5a000000-0000-4000-8000-000000000001'),
 ('5e000000-0000-4000-8000-000000000003','5b000000-0000-4000-8000-000000000001','5d000000-0000-4000-8000-000000000001','5c000000-0000-4000-8000-000000000003','2026-01-01','2026-01-15','withdrawn','5a000000-0000-4000-8000-000000000001'),
 ('5e000000-0000-4000-8000-000000000004','5b000000-0000-4000-8000-000000000001','5d000000-0000-4000-8000-000000000002','5c000000-0000-4000-8000-000000000005','2026-04-01',NULL,'active','5a000000-0000-4000-8000-000000000001'),
 ('5e000000-0000-4000-8000-000000000005','5b000000-0000-4000-8000-000000000002','5d000000-0000-4000-8000-000000000003','5c000000-0000-4000-8000-000000000006','2026-05-01',NULL,'active','5a000000-0000-4000-8000-000000000001'),
 ('5e000000-0000-4000-8000-000000000006','5b000000-0000-4000-8000-000000000003','5d000000-0000-4000-8000-000000000005','5c000000-0000-4000-8000-000000000007','2026-06-01',NULL,'active','5a000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,end_date,status,updated_by)
SELECT ('5f000000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,
 '5b000000-0000-4000-8000-000000000001','5d000000-0000-4000-8000-000000000004',
 '5c000000-0000-4000-8000-000000000004',
 ('2025-01-01'::date + (g-1)),CASE WHEN g=101 THEN NULL ELSE '2025-01-01'::date + (g-1) + 10 END,
 CASE WHEN g=101 THEN 'active' WHEN g%2=0 THEN 'completed' ELSE 'withdrawn' END,
 '5a000000-0000-4000-8000-000000000001'
FROM generate_series(1,101) g;

DO $$ BEGIN
 PERFORM set_config('test.cursor_wrong_actor',private.ministry_read_cursor_encode(jsonb_build_object(
  'uid','5a000000-0000-4000-8000-000000000002','resource','student_enrollments',
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
  'start_date','2026-03-01','id','5e000000-0000-4000-8000-000000000001')),true);
 PERFORM set_config('test.cursor_wrong_resource',private.ministry_read_cursor_encode(jsonb_build_object(
  'uid','5a000000-0000-4000-8000-000000000001','resource','enrollment_progress',
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
  'start_date','2026-03-01','id','5e000000-0000-4000-8000-000000000001')),true);
 PERFORM set_config('test.cursor_wrong_student',private.ministry_read_cursor_encode(jsonb_build_object(
  'uid','5a000000-0000-4000-8000-000000000001','resource','student_enrollments',
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000002',
  'start_date','2026-03-01','id','5e000000-0000-4000-8000-000000000001')),true);
 PERFORM set_config('test.cursor_wrong_scope',private.ministry_read_cursor_encode(jsonb_build_object(
  'uid','5a000000-0000-4000-8000-000000000001','resource','student_enrollments',
  'congregation_id','5b000000-0000-4000-8000-000000000003','student_id','5d000000-0000-4000-8000-000000000001',
  'start_date','2026-03-01','id','5e000000-0000-4000-8000-000000000001')),true);
 PERFORM set_config('test.cursor_extra_key',private.ministry_read_cursor_encode(jsonb_build_object(
  'uid','5a000000-0000-4000-8000-000000000001','resource','student_enrollments',
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
  'start_date','2026-03-01','id','5e000000-0000-4000-8000-000000000001','name','History Learner')),true);
END $$;

SELECT pg_temp.assert_true(has_function_privilege('authenticated',
 'public.ieadpe_ministry_list_student_enrollments(jsonb)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_ministry_list_student_enrollments(jsonb)','EXECUTE'),
 'enrollment history is authenticated-executable only');
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.ministry_enrollments','SELECT'),
 'enrollment history adds no direct table grant');
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_student_enrollments('{"congregation_id":"5b000000-0000-4000-8000-000000000001","student_id":"5d000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: anonymous enrollment history accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_student_enrollments('{"congregation_id":"5b000000-0000-4000-8000-000000000001","student_id":"5d000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: unauthenticated enrollment history accepted'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='unauthorized','missing actor reports unauthorized'); END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','5a000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE page jsonb; item jsonb; page_two jsonb; first_item jsonb; all_ids text[];
BEGIN
 page:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
  'limit',50,'cursor',NULL));
 PERFORM pg_temp.assert_true(page ?& ARRAY['items','next_cursor'] AND
  page-ARRAY['items','next_cursor']='{}'::jsonb,'page envelope is exact');
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=3 AND
  (SELECT array_agg(value->>'status' ORDER BY value->>'start_date' DESC) FROM jsonb_array_elements(page->'items') value)=
   ARRAY['active','completed','withdrawn'],'same-student history keeps all terminal statuses in start_date DESC order');
 PERFORM pg_temp.assert_true(page->'items'->0->>'id'='5e000000-0000-4000-8000-000000000001' AND
  page->'items'->0->>'class_name'='Active Class' AND page->'items'->0->>'start_date'='2026-03-01' AND
  page->'items'->0->'end_date'='null'::jsonb AND page->'items'->0->>'revision'='1',
  'active history item has the exact projected values');
 PERFORM pg_temp.assert_true(page->'items'->1->>'class_name'='Completed Class' AND
  page->'items'->1->>'end_date'='2026-02-28' AND page->'items'->2->>'end_date'='2026-01-15',
  'closed history retains nullable end dates');
 PERFORM pg_temp.assert_true((SELECT bool_and(value ?& ARRAY['id','class_id','class_name','start_date','end_date','status','revision'] AND
   value-ARRAY['id','class_id','class_name','start_date','end_date','status','revision']='{}'::jsonb)
   FROM jsonb_array_elements(page->'items') value),'every item keeps exactly the bounded key set');
 PERFORM pg_temp.assert_true((SELECT bool_and(value->>'start_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND
   (value->'end_date'='null'::jsonb OR value->>'end_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'))
   FROM jsonb_array_elements(page->'items') value),'dates are strict date-only strings');
 PERFORM pg_temp.assert_true(NOT page::text LIKE '%5a000000-0000-4000-8000-000000000001%' AND
  NOT page::text LIKE '%5d500000-0000-4000-8000-000000000001%' AND NOT page::text LIKE '%@example.test%',
  'history does not expose actor, canonical person, or account identity');

 page_two:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000002',
  'limit',50,'cursor',NULL));
 PERFORM pg_temp.assert_true(jsonb_array_length(page_two->'items')=1 AND
  page_two->'items'->0->>'id'='5e000000-0000-4000-8000-000000000004','history is bounded to the requested student');
END $$;

DO $$
DECLARE page jsonb; next_cursor text; all_ids text[]; seen integer; loops integer; item jsonb;
BEGIN
 page:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000004',
  'limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=100 AND page->>'next_cursor' IS NOT NULL,
  'limit+1 returns a bounded first page and continuation');
 all_ids:=ARRAY(SELECT value->>'id' FROM jsonb_array_elements(page->'items') value);
 PERFORM pg_temp.assert_true(page->'items'->0->>'start_date'='2025-04-11' AND
  page->'items'->99->>'start_date'='2025-01-02','first page starts at the latest start_date');
 page:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000004',
  'limit',100,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND page->>'next_cursor' IS NULL,
  '101-row history terminates on the second page');
 all_ids:=all_ids||ARRAY(SELECT value->>'id' FROM jsonb_array_elements(page->'items') value);
 PERFORM pg_temp.assert_true(cardinality(all_ids)=101 AND
  (SELECT count(DISTINCT value) FROM unnest(all_ids) value)=101,'101-row traversal is complete and duplicate-free');

 next_cursor:=NULL; seen:=0; loops:=0; all_ids:=ARRAY[]::text[];
 LOOP
  page:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000004',
   'limit',1,'cursor',next_cursor));
  seen:=seen+jsonb_array_length(page->'items'); loops:=loops+1;
  all_ids:=all_ids||ARRAY(SELECT value->>'id' FROM jsonb_array_elements(page->'items') value);
  next_cursor:=page->>'next_cursor';
  EXIT WHEN next_cursor IS NULL;
  PERFORM pg_temp.assert_true(loops<=101,'limit=1 traversal stays bounded');
 END LOOP;
 PERFORM pg_temp.assert_true(seen=101 AND cardinality(all_ids)=101 AND
  (SELECT count(DISTINCT value) FROM unnest(all_ids) value)=101,'limit=1 traversal visits all 101 rows exactly once');
END $$;

DO $$
DECLARE page jsonb; real_cursor text; tampered text;
BEGIN
 page:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
  'limit',1,'cursor',NULL));
 real_cursor:=page->>'next_cursor';
 tampered:=left(real_cursor,length(real_cursor)-1)||CASE WHEN right(real_cursor,1)='a' THEN 'b' ELSE 'a' END;
 PERFORM pg_temp.assert_true(real_cursor IS NOT NULL,'resumable page yields a signed cursor');
 page:=public.ieadpe_ministry_list_student_enrollments(jsonb_build_object(
  'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
  'limit',1,'cursor',real_cursor));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  page->'items'->0->>'id'='5e000000-0000-4000-8000-000000000002','the signed cursor resumes the same ordered history');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
   'limit',1,'cursor',tampered)::text)||'::jsonb)','22023','invalid_cursor','modified signature is rejected');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
   'limit',1,'cursor',current_setting('test.cursor_wrong_actor'))::text)||'::jsonb)',
  '22023','invalid_cursor','cursor bound to another actor is rejected');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
   'limit',1,'cursor',current_setting('test.cursor_wrong_resource'))::text)||'::jsonb)',
  '22023','invalid_cursor','cursor bound to another resource is rejected');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
   'limit',1,'cursor',current_setting('test.cursor_wrong_student'))::text)||'::jsonb)',
  '22023','invalid_cursor','cursor bound to another student is rejected');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
   'limit',1,'cursor',current_setting('test.cursor_wrong_scope'))::text)||'::jsonb)',
  '22023','invalid_cursor','cursor bound to another scope is rejected');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000003','student_id','5d000000-0000-4000-8000-000000000005',
   'limit',1,'cursor',real_cursor)::text)||'::jsonb)',
  '22023','invalid_cursor','cursor cannot cross an authorized scope');
 PERFORM pg_temp.assert_sqlstate(
  'SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal(jsonb_build_object(
   'congregation_id','5b000000-0000-4000-8000-000000000001','student_id','5d000000-0000-4000-8000-000000000001',
   'limit',1,'cursor',current_setting('test.cursor_extra_key'))::text)||'::jsonb)',
  '22023','invalid_cursor','cursor with unexpected claims is rejected');
END $$;

DO $$
DECLARE valid jsonb:='{"congregation_id":"5b000000-0000-4000-8000-000000000001","student_id":"5d000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb;
BEGIN
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments(NULL)',
  '22023','invalid_request','null request is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments(''[]''::jsonb)',
  '22023','invalid_request','non-object request is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments(''{}''::jsonb)',
  '22023','invalid_request','empty request is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||quote_literal((valid-'cursor')::text)||'::jsonb)',
  '22023','invalid_request','missing cursor key is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"unexpected":true}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','unexpected request key is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"student_id":7}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','non-string student id is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"student_id":"not-a-uuid"}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','malformed student id is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"congregation_id":"not-a-uuid"}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','malformed congregation id is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"limit":"10"}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','string limit is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"limit":1.5}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','fractional limit is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"cursor":7}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_request','non-string cursor is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"limit":0}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_limit','zero limit is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"limit":101}'::jsonb)::text)||'::jsonb)',
  '22023','invalid_limit','limit above 100 is rejected');
 PERFORM pg_temp.assert_sqlstate('SELECT public.ieadpe_ministry_list_student_enrollments('||
  quote_literal((valid||'{"student_id":"5d000000-0000-4000-8000-0000000000ff"}'::jsonb)::text)||'::jsonb)',
  '22023','student_not_found','missing same-scope student is not found');
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','5a000000-0000-4000-8000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_student_enrollments('{"congregation_id":"5b000000-0000-4000-8000-000000000001","student_id":"5d000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: foreign reader listed another scope'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='forbidden','foreign scope is forbidden'); END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','5a000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_student_enrollments('{"congregation_id":"5b000000-0000-4000-8000-000000000002","student_id":"5d000000-0000-4000-8000-000000000003","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: staff read an unauthorized congregation'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='forbidden','authorization precedes student lookup across scopes'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_student_enrollments('{"congregation_id":"5b000000-0000-4000-8000-000000000001","student_id":"5d000000-0000-4000-8000-000000000003","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: foreign student existence leaked'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='student_not_found','foreign student is indistinguishable from a missing same-scope student'); END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','5a000000-0000-4000-8000-000000000004',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_student_enrollments('{"congregation_id":"5b000000-0000-4000-8000-000000000001","student_id":"5d000000-0000-4000-8000-0000000000ff","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: revoked reader listed enrollment history'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='forbidden','revoked access denies before student lookup'); END;
END $$;
RESET ROLE;

ROLLBACK;
