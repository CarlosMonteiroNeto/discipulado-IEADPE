BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %', label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('a1700000-0000-0000-0000-000000000001','both@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000002','ministry-supervisor@example.test',now(),'{}');
INSERT INTO public.congregations(id,name) VALUES
 ('a2700000-0000-0000-0000-000000000001','Unified One'),
 ('a2700000-0000-0000-0000-000000000002','Unified Two'),
 ('a2700000-0000-0000-0000-000000000003','Archived Ministry');
UPDATE public.congregations SET archived_at=now()
 WHERE id='a2700000-0000-0000-0000-000000000003';
INSERT INTO public.user_access(id,user_email,user_id,role,congregation_id) VALUES
 ('a3700000-0000-0000-0000-000000000001','both@example.test','a1700000-0000-0000-0000-000000000001',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000001'),
 ('a3700000-0000-0000-0000-000000000002','ministry-supervisor@example.test','a1700000-0000-0000-0000-000000000002',
  'Membro da supervisão das campanhas',NULL);
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('a1700000-0000-0000-0000-000000000001','a2700000-0000-0000-0000-000000000002','ministry_staff',true),
 ('a1700000-0000-0000-0000-000000000001','a2700000-0000-0000-0000-000000000003','ministry_staff',true),
 ('a1700000-0000-0000-0000-000000000001','a2700000-0000-0000-0000-000000000001','ministry_staff',false),
 ('a1700000-0000-0000-0000-000000000002',NULL,'ministry_supervision',true);
SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->>'is_admin'='false' AND scope->>'is_supervision'='false',
  'ministry roles do not become campaign-wide roles');
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
  'campaign direction remains independently scoped');
 PERFORM pg_temp.assert_true(scope->>'ministry_supervision'='false' AND
  scope->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb AND
  private.ministry_can_access('a2700000-0000-0000-0000-000000000001') AND
  NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002'),
  'Base44 direction is effective and stale ministry grants do not add another scope');
END $$;
RESET ROLE;
DELETE FROM public.user_access WHERE user_id='a1700000-0000-0000-0000-000000000001'
 AND role='Membro da direção da campanha' AND congregation_id='a2700000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'ministry_congregation_ids'='[]'::jsonb AND
  NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000001') AND
  NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002'),
  'revoking the active Base44 assignment removes ministry scope despite stale grants');
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='[]'::jsonb,
  'revoking the shared assignment removes its campaign scope');
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((public.ieadpe_get_scope()->>'ministry_supervision')::boolean AND
 public.ieadpe_get_scope()->'ministry_congregation_ids'='[]'::jsonb AND
 private.ministry_supervisor() AND private.ministry_can_access('a2700000-0000-0000-0000-000000000001'),
 'Base44 supervision grants global ministry access without a scoped assignment');
RESET ROLE;
ROLLBACK;
