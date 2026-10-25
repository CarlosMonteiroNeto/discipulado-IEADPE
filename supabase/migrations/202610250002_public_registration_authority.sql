BEGIN;

-- Official creation now requires the same canonical scoped/global authority as
-- protected reads. The previous create branch admitted any active congregation,
-- so an authenticated account without a grant could create official records.
-- Lock order and the authorization-before-receipt order stay unchanged.
CREATE OR REPLACE FUNCTION private.convert_registration_command(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
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
  -- Immediate official creation is only for existing scoped or global authority.
  -- An active congregation alone is not permission.
  IF NOT private.can_access_congregation(scope_id) THEN
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

-- Photo drafts have no congregation payload, so they require at least one active
-- scoped grant or global management. This reuses the canonical access predicates.
CREATE OR REPLACE FUNCTION private.has_active_scope_authority() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND (private.is_global_manager() OR EXISTS(
  SELECT FROM public.congregations c
  WHERE c.archived_at IS NULL AND private.can_access_congregation(c.id)))
$$;
REVOKE ALL ON FUNCTION private.has_active_scope_authority() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.has_active_scope_authority() TO authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_create_photo_draft(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); receipt private.mutation_receipts; asset_id uuid;
 digest text; response jsonb;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR payload<>'{}'::jsonb THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.has_active_scope_authority() THEN
  RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
 WHERE r.actor_uid=actor AND r.operation_id=ieadpe_create_photo_draft.operation_id;
 IF FOUND THEN
  IF receipt.command<>'create_photo_draft' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 asset_id:=gen_random_uuid();
 INSERT INTO public.photo_assets(id,owner_id,path)
 VALUES(asset_id,actor,actor::text||'/'||asset_id::text||'.jpg');
 response:=jsonb_build_object('id',asset_id);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(actor,operation_id,'create_photo_draft',digest,response);
 RETURN response;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_create_photo_draft(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_create_photo_draft(uuid,jsonb) TO authenticated;

-- Uploading pending bytes is a separate authorization decision, so a revoked
-- grant cannot finish an upload with an already-issued draft.
DROP POLICY IF EXISTS convert_photo_insert ON storage.objects;
CREATE POLICY convert_photo_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='convert-photos' AND
 metadata->>'mimetype'='image/jpeg' AND
 CASE WHEN jsonb_typeof(metadata->'contentLength')='number' THEN
  (metadata->>'contentLength')::numeric BETWEEN 1 AND 1056768 ELSE false END AND
 EXISTS(SELECT FROM public.photo_assets a WHERE a.path=name AND a.owner_id=auth.uid()
  AND a.status='pending' AND a.expires_at>now()) AND
 private.has_active_scope_authority());

REVOKE ALL ON FUNCTION private.convert_registration_command(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;

COMMIT;
