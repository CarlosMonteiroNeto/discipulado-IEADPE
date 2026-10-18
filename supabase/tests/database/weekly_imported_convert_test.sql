BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
CREATE OR REPLACE FUNCTION private.weekly_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT timestamptz '2026-10-12 12:00:00+00' $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('78000000-0000-0000-0000-000000000001','weekly-import@example.test',now());
INSERT INTO private.admin_allowlist(user_id) VALUES('78000000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES
 ('78000000-0000-0000-0000-000000000002','Weekly import fixture');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id)
 VALUES('78000000-0000-0000-0000-000000000003','weekly-import-convert','Synthetic convert','Square',
  'female','2026-10-05','Oração','78000000-0000-0000-0000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','78000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true(NOT EXISTS(
 SELECT FROM jsonb_array_elements(public.ieadpe_weekly_overview()->'rows') item
 WHERE item->>'id'='78000000-0000-0000-0000-000000000002'),
 'weekly overview excludes a converted congregation when its guard row is missing');
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(
 SELECT FROM private.congregation_week_guards
 WHERE congregation_id='78000000-0000-0000-0000-000000000002' AND week_start='2026-10-05'),
 'fixture reproduces an imported conversion without a weekly guard');
ROLLBACK;
