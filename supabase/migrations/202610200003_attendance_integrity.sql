-- T2: immutable finalized attendance and explicit linked replacement.
-- Finalized/canceled sessions reject every new save; exact receipts still replay.
ALTER TABLE public.ministry_sessions
 ADD COLUMN replaces_session_id uuid REFERENCES public.ministry_sessions(id) ON DELETE RESTRICT,
 ADD CONSTRAINT ministry_sessions_replaces_not_self CHECK(replaces_session_id IS NULL OR replaces_session_id<>id);
CREATE UNIQUE INDEX ministry_sessions_replaces_unique
 ON public.ministry_sessions(replaces_session_id) WHERE replaces_session_id IS NOT NULL;

CREATE FUNCTION private.ministry_session_linkage_immutable() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NEW.replaces_session_id IS DISTINCT FROM OLD.replaces_session_id THEN
  RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.ministry_session_linkage_immutable() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ministry_sessions_linkage_immutable
 BEFORE UPDATE OF replaces_session_id ON public.ministry_sessions
 FOR EACH ROW EXECUTE FUNCTION private.ministry_session_linkage_immutable();

CREATE FUNCTION private.ministry_save_attendance_command(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); congregation uuid; session_uuid uuid; expected integer;
 row_session public.ministry_sessions; receipt private.mutation_receipts; digest text; response jsonb;
 marks jsonb; finalizing boolean; roster_count integer; revision_value integer;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['congregation_id','session_id','expected_revision','marks','finalize']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['congregation_id','session_id','expected_revision','marks','finalize'] OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'session_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
  jsonb_typeof(payload->'marks') IS DISTINCT FROM 'object' OR
  jsonb_typeof(payload->'finalize') IS DISTINCT FROM 'boolean' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  congregation:=(payload->>'congregation_id')::uuid;
  session_uuid:=(payload->>'session_id')::uuid;
  expected:=(payload->>'expected_revision')::integer;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_save_attendance_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>'save_attendance' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO row_session FROM public.ministry_sessions
  WHERE id=session_uuid AND congregation_id=congregation;
 IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.ministry_classes WHERE id=row_session.class_id FOR UPDATE;
 SELECT * INTO row_session FROM public.ministry_sessions WHERE id=session_uuid FOR UPDATE;
 IF row_session.status='finalized' THEN RAISE EXCEPTION 'session_finalized' USING ERRCODE='23514'; END IF;
 IF row_session.status='canceled' THEN RAISE EXCEPTION 'session_canceled' USING ERRCODE='23514'; END IF;
 IF row_session.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
 marks:=payload->'marks'; finalizing:=(payload->>'finalize')::boolean;
 IF NOT row_session.roster_frozen THEN
  INSERT INTO public.ministry_session_roster(congregation_id,session_id,enrollment_id,student_id,student_name,updated_by)
   SELECT congregation,row_session.id,e.id,e.student_id,coalesce(p.name,s.name),actor
   FROM public.ministry_enrollments e JOIN public.ministry_students s ON s.id=e.student_id
   LEFT JOIN public.ministry_people p ON p.id=s.person_id AND p.congregation_id=congregation
   WHERE e.class_id=row_session.class_id AND e.congregation_id=congregation
    AND e.start_date<=row_session.session_date AND (e.end_date IS NULL OR e.end_date>=row_session.session_date)
   ORDER BY e.id;
  UPDATE public.ministry_sessions SET roster_frozen=true WHERE id=row_session.id;
 END IF;
 SELECT count(*) INTO roster_count FROM public.ministry_session_roster WHERE session_id=row_session.id;
 IF (SELECT count(*) FROM jsonb_object_keys(marks))<>roster_count OR EXISTS(
  SELECT 1 FROM public.ministry_session_roster r WHERE r.session_id=row_session.id AND NOT marks ? r.enrollment_id::text) OR EXISTS(
  SELECT 1 FROM jsonb_each_text(marks) m WHERE m.value NOT IN ('present','absent','excused','unmarked')) THEN
  RAISE EXCEPTION 'roster_mismatch' USING ERRCODE='23514'; END IF;
 IF finalizing AND (roster_count=0 OR EXISTS(SELECT FROM jsonb_each_text(marks) WHERE value='unmarked') OR
  row_session.session_date>(now() AT TIME ZONE 'America/Recife')::date) THEN
  RAISE EXCEPTION 'attendance_incomplete' USING ERRCODE='23514'; END IF;
 INSERT INTO public.ministry_attendance(congregation_id,session_id,enrollment_id,student_id,status,updated_by)
  SELECT congregation,row_session.id,r.enrollment_id,r.student_id,marks->>r.enrollment_id::text,actor
  FROM public.ministry_session_roster r WHERE r.session_id=row_session.id
  ON CONFLICT(session_id,enrollment_id) DO UPDATE
   SET status=EXCLUDED.status,revision=public.ministry_attendance.revision+1,updated_at=now(),updated_by=actor;
 UPDATE public.ministry_sessions
  SET status=CASE WHEN finalizing THEN 'finalized' ELSE 'open' END,
   revision=revision+1,updated_at=now(),updated_by=actor
  WHERE id=row_session.id RETURNING revision INTO revision_value;
 response:=jsonb_build_object('id',row_session.id,'revision',revision_value,
  'status',CASE WHEN finalizing THEN 'finalized' ELSE 'open' END,
  'roster_frozen',true,'attendance_count',roster_count);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'save_attendance',digest,response);
 RETURN response;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
 WHEN foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;
REVOKE ALL ON FUNCTION private.ministry_save_attendance_command(uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_save_attendance(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_save_attendance_command(operation_id,payload)
$$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_save_attendance(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_save_attendance(uuid,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION private.ministry_create_session_command(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; congregation uuid; class_uuid uuid; session_day date;
 predecessor uuid; predecessor_row public.ministry_sessions;
 receipt private.mutation_receipts; digest text; response jsonb; class_row public.ministry_classes;
 revision_value integer;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','class_id','date','topic','replaces_session_id']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','class_id','date','topic'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'class_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'date') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'topic') NOT IN ('string','null') OR
  jsonb_typeof(payload->'replaces_session_id') NOT IN ('string','null') OR
  (payload->>'date') !~ '^\d{4}-\d{2}-\d{2}$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid; congregation:=(payload->>'congregation_id')::uuid;
  class_uuid:=(payload->>'class_id')::uuid; session_day:=(payload->>'date')::date;
  predecessor:=CASE WHEN jsonb_typeof(payload->'replaces_session_id')='string'
   THEN (payload->>'replaces_session_id')::uuid ELSE NULL END;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_create_session_command.operation_id;
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
 IF predecessor IS NOT NULL THEN
  IF predecessor=target THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023'; END IF;
  SELECT * INTO predecessor_row FROM public.ministry_sessions s
   WHERE s.id=predecessor AND s.congregation_id=congregation FOR UPDATE;
  IF NOT FOUND OR predecessor_row.class_id<>class_uuid OR predecessor_row.session_date<>session_day
   OR predecessor_row.status<>'canceled' THEN
   RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT FROM public.ministry_sessions child WHERE child.replaces_session_id=predecessor) THEN
   RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505'; END IF;
 END IF;
 INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,topic,replaces_session_id,updated_by)
  VALUES(target,congregation,class_uuid,session_day,payload->>'topic',predecessor,actor)
  RETURNING revision INTO revision_value;
 response:=jsonb_build_object('id',target,'revision',revision_value,'status','open');
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'create_session',digest,response);
 RETURN response;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
 WHEN foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;
REVOKE ALL ON FUNCTION private.ministry_create_session_command(uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_create_session(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_create_session_command(operation_id,payload)
$$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_create_session(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_create_session(uuid,jsonb) TO authenticated;

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
  'roster',coalesce((SELECT jsonb_agg(jsonb_build_object('enrollment_id',r.enrollment_id,'student_id',r.student_id,
    'student_name',r.student_name,'status',coalesce(a.status,'unmarked')) ORDER BY r.enrollment_id)
   FROM public.ministry_session_roster r LEFT JOIN public.ministry_attendance a ON a.session_id=r.session_id AND a.enrollment_id=r.enrollment_id
   WHERE r.session_id=s.id AND r.congregation_id=s.congregation_id),'[]'::jsonb)) INTO result
 FROM public.ministry_sessions s WHERE s.id=session_uuid AND s.congregation_id=congregation;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_class_sessions(request jsonb) RETURNS jsonb
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
  SELECT s.id,s.class_id,s.congregation_id,s.session_date,s.topic,s.status,s.revision,s.replaces_session_id
  FROM public.ministry_sessions s WHERE s.congregation_id=scope_id AND s.class_id=class_uuid AND
   (after_date IS NULL OR (s.session_date,s.id)>(after_date,after_id))
  ORDER BY s.session_date,s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'class_id',p.class_id,
   'congregation_id',p.congregation_id,'date',p.session_date,'topic',p.topic,
   'status',p.status,'revision',p.revision,'replaces_session_id',p.replaces_session_id,
   'replacement_session_id',(SELECT child.id FROM public.ministry_sessions child WHERE child.replaces_session_id=p.id))
   ORDER BY p.session_date,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',actor,
   'resource','class_sessions','congregation_id',scope_id,'class_id',class_uuid,
   'session_date',tail->>'date','session_id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;
