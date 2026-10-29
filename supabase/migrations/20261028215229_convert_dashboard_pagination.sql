BEGIN;
-- The dashboard follows a student rather than an enrollment; only present lessons qualify.
CREATE INDEX ministry_attendance_present_student_scope_session
 ON public.ministry_attendance(student_id,congregation_id,session_id) WHERE status='present';
CREATE COLLATION IF NOT EXISTS private.dashboard_pt (provider=icu, locale='pt-BR', deterministic=true);

-- Validate every requested scope before reading, including archived scopes for supervisors.
CREATE FUNCTION private.dashboard_scopes(request jsonb) RETURNS uuid[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[]; one_id uuid; element jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request->'congregation_id' IS NOT NULL AND jsonb_typeof(request->'congregation_id') NOT IN ('string','null') OR
    request->'congregation_ids' IS NOT NULL AND jsonb_typeof(request->'congregation_ids') NOT IN ('array','null') OR
    request->>'congregation_id' IS NOT NULL AND jsonb_typeof(request->'congregation_ids')='array' THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  IF request->>'congregation_id' IS NOT NULL THEN ids:=ARRAY[(request->>'congregation_id')::uuid];
  ELSIF jsonb_typeof(request->'congregation_ids')='array' THEN
   ids:=ARRAY[]::uuid[];
   FOR element IN SELECT value FROM jsonb_array_elements(request->'congregation_ids') LOOP
    IF jsonb_typeof(element)<>'string' THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
    ids:=array_append(ids,(element#>>'{}')::uuid);
   END LOOP;
   SELECT coalesce(array_agg(DISTINCT x ORDER BY x),ARRAY[]::uuid[]) INTO ids FROM unnest(ids) x;
  ELSE
   IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
   RETURN NULL;
  END IF;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 FOREACH one_id IN ARRAY ids LOOP
  IF NOT private.ministry_can_access(one_id) OR NOT EXISTS(SELECT FROM public.congregations WHERE id=one_id AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 END LOOP;
 RETURN ids;
END $$;

CREATE FUNCTION private.dashboard_rows(ids uuid[], search_text text, today date)
RETURNS TABLE(id uuid, congregation_id uuid, congregation_name text, person_name text, severity integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH facts AS (
  SELECT c.id,c.congregation_id,g.name AS congregation_name,coalesce(p.name,c.name) AS person_name,
   c.is_in_discipleship OR EXISTS(SELECT FROM public.ministry_students st JOIN public.ministry_enrollments e
    ON e.student_id=st.id AND e.congregation_id=st.congregation_id
    WHERE st.person_id=c.person_id AND st.congregation_id=c.congregation_id AND e.status='active') AS active,
   c.was_visited_once,c.conversion_date,greatest(c.last_visit_date,lesson.last_date) AS follow_date
  FROM public.converts c JOIN public.congregations g ON g.id=c.congregation_id AND g.archived_at IS NULL
  LEFT JOIN public.ministry_people p ON p.id=c.person_id AND p.congregation_id=c.congregation_id
  LEFT JOIN LATERAL (SELECT max(s.session_date) AS last_date FROM public.ministry_students st
   JOIN public.ministry_attendance a ON a.student_id=st.id AND a.congregation_id=st.congregation_id
   JOIN public.ministry_sessions s ON s.id=a.session_id AND s.congregation_id=a.congregation_id
   WHERE st.person_id=c.person_id AND st.congregation_id=c.congregation_id AND a.status='present' AND s.status='finalized') lesson ON true
  WHERE c.deleted_at IS NULL AND NOT c.is_deviated AND NOT c.is_discipleship_completed
   AND (ids IS NULL OR c.congregation_id=ANY(ids))
   AND (search_text IS NULL OR strpos(lower(coalesce(p.name,c.name)),search_text)>0)
 ), classified AS (
  SELECT *,today-coalesce(follow_date,conversion_date) >=
   CASE WHEN NOT (was_visited_once OR follow_date IS NOT NULL) THEN 1 WHEN active THEN 30 ELSE 7 END AS due
  FROM facts
 )
 SELECT id,congregation_id,congregation_name,person_name,
  CASE WHEN due AND NOT active THEN 0 WHEN NOT due AND active THEN 2 ELSE 1 END FROM classified
$$;

CREATE FUNCTION public.ieadpe_convert_dashboard_page(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[]; page_size integer; search_text text; status_text text; cursor_data jsonb; today date:=private.business_today();
 items jsonb; n integer; next_cursor text; last_row jsonb; scope_fingerprint text;
BEGIN
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','congregation_ids','search','status','limit','cursor']<>'{}'::jsonb OR
 jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
 (request ? 'search' AND jsonb_typeof(request->'search') NOT IN ('string','null')) OR
 (request ? 'status' AND jsonb_typeof(request->'status') NOT IN ('string','null')) OR
 (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN page_size:=(request->>'limit')::integer; EXCEPTION WHEN numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 search_text:=nullif(lower(btrim(request->>'search')),''); status_text:=request->>'status';
 IF length(search_text)>200 OR status_text IS NOT NULL AND status_text NOT IN ('red','yellow','green') THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 ids:=private.dashboard_scopes(request);
 -- dashboard_scopes sorts and deduplicates UUIDs; hash its canonical JSON including null.
 scope_fingerprint:=encode(sha256(convert_to(coalesce(to_jsonb(ids),'null'::jsonb)::text,'UTF8')),'hex');
 cursor_data:=private.ministry_read_cursor_decode(request->>'cursor','convert_dashboard');
 IF cursor_data IS NOT NULL AND (cursor_data->>'scope_fingerprint' IS DISTINCT FROM scope_fingerprint OR
 cursor_data->>'search' IS DISTINCT FROM search_text OR cursor_data->>'status' IS DISTINCT FROM status_text OR
 cursor_data->>'today' IS DISTINCT FROM today::text) THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
 WITH rows AS (
  SELECT *,CASE WHEN lower(btrim(congregation_name))='matriz' THEN 0 ELSE 1 END AS matriz
  FROM private.dashboard_rows(ids,search_text,today)
  WHERE status_text IS NULL OR severity=CASE status_text WHEN 'red' THEN 0 WHEN 'yellow' THEN 1 ELSE 2 END
 ), page AS (
  SELECT * FROM rows r WHERE cursor_data IS NULL OR
   (r.severity,r.matriz,r.congregation_name COLLATE private.dashboard_pt,r.congregation_id,r.person_name COLLATE private.dashboard_pt,r.id) >
   ((cursor_data->>'severity')::int,(cursor_data->>'matriz')::int,(cursor_data->>'congregation_name') COLLATE private.dashboard_pt,(cursor_data->>'congregation_id')::uuid,(cursor_data->>'person_name') COLLATE private.dashboard_pt,(cursor_data->>'id')::uuid)
  ORDER BY severity,matriz,congregation_name COLLATE private.dashboard_pt,congregation_id,person_name COLLATE private.dashboard_pt,id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('projection',private.ministry_convert_projection(c),'severity',severity,'matriz',matriz,'congregation_name',congregation_name,'congregation_id',page.congregation_id,'person_name',person_name,'id',page.id)
 ORDER BY severity,matriz,congregation_name COLLATE private.dashboard_pt,page.congregation_id,person_name COLLATE private.dashboard_pt,page.id),'[]'::jsonb),count(*) INTO items,n FROM page JOIN public.converts c ON c.id=page.id;
 IF n>page_size THEN
  last_row:=items->(page_size-1); items:=items-page_size;
  next_cursor:=private.ministry_read_cursor_encode(last_row-'projection'||jsonb_build_object('uid',auth.uid(),'resource','convert_dashboard','scope_fingerprint',scope_fingerprint,'search',search_text,'status',status_text,'today',today));
 END IF;
 SELECT coalesce(jsonb_agg(value->'projection' ORDER BY ordinality),'[]'::jsonb) INTO items FROM jsonb_array_elements(items) WITH ORDINALITY;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_convert_dashboard_counts(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[]; search_text text; counts jsonb;
BEGIN
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_ids','search']<>'{}'::jsonb OR
 jsonb_typeof(request->'congregation_ids') IS DISTINCT FROM 'array' OR
 (request ? 'search' AND jsonb_typeof(request->'search') NOT IN ('string','null')) THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 search_text:=nullif(lower(btrim(request->>'search')),''); IF length(search_text)>200 THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 ids:=private.dashboard_scopes(request);
 SELECT coalesce(jsonb_agg(jsonb_build_object('congregation_id',s.id,'red_count',coalesce(t.n,0)) ORDER BY s.id),'[]'::jsonb) INTO counts
 FROM unnest(ids) s(id) LEFT JOIN (SELECT congregation_id,count(*) AS n FROM private.dashboard_rows(ids,search_text,private.business_today()) WHERE severity=0 GROUP BY congregation_id) t ON t.congregation_id=s.id;
 RETURN jsonb_build_object('counts',counts);
END $$;
REVOKE ALL ON FUNCTION private.dashboard_scopes(jsonb),private.dashboard_rows(uuid[],text,date),public.ieadpe_convert_dashboard_page(jsonb),public.ieadpe_convert_dashboard_counts(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ieadpe_convert_dashboard_page(jsonb),public.ieadpe_convert_dashboard_counts(jsonb) TO authenticated;
COMMIT;
