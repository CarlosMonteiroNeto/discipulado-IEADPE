CREATE FUNCTION private.ministry_registry_command(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 actor uuid:=auth.uid(); receipt private.mutation_receipts; digest text; response jsonb;
 target uuid; previous_id uuid; congregation uuid; scope_text text; role_text text; record_name text; normalized text;
 phone_text text; birth date; expected integer; archived boolean; revision_value integer;
 contact public.ministry_contacts; previous_contact public.ministry_contacts; new_contact public.ministry_contacts;
 slot public.ministry_role_slots; student public.ministry_students; address_value jsonb; field_name text; field_value jsonb;
 allowed_roles constant text[]:=ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'];
 trim_chars constant text:=U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);

 IF command_name IN ('save_contact','set_contact_archived') THEN
  IF command_name='save_contact' THEN
   IF payload-ARRAY['id','scope','congregation_id','name','role_code','phone_e164','birth_date','expected_revision']<>'{}'::jsonb OR
    NOT payload ?& ARRAY['id','scope','congregation_id','name','role_code','phone_e164','birth_date'] OR
    jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'scope') IS DISTINCT FROM 'string' OR
    jsonb_typeof(payload->'name') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'role_code') NOT IN ('string','null') OR
    jsonb_typeof(payload->'phone_e164') NOT IN ('string','null') OR jsonb_typeof(payload->'birth_date') NOT IN ('string','null') OR
    jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') OR
    (payload ? 'expected_revision' AND (jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR (payload->'expected_revision')::text !~ '^[1-9][0-9]*$')) THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  ELSE
   IF payload-ARRAY['id','scope','congregation_id','archived','expected_revision']<>'{}'::jsonb OR
    NOT payload ?& ARRAY['id','scope','congregation_id','archived','expected_revision'] OR
    jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'scope') IS DISTINCT FROM 'string' OR
    jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') OR jsonb_typeof(payload->'archived') IS DISTINCT FROM 'boolean' OR
    jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  END IF;
  BEGIN
   target:=(payload->>'id')::uuid;
   congregation:=CASE WHEN jsonb_typeof(payload->'congregation_id')='string' THEN (payload->>'congregation_id')::uuid ELSE NULL END;
   expected:=CASE WHEN payload ? 'expected_revision' THEN (payload->>'expected_revision')::integer ELSE NULL END;
   IF command_name='save_contact' THEN
    scope_text:=payload->>'scope'; role_text:=payload->>'role_code';
    record_name:=btrim(payload->>'name',trim_chars); normalized:=lower(record_name); phone_text:=payload->>'phone_e164';
    IF jsonb_typeof(payload->'birth_date')='string' THEN
     IF payload->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
     birth:=(payload->>'birth_date')::date;
    END IF;
   ELSE scope_text:=payload->>'scope'; archived:=(payload->>'archived')::boolean; END IF;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
  END;
  IF scope_text NOT IN ('congregation','supervision') OR (scope_text='congregation' AND congregation IS NULL) OR
   (scope_text='supervision' AND congregation IS NOT NULL) THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
  IF scope_text='congregation' THEN
   IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
   PERFORM 1 FROM public.congregations WHERE id=congregation AND archived_at IS NULL FOR SHARE;
   IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
  ELSIF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  IF command_name='save_contact' AND (record_name='' OR length(record_name)>200 OR
   (phone_text IS NOT NULL AND phone_text !~ '^\+[1-9][0-9]{1,14}$') OR
   (role_text IS NOT NULL AND NOT (role_text=ANY(allowed_roles) AND
    ((scope_text='congregation' AND role_text=ANY(ARRAY['congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'])) OR
     (scope_text='supervision' AND role_text=ANY(ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary'])))))) THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;

 ELSIF command_name='replace_role_holder' THEN
  IF payload-ARRAY['scope','congregation_id','role_code','previous_contact_id','previous_expected_revision','id','expected_revision']<>'{}'::jsonb OR
   NOT payload ?& ARRAY['scope','congregation_id','role_code','previous_contact_id','previous_expected_revision','id','expected_revision'] OR
   jsonb_typeof(payload->'scope') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') OR
   jsonb_typeof(payload->'role_code') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'previous_contact_id') IS DISTINCT FROM 'string' OR
   jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'previous_expected_revision') IS DISTINCT FROM 'number' OR
   (payload->'previous_expected_revision')::text !~ '^[1-9][0-9]*$' OR jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
   (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  BEGIN
   congregation:=CASE WHEN jsonb_typeof(payload->'congregation_id')='string' THEN (payload->>'congregation_id')::uuid ELSE NULL END;
   target:=(payload->>'id')::uuid; expected:=(payload->>'expected_revision')::integer;
   previous_id:=(payload->>'previous_contact_id')::uuid;
   revision_value:=(payload->>'previous_expected_revision')::integer;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
  scope_text:=payload->>'scope'; role_text:=payload->>'role_code';
  IF scope_text NOT IN ('congregation','supervision') OR (scope_text='congregation' AND congregation IS NULL) OR
   (scope_text='supervision' AND congregation IS NOT NULL) OR NOT role_text=ANY(allowed_roles) OR
   (scope_text='congregation' AND role_text=ANY(ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary'])) OR
   (scope_text='supervision' AND role_text=ANY(ARRAY['congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'])) THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF (scope_text='congregation' AND NOT private.ministry_can_access(congregation)) OR (scope_text='supervision' AND NOT private.ministry_supervisor()) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;

 ELSIF command_name IN ('save_student','set_student_archived') THEN
  IF command_name='save_student' THEN
   IF payload-ARRAY['id','congregation_id','name','phone_e164','birth_date','address','education','marital_status','new_convert','water_baptized','wants_baptism','expected_revision']<>'{}'::jsonb OR
    NOT payload ?& ARRAY['id','congregation_id','name'] OR jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
    jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'name') IS DISTINCT FROM 'string' OR
    (payload ? 'expected_revision' AND (jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR (payload->'expected_revision')::text !~ '^[1-9][0-9]*$')) THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   IF (payload ? 'phone_e164' AND jsonb_typeof(payload->'phone_e164') NOT IN ('string','null')) OR
    (payload ? 'birth_date' AND jsonb_typeof(payload->'birth_date') NOT IN ('string','null')) OR
    (payload ? 'education' AND jsonb_typeof(payload->'education') NOT IN ('string','null')) OR
    (payload ? 'marital_status' AND jsonb_typeof(payload->'marital_status') NOT IN ('string','null')) OR
    (payload ? 'new_convert' AND jsonb_typeof(payload->'new_convert') NOT IN ('boolean','null')) OR
    (payload ? 'water_baptized' AND jsonb_typeof(payload->'water_baptized') NOT IN ('boolean','null')) OR
    (payload ? 'wants_baptism' AND jsonb_typeof(payload->'wants_baptism') NOT IN ('boolean','null')) OR
    (payload ? 'address' AND jsonb_typeof(payload->'address') NOT IN ('object','null')) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   address_value:=payload->'address';
   IF address_value IS NOT NULL AND address_value<>'null'::jsonb AND
    (address_value-ARRAY['street','district','city','postal_code','state_code']<>'{}'::jsonb OR EXISTS(
     SELECT FROM jsonb_each(address_value) a WHERE jsonb_typeof(a.value) NOT IN ('string','null'))) THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   IF payload ? 'birth_date' AND jsonb_typeof(payload->'birth_date')='string' AND payload->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  ELSE
   IF payload-ARRAY['id','congregation_id','archived','expected_revision']<>'{}'::jsonb OR
    NOT payload ?& ARRAY['id','congregation_id','archived','expected_revision'] OR jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
    jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'archived') IS DISTINCT FROM 'boolean' OR
    jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  END IF;
  BEGIN
   target:=(payload->>'id')::uuid; congregation:=(payload->>'congregation_id')::uuid;
   expected:=CASE WHEN payload ? 'expected_revision' THEN (payload->>'expected_revision')::integer ELSE NULL END;
   IF command_name='save_student' THEN
    record_name:=btrim(payload->>'name',trim_chars); normalized:=lower(record_name); phone_text:=payload->>'phone_e164';
    IF jsonb_typeof(payload->'birth_date')='string' THEN birth:=(payload->>'birth_date')::date; ELSE birth:=NULL; END IF;
   ELSE archived:=(payload->>'archived')::boolean; END IF;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
  IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations WHERE id=congregation AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
  IF command_name='save_student' AND (record_name='' OR length(record_name)>200 OR
   (phone_text IS NOT NULL AND phone_text !~ '^\+[1-9][0-9]{1,14}$') OR
   (payload->>'water_baptized')='true' AND (payload->>'wants_baptism')='true') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;

 ELSE RAISE EXCEPTION 'invalid_command' USING ERRCODE='22023'; END IF;

 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ministry_registry_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;

 IF command_name IN ('save_contact','set_contact_archived') THEN
  SELECT * INTO contact FROM public.ministry_contacts WHERE id=target FOR UPDATE;
  IF payload ? 'expected_revision' THEN
   IF contact.id IS NULL OR contact.scope<>scope_text OR contact.congregation_id IS DISTINCT FROM congregation THEN RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
   IF contact.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
   IF command_name='save_contact' THEN
    UPDATE public.ministry_contacts SET name=record_name,normalized_name=normalized,role_code=role_text,phone_e164=phone_text,birth_date=birth,
     revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
   ELSE
    IF archived AND EXISTS(SELECT FROM public.ministry_role_slots WHERE contact_id=target AND archived_at IS NULL) THEN RAISE EXCEPTION 'role_holder_assigned' USING ERRCODE='23514'; END IF;
    UPDATE public.ministry_contacts SET archived_at=CASE WHEN archived THEN coalesce(archived_at,now()) ELSE NULL END,
     revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
   END IF;
  ELSE
   IF contact.id IS NOT NULL THEN RAISE EXCEPTION 'record_exists' USING ERRCODE='23505'; END IF;
   IF command_name='set_contact_archived' THEN RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
   INSERT INTO public.ministry_contacts(id,congregation_id,scope,name,normalized_name,role_code,phone_e164,birth_date,updated_by)
    VALUES(target,congregation,scope_text,record_name,normalized,role_text,phone_text,birth,actor);
   revision_value:=1;
  END IF;
  response:=jsonb_build_object('id',target,'revision',revision_value);

 ELSIF command_name='replace_role_holder' THEN
  PERFORM 1 FROM public.ministry_contacts WHERE id IN (target,previous_id) ORDER BY id FOR UPDATE;
  SELECT * INTO new_contact FROM public.ministry_contacts WHERE id=target;
  SELECT * INTO previous_contact FROM public.ministry_contacts WHERE id=previous_id;
  IF new_contact.id IS NULL OR previous_contact.id IS NULL OR new_contact.scope<>scope_text OR previous_contact.scope<>scope_text OR
   new_contact.congregation_id IS DISTINCT FROM congregation OR previous_contact.congregation_id IS DISTINCT FROM congregation THEN
   RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
  IF new_contact.archived_at IS NOT NULL OR previous_contact.archived_at IS NOT NULL OR new_contact.role_code IS DISTINCT FROM role_text OR
   previous_contact.role_code IS DISTINCT FROM role_text THEN RAISE EXCEPTION 'invalid_role_holder' USING ERRCODE='23514'; END IF;
  IF new_contact.revision<>expected OR previous_contact.revision<>revision_value THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF new_contact.id=previous_id OR EXISTS(SELECT FROM public.ministry_role_slots s WHERE s.contact_id=target AND s.archived_at IS NULL) THEN
   RAISE EXCEPTION 'contact_already_assigned' USING ERRCODE='23505'; END IF;
  SELECT * INTO slot FROM public.ministry_role_slots s WHERE s.scope=scope_text AND s.congregation_id IS NOT DISTINCT FROM congregation AND
   s.role_code=role_text AND s.archived_at IS NULL FOR UPDATE;
  IF slot.id IS NULL OR slot.contact_id IS DISTINCT FROM previous_id THEN RAISE EXCEPTION 'role_slot_conflict' USING ERRCODE='40001'; END IF;
  UPDATE public.ministry_role_slots SET contact_id=target,revision=revision+1,updated_at=now(),updated_by=actor WHERE id=slot.id;
  UPDATE public.ministry_contacts SET revision=revision+1,updated_at=now(),updated_by=actor WHERE id IN (target,previous_id);
  response:=jsonb_build_object('id',target,'revision',expected+1,'previous_contact_id',previous_id,'previous_revision',revision_value+1);

 ELSIF command_name='save_student' THEN
  SELECT * INTO student FROM public.ministry_students WHERE id=target FOR UPDATE;
  IF payload ? 'expected_revision' THEN
   IF student.id IS NULL OR student.congregation_id<>congregation THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
   IF student.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
   IF student.archived_at IS NOT NULL THEN RAISE EXCEPTION 'student_archived' USING ERRCODE='22023'; END IF;
   UPDATE public.ministry_students SET name=record_name,normalized_name=normalized,
    phone_e164=CASE WHEN payload ? 'phone_e164' THEN phone_text ELSE phone_e164 END,
    birth_date=CASE WHEN payload ? 'birth_date' THEN birth ELSE birth_date END,
    address=CASE WHEN payload ? 'address' THEN CASE WHEN address_value='null'::jsonb THEN NULL ELSE address_value END ELSE address END,
    education=CASE WHEN payload ? 'education' THEN payload->>'education' ELSE education END,
    marital_status=CASE WHEN payload ? 'marital_status' THEN payload->>'marital_status' ELSE marital_status END,
    new_convert=CASE WHEN payload ? 'new_convert' THEN (payload->>'new_convert')::boolean ELSE new_convert END,
    water_baptized=CASE WHEN payload ? 'water_baptized' THEN (payload->>'water_baptized')::boolean ELSE water_baptized END,
    wants_baptism=CASE WHEN payload ? 'wants_baptism' THEN (payload->>'wants_baptism')::boolean ELSE wants_baptism END,
    revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
  ELSE
   IF student.id IS NOT NULL THEN RAISE EXCEPTION 'record_exists' USING ERRCODE='23505'; END IF;
   INSERT INTO public.ministry_students(id,congregation_id,name,normalized_name,phone_e164,birth_date,address,education,marital_status,
    new_convert,water_baptized,wants_baptism,updated_by)
   VALUES(target,congregation,record_name,normalized,phone_text,birth,CASE WHEN address_value='null'::jsonb THEN NULL ELSE address_value END,
    payload->>'education',payload->>'marital_status',(payload->>'new_convert')::boolean,(payload->>'water_baptized')::boolean,
    (payload->>'wants_baptism')::boolean,actor);
   revision_value:=1;
  END IF;
  response:=jsonb_build_object('id',target,'revision',revision_value);

 ELSE
  SELECT * INTO student FROM public.ministry_students WHERE id=target FOR UPDATE;
  IF student.id IS NULL OR student.congregation_id<>congregation THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
  IF student.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF archived AND EXISTS(SELECT FROM public.ministry_enrollments e WHERE e.student_id=target AND e.congregation_id=congregation AND e.status='active') THEN
   RAISE EXCEPTION 'active_enrollment' USING ERRCODE='23514'; END IF;
  UPDATE public.ministry_students SET archived_at=CASE WHEN archived THEN coalesce(archived_at,now()) ELSE NULL END,
   revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
  response:=jsonb_build_object('id',target,'revision',revision_value);
 END IF;

 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result) VALUES(actor,operation_id,command_name,digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'registry_conflict' USING ERRCODE='23505';
 WHEN check_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
 WHEN foreign_key_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
END $$;

CREATE FUNCTION public.ieadpe_ministry_save_contact(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_registry_command('save_contact',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_ministry_set_contact_archived(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_registry_command('set_contact_archived',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_ministry_replace_role_holder(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_registry_command('replace_role_holder',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_ministry_save_student(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_registry_command('save_student',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_ministry_set_student_archived(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.ministry_registry_command('set_student_archived',operation_id,payload) $$;
REVOKE ALL ON FUNCTION private.ministry_registry_command(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb),public.ieadpe_ministry_set_contact_archived(uuid,jsonb),
 public.ieadpe_ministry_replace_role_holder(uuid,jsonb),public.ieadpe_ministry_save_student(uuid,jsonb),
 public.ieadpe_ministry_set_student_archived(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb),public.ieadpe_ministry_set_contact_archived(uuid,jsonb),
 public.ieadpe_ministry_replace_role_holder(uuid,jsonb),public.ieadpe_ministry_save_student(uuid,jsonb),
 public.ieadpe_ministry_set_student_archived(uuid,jsonb) TO authenticated;
