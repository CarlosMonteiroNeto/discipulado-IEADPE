CREATE OR REPLACE FUNCTION private.ministry_academic_command(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); congregation uuid; target uuid; class_uuid uuid; student_uuid uuid; session_uuid uuid;
 expected integer; revision_value integer; record_name text; start_value date; end_value date; status_value text;
 row_class public.ministry_classes; row_enrollment public.ministry_enrollments; row_session public.ministry_sessions;
 receipt private.mutation_receipts; digest text; response jsonb; marks jsonb; finalizing boolean; roster_count integer; changed integer;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF command_name='save_class' THEN
  IF payload-ARRAY['id','congregation_id','name','teacher_contact_id','start_date','end_date','expected_revision']<>'{}'::jsonb OR
   NOT payload ?& ARRAY['id','congregation_id','name','teacher_contact_id','start_date','end_date'] THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  BEGIN target:=(payload->>'id')::uuid; congregation:=(payload->>'congregation_id')::uuid; start_value:=(payload->>'start_date')::date;
   end_value:=CASE WHEN jsonb_typeof(payload->'end_date')='string' THEN (payload->>'end_date')::date ELSE NULL END;
   class_uuid:=CASE WHEN jsonb_typeof(payload->'teacher_contact_id')='string' THEN (payload->>'teacher_contact_id')::uuid ELSE NULL END;
   expected:=CASE WHEN payload ? 'expected_revision' THEN (payload->>'expected_revision')::integer ELSE NULL END;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
  IF (payload->>'start_date') !~ '^\d{4}-\d{2}-\d{2}$' OR
   (jsonb_typeof(payload->'end_date')='string' AND (payload->>'end_date') !~ '^\d{4}-\d{2}-\d{2}$') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF jsonb_typeof(payload->'name') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'teacher_contact_id') NOT IN ('string','null') OR
   jsonb_typeof(payload->'end_date') NOT IN ('string','null') OR (payload ? 'expected_revision' AND jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  record_name:=btrim(payload->>'name'); IF record_name='' OR length(record_name)>200 OR (end_value IS NOT NULL AND end_value<start_value) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations WHERE id=congregation AND archived_at IS NULL FOR SHARE; IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 ELSIF command_name IN ('set_class_status','enroll_student','close_enrollment','create_session','cancel_session','save_attendance') THEN
  IF jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  BEGIN congregation:=(payload->>'congregation_id')::uuid; target:=CASE WHEN jsonb_typeof(payload->'id')='string' THEN (payload->>'id')::uuid ELSE NULL END;
   class_uuid:=CASE WHEN jsonb_typeof(payload->'class_id')='string' THEN (payload->>'class_id')::uuid ELSE NULL END;
   student_uuid:=CASE WHEN jsonb_typeof(payload->'student_id')='string' THEN (payload->>'student_id')::uuid ELSE NULL END;
   session_uuid:=CASE WHEN jsonb_typeof(payload->'session_id')='string' THEN (payload->>'session_id')::uuid ELSE NULL END;
   expected:=CASE WHEN jsonb_typeof(payload->'expected_revision')='number' THEN (payload->>'expected_revision')::integer ELSE NULL END;
   start_value:=CASE WHEN jsonb_typeof(payload->'start_date')='string' THEN (payload->>'start_date')::date WHEN jsonb_typeof(payload->'date')='string' THEN (payload->>'date')::date ELSE NULL END;
   end_value:=CASE WHEN jsonb_typeof(payload->'end_date')='string' THEN (payload->>'end_date')::date ELSE NULL END;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
  IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  IF command_name='set_class_status' AND (payload-ARRAY['id','congregation_id','status','expected_revision']<>'{}'::jsonb OR NOT payload ?& ARRAY['id','congregation_id','status','expected_revision'] OR expected IS NULL OR payload->>'status' NOT IN ('active','completed','archived')) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF command_name='enroll_student' AND (payload-ARRAY['id','congregation_id','class_id','student_id','start_date']<>'{}'::jsonb OR target IS NULL OR class_uuid IS NULL OR student_uuid IS NULL OR start_value IS NULL) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF command_name='close_enrollment' AND (payload-ARRAY['id','congregation_id','status','end_date','expected_revision']<>'{}'::jsonb OR NOT payload ?& ARRAY['id','congregation_id','status','end_date','expected_revision'] OR target IS NULL OR expected IS NULL OR payload->>'status' NOT IN ('completed','withdrawn') OR end_value IS NULL) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF command_name='create_session' AND (payload-ARRAY['id','congregation_id','class_id','date','topic']<>'{}'::jsonb OR NOT payload ?& ARRAY['id','congregation_id','class_id','date','topic'] OR target IS NULL OR class_uuid IS NULL OR start_value IS NULL OR jsonb_typeof(payload->'topic') NOT IN ('string','null')) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF command_name='cancel_session' AND (payload-ARRAY['id','congregation_id','expected_revision']<>'{}'::jsonb OR target IS NULL OR expected IS NULL) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF command_name='save_attendance' AND (payload-ARRAY['congregation_id','session_id','expected_revision','marks','finalize']<>'{}'::jsonb OR session_uuid IS NULL OR expected IS NULL OR jsonb_typeof(payload->'marks') IS DISTINCT FROM 'object' OR jsonb_typeof(payload->'finalize') IS DISTINCT FROM 'boolean') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF (jsonb_typeof(payload->'start_date')='string' AND (payload->>'start_date') !~ '^\d{4}-\d{2}-\d{2}$') OR
   (jsonb_typeof(payload->'date')='string' AND (payload->>'date') !~ '^\d{4}-\d{2}-\d{2}$') OR
   (jsonb_typeof(payload->'end_date')='string' AND (payload->>'end_date') !~ '^\d{4}-\d{2}-\d{2}$') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 ELSE RAISE EXCEPTION 'invalid_command' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ministry_academic_command.operation_id;
 IF FOUND THEN IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF; RETURN receipt.result; END IF;
 IF command_name='save_class' AND class_uuid IS NOT NULL AND NOT EXISTS(
  SELECT FROM public.ministry_contacts c WHERE c.id=class_uuid AND c.congregation_id=congregation AND c.scope='congregation' AND c.role_code='teacher' AND c.archived_at IS NULL
 ) THEN RAISE EXCEPTION 'invalid_teacher' USING ERRCODE='22023'; END IF;
 IF command_name='save_class' THEN
  SELECT * INTO row_class FROM public.ministry_classes WHERE id=target FOR UPDATE;
  IF expected IS NULL THEN
   IF row_class.id IS NOT NULL THEN RAISE EXCEPTION 'record_exists' USING ERRCODE='23505'; END IF;
   INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,teacher_contact_id,start_date,end_date,updated_by)
   VALUES(target,congregation,record_name,lower(record_name),class_uuid,start_value,end_value,actor) RETURNING revision INTO revision_value;
  ELSE
   IF row_class.id IS NULL OR row_class.congregation_id<>congregation THEN RAISE EXCEPTION 'class_not_found' USING ERRCODE='22023'; END IF;
   IF row_class.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
   UPDATE public.ministry_classes SET name=record_name,normalized_name=lower(record_name),teacher_contact_id=class_uuid,start_date=start_value,end_date=end_value,revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
  END IF;
 ELSIF command_name='set_class_status' THEN
  SELECT * INTO row_class FROM public.ministry_classes WHERE id=target AND congregation_id=congregation FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'class_not_found' USING ERRCODE='22023'; END IF;
  IF row_class.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  UPDATE public.ministry_classes SET status=payload->>'status',revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
 ELSIF command_name='enroll_student' THEN
  SELECT * INTO row_class FROM public.ministry_classes WHERE id=class_uuid AND congregation_id=congregation FOR UPDATE;
  IF NOT FOUND OR row_class.status<>'active' THEN RAISE EXCEPTION 'class_not_active' USING ERRCODE='23514'; END IF;
  PERFORM 1 FROM public.ministry_students WHERE id=student_uuid AND congregation_id=congregation AND archived_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
  IF (SELECT count(*) FROM public.ministry_enrollments WHERE class_id=class_uuid)>=100 THEN RAISE EXCEPTION 'class_capacity' USING ERRCODE='23514'; END IF;
  INSERT INTO public.ministry_enrollments(id,congregation_id,class_id,student_id,start_date,updated_by) VALUES(target,congregation,class_uuid,student_uuid,start_value,actor) RETURNING revision INTO revision_value;
 ELSIF command_name='close_enrollment' THEN
  SELECT * INTO row_enrollment FROM public.ministry_enrollments WHERE id=target AND congregation_id=congregation;
  IF NOT FOUND THEN RAISE EXCEPTION 'enrollment_not_found' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.ministry_classes WHERE id=row_enrollment.class_id FOR UPDATE;
  SELECT * INTO row_enrollment FROM public.ministry_enrollments WHERE id=target AND congregation_id=congregation FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'enrollment_not_found' USING ERRCODE='22023'; END IF;
  IF row_enrollment.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF row_enrollment.status<>'active' THEN RAISE EXCEPTION 'enrollment_closed' USING ERRCODE='23514'; END IF;
  IF end_value<row_enrollment.start_date THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  UPDATE public.ministry_enrollments SET status=payload->>'status',end_date=end_value,revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
 ELSIF command_name='create_session' THEN
  SELECT * INTO row_class FROM public.ministry_classes WHERE id=class_uuid AND congregation_id=congregation FOR SHARE;
  IF NOT FOUND OR row_class.status<>'active' THEN RAISE EXCEPTION 'class_not_active' USING ERRCODE='23514'; END IF;
  INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,topic,updated_by) VALUES(target,congregation,class_uuid,start_value,payload->>'topic',actor) RETURNING revision INTO revision_value;
  response:=jsonb_build_object('id',target,'revision',revision_value,'status','open');
 ELSIF command_name='cancel_session' THEN
  SELECT * INTO row_session FROM public.ministry_sessions WHERE id=target AND congregation_id=congregation;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.ministry_classes WHERE id=row_session.class_id FOR UPDATE;
  SELECT * INTO row_session FROM public.ministry_sessions WHERE id=target AND congregation_id=congregation FOR UPDATE;
  IF row_session.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF row_session.status='finalized' THEN RAISE EXCEPTION 'session_finalized' USING ERRCODE='23514'; END IF;
  UPDATE public.ministry_sessions SET status='canceled',revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
  response:=jsonb_build_object('id',target,'revision',revision_value,'status','canceled');
 ELSIF command_name='save_attendance' THEN
  SELECT * INTO row_session FROM public.ministry_sessions WHERE id=session_uuid AND congregation_id=congregation;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.ministry_classes WHERE id=row_session.class_id FOR UPDATE;
  SELECT * INTO row_session FROM public.ministry_sessions WHERE id=session_uuid FOR UPDATE;
  IF row_session.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF row_session.status='canceled' THEN RAISE EXCEPTION 'session_canceled' USING ERRCODE='23514'; END IF;
  marks:=payload->'marks'; finalizing:=(payload->>'finalize')::boolean;
  IF NOT row_session.roster_frozen THEN
   INSERT INTO public.ministry_session_roster(congregation_id,session_id,enrollment_id,student_id,student_name,updated_by)
    SELECT congregation,row_session.id,e.id,e.student_id,s.name,actor FROM public.ministry_enrollments e JOIN public.ministry_students s ON s.id=e.student_id
    WHERE e.class_id=row_session.class_id AND e.congregation_id=congregation AND e.start_date<=row_session.session_date AND (e.end_date IS NULL OR e.end_date>=row_session.session_date)
    ORDER BY e.id;
   UPDATE public.ministry_sessions SET roster_frozen=true WHERE id=row_session.id;
  END IF;
  SELECT count(*) INTO roster_count FROM public.ministry_session_roster WHERE session_id=row_session.id;
  IF (SELECT count(*) FROM jsonb_object_keys(marks))<>roster_count OR EXISTS(
   SELECT 1 FROM public.ministry_session_roster r WHERE r.session_id=row_session.id AND NOT marks ? r.enrollment_id::text) OR EXISTS(
   SELECT 1 FROM jsonb_each_text(marks) m WHERE m.value NOT IN ('present','absent','excused','unmarked')) THEN RAISE EXCEPTION 'roster_mismatch' USING ERRCODE='23514'; END IF;
  IF finalizing AND (roster_count=0 OR EXISTS(SELECT FROM jsonb_each_text(marks) WHERE value='unmarked') OR row_session.session_date>(now() AT TIME ZONE 'America/Recife')::date) THEN RAISE EXCEPTION 'attendance_incomplete' USING ERRCODE='23514'; END IF;
  IF row_session.status='finalized' AND NOT finalizing THEN RAISE EXCEPTION 'session_finalized' USING ERRCODE='23514'; END IF;
  INSERT INTO public.ministry_attendance(congregation_id,session_id,enrollment_id,student_id,status,updated_by)
   SELECT congregation,row_session.id,r.enrollment_id,r.student_id,marks->>r.enrollment_id::text,actor FROM public.ministry_session_roster r WHERE r.session_id=row_session.id
   ON CONFLICT(session_id,enrollment_id) DO UPDATE SET status=EXCLUDED.status,revision=public.ministry_attendance.revision+1,updated_at=now(),updated_by=actor;
  UPDATE public.ministry_sessions SET status=CASE WHEN finalizing THEN 'finalized' ELSE 'open' END,revision=revision+1,updated_at=now(),updated_by=actor WHERE id=row_session.id RETURNING revision INTO revision_value;
  response:=jsonb_build_object('id',row_session.id,'revision',revision_value,'status',CASE WHEN finalizing THEN 'finalized' ELSE 'open' END,'roster_frozen',true,'attendance_count',roster_count);
 END IF;
 IF response IS NULL THEN response:=jsonb_build_object('id',target,'revision',revision_value); END IF;
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result) VALUES(actor,operation_id,command_name,digest,response);
 RETURN response;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;