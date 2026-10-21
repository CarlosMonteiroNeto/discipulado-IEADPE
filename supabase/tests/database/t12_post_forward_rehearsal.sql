\ir base44_history_test.sql
BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %', label; END IF; END $$;
DO $$ BEGIN
 BEGIN
  EXECUTE 'CREATE TABLE private.base44_user_access_pending(legacy_base44_id text PRIMARY KEY)';
  RAISE EXCEPTION 'ASSERTION: blind replay of Base44 DDL unexpectedly succeeded';
 EXCEPTION WHEN duplicate_table THEN NULL; END;
 BEGIN
  EXECUTE 'ALTER TABLE public.converts ADD COLUMN legacy_base44_id text';
  RAISE EXCEPTION 'ASSERTION: blind replay of Base44 ALTER unexpectedly succeeded';
 EXCEPTION WHEN duplicate_column THEN NULL; END;
 BEGIN
  EXECUTE 'CREATE POLICY events_scope ON public.convert_events FOR SELECT USING(true)';
  RAISE EXCEPTION 'ASSERTION: blind replay of Base44 policy DDL unexpectedly succeeded';
 EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;
SELECT pg_temp.assert_true(to_regclass('private.base44_user_access_pending') IS NOT NULL
 AND to_regclass('private.base44_source_metadata') IS NOT NULL
 AND to_regclass('private.base44_migration_imports') IS NOT NULL
 AND to_regclass('private.base44_feedback_archive') IS NOT NULL,
 'Base44 tables exist before any ledger repair proposal');
SELECT pg_temp.assert_true(EXISTS(SELECT FROM pg_constraint WHERE conname='convert_events_legacy_target_check')
 AND (SELECT count(*)=4 FROM pg_indexes WHERE schemaname='public' AND indexname IN
 ('congregations_legacy_base44_id_key','converts_legacy_base44_id_key',
  'convert_events_legacy_base44_id_key','weekly_reports_legacy_base44_id_key')),
 'Base44 orphan constraint and all four source-key unique indexes are present');
SELECT pg_temp.assert_true((SELECT count(*)=4 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relname IN ('base44_user_access_pending','base44_source_metadata',
 'base44_migration_imports','base44_feedback_archive') AND c.relrowsecurity),
 'all Base44 private snapshot tables retain row-level security');
SELECT pg_temp.assert_true((SELECT count(*)=4 FROM information_schema.columns WHERE table_schema='public'
 AND (table_name,column_name) IN (('congregations','legacy_base44_id'),('converts','legacy_base44_id'),
 ('convert_events','legacy_base44_id'),('weekly_reports','legacy_base44_id'))), 'legacy source identity columns present');
SELECT pg_temp.assert_true(EXISTS(SELECT FROM pg_indexes WHERE schemaname='public' AND indexname='converts_scope_date')
 AND EXISTS(SELECT FROM pg_policies WHERE schemaname='public' AND tablename='convert_events' AND policyname='events_scope'),
 'representative index and row policy present');
SELECT pg_temp.assert_true(NOT has_table_privilege('anon','private.base44_user_access_pending','SELECT')
 AND NOT has_table_privilege('authenticated','private.base44_user_access_pending','SELECT')
 AND NOT has_table_privilege('service_role','private.base44_user_access_pending','SELECT'),
 'private pending records unavailable to API roles');
SELECT pg_temp.assert_true(to_regprocedure('private.base44_stable_uuid(text,text)') IS NOT NULL
 AND NOT has_function_privilege('authenticated','private.base44_stable_uuid(text,text)','EXECUTE'),
 'stable identity helper exists with least-privilege grants');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.converts WHERE id IN
 ('12000000-0000-0000-0000-000000000011','12000000-0000-0000-0000-000000000012')),
 'stable convert IDs and baseline counts survive forward migrations');
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.weekly_reports WHERE id='12000000-0000-0000-0000-000000000021'
 AND confirmed_by_name='Synthetic Operator'), 'manual weekly confirmation is preserved');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM private.base44_user_access_pending
 WHERE legacy_base44_id='t12-pending-1' AND import_digest=repeat('a',64)),
 'synthetic access snapshot and import digest are preserved');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM private.congregation_week_guards g JOIN
 (SELECT congregation_id,date_trunc('week',conversion_date)::date AS week_start,count(*)::int AS actual
  FROM public.converts WHERE deleted_at IS NULL GROUP BY congregation_id,date_trunc('week',conversion_date)::date) a
 USING(congregation_id,week_start) WHERE g.conversion_count=a.actual), 'synthetic weekly guards reconcile after 180002');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM private.congregation_week_guards g
 WHERE g.conversion_count IS DISTINCT FROM (SELECT count(*)::int FROM public.converts c WHERE c.congregation_id=g.congregation_id
 AND c.conversion_date BETWEEN g.week_start AND g.week_start+6 AND c.deleted_at IS NULL)), 'no stale weekly guards remain');
WITH expected(name, args) AS (VALUES
 ('ieadpe_get_scope',''),
 ('ieadpe_ministry_list_congregations','jsonb'),('ieadpe_ministry_list_directory','jsonb'),
 ('ieadpe_ministry_list_class_students','jsonb'),('ieadpe_ministry_get_session_attendance','jsonb'),
 ('ieadpe_ministry_get_enrollment_progress','jsonb'),('ieadpe_ministry_get_overview','jsonb'),
 ('ieadpe_ministry_list_pending_sessions','jsonb'),('ieadpe_ministry_list_convert_referrals','jsonb'),
 ('ieadpe_ministry_list_convert_student_candidates','jsonb'),('ieadpe_ministry_list_students','jsonb'),
 ('ieadpe_ministry_list_classes','jsonb'),
 ('ieadpe_ministry_save_contact','uuid, jsonb'),('ieadpe_ministry_replace_role_holder','uuid, jsonb'),
 ('ieadpe_ministry_set_contact_archived','uuid, jsonb'),('ieadpe_ministry_save_student','uuid, jsonb'),
 ('ieadpe_ministry_set_student_archived','uuid, jsonb'),('ieadpe_ministry_save_class','uuid, jsonb'),
 ('ieadpe_ministry_set_class_status','uuid, jsonb'),('ieadpe_ministry_enroll_student','uuid, jsonb'),
 ('ieadpe_ministry_close_enrollment','uuid, jsonb'),('ieadpe_ministry_create_session','uuid, jsonb'),
 ('ieadpe_ministry_cancel_session','uuid, jsonb'),('ieadpe_ministry_save_attendance','uuid, jsonb'),
 ('ieadpe_promote_convert_to_student','uuid, jsonb')
)
SELECT pg_temp.assert_true((SELECT count(*)=25 FROM expected e JOIN pg_proc p ON p.proname=e.name
 JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
 WHERE oidvectortypes(p.proargtypes)=e.args AND pg_get_function_result(p.oid)='jsonb'
 AND has_function_privilege('authenticated',p.oid,'EXECUTE')),
 'all 25 current RPC names, ordered argument types, jsonb envelopes and authenticated execute grants are present');
SELECT pg_temp.assert_true(EXISTS(SELECT FROM supabase_migrations.schema_migrations WHERE version='202610140018')
 AND NOT EXISTS(SELECT FROM supabase_migrations.schema_migrations WHERE version IN ('202610180001','202610180002')),
 'ledger repair remains a proposal after independent synthetic equivalence checks');
ROLLBACK;
\ir attendance_roster_preview_test.sql
