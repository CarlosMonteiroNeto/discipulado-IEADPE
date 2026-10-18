CREATE FUNCTION public.ieadpe_ministry_list_students(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; prefix text; cursor_text text; cursor_data jsonb;
 after_name text; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','name_prefix','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','name_prefix','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  jsonb_typeof(request->'name_prefix') NOT IN ('string','null') OR
  jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 prefix:=request->>'name_prefix';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix) OR length(prefix)>200) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'students');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','name','student_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_id:=(cursor_data->>'student_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id,s.name,s.phone_e164,s.convert_id,s.revision,s.normalized_name
  FROM public.ministry_students s
  WHERE s.congregation_id=scope_id AND s.archived_at IS NULL AND
   (prefix IS NULL OR left(s.normalized_name,length(lower(prefix)))=lower(prefix)) AND
   (after_name IS NULL OR (s.normalized_name,s.id)>(after_name,after_id))
  ORDER BY s.normalized_name,s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'phone_e164',p.phone_e164,
  'convert_id',p.convert_id,'revision',p.revision) ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','students','congregation_id',scope_id,'name_prefix',prefix,
   'name',lower(tail->>'name'),'student_id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_ministry_list_classes(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; requested_status text; cursor_text text; cursor_data jsonb;
 after_name text; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','status','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','status','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  jsonb_typeof(request->'status') NOT IN ('string','null') OR
  jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 requested_status:=request->>'status';
 IF requested_status IS NOT NULL AND requested_status NOT IN ('active','completed','archived') THEN
  RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'classes');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','status','name','class_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'status' IS DISTINCT FROM requested_status OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_id:=(cursor_data->>'class_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT c.id,c.name,c.status,c.start_date,c.end_date,c.revision,c.normalized_name
  FROM public.ministry_classes c
  WHERE c.congregation_id=scope_id AND (requested_status IS NULL OR c.status=requested_status) AND
   (after_name IS NULL OR (c.normalized_name,c.id)>(after_name,after_id))
  ORDER BY c.normalized_name,c.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'status',p.status,
  'start_date',p.start_date,'end_date',p.end_date,'revision',p.revision) ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','classes','congregation_id',scope_id,'status',requested_status,
   'name',lower(tail->>'name'),'class_id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_students(jsonb),
 public.ieadpe_ministry_list_classes(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_students(jsonb),
 public.ieadpe_ministry_list_classes(jsonb) TO authenticated;
