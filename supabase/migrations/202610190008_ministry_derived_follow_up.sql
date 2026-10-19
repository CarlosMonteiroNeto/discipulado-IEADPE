-- F1: add server-derived follow-up facts to the shared Ministry convert read.
-- Keep list/detail authorization, cursor behavior and mutation RPC envelopes intact.
CREATE OR REPLACE FUNCTION private.ministry_convert_projection(source public.converts) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'convert',jsonb_build_object('id',source.id,'internal_id',source.internal_id,'person_id',source.person_id,
   'congregation_id',source.congregation_id,'landmark',source.landmark,'gender',source.gender,
   'conversion_date',source.conversion_date,'worship_type',source.worship_type,'photo_url',source.photo_url,
   'photo_asset_id',source.photo_asset_id,'age',source.age,'last_visit_date',source.last_visit_date,
   'was_visited_once',source.was_visited_once,'visit_count',source.visit_count,'is_in_discipleship',source.is_in_discipleship,
   'discipleship_start_date',source.discipleship_start_date,'is_discipleship_completed',source.is_discipleship_completed,
   'is_deviated',source.is_deviated,'effective_is_in_discipleship',
    source.is_in_discipleship OR EXISTS(
     SELECT FROM public.ministry_students st JOIN public.ministry_enrollments e
      ON e.student_id=st.id AND e.congregation_id=st.congregation_id
     WHERE st.person_id=source.person_id AND st.congregation_id=source.congregation_id AND e.status='active'),
   'effective_discipleship_start_date',(
     SELECT min(starts.start_date) FROM (
      SELECT source.discipleship_start_date AS start_date
       WHERE source.is_in_discipleship AND source.discipleship_start_date IS NOT NULL
      UNION ALL
      SELECT e.start_date FROM public.ministry_students st JOIN public.ministry_enrollments e
       ON e.student_id=st.id AND e.congregation_id=st.congregation_id
       WHERE st.person_id=source.person_id AND st.congregation_id=source.congregation_id AND e.status='active'
     ) starts),
   'latest_qualifying_lesson_date',(
     SELECT max(s.session_date) FROM public.ministry_students st
      JOIN public.ministry_attendance a ON a.student_id=st.id AND a.congregation_id=st.congregation_id
      JOIN public.ministry_sessions s ON s.id=a.session_id AND s.congregation_id=a.congregation_id
      WHERE st.person_id=source.person_id AND st.congregation_id=source.congregation_id
       AND a.status='present' AND s.status='finalized'),
   'effective_follow_up_date',greatest(source.last_visit_date,(
     SELECT max(s.session_date) FROM public.ministry_students st
      JOIN public.ministry_attendance a ON a.student_id=st.id AND a.congregation_id=st.congregation_id
      JOIN public.ministry_sessions s ON s.id=a.session_id AND s.congregation_id=a.congregation_id
      WHERE st.person_id=source.person_id AND st.congregation_id=source.congregation_id
       AND a.status='present' AND s.status='finalized')),
   'created_by',source.created_by,'created_at',source.created_at,
   'updated_at',source.updated_at,'deleted_at',source.deleted_at,'revision',source.revision),
  'person',CASE WHEN p.id IS NULL THEN NULL ELSE jsonb_build_object('id',p.id,'congregation_id',p.congregation_id,
   'name',p.name,'normalized_name',p.normalized_name,'phone',p.phone,'birth_date',p.birth_date,'address',p.address) END,
  'person_revision',p.revision,
  'legacy_identity',CASE WHEN p.id IS NOT NULL THEN NULL ELSE jsonb_build_object(
   'name',source.name,'phone',source.phone,'address',source.address) END)
 FROM (SELECT source.*) source
 LEFT JOIN public.ministry_people p ON p.id=source.person_id AND p.congregation_id=source.congregation_id
$$;

CREATE OR REPLACE FUNCTION public.ieadpe_transition_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; action text; current_row public.converts;
 receipt private.mutation_receipts; digest text; response jsonb; event_kind text;
 today date:=private.business_today(); elapsed integer; latest_lesson date;
 follow_up date; effective_active boolean; effective_start date;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','action']<>'{}'::jsonb OR jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'action') IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 target:=(payload->>'id')::uuid; action:=payload->>'action';
 IF action NOT IN ('visit','start','stop','complete','deviate') THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 SELECT * INTO current_row FROM public.converts WHERE id=target FOR UPDATE;
 IF current_row.id IS NULL OR NOT private.can_access_congregation(current_row.congregation_id) THEN
  RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ieadpe_transition_convert.operation_id;
 IF FOUND THEN
  IF receipt.command<>'transition_convert' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF current_row.deleted_at IS NOT NULL OR current_row.is_deviated OR current_row.is_discipleship_completed THEN
  RAISE EXCEPTION 'convert_terminal' USING ERRCODE='22023'; END IF;
 SELECT max(s.session_date) INTO latest_lesson FROM public.ministry_students st
  JOIN public.ministry_attendance a ON a.student_id=st.id AND a.congregation_id=st.congregation_id
  JOIN public.ministry_sessions s ON s.id=a.session_id AND s.congregation_id=a.congregation_id
  WHERE st.person_id=current_row.person_id AND st.congregation_id=current_row.congregation_id
   AND a.status='present' AND s.status='finalized';
 SELECT coalesce(bool_or(e.status='active'),false),min(e.start_date) FILTER (WHERE e.status='active')
  INTO effective_active,effective_start FROM public.ministry_students st
  JOIN public.ministry_enrollments e ON e.student_id=st.id AND e.congregation_id=st.congregation_id
  WHERE st.person_id=current_row.person_id AND st.congregation_id=current_row.congregation_id;
 effective_active:=effective_active OR current_row.is_in_discipleship;
 IF current_row.is_in_discipleship AND current_row.discipleship_start_date IS NOT NULL THEN
  effective_start:=least(effective_start,current_row.discipleship_start_date);
 END IF;
 follow_up:=greatest(current_row.last_visit_date,latest_lesson);
 IF action='visit' THEN
  elapsed:=today-coalesce(follow_up,current_row.conversion_date);
  IF elapsed < (CASE WHEN NOT current_row.was_visited_once AND follow_up IS NULL THEN 1
                     WHEN effective_active THEN 30 ELSE 7 END) THEN
   RAISE EXCEPTION 'visit_not_due' USING ERRCODE='22023'; END IF;
  UPDATE public.converts SET visit_count=visit_count+1,was_visited_once=true,last_visit_date=today,updated_at=now() WHERE id=target;
  event_kind:='visit';
 ELSIF action='start' THEN
  IF effective_active THEN RAISE EXCEPTION 'discipleship_active' USING ERRCODE='22023'; END IF;
  UPDATE public.converts SET is_in_discipleship=true,discipleship_start_date=today,updated_at=now() WHERE id=target;
  event_kind:='discipleship_started';
 ELSIF action='stop' THEN
  IF NOT current_row.is_in_discipleship THEN RAISE EXCEPTION 'discipleship_inactive' USING ERRCODE='22023'; END IF;
  UPDATE public.converts SET is_in_discipleship=false,updated_at=now() WHERE id=target;
 ELSIF action='complete' THEN
  IF NOT effective_active OR effective_start IS NULL OR today-effective_start<90 THEN
   RAISE EXCEPTION 'completion_not_due' USING ERRCODE='22023'; END IF;
  UPDATE public.converts SET is_discipleship_completed=true,is_in_discipleship=false,updated_at=now() WHERE id=target;
  event_kind:='discipleship_completed';
 ELSE
  IF current_row.visit_count<3 THEN RAISE EXCEPTION 'insufficient_visits' USING ERRCODE='22023'; END IF;
  UPDATE public.converts SET is_deviated=true,is_in_discipleship=false,updated_at=now() WHERE id=target;
  event_kind:='deviated';
 END IF;
 IF event_kind IS NOT NULL THEN
  INSERT INTO public.convert_events(convert_id,convert_name,congregation_id,event_type,event_date,done_by_email,created_by,created_at)
   SELECT target,current_row.name,current_row.congregation_id,event_kind,today,u.email,actor,now() FROM auth.users u WHERE u.id=actor;
 END IF;
 response:=jsonb_build_object('id',target);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'transition_convert',digest,response);
 RETURN response;
END $$;

CREATE FUNCTION private.ministry_cancel_session_command(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; congregation uuid; expected integer;
 receipt private.mutation_receipts; digest text; response jsonb; session_row public.ministry_sessions;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','expected_revision']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','expected_revision'] THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN target:=(payload->>'id')::uuid; congregation:=(payload->>'congregation_id')::uuid;
  expected:=(payload->>'expected_revision')::integer;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 IF jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ministry_cancel_session_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>'cancel_session' OR receipt.payload_hash<>digest THEN RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO session_row FROM public.ministry_sessions WHERE id=target AND congregation_id=congregation;
 IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.ministry_classes WHERE id=session_row.class_id FOR UPDATE;
 SELECT * INTO session_row FROM public.ministry_sessions WHERE id=target AND congregation_id=congregation FOR UPDATE;
 IF session_row.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
 IF session_row.status='canceled' THEN RAISE EXCEPTION 'session_canceled' USING ERRCODE='23514'; END IF;
 UPDATE public.ministry_sessions SET status='canceled',revision=revision+1,updated_at=now(),updated_by=actor
  WHERE id=target RETURNING revision INTO expected;
 response:=jsonb_build_object('id',target,'revision',expected,'status','canceled');
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'cancel_session',digest,response);
 RETURN response;
EXCEPTION WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;
REVOKE ALL ON FUNCTION private.ministry_cancel_session_command(uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_cancel_session(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_cancel_session_command(operation_id,payload) $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_cancel_session(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_cancel_session(uuid,jsonb) TO authenticated;
