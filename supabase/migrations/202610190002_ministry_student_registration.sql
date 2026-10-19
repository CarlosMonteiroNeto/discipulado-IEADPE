BEGIN;

-- Shared registration writes use strict nested identity and domain payloads.
CREATE FUNCTION private.ministry_registration_address_valid(value jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT value='null'::jsonb OR (
  jsonb_typeof(value)='object' AND
  value ?& ARRAY['street','district','city','postal_code','state_code'] AND
  value-ARRAY['street','district','city','postal_code','state_code']='{}'::jsonb AND
  jsonb_typeof(value->'street') IN ('string','null') AND
  jsonb_typeof(value->'district') IN ('string','null') AND
  jsonb_typeof(value->'city') IN ('string','null') AND
  jsonb_typeof(value->'postal_code') IN ('string','null') AND
  jsonb_typeof(value->'state_code') IN ('string','null'))
$$;

CREATE FUNCTION private.ministry_register_student_command(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); scope_id uuid; student_uuid uuid; person_uuid uuid;
 receipt private.mutation_receipts; digest text; response jsonb;
 person_data jsonb; academic_data jsonb; person_name text; phone_text text; birth date;
 address_data jsonb; education_text text; marital_text text; new_convert_value boolean;
 water_value boolean; wants_value boolean; field_name text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','person_id','congregation_id','person','academic']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','person_id','congregation_id','person','academic'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'person_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'person') IS DISTINCT FROM 'object' OR
  jsonb_typeof(payload->'academic') IS DISTINCT FROM 'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  student_uuid:=(payload->>'id')::uuid;
  person_uuid:=(payload->>'person_id')::uuid;
  scope_id:=(payload->>'congregation_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_register_student_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>'register_student' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;

 person_data:=payload->'person'; academic_data:=payload->'academic';
 IF person_data-ARRAY['name','phone','birth_date','address']<>'{}'::jsonb OR
  NOT person_data ? 'name' OR jsonb_typeof(person_data->'name') IS DISTINCT FROM 'string' OR
  (person_data ? 'phone' AND jsonb_typeof(person_data->'phone') NOT IN ('string','null')) OR
  (person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date') NOT IN ('string','null')) OR
  (person_data ? 'address' AND jsonb_typeof(person_data->'address') NOT IN ('object','null')) OR
  (person_data ? 'address' AND NOT private.ministry_registration_address_valid(person_data->'address')) OR
  academic_data-ARRAY['education','marital_status','new_convert','water_baptized','wants_baptism']<>'{}'::jsonb OR
  (academic_data ? 'education' AND jsonb_typeof(academic_data->'education') NOT IN ('string','null')) OR
  (academic_data ? 'marital_status' AND jsonb_typeof(academic_data->'marital_status') NOT IN ('string','null')) OR
  (academic_data ? 'new_convert' AND jsonb_typeof(academic_data->'new_convert') NOT IN ('boolean','null')) OR
  (academic_data ? 'water_baptized' AND jsonb_typeof(academic_data->'water_baptized') NOT IN ('boolean','null')) OR
  (academic_data ? 'wants_baptism' AND jsonb_typeof(academic_data->'wants_baptism') NOT IN ('boolean','null')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 person_name:=btrim(person_data->>'name');
 phone_text:=person_data->>'phone';
 IF person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date')='string' THEN
  IF person_data->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  BEGIN birth:=(person_data->>'birth_date')::date;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 END IF;
 address_data:=CASE WHEN person_data ? 'address' THEN person_data->'address' ELSE NULL END;
 education_text:=academic_data->>'education'; marital_text:=academic_data->>'marital_status';
 new_convert_value:=(academic_data->>'new_convert')::boolean;
 water_value:=(academic_data->>'water_baptized')::boolean;
 wants_value:=(academic_data->>'wants_baptism')::boolean;
 IF person_name='' OR person_name<>btrim(person_data->>'name') OR length(person_name)>200 OR
  (phone_text IS NOT NULL AND phone_text !~ '^\+[1-9][0-9]{1,14}$') OR
  (jsonb_typeof(person_data->'birth_date')='string' AND birth IS NULL) OR
  (new_convert_value IS TRUE) OR (water_value IS TRUE AND wants_value IS TRUE) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,phone,birth_date,address,updated_by)
  VALUES(person_uuid,scope_id,person_name,lower(person_name),phone_text,birth,
   CASE WHEN address_data='null'::jsonb THEN NULL ELSE address_data END,actor);
 INSERT INTO public.ministry_students(id,congregation_id,person_id,name,normalized_name,phone_e164,
  birth_date,address,education,marital_status,new_convert,water_baptized,wants_baptism,updated_by)
  VALUES(student_uuid,scope_id,person_uuid,person_name,lower(person_name),phone_text,birth,
   CASE WHEN address_data='null'::jsonb THEN NULL ELSE address_data END,education_text,marital_text,
   new_convert_value,water_value,wants_value,actor);
 response:=jsonb_build_object('id',student_uuid,'person_id',person_uuid,'revision',1,'person_revision',1);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'register_student',digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_register_student(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_register_student_command(operation_id,payload)
$$;

CREATE FUNCTION private.ministry_save_student_academic(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; scope_id uuid; expected integer;
 student public.ministry_students; receipt private.mutation_receipts; digest text; response jsonb;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','expected_revision','education','marital_status','new_convert','water_baptized','wants_baptism']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','expected_revision'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
  (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' OR
  (payload ? 'education' AND jsonb_typeof(payload->'education') NOT IN ('string','null')) OR
  (payload ? 'marital_status' AND jsonb_typeof(payload->'marital_status') NOT IN ('string','null')) OR
  (payload ? 'new_convert' AND jsonb_typeof(payload->'new_convert') NOT IN ('boolean','null')) OR
  (payload ? 'water_baptized' AND jsonb_typeof(payload->'water_baptized') NOT IN ('boolean','null')) OR
  (payload ? 'wants_baptism' AND jsonb_typeof(payload->'wants_baptism') NOT IN ('boolean','null')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN target:=(payload->>'id')::uuid; scope_id:=(payload->>'congregation_id')::uuid;
  expected:=(payload->>'expected_revision')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_save_student_academic.operation_id;
 IF FOUND THEN
  IF receipt.command<>'save_student' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO student FROM public.ministry_students s WHERE s.id=target FOR UPDATE;
 IF student.id IS NULL OR student.congregation_id<>scope_id THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
 IF student.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
 IF student.archived_at IS NOT NULL THEN RAISE EXCEPTION 'student_archived' USING ERRCODE='22023'; END IF;
 IF (CASE WHEN payload ? 'water_baptized' THEN (payload->>'water_baptized')::boolean ELSE student.water_baptized END) IS TRUE AND
    (CASE WHEN payload ? 'wants_baptism' THEN (payload->>'wants_baptism')::boolean ELSE student.wants_baptism END) IS TRUE THEN
  RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023'; END IF;
 UPDATE public.ministry_students SET
  education=CASE WHEN payload ? 'education' THEN payload->>'education' ELSE education END,
  marital_status=CASE WHEN payload ? 'marital_status' THEN payload->>'marital_status' ELSE marital_status END,
  new_convert=CASE WHEN payload ? 'new_convert' THEN (payload->>'new_convert')::boolean ELSE new_convert END,
  water_baptized=CASE WHEN payload ? 'water_baptized' THEN (payload->>'water_baptized')::boolean ELSE water_baptized END,
  wants_baptism=CASE WHEN payload ? 'wants_baptism' THEN (payload->>'wants_baptism')::boolean ELSE wants_baptism END,
  revision=revision+1,updated_at=now(),updated_by=actor
 WHERE id=target RETURNING revision INTO expected;
 response:=jsonb_build_object('id',target,'revision',expected);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'save_student',digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_save_student(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_save_student_academic(operation_id,payload)
$$;

CREATE FUNCTION private.convert_registration_command(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; scope_id uuid; person_uuid uuid;
 old_row public.converts; new_row public.converts; person_row public.ministry_people;
 receipt private.mutation_receipts; digest text; response jsonb; person_data jsonb; convert_data jsonb;
 person_name text; phone_text text; birth date; address_data jsonb; expected_convert integer;
 expected_person integer; person_changed boolean; new_person_revision integer; asset public.photo_assets;
 guard record; cursor_key text;
 trim_chars CONSTANT text:=U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR command_name NOT IN ('create_convert','edit_convert') THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF command_name='create_convert' THEN
  IF payload-ARRAY['congregation_id','person','convert']<>'{}'::jsonb OR
   NOT payload ?& ARRAY['congregation_id','person','convert'] OR
   jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
   jsonb_typeof(payload->'person') IS DISTINCT FROM 'object' OR jsonb_typeof(payload->'convert') IS DISTINCT FROM 'object' THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 ELSE
  IF payload-ARRAY['id','congregation_id','expected_revision','expected_person_revision','person','convert']<>'{}'::jsonb OR
   NOT payload ?& ARRAY['id','congregation_id','expected_revision','expected_person_revision','person','convert'] OR
   jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
   jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' OR
   jsonb_typeof(payload->'expected_person_revision') IS DISTINCT FROM 'number' OR (payload->'expected_person_revision')::text !~ '^[1-9][0-9]*$' OR
   jsonb_typeof(payload->'person') IS DISTINCT FROM 'object' OR jsonb_typeof(payload->'convert') IS DISTINCT FROM 'object' THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 END IF;
 BEGIN
  scope_id:=(payload->>'congregation_id')::uuid;
  IF command_name='edit_convert' THEN
   target:=(payload->>'id')::uuid;
   expected_convert:=(payload->>'expected_revision')::integer;
   expected_person:=(payload->>'expected_person_revision')::integer;
  END IF;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF command_name='create_convert' THEN
  -- Registrars may create in an explicitly selected active congregation.
  -- Protected reads and every other command keep their existing scope checks.
  IF NOT private.can_access_congregation(scope_id) AND NOT EXISTS(
   SELECT FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 ELSE
  IF NOT private.can_access_congregation(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  SELECT * INTO old_row FROM public.converts c WHERE c.id=target FOR UPDATE;
  IF old_row.id IS NULL OR old_row.congregation_id IS DISTINCT FROM scope_id OR
   NOT private.can_access_congregation(old_row.congregation_id) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=convert_registration_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 person_data:=payload->'person'; convert_data:=payload->'convert';
 IF person_data-ARRAY['name','phone','birth_date','address']<>'{}'::jsonb OR
  NOT person_data ? 'name' OR jsonb_typeof(person_data->'name') IS DISTINCT FROM 'string' OR
  (person_data ? 'phone' AND jsonb_typeof(person_data->'phone') NOT IN ('string','null')) OR
  (person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date') NOT IN ('string','null')) OR
  (person_data ? 'address' AND jsonb_typeof(person_data->'address') NOT IN ('object','null')) OR
  (person_data ? 'address' AND NOT private.ministry_registration_address_valid(person_data->'address')) OR
  convert_data-ARRAY['landmark','gender','conversion_date','worship_type','age','photo_asset_id']<>'{}'::jsonb OR
  NOT convert_data ?& ARRAY['landmark','gender','conversion_date','worship_type'] OR
  jsonb_typeof(convert_data->'landmark') IS DISTINCT FROM 'string' OR
  jsonb_typeof(convert_data->'gender') IS DISTINCT FROM 'string' OR
  jsonb_typeof(convert_data->'conversion_date') IS DISTINCT FROM 'string' OR
  jsonb_typeof(convert_data->'worship_type') IS DISTINCT FROM 'string' OR
  (convert_data ? 'age' AND jsonb_typeof(convert_data->'age') NOT IN ('number','null')) OR
  (convert_data ? 'photo_asset_id' AND jsonb_typeof(convert_data->'photo_asset_id') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 person_name:=btrim(person_data->>'name',trim_chars); phone_text:=person_data->>'phone';
 IF person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date')='string' THEN
  IF person_data->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  BEGIN birth:=(person_data->>'birth_date')::date;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 END IF;
 address_data:=CASE WHEN person_data ? 'address' THEN person_data->'address' ELSE NULL END;
 IF person_name='' OR person_data->>'name'<>person_name OR
  (command_name='create_convert' AND length(person_name)>200) OR
  (phone_text IS NOT NULL AND phone_text !~ '^\+[1-9][0-9]{1,14}$') OR
  (person_data ? 'birth_date' AND jsonb_typeof(person_data->'birth_date')='string' AND birth IS NULL) OR
  btrim(convert_data->>'landmark',trim_chars)='' OR convert_data->>'landmark'<>btrim(convert_data->>'landmark',trim_chars) OR
  convert_data->>'gender' NOT IN ('male','female') OR
  btrim(convert_data->>'worship_type',trim_chars)='' OR convert_data->>'worship_type'<>btrim(convert_data->>'worship_type',trim_chars) OR
  convert_data->>'conversion_date' !~ '^\d{4}-\d{2}-\d{2}$' OR
  (convert_data ? 'age' AND convert_data->'age'<>'null'::jsonb AND (convert_data->'age')::text !~ '^[0-9]+$') THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  new_row.landmark:=convert_data->>'landmark'; new_row.gender:=convert_data->>'gender';
  new_row.conversion_date:=(convert_data->>'conversion_date')::date;
  new_row.worship_type:=convert_data->>'worship_type';
  new_row.age:=CASE WHEN convert_data ? 'age' THEN (convert_data->>'age')::integer ELSE NULL END;
  new_row.photo_asset_id:=CASE WHEN convert_data ? 'photo_asset_id' AND convert_data->>'photo_asset_id' IS NOT NULL THEN (convert_data->>'photo_asset_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 IF new_row.conversion_date>private.business_today() OR (new_row.age IS NOT NULL AND new_row.age NOT BETWEEN 0 AND 150) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF command_name='edit_convert' THEN
  IF old_row.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'convert_deleted' USING ERRCODE='22023'; END IF;
  IF old_row.person_id IS NULL THEN RAISE EXCEPTION 'person_link_required' USING ERRCODE='22023'; END IF;
  IF expected_convert<>old_row.revision THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  person_uuid:=old_row.person_id;
  SELECT * INTO person_row FROM public.ministry_people p WHERE p.id=person_uuid AND p.congregation_id=scope_id FOR UPDATE;
  IF person_row.id IS NULL THEN RAISE EXCEPTION 'person_link_required' USING ERRCODE='22023'; END IF;
  IF expected_person<>person_row.revision THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  person_changed:=person_row.name IS DISTINCT FROM person_name OR person_row.phone IS DISTINCT FROM phone_text OR
   person_row.birth_date IS DISTINCT FROM birth OR person_row.address IS DISTINCT FROM
   CASE WHEN address_data='null'::jsonb THEN NULL ELSE address_data END;
  IF person_changed AND length(person_name)>200 THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  new_person_revision:=person_row.revision;
 ELSE
  person_changed:=true; person_uuid:=gen_random_uuid(); new_person_revision:=1;
  new_row.id:=gen_random_uuid(); new_row.internal_id:=new_row.id::text; new_row.created_by:=actor;
  new_row.created_at:=now(); new_row.was_visited_once:=false; new_row.visit_count:=0;
  new_row.is_in_discipleship:=false; new_row.is_discipleship_completed:=false; new_row.is_deviated:=false;
 END IF;
 -- Lock photo rows in stable order after convert/person locks.
 PERFORM 1 FROM public.photo_assets WHERE id IN (old_row.photo_asset_id,new_row.photo_asset_id) ORDER BY id FOR UPDATE;
 IF new_row.photo_asset_id IS DISTINCT FROM old_row.photo_asset_id AND new_row.photo_asset_id IS NOT NULL THEN
  SELECT * INTO asset FROM public.photo_assets WHERE id=new_row.photo_asset_id;
  IF asset.id IS NULL OR asset.owner_id<>actor OR asset.status<>'pending' OR asset.expires_at<=now() OR
   NOT EXISTS(SELECT FROM storage.objects o WHERE o.bucket_id='convert-photos' AND o.name=asset.path) THEN
   RAISE EXCEPTION 'invalid_photo' USING ERRCODE='22023'; END IF;
 END IF;

 -- Lock both affected weekly counters in a stable order before changing rows.
 FOR guard IN SELECT DISTINCT congregation_id,week_start FROM (
  SELECT old_row.congregation_id,date_trunc('week',old_row.conversion_date)::date AS week_start
  UNION ALL SELECT scope_id,date_trunc('week',new_row.conversion_date)::date) weeks
  WHERE congregation_id IS NOT NULL AND week_start IS NOT NULL ORDER BY congregation_id,week_start LOOP
  INSERT INTO private.congregation_week_guards(congregation_id,week_start,conversion_count)
   SELECT guard.congregation_id,guard.week_start,count(*) FROM public.converts c
   WHERE c.congregation_id=guard.congregation_id AND c.conversion_date BETWEEN guard.week_start AND guard.week_start+6 AND c.deleted_at IS NULL
   ON CONFLICT DO NOTHING;
  PERFORM 1 FROM private.congregation_week_guards g WHERE g.congregation_id=guard.congregation_id AND g.week_start=guard.week_start FOR UPDATE;
 END LOOP;
 IF command_name='create_convert' THEN
  INSERT INTO public.ministry_people(id,congregation_id,name,normalized_name,phone,birth_date,address,updated_by)
   VALUES(person_uuid,scope_id,person_name,lower(person_name),phone_text,birth,
    CASE WHEN address_data='null'::jsonb THEN NULL ELSE address_data END,actor);
  new_row.person_id:=person_uuid; new_row.congregation_id:=scope_id; new_row.name:=person_name;
  new_row.phone:=phone_text; new_row.address:=CASE WHEN address_data IS NULL OR address_data='null'::jsonb THEN NULL ELSE address_data->>'street' END;
  new_row.revision:=1; new_row.updated_at:=now(); new_row.last_visit_date:=new_row.conversion_date;
  INSERT INTO public.converts SELECT new_row.*;
  UPDATE private.congregation_week_guards SET conversion_count=conversion_count+1
   WHERE congregation_id=scope_id AND week_start=date_trunc('week',new_row.conversion_date)::date;
  DELETE FROM public.weekly_reports WHERE congregation_id=scope_id AND week_start=date_trunc('week',new_row.conversion_date)::date;
 ELSE
  IF person_changed THEN
   UPDATE public.ministry_people SET name=person_name,normalized_name=lower(person_name),phone=phone_text,
    birth_date=birth,address=CASE WHEN address_data='null'::jsonb THEN NULL ELSE address_data END,
    revision=revision+1,updated_at=now(),updated_by=actor WHERE id=person_uuid RETURNING revision INTO new_person_revision;
  END IF;
  UPDATE public.converts SET landmark=new_row.landmark,gender=new_row.gender,
   conversion_date=new_row.conversion_date,worship_type=new_row.worship_type,
   age=new_row.age,photo_asset_id=new_row.photo_asset_id,revision=revision+1,updated_at=now()
   WHERE id=target RETURNING * INTO new_row;
  UPDATE private.congregation_week_guards SET conversion_count=conversion_count-1
   WHERE congregation_id=old_row.congregation_id AND week_start=date_trunc('week',old_row.conversion_date)::date;
  UPDATE private.congregation_week_guards SET conversion_count=conversion_count+1
   WHERE congregation_id=new_row.congregation_id AND week_start=date_trunc('week',new_row.conversion_date)::date;
  DELETE FROM public.weekly_reports WHERE (congregation_id=old_row.congregation_id AND week_start=date_trunc('week',old_row.conversion_date)::date)
    OR (congregation_id=new_row.congregation_id AND week_start=date_trunc('week',new_row.conversion_date)::date);
 END IF;
 UPDATE public.photo_assets SET status='detached' WHERE id=old_row.photo_asset_id AND id IS DISTINCT FROM new_row.photo_asset_id;
 UPDATE public.photo_assets SET status='attached',convert_id=new_row.id WHERE id=new_row.photo_asset_id;
 response:=jsonb_build_object('id',new_row.id,'person_id',person_uuid,'revision',new_row.revision,
  'person_revision',new_person_revision);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,command_name,digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN
  IF command_name='create_convert' THEN RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505';
  ELSE RAISE EXCEPTION 'academic_conflict' USING ERRCODE='23505'; END IF;
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'academic_invalid' USING ERRCODE='22023';
END $$;

CREATE OR REPLACE FUNCTION public.ieadpe_create_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.convert_registration_command('create_convert',operation_id,payload)
$$;
CREATE OR REPLACE FUNCTION public.ieadpe_edit_convert(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.convert_registration_command('edit_convert',operation_id,payload)
$$;

CREATE FUNCTION private.ministry_convert_projection(source public.converts) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'convert',jsonb_build_object('id',source.id,'internal_id',source.internal_id,'person_id',source.person_id,
   'congregation_id',source.congregation_id,'landmark',source.landmark,'gender',source.gender,
   'conversion_date',source.conversion_date,'worship_type',source.worship_type,'photo_url',source.photo_url,
   'photo_asset_id',source.photo_asset_id,'age',source.age,'last_visit_date',source.last_visit_date,
   'was_visited_once',source.was_visited_once,'visit_count',source.visit_count,'is_in_discipleship',source.is_in_discipleship,
   'discipleship_start_date',source.discipleship_start_date,'is_discipleship_completed',source.is_discipleship_completed,
   'is_deviated',source.is_deviated,'created_by',source.created_by,'created_at',source.created_at,
   'updated_at',source.updated_at,'deleted_at',source.deleted_at,'revision',source.revision),
  'person',CASE WHEN p.id IS NULL THEN NULL ELSE jsonb_build_object('id',p.id,'congregation_id',p.congregation_id,
   'name',p.name,'normalized_name',p.normalized_name,'phone',p.phone,'birth_date',p.birth_date,'address',p.address) END,
  'person_revision',p.revision,
  'legacy_identity',CASE WHEN p.id IS NOT NULL THEN NULL ELSE jsonb_build_object(
   'name',source.name,'phone',source.phone,'address',source.address) END)
 FROM (SELECT source.*) source
 LEFT JOIN public.ministry_people p ON p.id=source.person_id AND p.congregation_id=source.congregation_id
$$;

CREATE FUNCTION public.ieadpe_ministry_list_converts(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; prefix text; cursor_text text; cursor_data jsonb;
 after_id uuid; items jsonb; row_count integer; next_cursor text; tail_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','name_prefix','limit','cursor']<>'{}'::jsonb OR
  NOT request ? 'limit' OR jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'congregation_id' AND jsonb_typeof(request->'congregation_id') NOT IN ('string','null')) OR
  (request ? 'name_prefix' AND jsonb_typeof(request->'name_prefix') NOT IN ('string','null')) OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  page_size:=(request->>'limit')::integer;
  IF jsonb_typeof(request->'congregation_id')='string' THEN scope_id:=(request->>'congregation_id')::uuid; END IF;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 prefix:=request->>'name_prefix';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix) OR length(prefix)>200) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 prefix:=lower(prefix);
 IF scope_id IS NULL THEN
  IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'converts');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','convert_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM prefix OR jsonb_typeof(cursor_data->'convert_id') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_id:=(cursor_data->>'convert_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT c.id,private.ministry_convert_projection(c) AS projection
  FROM public.converts c LEFT JOIN public.ministry_people p ON p.id=c.person_id AND p.congregation_id=c.congregation_id
  WHERE c.deleted_at IS NULL AND (scope_id IS NULL OR c.congregation_id=scope_id) AND
   (prefix IS NULL OR left(lower(coalesce(p.name,c.name)),length(prefix))=prefix) AND
   (after_id IS NULL OR c.id>after_id)
  ORDER BY c.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(p.projection ORDER BY (p.projection->'convert'->>'id')::uuid),'[]'::jsonb),count(*)
  INTO items,row_count FROM page p;
 IF row_count>page_size THEN
  tail_id:=(items->(page_size-1)->'convert'->>'id')::uuid;
  items:=items-page_size;
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','converts','congregation_id',scope_id,'name_prefix',prefix,'convert_id',tail_id));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_ministry_get_convert(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; target uuid; source public.converts;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','convert_id']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','convert_id'] OR
  jsonb_typeof(request->'congregation_id') NOT IN ('string','null') OR
  jsonb_typeof(request->'convert_id') IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  IF jsonb_typeof(request->'congregation_id')='string' THEN scope_id:=(request->>'congregation_id')::uuid; END IF;
  target:=(request->>'convert_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF scope_id IS NULL THEN
  IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 SELECT * INTO source FROM public.converts c WHERE c.id=target AND c.deleted_at IS NULL
  AND c.congregation_id IS NOT DISTINCT FROM scope_id;
 IF source.id IS NULL THEN RAISE EXCEPTION 'convert_not_found' USING ERRCODE='22023'; END IF;
 RETURN private.ministry_convert_projection(source);
END $$;

REVOKE ALL ON FUNCTION private.ministry_registration_address_valid(jsonb),
 private.ministry_register_student_command(uuid,jsonb),private.ministry_save_student_academic(uuid,jsonb),
 private.convert_registration_command(text,uuid,jsonb),private.ministry_convert_projection(public.converts)
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_register_student(uuid,jsonb),
 public.ieadpe_ministry_save_student(uuid,jsonb),public.ieadpe_create_convert(uuid,jsonb),
 public.ieadpe_edit_convert(uuid,jsonb),public.ieadpe_ministry_list_converts(jsonb),
 public.ieadpe_ministry_get_convert(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_register_student(uuid,jsonb),
 public.ieadpe_ministry_save_student(uuid,jsonb),public.ieadpe_create_convert(uuid,jsonb),
 public.ieadpe_edit_convert(uuid,jsonb),public.ieadpe_ministry_list_converts(jsonb),
 public.ieadpe_ministry_get_convert(jsonb) TO authenticated;

COMMIT;
