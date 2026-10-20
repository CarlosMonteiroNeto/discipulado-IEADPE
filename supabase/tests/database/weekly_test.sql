BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
SELECT pg_temp.assert_true(private.report_week('2026-10-18 22:59:59+00') IS NULL,'Sunday 19:59 is hidden instead of exposing previous week');
SELECT pg_temp.assert_true(private.report_week('2026-10-18 23:00:00+00')='2026-10-12','Sunday 20:00 opens current week');
SELECT pg_temp.assert_true(private.report_week('2026-10-19 03:00:00+00')='2026-10-12','Monday uses preceding Sunday');

CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT timestamptz '2026-10-12 12:00:00+00' $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('71000000-0000-0000-0000-000000000001','weekly-manager@example.test',now()),
 ('71000000-0000-0000-0000-000000000002','weekly-direction@example.test',now()),
 ('71000000-0000-0000-0000-000000000003','weekly-registrar@example.test',now());
INSERT INTO private.admin_allowlist VALUES('71000000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES
 ('72000000-0000-0000-0000-000000000001','Sede'),
 ('72000000-0000-0000-0000-000000000002','Água');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('weekly-direction@example.test','71000000-0000-0000-0000-000000000002','Membro da direção da campanha','72000000-0000-0000-0000-000000000001');
SELECT set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=1,'direction overview contains only its congregation');

DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_confirm_zero(gen_random_uuid(),'{"congregation_id":"72000000-0000-0000-0000-000000000002"}');
  RAISE EXCEPTION 'ASSERTION: direction confirmed another scope'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_confirm_zero('73000000-0000-0000-0000-000000000001','{"congregation_id":"72000000-0000-0000-0000-000000000001"}');
SELECT pg_temp.assert_true((public.ieadpe_weekly_overview()->>'global')::boolean
 AND jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=2
 AND (public.ieadpe_weekly_overview()->'rows'->0->>'confirmed')::boolean
 AND NOT (public.ieadpe_weekly_overview()->'rows'->1->>'confirmed')::boolean,'global overview includes confirmed and waiting');
RESET ROLE;
-- Actual command mutation paths update overview, including moving between weeks.
DO $$ DECLARE created jsonb; payload jsonb; edit_payload jsonb; BEGIN
 payload:=jsonb_build_object(
  'congregation_id','72000000-0000-0000-0000-000000000001',
  'person',jsonb_build_object('name','Synthetic weekly','phone',NULL,'birth_date',NULL,'address',NULL),
  'convert',jsonb_build_object('landmark','Square','gender','male','conversion_date','2026-10-05',
   'worship_type','Prayer','age',NULL,'photo_asset_id',NULL));
 created:=public.ieadpe_create_convert(gen_random_uuid(),payload);
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=1,'create removes zero congregation from overview');
 PERFORM pg_temp.assert_true(NOT EXISTS(SELECT FROM public.weekly_reports),'create removes zero receipt report atomically');
 edit_payload:=jsonb_build_object('id',created->>'id',
  'congregation_id','72000000-0000-0000-0000-000000000001',
  'expected_revision',1,'expected_person_revision',1,
  'person',payload->'person',
  'convert',jsonb_set(payload->'convert','{conversion_date}','"2026-09-28"'::jsonb));
 PERFORM public.ieadpe_edit_convert(gen_random_uuid(),edit_payload);
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=2,'date move restores previous week');
 edit_payload:=jsonb_set(edit_payload,'{expected_revision}','2'::jsonb);
 edit_payload:=jsonb_set(edit_payload,'{convert,conversion_date}','"2026-10-05"'::jsonb);
 PERFORM public.ieadpe_edit_convert(gen_random_uuid(),edit_payload);
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=1,'date move forward removes zero congregation again');
 PERFORM public.ieadpe_delete_convert(gen_random_uuid(),jsonb_build_object('id',created->>'id'));
 PERFORM pg_temp.assert_true(jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=2,'delete restores zero congregation');
 PERFORM pg_temp.assert_true((SELECT sum(conversion_count)=0 FROM private.congregation_week_guards),'all affected guards return to zero');
END $$;
-- Privileged clock changes are fixture-only. Public functions accept no instant.
CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT timestamptz '2026-10-18 22:59:59+00' $$;
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT (public.ieadpe_weekly_overview()->>'visible')::boolean
 AND jsonb_array_length(public.ieadpe_weekly_overview()->'rows')=0,'Sunday before 20 hides older overview');
SELECT pg_temp.assert_true(public.ieadpe_confirm_zero('73000000-0000-0000-0000-000000000001','{"congregation_id":"72000000-0000-0000-0000-000000000001"}') ? 'id','valid receipt replay remains available while window closed');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_confirm_zero(gen_random_uuid(),'{"congregation_id":"72000000-0000-0000-0000-000000000001"}');
  RAISE EXCEPTION 'ASSERTION: hidden older window accepted fresh command'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.ieadpe_weekly_overview(NULL,'2026-10-05');
  RAISE EXCEPTION 'ASSERTION: rollover accepted old traversal'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM private.weekly_now(); RAISE EXCEPTION 'ASSERTION: clock exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT timestamptz '2026-10-18 23:00:00+00' $$;
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((public.ieadpe_weekly_overview()->>'visible')::boolean
 AND public.ieadpe_weekly_overview()->>'week_start'='2026-10-12','Sunday 20 opens server overview');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_weekly_overview(); RAISE EXCEPTION 'ASSERTION: registrar enumerated overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- Bound every response, including large global rosters and continuation.
SELECT set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
INSERT INTO public.congregations(id,name) SELECT ('74000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'Synthetic '||i FROM generate_series(1,1203) i;
SET LOCAL ROLE authenticated;
DO $$ DECLARE response jsonb; after_id uuid; n integer:=0; pages integer:=0; item jsonb; previous uuid; BEGIN
 LOOP
  response:=public.ieadpe_weekly_overview(after_id,CASE WHEN pages=0 THEN NULL ELSE date '2026-10-12' END);
  PERFORM pg_temp.assert_true(jsonb_array_length(response->'rows')<=100,'server page is bounded');
  FOR item IN SELECT * FROM jsonb_array_elements(response->'rows') LOOP
   PERFORM pg_temp.assert_true(previous IS NULL OR (item->>'id')::uuid>previous,'ascending unique page traversal');
   previous:=(item->>'id')::uuid; n:=n+1;
  END LOOP;
  pages:=pages+1;
  EXIT WHEN jsonb_array_length(response->'rows')<100;
  after_id:=previous;
 END LOOP;
 PERFORM pg_temp.assert_true(n=1205 AND pages=13,'all 1205 rows are paged exactly once');
END $$;
RESET ROLE;
DELETE FROM private.admin_allowlist;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_confirm_zero('73000000-0000-0000-0000-000000000001','{"congregation_id":"72000000-0000-0000-0000-000000000001"}');
  RAISE EXCEPTION 'ASSERTION: revoked actor replayed receipt'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_weekly_overview(); RAISE EXCEPTION 'ASSERTION: revoked actor read overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_weekly_overview(); RAISE EXCEPTION 'ASSERTION: anonymous overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
