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
INSERT INTO public.ministry_contacts(id,congregation_id,name,normalized_name,scope,legacy_firebase_id,updated_by) VALUES
 ('83000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','Ana','ana','congregation','firebase-contact-1','81000000-0000-0000-0000-000000000001'),
 ('83000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','Bia','bia','congregation','firebase-contact-2','81000000-0000-0000-0000-000000000001'),
 ('83000000-0000-0000-0000-000000000003',NULL,'Supervisor','supervisor','supervision','firebase-contact-3','81000000-0000-0000-0000-000000000002'),
 ('83000000-0000-0000-0000-000000000004','82000000-0000-0000-0000-000000000001','Carla','carla','congregation','firebase-contact-4','81000000-0000-0000-0000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,legacy_firebase_id,updated_by) VALUES
 ('84000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','Lia','lia','firebase-student-1','81000000-0000-0000-0000-000000000001'),
 ('84000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','Mia','mia','firebase-student-2','81000000-0000-0000-0000-000000000005');

SELECT pg_temp.assert_true((SELECT count(*)=9 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname LIKE 'ministry_%' AND c.relkind='r' AND c.relrowsecurity),'RLS enabled on every ministry table');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.ministry_students),'legacy Firebase keys are separate from UUID primary keys');

SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.ministry_students),'staff reads own congregation');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.ministry_students WHERE congregation_id='82000000-0000-0000-0000-000000000002'),'staff cannot read another congregation');
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.ministry_students','INSERT') AND NOT has_table_privilege('authenticated','public.ministry_attendance','UPDATE'),'ministry client role has no business write privilege');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.ministry_contacts),'staff cannot read supervision contacts');
SELECT pg_temp.assert_true((public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb)->'items'->0->>'name')='Ana','directory projects allowed contact and page one');
SELECT pg_temp.assert_true(public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":"82000000-0000-0000-0000-000000000001","limit":1,"cursor":null}'::jsonb)->>'next_cursor' IS NOT NULL,'full page returns continuation');
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
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.ministry_students),'campaign direction does not imply ministry');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000004',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.ministry_students),'inactive ministry grant cannot read');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.ministry_students),'ministry supervisor reads across congregations');
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_directory('{"scope":"all","congregation_id":null,"limit":100,"cursor":null}'::jsonb)->'items')=4,'supervisor all-scope directory bounded projection');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"congregation","congregation_id":null,"limit":101,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: oversized page accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_directory('{"scope":"all","congregation_id":"82000000-0000-0000-0000-000000000001","limit":20,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: all plus congregation accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
