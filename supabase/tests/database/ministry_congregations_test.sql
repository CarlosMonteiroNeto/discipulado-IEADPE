BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %', label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('b1700000-0000-0000-0000-000000000001','ministry-supervisor@example.test',now(),'{}'),
 ('b1700000-0000-0000-0000-000000000002','ministry-staff@example.test',now(),'{}'),
 ('b1700000-0000-0000-0000-000000000003','campaign-only@example.test',now(),'{}');
INSERT INTO public.congregations(id,name) VALUES
 ('b2700000-0000-0000-0000-000000000001','Active One'),
 ('b2700000-0000-0000-0000-000000000002','Active Two'),
 ('b2700000-0000-0000-0000-000000000003','Archived');
UPDATE public.congregations SET archived_at=now()
 WHERE id='b2700000-0000-0000-0000-000000000003';
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('b1700000-0000-0000-0000-000000000001',NULL,'ministry_supervision',true),
 ('b1700000-0000-0000-0000-000000000002','b2700000-0000-0000-0000-000000000001','ministry_staff',true);
SELECT set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; BEGIN
 page:=public.ieadpe_ministry_list_congregations('{"limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1,'directory page is bounded');
 PERFORM pg_temp.assert_true(page->'items'->0 ?& ARRAY['id','name'],'directory returns only congregation id and name');
 PERFORM pg_temp.assert_true(page->>'next_cursor' IS NOT NULL,'full page returns a cursor');
 page:=public.ieadpe_ministry_list_congregations(jsonb_set(
  '{"limit":1}'::jsonb,'{cursor}',page->'next_cursor'));
 PERFORM pg_temp.assert_true(page->'items'->0->>'id'='b2700000-0000-0000-0000-000000000002',
  'supervisor can page active congregations in stable order');
 PERFORM pg_temp.assert_true((public.ieadpe_ministry_list_congregations(
  '{"limit":10,"cursor":null}'::jsonb)->'items')::text NOT LIKE '%Archived%',
  'archived congregations are hidden');
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; BEGIN
 page:=public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  page->'items'->0->>'id'='b2700000-0000-0000-0000-000000000001' AND
  page->'items'->0->>'name'='Active One',
  'staff sees only its own active ministry congregation');
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: caller without ministry grant listed catalog';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT has_function_privilege('anon',
 'public.ieadpe_ministry_list_congregations(jsonb)','EXECUTE'),
 'anonymous callers cannot list the ministry catalog');
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated',
 'public.ministry_grants','SELECT'),'catalog RPC grants no direct ministry table access');
ROLLBACK;
