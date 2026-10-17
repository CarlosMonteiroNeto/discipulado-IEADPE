BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('91000000-0000-0000-0000-000000000001','ui-staff-a@example.test',now()),
 ('91000000-0000-0000-0000-000000000002','ui-staff-b@example.test',now()),
 ('91000000-0000-0000-0000-000000000003','ui-campaign@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('92000000-0000-0000-0000-000000000001','UI Congregation A'),
 ('92000000-0000-0000-0000-000000000002','UI Congregation B');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','ministry_staff',true),
 ('91000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000002','ministry_staff',true);
INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,phone_e164,convert_id,updated_by) VALUES
 ('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Ana','ana',null,null,'91000000-0000-0000-0000-000000000001'),
 ('93000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','Beatriz','beatriz','+5511999999999',null,'91000000-0000-0000-0000-000000000001'),
 ('93000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','Camila','camila',null,null,'91000000-0000-0000-0000-000000000002');
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,status,updated_by) VALUES
 ('94000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Fundamentos','fundamentos','2026-10-01','active','91000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','Integração','integracao','2026-10-02','active','91000000-0000-0000-0000-000000000001'),
 ('94000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','Arquivo','arquivo','2026-10-03','archived','91000000-0000-0000-0000-000000000001');

SELECT set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; next_page jsonb; BEGIN
 page:=public.ieadpe_ministry_list_students('{"congregation_id":"92000000-0000-0000-0000-000000000001","name_prefix":null,"limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND page->'items'->0->>'name'='Ana' AND page->>'next_cursor' IS NOT NULL,'student page is scoped, minimal, stable and bounded');
 next_page:=public.ieadpe_ministry_list_students(jsonb_build_object('congregation_id','92000000-0000-0000-0000-000000000001','name_prefix',null,'limit',1,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(next_page->'items')=1 AND next_page->'items'->0->>'name'='Beatriz' AND next_page->>'next_cursor' IS NULL,'student cursor advances exactly once');
 PERFORM pg_temp.assert_true((public.ieadpe_ministry_list_students('{"congregation_id":"92000000-0000-0000-0000-000000000001","name_prefix":"Bea","limit":10,"cursor":null}'::jsonb)->'items'->0->>'convert_id') IS NULL,'student referral field remains nullable');
 page:=public.ieadpe_ministry_list_classes('{"congregation_id":"92000000-0000-0000-0000-000000000001","status":"active","limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND page->'items'->0->>'name'='Fundamentos' AND page->>'next_cursor' IS NOT NULL,'class page filters status before paging');
 next_page:=public.ieadpe_ministry_list_classes(jsonb_build_object('congregation_id','92000000-0000-0000-0000-000000000001','status','active','limit',1,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(next_page->'items')=1 AND next_page->'items'->0->>'name'='Integração' AND next_page->>'next_cursor' IS NULL,'class cursor advances in stable name order');
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_ministry_list_classes('{"congregation_id":"92000000-0000-0000-0000-000000000001","status":"archived","limit":10,"cursor":null}'::jsonb)->'items')=1,'class status filter includes only explicitly selected class state');
 BEGIN PERFORM public.ieadpe_ministry_list_students('{"congregation_id":"92000000-0000-0000-0000-000000000002","name_prefix":null,"limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: cross-scope student read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_classes('{"congregation_id":"92000000-0000-0000-0000-000000000002","status":null,"limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: cross-scope class read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_classes('{"congregation_id":"92000000-0000-0000-0000-000000000001","status":"unknown","limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: unknown class status accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_students('{"congregation_id":"92000000-0000-0000-0000-000000000001","name_prefix":null,"limit":101,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: oversized student page accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_students('{"congregation_id":"92000000-0000-0000-0000-000000000001","name_prefix":null,"limit":0,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: zero-sized student page accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM count(*) FROM public.ministry_students; RAISE EXCEPTION 'ASSERTION: direct student read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_students('{"congregation_id":"92000000-0000-0000-0000-000000000001","name_prefix":null,"limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: other congregation students visible'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_classes('{"congregation_id":"92000000-0000-0000-0000-000000000001","status":null,"limit":10,"cursor":null}'::jsonb); RAISE EXCEPTION 'ASSERTION: campaign-only role reads ministry classes'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.ministry_students','SELECT') AND NOT has_table_privilege('authenticated','public.ministry_classes','SELECT'),'direct UI table reads remain revoked');
RESET ROLE;
ROLLBACK;
