BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('97000000-0000-0000-0000-000000000010','session-staff@example.test',now()),
 ('97000000-0000-0000-0000-000000000011','session-foreign@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('97000000-0000-0000-0000-000000000001','Session A'),('97000000-0000-0000-0000-000000000005','Session B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('session-staff@example.test','97000000-0000-0000-0000-000000000010','Membro da direção da campanha','97000000-0000-0000-0000-000000000001'),
 ('session-foreign@example.test','97000000-0000-0000-0000-000000000011','Membro da direção da campanha','97000000-0000-0000-0000-000000000005'),
 ('session-foreign@example.test','97000000-0000-0000-0000-000000000011','Membro da direção da campanha','97000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('97000000-0000-0000-0000-000000000010','97000000-0000-0000-0000-000000000001','ministry_staff',true),
 ('97000000-0000-0000-0000-000000000011','97000000-0000-0000-0000-000000000005','ministry_staff',true),
 ('97000000-0000-0000-0000-000000000011','97000000-0000-0000-0000-000000000001','ministry_staff',true);
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,end_date,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000002','97000000-0000-0000-0000-000000000001','Class A','class a','2026-01-10','2026-12-20','97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000006','97000000-0000-0000-0000-000000000001','Class B','class b','2026-01-01',NULL,'97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000008','97000000-0000-0000-0000-000000000001','Replay Class','replay class','2026-01-10','2026-12-20','97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000003','97000000-0000-0000-0000-000000000001','Completed','completed','2026-01-01','2026-12-31','97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000004','97000000-0000-0000-0000-000000000001','Archived','archived','2026-01-01','2026-12-31','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,end_date,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000007','97000000-0000-0000-0000-000000000005','Foreign class','foreign class','2026-01-01','2026-12-31','97000000-0000-0000-0000-000000000011');
UPDATE public.ministry_classes SET status='completed' WHERE id='97000000-0000-0000-0000-000000000003';
UPDATE public.ministry_classes SET status='archived' WHERE id='97000000-0000-0000-0000-000000000004';
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,topic,roster_frozen,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000020','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000002','2026-01-08','open','past','true','97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000021','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000002','2026-01-11','open',NULL,false,'97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000022','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000006','2026-01-12','open',NULL,false,'97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000023','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000003','2026-02-01','finalized',NULL,true,'97000000-0000-0000-0000-000000000010'),
 ('97000000-0000-0000-0000-000000000024','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000004','2026-02-02','finalized',NULL,true,'97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000026','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000002','2026-12-19','open','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,roster_frozen,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000027','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000002','2026-12-18','finalized',true,'97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000030','97000000-0000-0000-0000-000000000001','Learner','learner','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000031','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000030','Learner','learner','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000032','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000031','97000000-0000-0000-0000-000000000002','2026-01-01','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_session_roster(id,congregation_id,session_id,enrollment_id,student_id,student_name,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000033','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000020','97000000-0000-0000-0000-000000000032','97000000-0000-0000-0000-000000000031','Historical Name','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_attendance(id,congregation_id,session_id,enrollment_id,student_id,status,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000034','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000020','97000000-0000-0000-0000-000000000032','97000000-0000-0000-0000-000000000031','present','97000000-0000-0000-0000-000000000010');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,updated_by)
 SELECT ('97000001-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000002',('2027-03-01'::date+n),CASE WHEN n%2=0 THEN 'open' ELSE 'canceled' END,'97000000-0000-0000-0000-000000000010' FROM generate_series(0,100) n;
SELECT set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000010',true);
DO $$ DECLARE response jsonb; tail jsonb; all_items jsonb; BEGIN
 response:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',100,'cursor',NULL));
 PERFORM pg_temp.assert_true((SELECT count(*)=2 FROM jsonb_object_keys(response)) AND jsonb_array_length(response->'items')=100 AND response->>'next_cursor' IS NOT NULL,'class session page is scoped and bounded');
 PERFORM pg_temp.assert_true(response->'items'->0->>'id'='97000000-0000-0000-0000-000000000020' AND response->'items'->0->>'revision'='1','page returns exact ordered keys and revision');
 PERFORM pg_temp.assert_true((SELECT bool_and(item ?& ARRAY['id','class_id','congregation_id','date','topic','status','revision'] AND item-ARRAY['id','class_id','congregation_id','date','topic','status','revision']='{}'::jsonb) FROM jsonb_array_elements(response->'items') item),'item exact keys');
 PERFORM public.ieadpe_ministry_cancel_session(gen_random_uuid(),jsonb_build_object('id','97000000-0000-0000-0000-000000000020','congregation_id','97000000-0000-0000-0000-000000000001','expected_revision',1));
 INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,updated_by) VALUES('97000000-0000-0000-0000-000000000025','97000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000002','2026-01-08','97000000-0000-0000-0000-000000000010');
 PERFORM pg_temp.assert_true((SELECT status='present' FROM public.ministry_attendance WHERE session_id='97000000-0000-0000-0000-000000000020') AND (SELECT student_name='Historical Name' FROM public.ministry_session_roster WHERE session_id='97000000-0000-0000-0000-000000000020'),'cancel releases live date and retains marks');
 response:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',100,'cursor',NULL));
 tail:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',100,'cursor',response->>'next_cursor'));
 all_items:=(response->'items')||(tail->'items');
 PERFORM pg_temp.assert_true(response->'items' @> '[{"date":"2026-12-19","status":"open"}]'::jsonb AND
  (SELECT count(DISTINCT item->>'status')=3 FROM jsonb_array_elements(all_items) item),'future and all statuses remain discoverable');
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000004','limit',100,'cursor',NULL))->'items')=1,'archived class sessions remain discoverable');
 PERFORM pg_temp.assert_true(public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000003','limit',100,'cursor',NULL))->'items'->0->>'status'='finalized','historical finalized status is preserved');
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',response->>'next_cursor'))->'items')=1,'page size may change');
END $$;

DO $$ DECLARE response jsonb; page1 jsonb; page2 jsonb; other_page jsonb; day_value text; begin_count integer; receipt_count integer; BEGIN
 response:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',100,'cursor',NULL));
 page1:=response; page2:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',100,'cursor',response->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(page2->'items')=6 AND page2->>'next_cursor' IS NULL,'empty tail returns remaining rows and null cursor');
 PERFORM pg_temp.assert_true(page1->'items'->0->>'date'='2026-01-08' AND page1->'items'->1->>'date'='2026-01-08' AND page1->'items'->0->>'id'<'97000000-0000-0000-0000-000000000025','date and id order is ascending');
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',NULL))->'items')=1,'page size one is accepted');
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',100,'cursor',NULL))->'items')=100,'page size 100 is accepted');
 FOREACH day_value IN ARRAY ARRAY['0','101'] LOOP
  BEGIN PERFORM public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',day_value::integer,'cursor',NULL)); RAISE EXCEPTION 'ASSERTION: invalid page size accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_limit','out-of-range limit is invalid_limit'); END;
 END LOOP;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":-1,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: negative integer limit accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_limit','negative integer is invalid_limit'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":999999999999999999999999999999999,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: oversized integer limit accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_limit','large integer is invalid_limit'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":1.5,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: fractional limit accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_request','fractional limit is invalid_request'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":10,"cursor":null,"extra":true}'::jsonb); RAISE EXCEPTION 'ASSERTION: unknown key accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_request','unknown keys rejected'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: missing key accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_request','missing keys rejected'); END;
 page1:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',NULL));
 PERFORM set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000011',true);
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',page1->>'next_cursor')); RAISE EXCEPTION 'ASSERTION: other user cursor accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_cursor','cursor binds actor'); END;
 other_page:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',NULL));
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000005','class_id','97000000-0000-0000-0000-000000000007','limit',1,'cursor',other_page->>'next_cursor')); RAISE EXCEPTION 'ASSERTION: other-congregation cursor accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_cursor','cursor binds congregation'); END;
 PERFORM set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000010',true);
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000006','limit',1,'cursor',page1->>'next_cursor')); RAISE EXCEPTION 'ASSERTION: cross-class cursor accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_cursor','cursor binds caller class and congregation'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000005','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',page1->>'next_cursor')); RAISE EXCEPTION 'ASSERTION: cross-congregation cursor accepted'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='forbidden','cursor rechecks congregation authority'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions(jsonb_build_object('congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','limit',1,'cursor',left(page1->>'next_cursor',length(page1->>'next_cursor')-1)||'X')); RAISE EXCEPTION 'ASSERTION: tampered cursor accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='invalid_cursor','cursor signature is checked'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000099","limit":1,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: missing class accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='class_not_found','missing class error'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000007","limit":1,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: foreign class exposed'; EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='class_not_found','foreign class concealed as not found'); END;
 BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000005","class_id":"97000000-0000-0000-0000-000000000002","limit":1,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: foreign class exposed'; EXCEPTION WHEN SQLSTATE '42501' THEN PERFORM pg_temp.assert_true(SQLERRM='forbidden','foreign congregation denied'); END;
END $$;

DO $$ DECLARE day_value text; response jsonb; op uuid; payload jsonb; prior_receipts integer; prior_rows integer; BEGIN
 FOREACH day_value IN ARRAY ARRAY['2026-01-09','2026-12-21'] LOOP
  BEGIN PERFORM public.ieadpe_ministry_create_session(gen_random_uuid(),jsonb_build_object('id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','date',day_value,'topic',NULL)); RAISE EXCEPTION 'ASSERTION: out-of-period creation accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','period error is safe'); END;
 END LOOP;
 FOREACH day_value IN ARRAY ARRAY['2026-01-10','2026-12-20'] LOOP
  response:=public.ieadpe_ministry_create_session(gen_random_uuid(),jsonb_build_object('id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000002','date',day_value,'topic',NULL));
  PERFORM pg_temp.assert_true(response->>'status'='open' AND (response->>'revision')::integer=1,'class period bounds are inclusive');
 END LOOP;
 response:=public.ieadpe_ministry_create_session(gen_random_uuid(),jsonb_build_object('id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000006','date',(now() AT TIME ZONE 'America/Recife')::date+1,'topic',NULL));
 PERFORM pg_temp.assert_true(response->>'status'='open' AND (response->>'revision')::integer=1,'open-ended class permits future date');
 op:=gen_random_uuid(); payload:=jsonb_build_object('id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000008','date','2026-04-01','topic',NULL);
  response:=public.ieadpe_ministry_create_session(op,payload);
  SELECT count(*) INTO prior_receipts FROM private.mutation_receipts WHERE actor_uid='97000000-0000-0000-0000-000000000010';
  SELECT count(*) INTO prior_rows FROM public.ministry_sessions WHERE class_id='97000000-0000-0000-0000-000000000008' AND session_date='2026-04-01';
  BEGIN PERFORM public.ieadpe_ministry_create_session(gen_random_uuid(),jsonb_build_object('id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001','class_id','97000000-0000-0000-0000-000000000008','date','2026-04-01','topic',NULL)); RAISE EXCEPTION 'ASSERTION: duplicate date accepted';
  EXCEPTION WHEN SQLSTATE '23505' THEN PERFORM pg_temp.assert_true(SQLERRM='academic_conflict','duplicate date returns safe conflict'); END;
  PERFORM pg_temp.assert_true((SELECT count(*)=prior_rows FROM public.ministry_sessions WHERE class_id='97000000-0000-0000-0000-000000000008' AND session_date='2026-04-01') AND
   (SELECT count(*)=prior_receipts FROM private.mutation_receipts WHERE actor_uid='97000000-0000-0000-0000-000000000010'),'duplicate creates no row or receipt');
  PERFORM public.ieadpe_ministry_cancel_session(gen_random_uuid(),jsonb_build_object('id',response->>'id','congregation_id','97000000-0000-0000-0000-000000000001','expected_revision',1));
  PERFORM public.ieadpe_ministry_set_class_status(gen_random_uuid(),jsonb_build_object('id','97000000-0000-0000-0000-000000000008','congregation_id','97000000-0000-0000-0000-000000000001','status','completed','expected_revision',1));
  PERFORM pg_temp.assert_true(public.ieadpe_ministry_create_session(op,payload)=response,'create replay survives historical class state');
END $$;

SET LOCAL ROLE anon;
DO $$ BEGIN BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":1,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: anonymous execute granted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000011',true);
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":1,"cursor":null}'::jsonb)->'items')=1,'authorized second actor reads scoped class');
SELECT set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000010',true);
DELETE FROM public.user_access WHERE user_id='97000000-0000-0000-0000-000000000010';
DO $$ BEGIN BEGIN PERFORM public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000001","class_id":"97000000-0000-0000-0000-000000000002","limit":1,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: revoked caller read class'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $$;

SELECT set_config('request.jwt.claim.sub','97000000-0000-0000-0000-000000000090',true);
DO $$ DECLARE response jsonb; BEGIN
 response:=public.ieadpe_ministry_list_class_sessions('{"congregation_id":"97000000-0000-0000-0000-000000000091","class_id":"97000000-0000-0000-0000-000000000092","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(response->'items'->0->>'date'='2026-02-01','historical out-of-period session remains cancellable');
 response:=public.ieadpe_ministry_cancel_session(gen_random_uuid(),' {"id":"97000000-0000-0000-0000-000000000093","congregation_id":"97000000-0000-0000-0000-000000000091","expected_revision":1}'::jsonb);
 PERFORM pg_temp.assert_true(response->>'status'='canceled','legacy out-of-period row can be canceled');
END $$;
ROLLBACK;
