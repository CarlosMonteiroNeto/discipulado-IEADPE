BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.assert_link_snapshot(convert_uuid uuid,expected_phone text,expected_snapshot jsonb,
 expected_education text,expected_address jsonb) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT FROM public.ministry_students s WHERE s.convert_id=convert_uuid AND
  s.phone_e164 IS NOT DISTINCT FROM expected_phone AND s.convert_snapshot=expected_snapshot AND
  s.education IS NOT DISTINCT FROM expected_education AND s.address IS NOT DISTINCT FROM expected_address AND s.promoted_at IS NOT NULL)
$$;
CREATE FUNCTION pg_temp.assert_link_count(convert_uuid uuid,expected bigint) RETURNS boolean
 LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT count(*)=expected FROM public.ministry_students WHERE convert_id=convert_uuid
$$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('a1000000-0000-0000-0000-000000000001','link-staff@example.test',now()),
 ('a1000000-0000-0000-0000-000000000002','link-other@example.test',now()),
 ('a1000000-0000-0000-0000-000000000003','link-campaign@example.test',now()),
 ('a1000000-0000-0000-0000-000000000004','link-legacy@example.test',now()),
 ('a1000000-0000-0000-0000-000000000005','link-admin@example.test',now());
INSERT INTO private.admin_allowlist(user_id) VALUES('a1000000-0000-0000-0000-000000000005');
INSERT INTO public.congregations(id,name) VALUES
 ('a2000000-0000-0000-0000-000000000001','Link A'),('a2000000-0000-0000-0000-000000000002','Link B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('link-staff@example.test','a1000000-0000-0000-0000-000000000001','Membro da direção da campanha','a2000000-0000-0000-0000-000000000001'),
 ('link-other@example.test','a1000000-0000-0000-0000-000000000002','Membro da direção da campanha','a2000000-0000-0000-0000-000000000002');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','ministry_staff',true),
 ('a1000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002','ministry_staff',true),
 ('a1000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000001','ministry_staff',true);
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('link-campaign@example.test','a1000000-0000-0000-0000-000000000003','Membro da direção da campanha','a2000000-0000-0000-0000-000000000001');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id,
 address,phone,is_discipleship_completed,deleted_at) VALUES
 ('a3000000-0000-0000-0000-000000000001','link-active','Rosa Silva','Praça','female','2026-10-01','Culto','a2000000-0000-0000-0000-000000000001','Rua Um, 10','+5511999999999',false,NULL),
 ('a3000000-0000-0000-0000-000000000002','link-terminal','Rosa Silva','Praça','female','2026-10-02','Culto','a2000000-0000-0000-0000-000000000001',NULL,NULL,true,NULL),
 ('a3000000-0000-0000-0000-000000000003','link-deviated','Davi','Praça','male','2026-10-03','Culto','a2000000-0000-0000-0000-000000000001',NULL,NULL,false,NULL),
 ('a3000000-0000-0000-0000-000000000004','link-deleted','Deleted','Praça','male','2026-10-04','Culto','a2000000-0000-0000-0000-000000000001',NULL,NULL,false,now()),
 ('a3000000-0000-0000-0000-000000000005','link-unassigned','Unassigned','Praça','male','2026-10-05','Culto',NULL,NULL,NULL,false,NULL),
 ('a3000000-0000-0000-0000-000000000006','link-invalid-phone','Bad Phone','Praça','male','2026-10-06','Culto','a2000000-0000-0000-0000-000000000001',NULL,'(11) 99999-9999',false,NULL),
 ('a3000000-0000-0000-0000-000000000007','link-deviated-2','Deviated','Praça','male','2026-10-07','Culto','a2000000-0000-0000-0000-000000000001',NULL,NULL,false,NULL),
 ('a3000000-0000-0000-0000-000000000008','link-other-scope','Other Scope','Praça','female','2026-10-08','Culto','a2000000-0000-0000-0000-000000000002',NULL,NULL,false,NULL);
UPDATE public.converts SET is_deviated=true WHERE id='a3000000-0000-0000-0000-000000000007';
INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,phone_e164,address,education,
 new_convert,updated_by) VALUES
 ('a4000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Rosa Silva','rosa silva','+5511888888888','{"street":"Student address"}','Higher',false,'a1000000-0000-0000-0000-000000000001'),
 ('a4000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002','Other','other',NULL,NULL,NULL,NULL,'a1000000-0000-0000-0000-000000000002'),
 ('a4000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000001','Archived','archived',NULL,NULL,NULL,NULL,'a1000000-0000-0000-0000-000000000001'),
 ('a4000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000001','Rosa Lima','rosa lima',NULL,NULL,NULL,NULL,'a1000000-0000-0000-0000-000000000001');
UPDATE public.ministry_students SET archived_at=now() WHERE id='a4000000-0000-0000-0000-000000000003';

SELECT set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; page2 jsonb; page3 jsonb; result jsonb; BEGIN
 page:=public.ieadpe_ministry_list_convert_referrals('{"congregation_id":"a2000000-0000-0000-0000-000000000001","limit":100,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=5,'referrals include assigned nondeleted converts only');
 PERFORM pg_temp.assert_true((page->'items'->0)-ARRAY['convert_id','congregation_id','name','phone','address','conversion_date']='{}'::jsonb,
  'minimal referral allowlist only');
 PERFORM pg_temp.assert_true(jsonb_typeof(page->'items'->0->'phone')='null' AND jsonb_typeof(page->'items'->0->'address')='null',
  'nullable phone and address remain JSON null');
 BEGIN PERFORM public.ieadpe_ministry_list_convert_referrals('{"congregation_id":"a2000000-0000-0000-0000-000000000002","limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: out-of-scope referral access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 page:=public.ieadpe_ministry_list_convert_referrals('{"congregation_id":"a2000000-0000-0000-0000-000000000001","limit":2,"cursor":null}'::jsonb);
 page2:=public.ieadpe_ministry_list_convert_referrals(jsonb_build_object('congregation_id','a2000000-0000-0000-0000-000000000001','limit',2,'cursor',page->>'next_cursor'));
 page3:=public.ieadpe_ministry_list_convert_referrals(jsonb_build_object('congregation_id','a2000000-0000-0000-0000-000000000001','limit',2,'cursor',page2->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=2 AND jsonb_array_length(page2->'items')=2 AND
  jsonb_array_length(page3->'items')=1 AND page3->'next_cursor'='null'::jsonb,
  'referral cursor pages every eligible row exactly once');
 page:=public.ieadpe_ministry_list_convert_student_candidates('{"congregation_id":"a2000000-0000-0000-0000-000000000001","name_prefix":"Rosa","limit":1,"cursor":null}'::jsonb);
 page2:=public.ieadpe_ministry_list_convert_student_candidates(jsonb_build_object('congregation_id','a2000000-0000-0000-0000-000000000001','name_prefix','Rosa','limit',1,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND page->'items'->0->>'student_id'='a4000000-0000-0000-0000-000000000004' AND
  jsonb_array_length(page2->'items')=1 AND page2->'items'->0->>'student_id'='a4000000-0000-0000-0000-000000000001' AND page2->'next_cursor'='null'::jsonb,
  'candidate cursors bind name prefix and page only scoped unlinked nonarchived students');
 PERFORM pg_temp.assert_true((SELECT count(*)=5 FROM public.converts),
  'campaign direction sees active converts in its own congregation only');
 BEGIN PERFORM count(*) FROM public.ministry_students; RAISE EXCEPTION 'ASSERTION: ministry actor bypassed bounded student read';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.ministry_students SET name=name WHERE id='a4000000-0000-0000-0000-000000000001';
  RAISE EXCEPTION 'ASSERTION: ministry actor directly wrote student/link data'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM count(*) FROM public.ministry_students s JOIN public.converts c ON c.id=s.convert_id;
  RAISE EXCEPTION 'ASSERTION: direct convert/student join was allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 result:=public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000001',
  '{"convert_id":"a3000000-0000-0000-0000-000000000001","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
 PERFORM pg_temp.assert_true(result=jsonb_build_object('convert_id','a3000000-0000-0000-0000-000000000001',
  'student_id',result->>'student_id','congregation_id','a2000000-0000-0000-0000-000000000001','status','linked'),
  'new student promotion returns only safe minimal identifiers');
 PERFORM pg_temp.assert_true(pg_temp.assert_link_snapshot('a3000000-0000-0000-0000-000000000001',
  '+5511999999999','{"name":"Rosa Silva","phone":"+5511999999999","address":"Rua Um, 10"}'::jsonb,NULL,
  '{"street":"Rua Um, 10"}'::jsonb),'promotion creates only initial snapshot and provenance');
 PERFORM pg_temp.assert_true(public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000001',
  '{"convert_id":"a3000000-0000-0000-0000-000000000001","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb)=result,
  'lost-response retry replays the exact result');
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000015',
  '{"convert_id":"a3000000-0000-0000-0000-000000000008","congregation_id":"a2000000-0000-0000-0000-000000000002","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: direction promoted a convert in congregation B'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000001',
  '{"convert_id":"a3000000-0000-0000-0000-000000000002","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: altered payload under same operation accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(pg_temp.assert_link_count('a3000000-0000-0000-0000-000000000001',1),'retry did not duplicate link');
 result:=public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000002',
  '{"convert_id":"a3000000-0000-0000-0000-000000000006","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
 PERFORM pg_temp.assert_true(pg_temp.assert_link_snapshot('a3000000-0000-0000-0000-000000000006',NULL,
  '{"name":"Bad Phone","phone":"(11) 99999-9999","address":null}'::jsonb,NULL,NULL),
  'non-E.164 source phone remains exact in provenance and student phone stays null');
 result:=public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000003',
  '{"convert_id":"a3000000-0000-0000-0000-000000000002","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":"a4000000-0000-0000-0000-000000000001"}'::jsonb);
 PERFORM pg_temp.assert_true(pg_temp.assert_link_snapshot('a3000000-0000-0000-0000-000000000002',
  '+5511888888888','{"name":"Rosa Silva","phone":null,"address":null}'::jsonb,'Higher',
  '{"street":"Student address"}'::jsonb), 'explicit existing-student link preserves all owned fields');
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000004',
  '{"convert_id":"a3000000-0000-0000-0000-000000000003","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":"a4000000-0000-0000-0000-000000000002"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: out-of-scope candidate accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000011',
  '{"convert_id":"a3000000-0000-0000-0000-000000000003","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":"a4000000-0000-0000-0000-000000000003"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived candidate accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000012',
  '{"convert_id":"a3000000-0000-0000-0000-000000000003","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":"a4000000-0000-0000-0000-000000000001"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: already-linked candidate accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 result:=public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000013',
  '{"convert_id":"a3000000-0000-0000-0000-000000000007","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='linked','deviated nondeleted convert remains eligible');
 BEGIN PERFORM public.ieadpe_ministry_list_convert_referrals('{"congregation_id":"a2000000-0000-0000-0000-000000000001","limit":10,"cursor":"bad"}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: malformed cursor accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.assert_true(has_function_privilege('authenticated','public.ieadpe_promote_convert_to_student(uuid,jsonb)','EXECUTE') AND
  NOT has_table_privilege('authenticated','public.ministry_students','INSERT') AND
  NOT has_table_privilege('authenticated','public.ministry_students','UPDATE') AND
  NOT has_function_privilege('anon','public.ieadpe_promote_convert_to_student(uuid,jsonb)','EXECUTE') AND
  NOT EXISTS(SELECT FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
   WHERE p.oid='public.ieadpe_promote_convert_to_student(uuid,jsonb)'::regprocedure AND a.grantee=0 AND a.privilege_type='EXECUTE'),
  'only authenticated clients can invoke promotion');
END $$;

RESET ROLE;
UPDATE public.converts SET deleted_at=now() WHERE id='a3000000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ DECLARE replay jsonb; BEGIN
 replay:=public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000001',
  '{"convert_id":"a3000000-0000-0000-0000-000000000001","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
 PERFORM pg_temp.assert_true(replay->>'status'='linked','receipt replay succeeds after source is archived');
END $$;

SELECT set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000005',
  '{"convert_id":"a3000000-0000-0000-0000-000000000001","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: out-of-scope conversion promoted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000003',true);
RESET ROLE;
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id)
 VALUES('a3000000-0000-0000-0000-000000000009','link-direction-promotion','Direction Promotion','Praça','female','2026-10-09','Culto','a2000000-0000-0000-0000-000000000001');
SET LOCAL ROLE authenticated;
DO $$ DECLARE result jsonb; BEGIN
 result:=public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000006',
  '{"convert_id":"a3000000-0000-0000-0000-000000000009","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
 PERFORM pg_temp.assert_true(result->>'status'='linked',
  'direction assignment also authorizes ministry handoff in its congregation');
END $$;
SELECT set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000004',true);
DO $$ BEGIN
 PERFORM pg_temp.assert_true((SELECT count(*)=0 FROM public.converts),
  'active legacy ministry grant without user_access cannot read campaign rows');
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000007',
  '{"convert_id":"a3000000-0000-0000-0000-000000000001","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: active legacy ministry grant alone promoted convert'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000008',
  '{"convert_id":"a3000000-0000-0000-0000-000000000004","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: soft-deleted convert promoted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000009',
  '{"convert_id":"a3000000-0000-0000-0000-000000000005","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: unassigned convert promoted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_promote_convert_to_student('a5000000-0000-0000-0000-000000000010',
  '{"convert_id":"a3000000-0000-0000-0000-000000000001","congregation_id":"a2000000-0000-0000-0000-000000000001","student_id":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: duplicate convert linked'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.ministry_enrollments e JOIN public.ministry_students s ON s.id=e.student_id
 WHERE s.convert_id IN ('a3000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000002')),
 'promotion does not enroll a student');
DO $$ BEGIN
 UPDATE public.ministry_students SET promoted_at=promoted_at-interval '1 second'
  WHERE convert_id='a3000000-0000-0000-0000-000000000001';
 RAISE EXCEPTION 'ASSERTION: link provenance was mutable';
 EXCEPTION WHEN check_violation THEN NULL; END $$;
DO $$ BEGIN
 INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,convert_id,convert_snapshot)
 VALUES('a4000000-0000-0000-0000-000000000009','a2000000-0000-0000-0000-000000000001','Partial','partial',
  'a3000000-0000-0000-0000-000000000003','{"name":"Partial"}'::jsonb);
 RAISE EXCEPTION 'ASSERTION: partial link metadata accepted';
 EXCEPTION WHEN check_violation THEN NULL; END $$;
ROLLBACK;
