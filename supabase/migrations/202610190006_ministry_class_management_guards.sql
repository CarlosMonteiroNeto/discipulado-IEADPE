CREATE FUNCTION private.ministry_class_before_write() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.teacher_contact_id IS NOT NULL THEN
   PERFORM 1 FROM public.ministry_contacts c
   WHERE c.id=NEW.teacher_contact_id AND c.congregation_id=NEW.congregation_id
    AND c.scope='congregation' AND c.role_code='teacher' AND c.archived_at IS NULL
   FOR SHARE;
   IF NOT FOUND THEN RAISE EXCEPTION 'invalid_class_teacher' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
 END IF;

 IF NEW.id IS DISTINCT FROM OLD.id OR NEW.congregation_id IS DISTINCT FROM OLD.congregation_id THEN
  RAISE EXCEPTION 'class_identity_immutable' USING ERRCODE='23514';
 END IF;

 IF NEW.teacher_contact_id IS NOT NULL THEN
  PERFORM 1 FROM public.ministry_contacts c
  WHERE c.id=NEW.teacher_contact_id AND c.congregation_id=NEW.congregation_id
   AND c.scope='congregation' AND c.role_code='teacher' AND c.archived_at IS NULL
  FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_class_teacher' USING ERRCODE='23514'; END IF;
 END IF;

 IF (NEW.name IS DISTINCT FROM OLD.name OR
     NEW.normalized_name IS DISTINCT FROM OLD.normalized_name OR
     NEW.teacher_contact_id IS DISTINCT FROM OLD.teacher_contact_id OR
     NEW.start_date IS DISTINCT FROM OLD.start_date OR
     NEW.end_date IS DISTINCT FROM OLD.end_date) AND
    (OLD.status IN ('completed','archived') OR NEW.status IS DISTINCT FROM OLD.status) THEN
  RAISE EXCEPTION 'class_details_read_only' USING ERRCODE='23514';
 END IF;

 IF (NEW.start_date IS DISTINCT FROM OLD.start_date OR NEW.end_date IS DISTINCT FROM OLD.end_date) AND
    (EXISTS(SELECT FROM public.ministry_enrollments e WHERE e.class_id=OLD.id) OR
     EXISTS(SELECT FROM public.ministry_sessions s WHERE s.class_id=OLD.id)) THEN
  RAISE EXCEPTION 'class_period_frozen' USING ERRCODE='23514';
 END IF;

 IF NEW.status IS DISTINCT FROM OLD.status THEN
  IF OLD.status='active' AND NEW.status='completed' THEN
   IF EXISTS(SELECT FROM public.ministry_enrollments e WHERE e.class_id=OLD.id AND e.status='active') OR
      EXISTS(SELECT FROM public.ministry_sessions s WHERE s.class_id=OLD.id AND s.status='open') THEN
    RAISE EXCEPTION 'class_has_open_academic_work' USING ERRCODE='23514';
   END IF;
  ELSIF OLD.status='active' AND NEW.status='archived' THEN
   IF EXISTS(SELECT FROM public.ministry_enrollments e WHERE e.class_id=OLD.id) OR
      EXISTS(SELECT FROM public.ministry_sessions s WHERE s.class_id=OLD.id) THEN
    RAISE EXCEPTION 'class_has_history' USING ERRCODE='23514';
   END IF;
  ELSIF OLD.status='completed' AND NEW.status='archived' THEN
   NULL;
  ELSIF OLD.status='archived' AND NEW.status='active' THEN
   NULL;
  ELSE
   RAISE EXCEPTION 'invalid_class_transition' USING ERRCODE='23514';
  END IF;
 END IF;

 RETURN NEW;
END $$;

CREATE TRIGGER ministry_class_management_guard
BEFORE INSERT OR UPDATE ON public.ministry_classes
FOR EACH ROW EXECUTE FUNCTION private.ministry_class_before_write();

REVOKE ALL ON FUNCTION private.ministry_class_before_write() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_classes(request jsonb) RETURNS jsonb
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
   SELECT c.id,c.name,c.status,c.start_date,c.end_date,c.revision,c.normalized_name,c.teacher_contact_id
   FROM public.ministry_classes c
   WHERE c.congregation_id=scope_id AND (requested_status IS NULL OR c.status=requested_status) AND
    (after_name IS NULL OR (c.normalized_name,c.id)>(after_name,after_id))
   ORDER BY c.normalized_name,c.id LIMIT page_size+1
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'status',p.status,
   'start_date',p.start_date,'end_date',p.end_date,'revision',p.revision,'teacher_contact_id',p.teacher_contact_id)
   ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
  INTO items,item_count FROM page p;
  IF item_count>page_size THEN
   items:=items-(item_count-1); tail:=items->(page_size-1);
   next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
    'resource','classes','congregation_id',scope_id,'status',requested_status,
    'name',lower(tail->>'name'),'class_id',tail->>'id'));
  ELSE next_cursor:=NULL; END IF;
  RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
 END $$;
