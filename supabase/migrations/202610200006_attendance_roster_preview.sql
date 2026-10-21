-- S16: preview the writer's date-eligible roster without freezing or writing it.
-- The first explicit save remains the only roster freezer and rechecks eligibility.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_get_session_attendance(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; session_uuid uuid; session_row public.ministry_sessions; result jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','session_id']<>'{}'::jsonb OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR jsonb_typeof(request->'session_id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=(request->>'congregation_id')::uuid; session_uuid:=(request->>'session_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO session_row FROM public.ministry_sessions WHERE id=session_uuid AND congregation_id=congregation;
 IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found' USING ERRCODE='22023'; END IF;
 SELECT jsonb_build_object('session',jsonb_build_object('id',s.id,'congregation_id',s.congregation_id,'revision',s.revision,
   'created_at',s.created_at,'updated_at',s.updated_at,'updated_by',s.updated_by,'class_id',s.class_id,'date',s.session_date,
   'topic',s.topic,'status',s.status,'roster_frozen',s.roster_frozen,'lesson_index',s.lesson_index,'lesson_part',s.lesson_part,
   'lesson_finished',s.lesson_finished,'replaces_session_id',s.replaces_session_id,
   'replacement_session_id',(SELECT child.id FROM public.ministry_sessions child WHERE child.replaces_session_id=s.id)),
  'roster',CASE WHEN s.status='open' AND NOT s.roster_frozen THEN
   coalesce((SELECT jsonb_agg(jsonb_build_object('enrollment_id',e.id,'student_id',e.student_id,
     'student_name',coalesce(p.name,st.name),'status','unmarked') ORDER BY e.id)
    FROM public.ministry_enrollments e
    JOIN public.ministry_students st ON st.id=e.student_id AND st.congregation_id=e.congregation_id
    LEFT JOIN public.ministry_people p ON p.id=st.person_id AND p.congregation_id=e.congregation_id
    WHERE e.congregation_id=s.congregation_id AND e.class_id=s.class_id
     AND e.start_date<=s.session_date AND (e.end_date IS NULL OR e.end_date>=s.session_date)),
    '[]'::jsonb)
   ELSE coalesce((SELECT jsonb_agg(jsonb_build_object('enrollment_id',r.enrollment_id,'student_id',r.student_id,
     'student_name',r.student_name,'status',coalesce(a.status,'unmarked')) ORDER BY r.enrollment_id)
    FROM public.ministry_session_roster r LEFT JOIN public.ministry_attendance a
     ON a.session_id=r.session_id AND a.enrollment_id=r.enrollment_id
    WHERE r.session_id=s.id AND r.congregation_id=s.congregation_id),'[]'::jsonb)
  END) INTO result
 FROM public.ministry_sessions s WHERE s.id=session_uuid AND s.congregation_id=congregation;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_session_attendance(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_session_attendance(jsonb) TO authenticated;
