BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %', label; END IF; END $$;
SELECT pg_temp.assert_true((SELECT count(*)=18 FROM supabase_migrations.schema_migrations WHERE version LIKE '20261014%')
 AND EXISTS(SELECT FROM supabase_migrations.schema_migrations WHERE version='202610140018')
 AND NOT EXISTS(SELECT FROM supabase_migrations.schema_migrations WHERE version IN ('202610180001','202610180002')),
 'ledger remains at 018 while both 180001/180002 are unrecorded');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.converts WHERE id IN
 ('12000000-0000-0000-0000-000000000011','12000000-0000-0000-0000-000000000012'))
 AND (SELECT count(*)=1 FROM public.weekly_reports WHERE id='12000000-0000-0000-0000-000000000021'
 AND confirmed_by_name='Synthetic Operator'), 'stable convert IDs and manual weekly state survive 180002');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM private.base44_user_access_pending
 WHERE legacy_base44_id='t12-pending-1' AND import_digest=repeat('a',64))
 AND (SELECT count(*)=1 FROM private.base44_source_metadata WHERE legacy_base44_id='t12-stable-1')
 AND (SELECT count(*)=1 FROM private.base44_migration_imports WHERE source='base44' AND export_digest=repeat('a',64)),
 'private Base44 snapshot/source/import receipt are preserved');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM private.congregation_week_guards g
 WHERE g.conversion_count IS DISTINCT FROM (SELECT count(*)::int FROM public.converts c WHERE c.congregation_id=g.congregation_id
 AND c.conversion_date BETWEEN g.week_start AND g.week_start+6 AND c.deleted_at IS NULL)),
 'guard counts are reconciled by 180002');
SELECT pg_temp.assert_true(to_regclass('private.base44_user_access_pending') IS NOT NULL
 AND (SELECT relrowsecurity FROM pg_class WHERE oid='private.base44_user_access_pending'::regclass)
 AND NOT has_table_privilege('anon','private.base44_user_access_pending','SELECT')
 AND NOT has_table_privilege('authenticated','private.base44_user_access_pending','SELECT'),
 'private snapshot remains RLS protected and unavailable to API roles');
SELECT pg_temp.assert_true(EXISTS(SELECT FROM pg_indexes WHERE schemaname='public' AND indexname='converts_scope_date')
 AND EXISTS(SELECT FROM pg_policies WHERE schemaname='public' AND tablename='convert_events' AND policyname='events_scope')
 AND EXISTS(SELECT FROM pg_constraint WHERE conname='convert_events_legacy_target_check'),
 'Base44 index, policy and orphan constraint exist at the baseline');
ROLLBACK;
