BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('a1700000-0000-0000-0000-000000000001','admin-only@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000002','supervision-only@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000003','direction-a@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000004','directions-ab@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000005','grant-only@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000006','audit-only@example.test',now(),'{"role":"admin","email_verified":true}'),
 ('a1700000-0000-0000-0000-000000000007','binding@example.test',NULL,'{"role":"admin","email_verified":true}'),
 ('a1700000-0000-0000-0000-000000000008','archived-direction@example.test',now(),'{}'),
 ('a1700000-0000-0000-0000-000000000009','mixed-global@example.test',now(),'{}');
INSERT INTO private.admin_allowlist(user_id) VALUES('a1700000-0000-0000-0000-000000000001');
INSERT INTO public.congregations(id,name) VALUES
 ('a2700000-0000-0000-0000-000000000001','Unified A'),
 ('a2700000-0000-0000-0000-000000000002','Unified B'),
 ('a2700000-0000-0000-0000-000000000003','Unified Archived');
UPDATE public.congregations SET archived_at=now() WHERE id='a2700000-0000-0000-0000-000000000003';

INSERT INTO public.user_access(id,user_email,user_id,role,congregation_id) VALUES
 ('a3700000-0000-0000-0000-000000000001','supervision-only@example.test','a1700000-0000-0000-0000-000000000002',
  'Membro da supervisão das campanhas',NULL),
 ('a3700000-0000-0000-0000-000000000002','direction-a@example.test','a1700000-0000-0000-0000-000000000003',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000001'),
 ('a3700000-0000-0000-0000-000000000003','directions-ab@example.test','a1700000-0000-0000-0000-000000000004',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000002'),
 ('a3700000-0000-0000-0000-000000000004','directions-ab@example.test','a1700000-0000-0000-0000-000000000004',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000001'),
 ('a3700000-0000-0000-0000-000000000005','binding@example.test',NULL,
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000001'),
 ('a3700000-0000-0000-0000-000000000006','archived-direction@example.test','a1700000-0000-0000-0000-000000000008',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000001'),
 ('a3700000-0000-0000-0000-000000000007','mixed-global@example.test','a1700000-0000-0000-0000-000000000009',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000002'),
 ('a3700000-0000-0000-0000-000000000008','mixed-global@example.test','a1700000-0000-0000-0000-000000000009',
  'Membro da direção da campanha','a2700000-0000-0000-0000-000000000001'),
 ('a3700000-0000-0000-0000-000000000009','mixed-global@example.test','a1700000-0000-0000-0000-000000000009',
  'Membro da supervisão das campanhas',NULL);
INSERT INTO private.base44_user_access_pending(
 legacy_base44_id,user_email,role,congregation_id,legacy_congregation_id,created_at,updated_at,import_digest
) VALUES(
 'audit-only-1','audit-only@example.test','Membro da direção da campanha','a2700000-0000-0000-0000-000000000001',
 'legacy-a',now(),now(),'local-test-digest'
);
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('a1700000-0000-0000-0000-000000000003','a2700000-0000-0000-0000-000000000002','ministry_staff',true),
 ('a1700000-0000-0000-0000-000000000005','a2700000-0000-0000-0000-000000000001','ministry_staff',true),
 ('a1700000-0000-0000-0000-000000000005',NULL,'ministry_supervision',true);
INSERT INTO public.ministry_contacts(id,congregation_id,updated_by,name,normalized_name,scope,role_code) VALUES
 ('a4700000-0000-0000-0000-000000000001','a2700000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000003',
  'Anna','anna','congregation','teacher'),
 ('a4700000-0000-0000-0000-000000000002','a2700000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000003',
  'Bea','bea','congregation','teacher');

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(private.ministry_supervisor(),'allowlist-only global ministry authority');
SELECT pg_temp.assert_true(private.ministry_can_access(NULL)=false,'null scope denied');
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(jsonb_typeof(scope->'is_admin')='boolean' AND
  jsonb_typeof(scope->'is_supervision')='boolean' AND jsonb_typeof(scope->'congregation_ids')='array' AND
  jsonb_typeof(scope->'ministry_supervision')='boolean' AND
  jsonb_typeof(scope->'ministry_congregation_ids')='array','all five scope fields retain their JSON types');
 PERFORM pg_temp.assert_true(scope->'is_admin'='true'::jsonb AND scope->'is_supervision'='false'::jsonb AND
  scope->'congregation_ids'='[]'::jsonb AND scope->'ministry_supervision'='true'::jsonb AND
  scope->'ministry_congregation_ids'='[]'::jsonb,'allowlist-only scope keeps exact global flags and empty arrays');
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'is_admin'='false'::jsonb AND scope->'is_supervision'='true'::jsonb AND
  scope->'congregation_ids'='[]'::jsonb AND scope->'ministry_supervision'='true'::jsonb AND
  scope->'ministry_congregation_ids'='[]'::jsonb,'supervision-only scope is global without scoped ministry IDs');
 PERFORM pg_temp.assert_true(private.ministry_supervisor() AND private.ministry_can_access('a2700000-0000-0000-0000-000000000002'),
  'Base44 supervision grants global ministry helper access');
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(NOT private.ministry_supervisor() AND private.ministry_can_access('a2700000-0000-0000-0000-000000000001') AND
  NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002'),'direction A grants only its assigned ministry congregation');
 PERFORM pg_temp.assert_true(scope->'is_admin'='false'::jsonb AND scope->'is_supervision'='false'::jsonb AND
  scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb AND
  scope->'ministry_supervision'='false'::jsonb AND
  scope->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
  'direction A scope contains only sorted active Base44 direction assignments');
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000004',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000001","a2700000-0000-0000-0000-000000000002"]'::jsonb AND
  scope->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001","a2700000-0000-0000-0000-000000000002"]'::jsonb,
  'multiple direction assignments produce exact sorted union');
 PERFORM pg_temp.assert_true(NOT (scope->>'ministry_supervision')::boolean,'direction union does not become global');
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000009',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'is_admin'='false'::jsonb AND scope->'is_supervision'='true'::jsonb AND
  scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000001","a2700000-0000-0000-0000-000000000002"]'::jsonb AND
  scope->'ministry_supervision'='true'::jsonb AND
  scope->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001","a2700000-0000-0000-0000-000000000002"]'::jsonb,
  'mixed global and direction roles preserve flags and assigned IDs');
 PERFORM pg_temp.assert_true(private.ministry_supervisor() AND private.ministry_can_access('a2700000-0000-0000-0000-000000000003'),
  'global role takes precedence and retains historical archived access');
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000005',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(NOT private.ministry_supervisor() AND NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000001'),
  'stale active staff and supervision grants grant no effective access');
 PERFORM pg_temp.assert_true(scope->'ministry_supervision'='false'::jsonb AND
  scope->'ministry_congregation_ids'='[]'::jsonb,'grant-only scope remains empty');
 BEGIN PERFORM public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: grant-only actor listed ministry congregations';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000006',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(NOT private.ministry_supervisor() AND NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000001') AND
  scope->'is_supervision'='false'::jsonb AND scope->'congregation_ids'='[]'::jsonb AND
  scope->'ministry_congregation_ids'='[]'::jsonb,'pending audit row alone grants and binds nothing');
 BEGIN PERFORM public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: pending audit-only actor listed ministry congregations';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.user_access WHERE user_email='audit-only@example.test'),
 'pending audit row did not create an active user_access assignment');

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000007',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.ieadpe_get_scope()->'congregation_ids'='[]'::jsonb AND
 public.ieadpe_get_scope()->'ministry_congregation_ids'='[]'::jsonb,
 'unconfirmed email and forged metadata do not bind an assignment');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT user_id IS NULL FROM public.user_access WHERE id='a3700000-0000-0000-0000-000000000005'),
 'unconfirmed assignment remains unbound');
CREATE TEMP TABLE base44_unified_access_version AS
 SELECT version AS before_version FROM private.access_versions WHERE user_id='a1700000-0000-0000-0000-000000000007';
UPDATE auth.users SET email_confirmed_at=now() WHERE id='a1700000-0000-0000-0000-000000000007';
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb AND
  private.ministry_can_access('a2700000-0000-0000-0000-000000000001'),
  'confirmed normalized email binds through get_scope');
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT a.version=v.before_version+1 FROM private.access_versions a CROSS JOIN base44_unified_access_version v
 WHERE a.user_id='a1700000-0000-0000-0000-000000000007'),'binding increments access version exactly once');
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_get_scope();
RESET ROLE;
SELECT pg_temp.assert_true((SELECT a.version=v.before_version+1 FROM private.access_versions a CROSS JOIN base44_unified_access_version v
 WHERE a.user_id='a1700000-0000-0000-0000-000000000007'),'repeated scope load does not increment access version');
SELECT pg_temp.assert_true((SELECT user_id='a1700000-0000-0000-0000-000000000007' FROM public.user_access WHERE id='a3700000-0000-0000-0000-000000000005'),
 'confirmed identity is bound to its active assignment');

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; next_page jsonb; BEGIN
 page:=public.ieadpe_ministry_list_congregations('{"limit":1,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  page->'items'->0->>'id'='a2700000-0000-0000-0000-000000000001' AND
  page->>'next_cursor'='a2700000-0000-0000-0000-000000000001',
  'global directory page is bounded and returns a stable cursor');
 next_page:=public.ieadpe_ministry_list_congregations(jsonb_build_object('limit',1,'cursor',page->>'next_cursor'));
 PERFORM pg_temp.assert_true(jsonb_array_length(next_page->'items')=1 AND
  next_page->'items'->0->>'id'='a2700000-0000-0000-0000-000000000002' AND
  next_page->>'next_cursor' IS NULL,'global directory cursor advances across active congregations');
 BEGIN PERFORM public.ieadpe_ministry_list_congregations('{"limit":101,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: oversized directory page accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; BEGIN
 page:=public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  page->'items'->0->>'id'='a2700000-0000-0000-0000-000000000001' AND page->>'next_cursor' IS NULL,
  'direction directory lists only its own active congregation');
 PERFORM pg_temp.assert_true(NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002') AND
  public.ieadpe_get_scope()->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
  'stale active ministry grant toggle cannot add congregation B');
END $$;
RESET ROLE;
UPDATE public.ministry_grants SET active=false WHERE user_id='a1700000-0000-0000-0000-000000000003'
 AND congregation_id='a2700000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002') AND
 public.ieadpe_get_scope()->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
 'deactivating a grant does not change Base44 ministry scope');
RESET ROLE;
UPDATE public.ministry_grants SET active=true WHERE user_id='a1700000-0000-0000-0000-000000000003'
 AND congregation_id='a2700000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002') AND
 public.ieadpe_get_scope()->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
 'reactivating a grant does not change Base44 ministry scope');
RESET ROLE;
DELETE FROM public.ministry_grants WHERE user_id='a1700000-0000-0000-0000-000000000003'
 AND congregation_id='a2700000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000002') AND
 public.ieadpe_get_scope()->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
 'deleting a grant does not change Base44 ministry scope');
RESET ROLE;

DO $$ DECLARE page jsonb; old_cursor text; scope jsonb; BEGIN
 PERFORM set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000003',true);
 page:=public.ieadpe_ministry_list_directory(jsonb_build_object('scope','congregation',
  'congregation_id','a2700000-0000-0000-0000-000000000001','limit',1,'cursor',NULL));
 old_cursor:=page->>'next_cursor';
 PERFORM pg_temp.assert_true(old_cursor IS NOT NULL,'direction A receives a scoped cursor before reassignment');
 PERFORM set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000001',true);
 PERFORM public.ieadpe_save_access('a5700000-0000-0000-0000-000000000001',
  '{"id":"a3700000-0000-0000-0000-000000000002","user_email":"direction-a@example.test","role":"Membro da direção da campanha","congregation_id":"a2700000-0000-0000-0000-000000000002"}'::jsonb);
 PERFORM set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000003',true);
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000002"]'::jsonb AND
  scope->'ministry_congregation_ids'='["a2700000-0000-0000-0000-000000000002"]'::jsonb AND
  NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000001') AND
  private.ministry_can_access('a2700000-0000-0000-0000-000000000002'),
  'reassignment refreshes exact scope from A to B');
 BEGIN
  PERFORM public.ieadpe_ministry_list_directory(jsonb_build_object('scope','congregation',
   'congregation_id','a2700000-0000-0000-0000-000000000001','limit',1,'cursor',old_cursor));
  RAISE EXCEPTION 'ASSERTION: stale A cursor returned records after reassignment';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_ministry_list_directory(jsonb_build_object('scope','congregation',
   'congregation_id','a2700000-0000-0000-0000-000000000001','limit',10,'cursor',NULL));
  RAISE EXCEPTION 'ASSERTION: stale A scope returned records after reassignment';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 page:=public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  page->'items'->0->>'id'='a2700000-0000-0000-0000-000000000002',
  'reassigned direction sees only B in the congregation picker');
END $$;
RESET ROLE;

UPDATE public.congregations SET archived_at=now() WHERE id='a2700000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000008',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE scope jsonb; BEGIN
 scope:=public.ieadpe_get_scope();
 PERFORM pg_temp.assert_true(scope->'congregation_ids'='["a2700000-0000-0000-0000-000000000001"]'::jsonb,
  'archived direction assignment remains in campaign scope');
 PERFORM pg_temp.assert_true(scope->'ministry_congregation_ids'='[]'::jsonb AND
  scope->'ministry_supervision'='false'::jsonb AND
  NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000001'),
  'archived direction assignment is excluded from ministry scope');
 BEGIN PERFORM public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived-only direction listed the active catalog';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ieadpe_ministry_save_contact('a6700000-0000-0000-0000-000000000001',
  '{"id":"a6700000-0000-0000-0000-000000000001","scope":"congregation","congregation_id":"a2700000-0000-0000-0000-000000000001","name":"Archived Write","role_code":"teacher","phone_e164":null,"birth_date":null,"email":null}'::jsonb);
  RAISE EXCEPTION 'ASSERTION: archived-only direction wrote to the archived congregation';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.ministry_contacts
 WHERE id='a6700000-0000-0000-0000-000000000001'),
 'denied archived-congregation write created no contact');
SELECT set_config('request.jwt.claim.sub','a1700000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE page jsonb; BEGIN
 PERFORM pg_temp.assert_true(private.ministry_supervisor() AND
  private.ministry_can_access('a2700000-0000-0000-0000-000000000001'),
  'global authority retains helper access to archived A');
 page:=public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb);
 PERFORM pg_temp.assert_true(jsonb_array_length(page->'items')=1 AND
  page->'items'->0->>'id'='a2700000-0000-0000-0000-000000000002',
  'global picker excludes archived A');
END $$;
RESET ROLE;
UPDATE public.congregations SET archived_at=now() WHERE id='a2700000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.ieadpe_ministry_list_congregations('{"limit":10,"cursor":null}'::jsonb)->'items'='[]'::jsonb,
 'global picker returns an empty page for an empty active catalog');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT private.ministry_supervisor() AND
 NOT private.ministry_can_access('a2700000-0000-0000-0000-000000000001') AND
 NOT private.ministry_can_access(NULL),'anonymous identity is denied by ministry helpers');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_get_scope(); RAISE EXCEPTION 'ASSERTION: anonymous identity loaded scope';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','private.ministry_supervisor()','EXECUTE') AND
 NOT has_function_privilege('anon','private.ministry_can_access(uuid)','EXECUTE') AND
 NOT has_function_privilege('anon','public.ieadpe_get_scope()','EXECUTE'),
 'anonymous callers cannot execute ministry helpers or load scope');
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_get_scope(); RAISE EXCEPTION 'ASSERTION: anonymous role executed scope';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
