-- Synthetic hosted-shaped baseline staged after 202610180001 and before 180002.
CREATE SCHEMA IF NOT EXISTS supabase_migrations;
CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (version text PRIMARY KEY, statements text[]);
INSERT INTO supabase_migrations.schema_migrations(version, statements)
SELECT '20261014' || lpad(n::text, 4, '0'), ARRAY[]::text[] FROM generate_series(1, 18) AS n
ON CONFLICT (version) DO NOTHING;
INSERT INTO public.congregations(id, name) VALUES
 ('12000000-0000-0000-0000-000000000001', 'Synthetic Base44 North'),
 ('12000000-0000-0000-0000-000000000002', 'Synthetic Base44 South');
INSERT INTO public.converts(id, internal_id, name, landmark, gender, conversion_date, worship_type, congregation_id) VALUES
 ('12000000-0000-0000-0000-000000000011', 't12-stable-1', 'Synthetic Convert One', 'North Square', 'female', DATE '2026-10-12', 'Oração', '12000000-0000-0000-0000-000000000001'),
 ('12000000-0000-0000-0000-000000000012', 't12-stable-2', 'Synthetic Convert Two', 'South Square', 'male', DATE '2026-10-13', 'Culto', '12000000-0000-0000-0000-000000000002');
INSERT INTO public.weekly_reports(id, congregation_id, week_start, confirmed_by_email, confirmed_by_name) VALUES
 ('12000000-0000-0000-0000-000000000021', '12000000-0000-0000-0000-000000000001', DATE '2026-10-12', 'synthetic@example.test', 'Synthetic Operator');
INSERT INTO private.congregation_week_guards(congregation_id, week_start, conversion_count) VALUES
 ('12000000-0000-0000-0000-000000000001', DATE '2026-10-12', 99);
INSERT INTO private.base44_user_access_pending(
 legacy_base44_id,user_email,role,congregation_id,legacy_congregation_id,created_at,updated_at,import_digest
) VALUES ('t12-pending-1','synthetic@example.test','Membro da direção da campanha',
 '12000000-0000-0000-0000-000000000001','legacy-congregation-1',now(),now(),repeat('a',64));
INSERT INTO private.base44_source_metadata(entity_name,legacy_base44_id,created_by_id,created_by,is_sample,
 source_created_date,source_updated_date,import_digest) VALUES
 ('Convert','t12-stable-1','synthetic-user','Synthetic',false,'2026-10-12','2026-10-12',repeat('a',64));
INSERT INTO private.base44_migration_imports(source,export_digest,record_counts) VALUES
 ('base44',repeat('a',64),'{"converts":2,"congregations":2}'::jsonb);
DO $$ BEGIN
 IF (SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version LIKE '20261014%') <> 18 THEN
  RAISE EXCEPTION 'ASSERTION: synthetic baseline ledger does not end at 202610140018'; END IF;
 IF EXISTS (SELECT FROM supabase_migrations.schema_migrations WHERE version IN ('202610180001','202610180002')) THEN
  RAISE EXCEPTION 'ASSERTION: Base44 migrations unexpectedly recorded'; END IF;
 IF (SELECT conversion_count FROM private.congregation_week_guards WHERE congregation_id='12000000-0000-0000-0000-000000000001' AND week_start=DATE '2026-10-12') <> 99 THEN
  RAISE EXCEPTION 'ASSERTION: stale synthetic guard seed was not created'; END IF;
END $$;
