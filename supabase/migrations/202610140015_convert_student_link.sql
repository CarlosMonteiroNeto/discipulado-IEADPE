-- A convert may refer to at most one ministry student. The timestamp records
-- when the initial snapshot was taken; later edits are deliberately independent.
ALTER TABLE public.ministry_students
 ADD COLUMN convert_id uuid REFERENCES public.converts(id) ON DELETE RESTRICT,
 ADD COLUMN promoted_at timestamptz,
 ADD COLUMN convert_snapshot jsonb;
ALTER TABLE public.ministry_students ADD CONSTRAINT ministry_students_convert_link_pair
 CHECK ((convert_id IS NULL) = (promoted_at IS NULL) AND (convert_id IS NULL) = (convert_snapshot IS NULL)),
 ADD CONSTRAINT ministry_students_convert_snapshot_shape CHECK(convert_snapshot IS NULL OR
  (jsonb_typeof(convert_snapshot)='object' AND convert_snapshot ?& ARRAY['name','phone','address'] AND
   convert_snapshot-ARRAY['name','phone','address']='{}'::jsonb AND
   jsonb_typeof(convert_snapshot->'name')='string' AND convert_snapshot->>'name'<>'' AND
   jsonb_typeof(convert_snapshot->'phone') IN ('string','null') AND
   jsonb_typeof(convert_snapshot->'address') IN ('string','null')));
CREATE UNIQUE INDEX ministry_students_one_convert_link ON public.ministry_students(convert_id)
 WHERE convert_id IS NOT NULL;
CREATE INDEX ministry_students_convert_link_scope ON public.ministry_students(congregation_id,convert_id)
 WHERE convert_id IS NOT NULL;

CREATE FUNCTION private.prevent_convert_link_rewrite() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.convert_id IS NOT NULL AND
  (NEW.convert_id,NEW.promoted_at,NEW.convert_snapshot) IS DISTINCT FROM
  (OLD.convert_id,OLD.promoted_at,OLD.convert_snapshot) THEN
  RAISE EXCEPTION 'convert_link_immutable' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.prevent_convert_link_rewrite() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ministry_student_convert_link_immutable
 BEFORE UPDATE OF convert_id,promoted_at,convert_snapshot ON public.ministry_students
 FOR EACH ROW EXECUTE FUNCTION private.prevent_convert_link_rewrite();

CREATE FUNCTION public.ieadpe_ministry_list_convert_student_candidates(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; name_prefix text; cursor_text text; cursor_data jsonb;
 after_name text; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','name_prefix','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','name_prefix','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'name_prefix') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 name_prefix:=request->>'name_prefix';
 IF name_prefix='' OR length(name_prefix)>200 OR name_prefix<>btrim(name_prefix) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT FROM private.admin_allowlist a WHERE a.user_id=auth.uid()) AND
  NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations WHERE id=scope_id AND archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'convert_student_candidates');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','name','student_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM name_prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_id:=(cursor_data->>'student_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id,s.name,s.normalized_name,s.phone_e164,s.address
  FROM public.ministry_students s
  WHERE s.congregation_id=scope_id AND s.archived_at IS NULL AND s.convert_id IS NULL
   AND left(s.normalized_name,length(lower(name_prefix)))=lower(name_prefix)
   AND (after_name IS NULL OR (s.normalized_name,s.id)>(after_name,after_id))
  ORDER BY s.normalized_name,s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('student_id',p.id,'name',p.name,
  'phone',p.phone_e164,'address',p.address) ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','convert_student_candidates','congregation_id',scope_id,
   'name_prefix',name_prefix,'name',lower(tail->>'name'),'student_id',tail->>'student_id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_ministry_list_convert_referrals(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; cursor_text text; cursor_data jsonb;
 after_date date; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT FROM private.admin_allowlist a WHERE a.user_id=auth.uid()) AND
  NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations WHERE id=scope_id AND archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'convert_referrals');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','conversion_date','convert_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   jsonb_typeof(cursor_data->'conversion_date') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_date:=(cursor_data->>'conversion_date')::date; after_id:=(cursor_data->>'convert_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT c.id,c.name,c.phone,c.address,c.conversion_date
  FROM public.converts c
  WHERE c.congregation_id=scope_id AND c.deleted_at IS NULL
   AND NOT EXISTS(SELECT FROM public.ministry_students s WHERE s.convert_id=c.id)
   AND (after_date IS NULL OR (c.conversion_date,c.id)<(after_date,after_id))
  ORDER BY c.conversion_date DESC,c.id DESC LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('convert_id',p.id,'congregation_id',scope_id,
  'name',p.name,'phone',p.phone,'address',p.address,'conversion_date',p.conversion_date)
  ORDER BY p.conversion_date DESC,p.id DESC),'[]'::jsonb),count(*) INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','convert_referrals','congregation_id',scope_id,
   'conversion_date',tail->>'conversion_date','convert_id',tail->>'convert_id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_promote_convert_to_student(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); convert_uuid uuid; scope_id uuid; student_uuid uuid;
 convert_row public.converts; student_row public.ministry_students; receipt private.mutation_receipts;
 digest text; response jsonb; phone_value text; address_value text; student_name text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['convert_id','congregation_id','student_id']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['convert_id','congregation_id','student_id'] OR
  jsonb_typeof(payload->'convert_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'student_id') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  convert_uuid:=(payload->>'convert_id')::uuid;
  scope_id:=(payload->>'congregation_id')::uuid;
  student_uuid:=CASE WHEN jsonb_typeof(payload->'student_id')='string' THEN (payload->>'student_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT EXISTS(SELECT FROM private.admin_allowlist a WHERE a.user_id=actor) AND
  NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO convert_row FROM public.converts c WHERE c.id=convert_uuid FOR UPDATE;
 IF NOT FOUND OR convert_row.congregation_id IS DISTINCT FROM scope_id THEN
  RAISE EXCEPTION 'convert_unavailable' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ieadpe_promote_convert_to_student.operation_id;
 IF FOUND THEN
  IF receipt.command<>'promote_convert_to_student' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF convert_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'convert_unavailable' USING ERRCODE='22023'; END IF;
 IF student_uuid IS NOT NULL THEN
  SELECT * INTO student_row FROM public.ministry_students s WHERE s.id=student_uuid FOR UPDATE;
  IF NOT FOUND OR student_row.congregation_id IS DISTINCT FROM scope_id OR
   student_row.archived_at IS NOT NULL OR student_row.convert_id IS NOT NULL THEN
   RAISE EXCEPTION 'candidate_unavailable' USING ERRCODE='22023'; END IF;
 ELSE
  phone_value:=convert_row.phone;
  IF phone_value IS NOT NULL AND phone_value !~ '^\+[1-9][0-9]{1,14}$' THEN phone_value:=NULL; END IF;
  student_name:=btrim(convert_row.name);
  address_value:=convert_row.address;
  student_uuid:=gen_random_uuid();
  INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,phone_e164,address,
   convert_id,promoted_at,convert_snapshot,updated_by)
  VALUES(student_uuid,scope_id,student_name,lower(student_name),phone_value,
   CASE WHEN address_value IS NULL THEN NULL ELSE jsonb_build_object('street',address_value) END,
   convert_uuid,now(),jsonb_build_object('name',convert_row.name,'phone',convert_row.phone,'address',convert_row.address),actor);
 END IF;
 IF student_row.id IS NOT NULL THEN
  UPDATE public.ministry_students SET convert_id=convert_uuid,promoted_at=now(),
   convert_snapshot=jsonb_build_object('name',convert_row.name,'phone',convert_row.phone,'address',convert_row.address),updated_at=now(),
   revision=revision+1,updated_by=actor WHERE id=student_uuid;
 END IF;
 response:=jsonb_build_object('convert_id',convert_uuid,'student_id',student_uuid,
  'congregation_id',scope_id,'status','linked');
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(actor,operation_id,'promote_convert_to_student',digest,response);
 RETURN response;
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'convert_already_linked' USING ERRCODE='22023';
END $$;

REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_convert_student_candidates(jsonb),
 public.ieadpe_ministry_list_convert_referrals(jsonb),
 public.ieadpe_promote_convert_to_student(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_convert_student_candidates(jsonb),
 public.ieadpe_ministry_list_convert_referrals(jsonb),
 public.ieadpe_promote_convert_to_student(uuid,jsonb) TO authenticated;
