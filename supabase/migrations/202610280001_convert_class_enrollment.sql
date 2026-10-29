-- Starting discipleship enrolls the canonical person atomically in an active local class.
CREATE OR REPLACE FUNCTION public.ieadpe_transition_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; action text; current_row public.converts;
 receipt private.mutation_receipts; digest text; response jsonb; event_kind text;
 today date:=private.business_today(); elapsed integer; latest_lesson date;
 follow_up date; effective_active boolean; effective_start date; class_uuid uuid; enrollment_result jsonb;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','action','class_id']<>'{}'::jsonb OR jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'action') IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 target:=(payload->>'id')::uuid; action:=payload->>'action';
 IF (action='start' AND jsonb_typeof(payload->'class_id') IS DISTINCT FROM 'string') OR
  (action<>'start' AND payload ? 'class_id') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
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
  IF current_row.person_id IS NULL THEN RAISE EXCEPTION 'person_link_required' USING ERRCODE='22023'; END IF;
  BEGIN class_uuid:=(payload->>'class_id')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
  enrollment_result:=public.ieadpe_ministry_enroll_student(
   md5('convert-start-enrollment|'||actor::text||'|'||operation_id::text)::uuid,
   jsonb_build_object('id',md5('convert-start-id|'||actor::text||'|'||operation_id::text)::uuid,
    'congregation_id',current_row.congregation_id,'class_id',class_uuid,
    'person_id',current_row.person_id,'start_date',today));
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
