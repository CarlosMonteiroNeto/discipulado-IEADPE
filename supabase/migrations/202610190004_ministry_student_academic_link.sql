BEGIN;

-- Student detail is deliberately scoped to one active congregation. Identity
-- fields come from ministry_people when linked; the academic extension keeps
-- its own revision and lifecycle.
CREATE FUNCTION public.ieadpe_ministry_get_student(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; student_uuid uuid; student_row public.ministry_students;
 person_row public.ministry_people;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','student_id']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','student_id'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'student_id') IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  scope_id:=(request->>'congregation_id')::uuid;
  student_uuid:=(request->>'student_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO student_row FROM public.ministry_students s
  WHERE s.id=student_uuid AND s.congregation_id=scope_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
 SELECT * INTO person_row FROM public.ministry_people p
  WHERE p.id=student_row.person_id AND p.congregation_id=scope_id;
 RETURN jsonb_build_object('student',jsonb_build_object(
  'id',student_row.id,'person_id',student_row.person_id,
  'congregation_id',student_row.congregation_id,
  'name',coalesce(person_row.name,student_row.name),
  'normalized_name',coalesce(person_row.normalized_name,student_row.normalized_name),
  'phone_e164',CASE WHEN person_row.id IS NULL THEN student_row.phone_e164 ELSE person_row.phone END,
  'birth_date',CASE WHEN person_row.id IS NULL THEN student_row.birth_date ELSE person_row.birth_date END,
  'address',CASE WHEN person_row.id IS NULL THEN student_row.address ELSE person_row.address END,
  'education',student_row.education,'marital_status',student_row.marital_status,
  'new_convert',student_row.new_convert,'water_baptized',student_row.water_baptized,
  'wants_baptism',student_row.wants_baptism,'archived_at',student_row.archived_at,
  'revision',student_row.revision,'person_revision',person_row.revision,
  'link_state',CASE WHEN student_row.person_id IS NULL THEN 'unlinked' ELSE 'linked' END,
  'created_at',student_row.created_at,'updated_at',student_row.updated_at,
  'updated_by',student_row.updated_by));
END $$;

-- Include archived rows in the same bounded page so operators can reopen a
-- student's history and restore the record. The response and cursor contract
-- remain unchanged; archive state is already part of each row projection.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_students(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; prefix text; cursor_text text; cursor_data jsonb;
 after_name text; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','name_prefix','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','limit'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'name_prefix' AND jsonb_typeof(request->'name_prefix') NOT IN ('string','null')) OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 prefix:=request->>'name_prefix';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix) OR length(prefix)>200) THEN
  RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'students');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','name','student_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_id:=(cursor_data->>'student_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id,s.congregation_id,s.person_id,p.revision AS person_revision,
   coalesce(p.name,s.name) AS name,coalesce(p.normalized_name,s.normalized_name) AS normalized_name,
   CASE WHEN p.id IS NULL THEN s.phone_e164 ELSE p.phone END AS phone,
   CASE WHEN p.id IS NULL THEN s.birth_date ELSE p.birth_date END AS birth_date,
   CASE WHEN p.id IS NULL THEN s.address ELSE p.address END AS address,
   s.education,s.marital_status,s.new_convert,s.water_baptized,s.wants_baptism,
   s.archived_at,s.revision
  FROM public.ministry_students s
  LEFT JOIN public.ministry_people p ON p.id=s.person_id AND p.congregation_id=s.congregation_id
  WHERE s.congregation_id=scope_id AND
   (prefix IS NULL OR left(coalesce(p.normalized_name,s.normalized_name),length(lower(prefix)))=lower(prefix)) AND
   (after_name IS NULL OR (coalesce(p.normalized_name,s.normalized_name),s.id)>(after_name,after_id))
  ORDER BY coalesce(p.normalized_name,s.normalized_name),s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'person_id',p.person_id,
  'congregation_id',p.congregation_id,'name',p.name,'phone',p.phone,'birth_date',p.birth_date,
  'address',p.address,'education',p.education,'marital_status',p.marital_status,
  'new_convert',p.new_convert,'water_baptized',p.water_baptized,'wants_baptism',p.wants_baptism,
  'archived_at',p.archived_at,'revision',p.revision,'person_revision',p.person_revision,
  'link_state',CASE WHEN p.person_id IS NULL THEN 'unlinked' ELSE 'linked' END)
  ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*) INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','students','congregation_id',scope_id,'name_prefix',prefix,
   'name',lower(tail->>'name'),'student_id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

-- Preserve the actionable active-enrollment error at the RPC boundary. The
-- legacy registry helper maps check violations to a generic registry error,
-- so this wrapper performs the same-scope lock and guard before delegating.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_set_student_archived(
 operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; scope_id uuid; expected integer;
 student_row public.ministry_students;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','archived','expected_revision']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','archived','expected_revision'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'archived') IS DISTINCT FROM 'boolean' OR
  jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
  (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid;
  scope_id:=(payload->>'congregation_id')::uuid;
  expected:=(payload->>'expected_revision')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 IF (payload->>'archived')::boolean THEN
  SELECT * INTO student_row FROM public.ministry_students s
   WHERE s.id=target AND s.congregation_id=scope_id FOR UPDATE;
  IF FOUND AND student_row.revision=expected AND EXISTS(
   SELECT FROM public.ministry_enrollments e
   WHERE e.student_id=target AND e.congregation_id=scope_id AND e.status='active') THEN
   RAISE EXCEPTION 'active_enrollment' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN private.ministry_registry_command('set_student_archived',operation_id,payload);
END $$;

-- Teacher detail intentionally returns only the fields needed by the editor.
CREATE FUNCTION public.ieadpe_ministry_get_teacher_contact(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; contact_uuid uuid; contact_row public.ministry_contacts;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','contact_id']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','contact_id'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'contact_id') IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  scope_id:=(request->>'congregation_id')::uuid;
  contact_uuid:=(request->>'contact_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO contact_row FROM public.ministry_contacts c
  WHERE c.id=contact_uuid AND c.congregation_id=scope_id AND c.scope='congregation'
   AND c.role_code='teacher' AND c.archived_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
 RETURN jsonb_build_object('contact',jsonb_build_object(
  'id',contact_row.id,'congregation_id',contact_row.congregation_id,
  'name',contact_row.name,'phone_e164',contact_row.phone_e164,
  'birth_date',contact_row.birth_date,'revision',contact_row.revision));
END $$;

-- Enrollment now accepts a canonical person. In one transaction it creates
-- or reuses that person's same-scope academic row, then invokes the existing
-- academic enrollment command. The outer receipt keeps the reviewed envelope
-- and wraps the inner command's response with both linked IDs and revisions.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_enroll_student(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); scope_id uuid; target uuid; class_uuid uuid;
 person_uuid uuid; start_value date; person_row public.ministry_people;
 student_row public.ministry_students; receipt private.mutation_receipts;
 digest text; response jsonb; academic_result jsonb; internal_operation uuid;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','class_id','person_id','start_date']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','class_id','person_id','start_date'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'class_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'person_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'start_date') IS DISTINCT FROM 'string' OR
  payload->>'start_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid;
  scope_id:=(payload->>'congregation_id')::uuid;
  class_uuid:=(payload->>'class_id')::uuid;
  person_uuid:=(payload->>'person_id')::uuid;
  start_value:=(payload->>'start_date')::date;
 EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
 END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ieadpe_ministry_enroll_student.operation_id;
 IF FOUND THEN
  IF receipt.command<>'enroll_student' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO person_row FROM public.ministry_people p
  WHERE p.id=person_uuid AND p.congregation_id=scope_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'person_not_found' USING ERRCODE='22023'; END IF;
 INSERT INTO public.ministry_students(
  congregation_id,person_id,name,normalized_name,phone_e164,birth_date,address,updated_by)
 VALUES(scope_id,person_uuid,person_row.name,person_row.normalized_name,
  CASE WHEN person_row.phone ~ '^\+[1-9][0-9]{1,14}$' THEN person_row.phone ELSE NULL END,
  person_row.birth_date,person_row.address,actor)
 ON CONFLICT (person_id) WHERE person_id IS NOT NULL DO NOTHING;
 SELECT * INTO student_row FROM public.ministry_students s
  WHERE s.person_id=person_uuid AND s.congregation_id=scope_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
 IF student_row.archived_at IS NOT NULL THEN RAISE EXCEPTION 'student_archived' USING ERRCODE='22023'; END IF;
 internal_operation:=md5('ministry-enrollment|'||actor::text||'|'||operation_id::text)::uuid;
 academic_result:=private.ministry_academic_command('enroll_student',internal_operation,
  jsonb_build_object('id',target,'congregation_id',scope_id,'class_id',class_uuid,
   'student_id',student_row.id,'start_date',start_value));
 response:=jsonb_build_object('id',target,'student_id',student_row.id,
  'person_id',person_uuid,'revision',(academic_result->>'revision')::integer,
  'student_revision',student_row.revision);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'enroll_student',digest,response);
 RETURN response;
END $$;

-- A convert can be linked only through its canonical person. Existing student
-- identity is never silently merged; an unlinked academic row can be attached
-- only after the user explicitly selects it and supplies its current revision.
CREATE OR REPLACE FUNCTION public.ieadpe_promote_convert_to_student(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); convert_uuid uuid; scope_id uuid; student_uuid uuid;
 expected integer; convert_row public.converts; student_row public.ministry_students;
 person_row public.ministry_people; receipt private.mutation_receipts;
 digest text; response jsonb; phone_value text; constraint_name text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['convert_id','congregation_id','student_id','expected_student_revision']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['convert_id','congregation_id','student_id'] OR
  jsonb_typeof(payload->'convert_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'student_id') NOT IN ('string','null') OR
  (jsonb_typeof(payload->'student_id')='null' AND payload ? 'expected_student_revision') OR
  (jsonb_typeof(payload->'student_id')='string' AND
   (NOT payload ? 'expected_student_revision' OR
    jsonb_typeof(payload->'expected_student_revision') IS DISTINCT FROM 'number' OR
    (payload->'expected_student_revision')::text !~ '^[1-9][0-9]*$')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  convert_uuid:=(payload->>'convert_id')::uuid;
  scope_id:=(payload->>'congregation_id')::uuid;
  student_uuid:=CASE WHEN jsonb_typeof(payload->'student_id')='string'
   THEN (payload->>'student_id')::uuid ELSE NULL END;
  expected:=CASE WHEN payload ? 'expected_student_revision'
   THEN (payload->>'expected_student_revision')::integer ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
 END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO convert_row FROM public.converts c WHERE c.id=convert_uuid FOR UPDATE;
 IF NOT FOUND OR convert_row.congregation_id IS DISTINCT FROM scope_id THEN
  RAISE EXCEPTION 'convert_unavailable' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ieadpe_promote_convert_to_student.operation_id;
 IF FOUND THEN
  IF receipt.command<>'promote_convert_to_student' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF convert_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'convert_unavailable' USING ERRCODE='22023'; END IF;
 IF convert_row.person_id IS NULL THEN RAISE EXCEPTION 'person_link_required' USING ERRCODE='22023'; END IF;
 SELECT * INTO person_row FROM public.ministry_people p
  WHERE p.id=convert_row.person_id AND p.congregation_id=scope_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'person_link_required' USING ERRCODE='22023'; END IF;
 IF student_uuid IS NULL THEN
  IF EXISTS(SELECT FROM public.ministry_students s WHERE s.person_id=person_row.id) THEN
   RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023'; END IF;
  phone_value:=person_row.phone;
  IF phone_value IS NOT NULL AND phone_value !~ '^\+[1-9][0-9]{1,14}$' THEN phone_value:=NULL; END IF;
  student_uuid:=gen_random_uuid();
  INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,
   phone_e164,birth_date,address,convert_id,promoted_at,convert_snapshot,updated_by)
  VALUES(student_uuid,scope_id,person_row.id,person_row.name,person_row.normalized_name,
   phone_value,person_row.birth_date,person_row.address,convert_uuid,now(),
   jsonb_build_object('name',convert_row.name,'phone',convert_row.phone,
    'address',convert_row.address),actor)
  RETURNING * INTO student_row;
 ELSE
  SELECT * INTO student_row FROM public.ministry_students s
   WHERE s.id=student_uuid FOR UPDATE;
  IF NOT FOUND OR student_row.congregation_id IS DISTINCT FROM scope_id OR
   student_row.archived_at IS NOT NULL OR student_row.convert_id IS NOT NULL THEN
   RAISE EXCEPTION 'candidate_unavailable' USING ERRCODE='22023'; END IF;
  IF student_row.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF student_row.person_id IS NOT NULL AND student_row.person_id<>person_row.id THEN
   RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023'; END IF;
  IF student_row.person_id IS NULL AND EXISTS(SELECT FROM public.ministry_students s
   WHERE s.person_id=person_row.id AND s.id<>student_uuid) THEN
   RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023'; END IF;
  UPDATE public.ministry_students SET person_id=person_row.id,convert_id=convert_uuid,
   promoted_at=now(),convert_snapshot=jsonb_build_object('name',convert_row.name,
    'phone',convert_row.phone,'address',convert_row.address),
   revision=revision+1,updated_at=now(),updated_by=actor
  WHERE id=student_uuid RETURNING * INTO student_row;
 END IF;
 response:=jsonb_build_object('convert_id',convert_uuid,'student_id',student_uuid,
  'person_id',person_row.id,'congregation_id',scope_id,'status','linked');
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'promote_convert_to_student',digest,response);
 RETURN response;
EXCEPTION WHEN unique_violation THEN
 GET STACKED DIAGNOSTICS constraint_name=CONSTRAINT_NAME;
 IF constraint_name='ministry_students_one_convert_link' THEN
  RAISE EXCEPTION 'convert_already_linked' USING ERRCODE='22023';
 END IF;
 RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023';
END $$;

REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_student(jsonb),
 public.ieadpe_ministry_get_teacher_contact(jsonb),
 public.ieadpe_ministry_enroll_student(uuid,jsonb),
 public.ieadpe_promote_convert_to_student(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_student(jsonb),
 public.ieadpe_ministry_get_teacher_contact(jsonb),
 public.ieadpe_ministry_enroll_student(uuid,jsonb),
 public.ieadpe_promote_convert_to_student(uuid,jsonb) TO authenticated;

COMMIT;
