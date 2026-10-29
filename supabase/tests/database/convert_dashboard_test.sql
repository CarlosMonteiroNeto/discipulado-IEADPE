BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES ('af000000-0000-4000-8000-000000000001','dashboard@example.test',now());
INSERT INTO public.congregations(id,name) VALUES ('af000000-0000-4000-8000-000000000002','Matriz'),('af000000-0000-4000-8000-000000000003','Outra');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES ('dashboard@example.test','af000000-0000-4000-8000-000000000001','Membro da direção da campanha','af000000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','af000000-0000-4000-8000-000000000001',true);
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id) VALUES
 ('af000000-0000-4000-8000-000000000010','dash-1','Zélia','Square','female',private.business_today()-10,'Culto regular','af000000-0000-4000-8000-000000000002'),
 ('af000000-0000-4000-8000-000000000011','dash-2','Álvaro','Square','male',private.business_today()-10,'Culto regular','af000000-0000-4000-8000-000000000002'),
 ('af000000-0000-4000-8000-000000000012','dash-3','Ana','Square','female',private.business_today(),'Culto regular','af000000-0000-4000-8000-000000000002');
DO $$ DECLARE p jsonb; q jsonb; counts jsonb; BEGIN
 p:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_id','af000000-0000-4000-8000-000000000002','limit',1));
 PERFORM pg_temp.assert_true(p->'items'->0->'convert'->>'id'='af000000-0000-4000-8000-000000000011','severity then Portuguese name');
 q:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_id','af000000-0000-4000-8000-000000000002','limit',1,'cursor',p->>'next_cursor'));
 PERFORM pg_temp.assert_true(q->'items'->0->'convert'->>'id'='af000000-0000-4000-8000-000000000010','cursor follows name ordering');
 q:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_id','af000000-0000-4000-8000-000000000002','limit',50,'search','lva'));
 PERFORM pg_temp.assert_true(jsonb_array_length(q->'items')=1,'substring search');
 counts:=public.ieadpe_convert_dashboard_counts(jsonb_build_object('congregation_ids',jsonb_build_array('af000000-0000-4000-8000-000000000002')));
 PERFORM pg_temp.assert_true((counts->'counts'->0->>'red_count')::int=2,'exact red count');
 BEGIN PERFORM public.ieadpe_convert_dashboard_counts(jsonb_build_object('congregation_ids',jsonb_build_array('af000000-0000-4000-8000-000000000003'))); RAISE EXCEPTION 'ASSERTION: foreign scope'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_id','af000000-0000-4000-8000-000000000002','limit',1,'search','x','cursor',p->>'next_cursor')); RAISE EXCEPTION 'ASSERTION: cursor filter'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
-- A large authorized scope list must not make the opaque cursor grow with every UUID.
INSERT INTO public.congregations(id,name)
 SELECT md5('dashboard-scope-'||n)::uuid,'Scope '||n FROM generate_series(1,80) n;
INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
 SELECT 'dashboard@example.test','af000000-0000-4000-8000-000000000001',
 'Membro da direção da campanha',md5('dashboard-scope-'||n)::uuid FROM generate_series(1,80) n;
DO $$ DECLARE ids jsonb; changed jsonb; page jsonb; next_page jsonb; BEGIN
 SELECT jsonb_agg(id ORDER BY id) INTO ids FROM (
  SELECT md5('dashboard-scope-'||n)::uuid AS id FROM generate_series(1,80) n
  UNION ALL SELECT 'af000000-0000-4000-8000-000000000002'::uuid) s;
 page:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_ids',ids,'limit',1));
 PERFORM pg_temp.assert_true(length(page->>'next_cursor')<2048,'cursor stays compact with 81 scopes');
 next_page:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_ids',ids,'limit',1,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(next_page->'items')=1,'large scope cursor continues');
 changed:=ids-0;
 BEGIN
  PERFORM public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_ids',changed,'limit',1,'cursor',page->>'next_cursor'));
  RAISE EXCEPTION 'ASSERTION: changed scope accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;

-- Active enrollment changes the projected status and must not inflate red counts.
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name) VALUES
 ('af000000-0000-4000-8000-000000000020','af000000-0000-4000-8000-000000000002','Zélia Canonical','zélia canonical');
UPDATE public.converts SET person_id='af000000-0000-4000-8000-000000000020' WHERE id='af000000-0000-4000-8000-000000000010';
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name) VALUES
 ('af000000-0000-4000-8000-000000000021','af000000-0000-4000-8000-000000000002','af000000-0000-4000-8000-000000000020','Zélia Canonical','zélia canonical');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date) VALUES
 ('af000000-0000-4000-8000-000000000022','af000000-0000-4000-8000-000000000002','Class','class',private.business_today()-20);
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date) VALUES
 ('af000000-0000-4000-8000-000000000023','af000000-0000-4000-8000-000000000002','af000000-0000-4000-8000-000000000021','af000000-0000-4000-8000-000000000022',private.business_today()-20);
DO $$ DECLARE p jsonb; counts jsonb; BEGIN
 counts:=public.ieadpe_convert_dashboard_counts(jsonb_build_object('congregation_ids',jsonb_build_array('af000000-0000-4000-8000-000000000002')));
 PERFORM pg_temp.assert_true((counts->'counts'->0->>'red_count')::int=1,'active enrollment excluded from red count');
 p:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_ids',jsonb_build_array('af000000-0000-4000-8000-000000000002'),'status','yellow','search','canonical','limit',50));
 PERFORM pg_temp.assert_true(p->'items'->0->'convert'->>'id'='af000000-0000-4000-8000-000000000010','canonical name and projected enrollment');
 INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status) VALUES
  ('af000000-0000-4000-8000-000000000024','af000000-0000-4000-8000-000000000002','af000000-0000-4000-8000-000000000022',private.business_today(),'finalized');
 INSERT INTO public.ministry_session_roster(congregation_id,session_id,enrollment_id,student_id,student_name,updated_by) VALUES
  ('af000000-0000-4000-8000-000000000002','af000000-0000-4000-8000-000000000024','af000000-0000-4000-8000-000000000023','af000000-0000-4000-8000-000000000021','Zélia Canonical','af000000-0000-4000-8000-000000000001');
 INSERT INTO public.ministry_attendance(congregation_id,session_id,enrollment_id,student_id,status) VALUES
  ('af000000-0000-4000-8000-000000000002','af000000-0000-4000-8000-000000000024','af000000-0000-4000-8000-000000000023','af000000-0000-4000-8000-000000000021','present');
 p:=public.ieadpe_convert_dashboard_page(jsonb_build_object('congregation_id','af000000-0000-4000-8000-000000000002','status','green','limit',50));
 PERFORM pg_temp.assert_true(p->'items'->0->'convert'->>'id'='af000000-0000-4000-8000-000000000010','finalized present lesson updates green status');
 UPDATE public.converts SET is_deviated=true WHERE id='af000000-0000-4000-8000-000000000011';
 counts:=public.ieadpe_convert_dashboard_counts(jsonb_build_object('congregation_ids',jsonb_build_array('af000000-0000-4000-8000-000000000002')));
 PERFORM pg_temp.assert_true((counts->'counts'->0->>'red_count')::int=0,'terminal record excluded');
END $$;
ROLLBACK;
