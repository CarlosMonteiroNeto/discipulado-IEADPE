-- Ministry supervision needs an explicit congregation choice before entering
-- congregation-scoped student, class, enrollment, or attendance workflows.
-- The projection is limited to active congregation IDs and display names.
CREATE FUNCTION public.ieadpe_ministry_list_congregations(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE page_size integer; after_id uuid; items jsonb; item_count integer; tail_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
    request-ARRAY['limit','cursor']<>'{}'::jsonb OR
    jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
    (request->'limit')::text !~ '^[0-9]+$' OR
    (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END IF;
 BEGIN
  page_size:=(request->>'limit')::integer;
  IF nullif(request->>'cursor','') IS NOT NULL THEN after_id:=(request->>'cursor')::uuid; END IF;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_supervisor() AND NOT EXISTS(
    SELECT FROM public.ministry_grants g WHERE g.user_id=auth.uid()
      AND g.active AND g.role='ministry_staff' AND g.congregation_id IS NOT NULL
 ) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 WITH page AS (
  SELECT c.id,c.name FROM public.congregations c
  WHERE c.archived_at IS NULL AND private.ministry_can_access(c.id)
    AND (after_id IS NULL OR c.id>after_id)
  ORDER BY c.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) ORDER BY p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  tail_id:=((items->(page_size-1))->>'id')::uuid;
  items:=items-page_size;
  RETURN jsonb_build_object('items',items,'next_cursor',tail_id);
 END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',NULL);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_congregations(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_congregations(jsonb) TO authenticated;
