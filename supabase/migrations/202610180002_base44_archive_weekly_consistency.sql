-- Preserve every exported Feedback object without assuming an unmapped source schema.
CREATE TABLE private.base44_feedback_archive (
 legacy_base44_id text PRIMARY KEY CHECK(legacy_base44_id<>''),
 source_record jsonb NOT NULL CHECK(jsonb_typeof(source_record)='object'),
 import_digest text NOT NULL,
 archived_at timestamptz NOT NULL DEFAULT now(),
 CHECK(source_record->>'id'=legacy_base44_id)
);
ALTER TABLE private.base44_feedback_archive ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.base44_feedback_archive FROM PUBLIC,anon,authenticated,service_role;

-- Reconcile counters from the canonical convert rows, including the newly imported
-- weeks and existing guard rows that may have been stale or initialized as zero.
WITH affected_weeks AS (
 SELECT congregation_id,week_start FROM private.congregation_week_guards
 UNION
 SELECT congregation_id,date_trunc('week',conversion_date)::date
 FROM public.converts
 WHERE deleted_at IS NULL AND congregation_id IS NOT NULL
), actual_counts AS (
 SELECT w.congregation_id,w.week_start,count(c.id)::integer AS conversion_count
 FROM affected_weeks w
 LEFT JOIN public.converts c ON c.congregation_id=w.congregation_id
  AND c.conversion_date BETWEEN w.week_start AND w.week_start+6 AND c.deleted_at IS NULL
 GROUP BY w.congregation_id,w.week_start
)
INSERT INTO private.congregation_week_guards(congregation_id,week_start,conversion_count)
SELECT congregation_id,week_start,conversion_count FROM actual_counts
ON CONFLICT(congregation_id,week_start) DO UPDATE SET conversion_count=excluded.conversion_count;

-- The guard is a mutation lock/counter. Read-time truth comes from converts so
-- a missing guard can never make a congregation look eligible to confirm zero.
CREATE OR REPLACE FUNCTION public.ieadpe_weekly_overview(after_id uuid DEFAULT NULL, expected_week date DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE week_date date; global_scope boolean; rows jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 global_scope:=private.is_global_manager();
 IF NOT global_scope AND NOT EXISTS(SELECT FROM public.user_access WHERE user_id=auth.uid()
  AND role='Membro da direção da campanha' AND congregation_id IS NOT NULL) THEN
  RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 week_date:=private.report_week(private.weekly_now());
 IF expected_week IS NOT NULL AND week_date IS DISTINCT FROM expected_week THEN
  RAISE EXCEPTION 'reporting_changed' USING ERRCODE='22023'; END IF;
 IF week_date IS NULL THEN
  RETURN jsonb_build_object('visible',false,'global',global_scope,'week_start',NULL,'rows','[]'::jsonb);
 END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(page) ORDER BY page.id),'[]'::jsonb) INTO rows FROM (
  SELECT c.id,c.name,EXISTS(SELECT FROM public.weekly_reports r
   WHERE r.congregation_id=c.id AND r.week_start=week_date) AS confirmed
  FROM public.congregations c
  WHERE c.archived_at IS NULL AND (after_id IS NULL OR c.id>after_id)
   AND private.can_access_congregation(c.id)
   AND NOT EXISTS(SELECT FROM public.converts v
    WHERE v.congregation_id=c.id AND v.conversion_date BETWEEN week_date AND week_date+6
     AND v.deleted_at IS NULL)
  ORDER BY c.id LIMIT 100
 ) page;
 RETURN jsonb_build_object('visible',true,'global',global_scope,'week_start',week_date,'rows',rows);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_weekly_overview(uuid,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_weekly_overview(uuid,date) TO authenticated;
