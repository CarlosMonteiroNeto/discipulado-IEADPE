-- Bounded, scoped enrollment history for one student.
-- Reuses the existing signed read-cursor and access helpers; no table grant is added.
CREATE FUNCTION public.ieadpe_ministry_list_student_enrollments(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; student_uuid uuid; page_size integer; cursor_text text; cursor_data jsonb;
 after_date date; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','student_id','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','student_id','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'student_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request->'limit')::text !~ '^[0-9]+$' OR
  jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  congregation:=(request->>'congregation_id')::uuid;
  student_uuid:=(request->>'student_id')::uuid;
  page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT FROM public.ministry_students s
  WHERE s.id=student_uuid AND s.congregation_id=congregation) THEN
  RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;

 cursor_text:=request->>'cursor';
 cursor_data:=private.ministry_read_cursor_decode(cursor_text,'student_enrollments');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','student_id','start_date','id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM congregation::text OR
   cursor_data->>'student_id' IS DISTINCT FROM student_uuid::text OR
   jsonb_typeof(cursor_data->'start_date') IS DISTINCT FROM 'string' OR
   jsonb_typeof(cursor_data->'id') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN
   after_date:=(cursor_data->>'start_date')::date;
   after_id:=(cursor_data->>'id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;

 WITH page AS (
  SELECT e.id,e.class_id,c.name AS class_name,e.start_date,e.end_date,e.status,e.revision
  FROM public.ministry_enrollments e
  JOIN public.ministry_classes c ON c.id=e.class_id AND c.congregation_id=e.congregation_id
  WHERE e.congregation_id=congregation AND e.student_id=student_uuid
   AND e.status IN ('active','completed','withdrawn')
   AND (after_date IS NULL OR (e.start_date,e.id)<(after_date,after_id))
  ORDER BY e.start_date DESC,e.id DESC
  LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'class_id',p.class_id,'class_name',p.class_name,
   'start_date',p.start_date,'end_date',p.end_date,'status',p.status,'revision',p.revision)
   ORDER BY p.start_date DESC,p.id DESC),'[]'::jsonb),count(*)
  INTO items,item_count
 FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1);
  tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object(
   'uid',auth.uid(),'resource','student_enrollments','congregation_id',congregation,
   'student_id',student_uuid,'start_date',tail->>'start_date','id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_student_enrollments(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_student_enrollments(jsonb) TO authenticated;
