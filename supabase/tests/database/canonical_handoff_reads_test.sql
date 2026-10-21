BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('c1000000-0000-4000-8000-000000000001','handoff-staff@example.test',now()),
 ('c1000000-0000-4000-8000-000000000002','handoff-peer@example.test',now()),
 ('c1000000-0000-4000-8000-000000000003','handoff-other@example.test',now()),
 ('c1000000-0000-4000-8000-000000000004','handoff-revoked@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('c2000000-0000-4000-8000-000000000001','Handoff A'),
 ('c2000000-0000-4000-8000-000000000002','Handoff B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('handoff-staff@example.test','c1000000-0000-4000-8000-000000000001','Membro da direção da campanha','c2000000-0000-4000-8000-000000000001'),
 ('handoff-peer@example.test','c1000000-0000-4000-8000-000000000002','Membro da direção da campanha','c2000000-0000-4000-8000-000000000001'),
 ('handoff-other@example.test','c1000000-0000-4000-8000-000000000003','Membro da direção da campanha','c2000000-0000-4000-8000-000000000002'),
 ('handoff-revoked@example.test','c1000000-0000-4000-8000-000000000004','Membro da direção da campanha','c2000000-0000-4000-8000-000000000001');
DELETE FROM public.user_access WHERE user_id='c1000000-0000-4000-8000-000000000004';

INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,phone,address,updated_by) VALUES
 ('c3000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','Ana Antiga','ana antiga',NULL,
  '{"street":"Rua Um","district":"Centro","city":"Recife","state_code":"PE","postal_code":"50000-000"}','c1000000-0000-4000-8000-000000000001'),
 ('c3000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000001','Sem Contato','sem contato',NULL,
  '{"street":"   ","district":"","city":null,"state_code":null,"postal_code":null}','c1000000-0000-4000-8000-000000000001'),
 ('c3000000-0000-4000-8000-000000000003','c2000000-0000-4000-8000-000000000001','Historico Original','historico original',NULL,NULL,
  'c1000000-0000-4000-8000-000000000001'),
 ('c3000000-0000-4000-8000-000000000004','c2000000-0000-4000-8000-000000000001','Aluno Nulo','aluno nulo',NULL,NULL,
  'c1000000-0000-4000-8000-000000000001');
-- Canonical names run opposite to their generated IDs so ordering and cursor
-- continuation can only pass when they use the canonical normalized name.
INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,updated_by)
SELECT ('c4000000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,
 'c2000000-0000-4000-8000-000000000001','Paginado '||lpad((102-g)::text,3,'0'),
 'paginado '||lpad((102-g)::text,3,'0'),'c1000000-0000-4000-8000-000000000001'
FROM generate_series(1,101) g;

INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,
 congregation_id,address,phone,person_id) VALUES
 ('c5000000-0000-4000-8000-000000000001','handoff-c1','Ana Antiga','Praça','female','2026-10-10','Culto',
  'c2000000-0000-4000-8000-000000000001','Endereco Legado A','+5511999990001','c3000000-0000-4000-8000-000000000001'),
 ('c5000000-0000-4000-8000-000000000002','handoff-c2','Sem Contato','Praça','male','2026-10-09','Culto',
  'c2000000-0000-4000-8000-000000000001','Endereco Fantasma','+5511999990002','c3000000-0000-4000-8000-000000000002'),
 ('c5000000-0000-4000-8000-000000000003','handoff-c3','Legado Antigo','Praça','male','2026-10-08','Culto',
  'c2000000-0000-4000-8000-000000000001','Rua Legada','+5511999990003',NULL),
 ('c5000000-0000-4000-8000-000000000004','handoff-cs','Historico Original','Praça','female','2026-10-07','Culto',
  'c2000000-0000-4000-8000-000000000001',NULL,NULL,'c3000000-0000-4000-8000-000000000003');

INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,phone_e164,address,
 updated_by) VALUES
 ('c6000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001',
  'Ana Antiga','ana antiga','+5511888880001','{"street":"Legado Aluno"}','c1000000-0000-4000-8000-000000000001'),
 ('c6000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000002',
  'Sem Contato','sem contato','+5511888880002','{"street":"Fantasma Aluno"}','c1000000-0000-4000-8000-000000000001'),
 ('c6000000-0000-4000-8000-000000000003','c2000000-0000-4000-8000-000000000001',NULL,
  'Sem Pessoa','sem pessoa','+5511888880003','{"street":"Rua Aluno Legado"}','c1000000-0000-4000-8000-000000000001'),
 ('c6000000-0000-4000-8000-000000000005','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000004',
  'Aluno Nulo','aluno nulo','+5511888880004','{"street":"Fantasma Nulo"}','c1000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,phone_e164,address,
 convert_id,promoted_at,convert_snapshot,updated_by) VALUES
 ('c6000000-0000-4000-8000-000000000004','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000003',
  'Historico Original','historico original',NULL,NULL,'c5000000-0000-4000-8000-000000000004',now(),
  '{"name":"Historico Original","phone":null,"address":null}','c1000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,updated_by)
SELECT ('c7000000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,
 'c2000000-0000-4000-8000-000000000001',('c4000000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,
 'Aluno '||lpad(g::text,3,'0'),'aluno '||lpad(g::text,3,'0'),'c1000000-0000-4000-8000-000000000001'
FROM generate_series(1,101) g;

INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by) VALUES
 ('c8000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001',
  'Classe Historico','classe historico','2026-01-01','c1000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_enrollments(id,congregation_id,student_id,class_id,start_date,updated_by) VALUES
 ('c9000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001',
  'c6000000-0000-4000-8000-000000000004','c8000000-0000-4000-8000-000000000001',
  '2026-01-01','c1000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,updated_by) VALUES
 ('ca000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001',
  'c8000000-0000-4000-8000-000000000001','2026-10-05','c1000000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_session_roster(id,congregation_id,session_id,enrollment_id,student_id,
 student_name,updated_by) VALUES
 ('cb000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001',
  'ca000000-0000-4000-8000-000000000001','c9000000-0000-4000-8000-000000000001',
  'c6000000-0000-4000-8000-000000000004','Historico Original','c1000000-0000-4000-8000-000000000001');

SELECT set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; page2 jsonb; item jsonb; detail jsonb; candidate jsonb;
 cursor_text text; bad_cursor text; saved jsonb; BEGIN
 saved:=public.ieadpe_ministry_save_person('cc000000-0000-4000-8000-000000000001',
  jsonb_build_object('id','c3000000-0000-4000-8000-000000000001',
   'congregation_id','c2000000-0000-4000-8000-000000000001','expected_revision',1,
   'person',jsonb_build_object('name','Beatriz Nova','phone',NULL,'birth_date',NULL,
    'address',jsonb_build_object('street','Rua Dois','district','Centro','city','Olinda',
     'state_code','PE','postal_code','53000-000'))));
 PERFORM pg_temp.assert_true(saved=jsonb_build_object('id','c3000000-0000-4000-8000-000000000001','revision',2),
  'save_person rename accepted');
 saved:=public.ieadpe_ministry_save_person('cc000000-0000-4000-8000-000000000002',
  jsonb_build_object('id','c3000000-0000-4000-8000-000000000003',
   'congregation_id','c2000000-0000-4000-8000-000000000001','expected_revision',1,
   'person',jsonb_build_object('name','Historico Editado','phone',NULL,'birth_date',NULL,'address',NULL)));
 PERFORM pg_temp.assert_true(saved->>'revision'='2','snapshot person rename accepted');

 detail:=public.ieadpe_ministry_get_convert(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001',
  'convert_id','c5000000-0000-4000-8000-000000000001'));
 PERFORM pg_temp.assert_true(detail->'person'->>'name'='Beatriz Nova' AND
  detail->'person'->'phone'='null'::jsonb AND detail->'person'->'address'->>'city'='Olinda' AND
  detail->'legacy_identity'='null'::jsonb,
  'convert detail reads canonical identity with no legacy fallback');
 PERFORM pg_temp.assert_true((SELECT name='Ana Antiga' FROM public.converts
  WHERE id='c5000000-0000-4000-8000-000000000001'),
  'convert detail leaves its stored convert snapshot unchanged');
 detail:=public.ieadpe_ministry_get_student(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001',
  'student_id','c6000000-0000-4000-8000-000000000001'));
 PERFORM pg_temp.assert_true(detail->'student'->>'name'='Beatriz Nova' AND
  detail->'student'->>'normalized_name'='beatriz nova' AND
  detail->'student'->'phone_e164'='null'::jsonb AND
  detail->'student'->'address'->>'street'='Rua Dois' AND detail->'student'->>'link_state'='linked',
  'student detail reads canonical identity without resurrecting student compatibility values');

 page:=public.ieadpe_ministry_list_convert_referrals('{"congregation_id":"c2000000-0000-4000-8000-000000000001","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=3,'referrals exclude converted students');
 item:=page->'items'->0;
 PERFORM pg_temp.assert_true(item->>'convert_id'='c5000000-0000-4000-8000-000000000001' AND
  item->>'name'='Beatriz Nova' AND item->'phone'='null'::jsonb AND
  item->>'address'='Rua Dois, Centro, Olinda, PE, 53000-000',
  'referral uses canonical name, null phone and comma-space text address');
 PERFORM pg_temp.assert_true(item-ARRAY['convert_id','congregation_id','name','phone','address','conversion_date']='{}'::jsonb,
  'referral projection keeps its allowlisted keys');
 item:=page->'items'->1;
 PERFORM pg_temp.assert_true(item->>'name'='Sem Contato' AND item->'phone'='null'::jsonb AND
  item->'address'='null'::jsonb,
  'linked blank canonical address and null phone do not fall back to referral snapshots');
 item:=page->'items'->2;
 PERFORM pg_temp.assert_true(item->>'name'='Legado Antigo' AND item->>'phone'='+5511999990003' AND
  item->>'address'='Rua Legada',
  'unlinked legacy referral keeps its compatibility fallback');

 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Bea","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(candidate->'items')=1,'renamed student found by canonical prefix');
 item:=candidate->'items'->0;
 PERFORM pg_temp.assert_true(item->>'student_id'='c6000000-0000-4000-8000-000000000001' AND
  item->>'name'='Beatriz Nova' AND item->'phone'='null'::jsonb AND
  jsonb_typeof(item->'address')='object' AND
  item->'address'=jsonb_build_object('street','Rua Dois','district','Centro','city','Olinda',
   'state_code','PE','postal_code','53000-000'),
  'candidate returns canonical name, null phone and strict structured address');
 PERFORM pg_temp.assert_true(item-ARRAY['student_id','name','phone','address']='{}'::jsonb,
  'candidate projection keeps its allowlisted keys');
 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Ana","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM jsonb_array_elements(candidate->'items') i
  WHERE i->>'student_id'='c6000000-0000-4000-8000-000000000001'),
  'old linked-student prefix no longer matches after canonical rename');
 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Sem Contato","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(candidate->'items')=1 AND
  candidate->'items'->0->'phone'='null'::jsonb AND
  candidate->'items'->0->'address'=jsonb_build_object('street','   ','district','','city',NULL,
   'state_code',NULL,'postal_code',NULL),
  'linked canonical student values keep their strict null and structured forms');
 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Aluno Nulo","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(candidate->'items')=1 AND
  candidate->'items'->0->'phone'='null'::jsonb AND candidate->'items'->0->'address'='null'::jsonb,
  'linked null canonical student phone and address remain null');
 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Sem Pessoa","limit":100,"cursor":null}'::jsonb);
 item:=candidate->'items'->0;
 PERFORM pg_temp.assert_true(item->>'phone'='+5511888880003' AND
  item->'address'=jsonb_build_object('street','Rua Aluno Legado'),
  'unlinked student keeps its compatibility identity fields');

 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Paginado","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(candidate->'items')=100 AND
  candidate->>'next_cursor' IS NOT NULL AND candidate->'items'->0->>'name'='Paginado 001',
  'candidate limit 100 uses canonical ordering and offers a continuation');
 cursor_text:=candidate->>'next_cursor';
 candidate:=public.ieadpe_ministry_list_convert_student_candidates(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001','name_prefix','Paginado',
  'limit',100,'cursor',cursor_text));
 PERFORM pg_temp.assert_true(jsonb_array_length(candidate->'items')=1 AND
  candidate->'items'->0->>'name'='Paginado 101' AND candidate->'next_cursor'='null'::jsonb,
  '101-row canonical pagination completes exactly once');
 candidate:=public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Paginado","limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(candidate->'items')=1 AND
  candidate->'items'->0->>'name'='Paginado 001' AND candidate->>'next_cursor' IS NOT NULL,
  'candidate limit one is supported');
 BEGIN PERFORM public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Paginado","limit":0,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: candidate limit zero accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","name_prefix":"Paginado","limit":101,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: candidate limit 101 accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 bad_cursor:=left(cursor_text,length(cursor_text)-1)||
  CASE WHEN right(cursor_text,1)='0' THEN '1' ELSE '0' END;
 BEGIN PERFORM public.ieadpe_ministry_list_convert_student_candidates(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001','name_prefix','Paginado',
  'limit',100,'cursor',bad_cursor));
  RAISE EXCEPTION 'ASSERTION: tampered candidate cursor accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000002',true);
 BEGIN PERFORM public.ieadpe_ministry_list_convert_student_candidates(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001','name_prefix','Paginado',
  'limit',100,'cursor',cursor_text));
  RAISE EXCEPTION 'ASSERTION: foreign actor cursor accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000003',true);
 BEGIN PERFORM public.ieadpe_ministry_list_convert_student_candidates(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000002','name_prefix','Paginado',
  'limit',100,'cursor',cursor_text));
  RAISE EXCEPTION 'ASSERTION: foreign scope cursor accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);

 page:=public.ieadpe_ministry_list_convert_referrals(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","limit":1,"cursor":null}'::jsonb);
 page2:=public.ieadpe_ministry_list_convert_referrals(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001','limit',1,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  jsonb_array_length(page2->'items')=1 AND page2->>'next_cursor' IS NOT NULL,
  'referral limit one pages by its signed cursor');
 bad_cursor:=left(page->>'next_cursor',length(page->>'next_cursor')-1)||
  CASE WHEN right(page->>'next_cursor',1)='0' THEN '1' ELSE '0' END;
 BEGIN PERFORM public.ieadpe_ministry_list_convert_referrals(jsonb_build_object(
  'congregation_id','c2000000-0000-4000-8000-000000000001','limit',1,'cursor',bad_cursor));
  RAISE EXCEPTION 'ASSERTION: tampered referral cursor accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_list_convert_referrals(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","limit":101,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: referral limit 101 accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 PERFORM set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000004',true);
 BEGIN PERFORM public.ieadpe_ministry_list_convert_referrals(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: revoked reader listed referrals'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
 BEGIN PERFORM public.ieadpe_ministry_list_convert_student_candidates(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000002","name_prefix":"Paginado","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: foreign scope reader listed candidates'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 PERFORM pg_temp.assert_true(has_function_privilege('authenticated',
  'public.ieadpe_ministry_list_convert_referrals(jsonb)','EXECUTE') AND
  has_function_privilege('authenticated',
  'public.ieadpe_ministry_list_convert_student_candidates(jsonb)','EXECUTE') AND
  NOT has_function_privilege('anon','public.ieadpe_ministry_list_convert_referrals(jsonb)','EXECUTE') AND
  NOT has_function_privilege('anon','public.ieadpe_ministry_list_convert_student_candidates(jsonb)','EXECUTE'),
  'only authenticated clients keep bounded handoff access');
END $$;

RESET ROLE;
SELECT pg_temp.assert_true((SELECT name='Historico Original' AND
 convert_snapshot=jsonb_build_object('name','Historico Original','phone',NULL,'address',NULL)
 FROM public.ministry_students WHERE id='c6000000-0000-4000-8000-000000000004'),
 'stored student snapshot is unchanged after person edits');
SELECT pg_temp.assert_true((SELECT name='Historico Original' FROM public.converts
 WHERE id='c5000000-0000-4000-8000-000000000004'),
 'stored convert snapshot is unchanged after person edits');
SELECT pg_temp.assert_true((SELECT student_name='Historico Original' FROM public.ministry_session_roster
 WHERE id='cb000000-0000-4000-8000-000000000001'),'frozen roster label is unchanged');
SELECT pg_temp.assert_true((SELECT person_id IS NULL FROM public.ministry_students
 WHERE id='c6000000-0000-4000-8000-000000000003'),'no name-based match was created');
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_ministry_list_convert_referrals(
  '{"congregation_id":"c2000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: anonymous reader listed referrals'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
