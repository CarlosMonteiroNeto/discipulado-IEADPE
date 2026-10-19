-- L1 class-session history read and creation-only inclusive class-period guard.
CREATE FUNCTION public.ieadpe_ministry_list_class_sessions(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); scope_id uuid; class_uuid uuid; page_size integer; limit_value numeric;
 cursor_text text; cursor_data jsonb; after_date date; after_id uuid;
 items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','class_id','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','class_id','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'class_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^-?[0-9]+$' OR
  jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  scope_id:=(request->>'congregation_id')::uuid;
  class_uuid:=(request->>'class_id')::uuid;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 BEGIN limit_value:=(request->>'limit')::numeric;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END;
 IF limit_value NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 page_size:=limit_value::integer;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT FROM public.ministry_classes c WHERE c.id=class_uuid AND c.congregation_id=scope_id) THEN
  RAISE EXCEPTION 'class_not_found' USING ERRCODE='22023'; END IF;
 cursor_text:=request->>'cursor';
 cursor_data:=private.ministry_read_cursor_decode(cursor_text,'class_sessions');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','class_id','session_date','session_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'class_id' IS DISTINCT FROM class_uuid::text OR
   jsonb_typeof(cursor_data->'session_date') IS DISTINCT FROM 'string' OR
   jsonb_typeof(cursor_data->'session_id') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_date:=(cursor_data->>'session_date')::date; after_id:=(cursor_data->>'session_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id,s.class_id,s.congregation_id,s.session_date,s.topic,s.status,s.revision
  FROM public.ministry_sessions s WHERE s.congregation_id=scope_id AND s.class_id=class_uuid AND
   (after_date IS NULL OR (s.session_date,s.id)>(after_date,after_id))
  ORDER BY s.session_date,s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'class_id',p.class_id,
   'congregation_id',p.congregation_id,'date',p.session_date,'topic',p.topic,
   'status',p.status,'revision',p.revision) ORDER BY p.session_date,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',actor,
   'resource','class_sessions','congregation_id',scope_id,'class_id',class_uuid,
   'session_date',tail->>'date','session_id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_class_sessions(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_class_sessions(jsonb) TO authenticated;

CREATE FUNCTION private.ministry_create_session_command(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; congregation uuid; class_uuid uuid; session_day date;
 receipt private.mutation_receipts; digest text; response jsonb; class_row public.ministry_classes; revision_value integer;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','class_id','date','topic']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','class_id','date','topic'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'class_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'date') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'topic') NOT IN ('string','null') OR (payload->>'date') !~ '^\d{4}-\d{2}-\d{2}$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid; congregation:=(payload->>'congregation_id')::uuid;
  class_uuid:=(payload->>'class_id')::uuid; session_day:=(payload->>'date')::date;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ministry_create_session_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>'create_session' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO class_row FROM public.ministry_classes c
  WHERE c.id=class_uuid AND c.congregation_id=congregation FOR UPDATE;
 IF NOT FOUND OR class_row.status<>'active' THEN RAISE EXCEPTION 'class_not_active' USING ERRCODE='23514'; END IF;
 IF session_day<class_row.start_date OR (class_row.end_date IS NOT NULL AND session_day>class_row.end_date) THEN
  RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023'; END IF;
 INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,topic,updated_by)
  VALUES(target,congregation,class_uuid,session_day,payload->>'topic',actor) RETURNING revision INTO revision_value;
 response:=jsonb_build_object('id',target,'revision',revision_value,'status','open');
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'create_session',digest,response);
 RETURN response;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;
REVOKE ALL ON FUNCTION private.ministry_create_session_command(uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_create_session(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_create_session_command(operation_id,payload) $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_create_session(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_create_session(uuid,jsonb) TO authenticated;
