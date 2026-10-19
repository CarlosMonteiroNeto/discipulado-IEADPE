BEGIN;

ALTER TABLE public.ministry_contacts
 ADD COLUMN email text,
 ADD COLUMN user_access_id uuid REFERENCES public.user_access(id) ON DELETE RESTRICT;
ALTER TABLE public.ministry_contacts
 ADD CONSTRAINT ministry_contacts_email_normalized CHECK(
  email IS NULL OR (email=btrim(email) AND email=lower(email) AND email LIKE '%@%'));
CREATE UNIQUE INDEX ministry_contacts_user_access_unique
 ON public.ministry_contacts(user_access_id) WHERE user_access_id IS NOT NULL;

-- Linked assignments count as authority only while the binding still matches a
-- verified Auth email and the linked directory email.
CREATE OR REPLACE FUNCTION private.is_global_manager() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND (
  EXISTS(SELECT FROM private.admin_allowlist WHERE user_id=auth.uid()) OR
  EXISTS(SELECT FROM public.user_access ua JOIN auth.users u ON u.id=ua.user_id
   WHERE ua.role='Membro da supervisão das campanhas' AND u.id=auth.uid()
    AND u.email_confirmed_at IS NOT NULL AND lower(btrim(u.email))=ua.user_email
    AND (NOT EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=ua.id)
      OR EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=ua.id
       AND c.email=ua.user_email)))
 )
$$;
CREATE OR REPLACE FUNCTION private.can_access_congregation(scope_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND (private.is_global_manager() OR EXISTS(
  SELECT FROM public.user_access ua JOIN auth.users u ON u.id=ua.user_id
  WHERE ua.role='Membro da direção da campanha' AND ua.congregation_id=scope_id
   AND u.id=auth.uid() AND u.email_confirmed_at IS NOT NULL
   AND lower(btrim(u.email))=ua.user_email
   AND (NOT EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=ua.id)
     OR EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=ua.id
      AND c.email=ua.user_email))))
$$;
REVOKE ALL ON FUNCTION private.is_global_manager(),private.can_access_congregation(uuid)
 FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.is_global_manager(),private.can_access_congregation(uuid)
 TO authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_get_scope() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE verified_email text; bound_count integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(711039001);
 SELECT lower(btrim(email)) INTO verified_email FROM auth.users
  WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL;
 IF verified_email IS NOT NULL THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(verified_email,0));
 END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 UPDATE public.user_access ua SET user_id=auth.uid(),updated_at=now()
  WHERE ua.user_id IS NULL AND ua.user_email=verified_email AND
   (NOT EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=ua.id)
    OR EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=ua.id
     AND c.email=ua.user_email));
 GET DIAGNOSTICS bound_count=ROW_COUNT;
 IF bound_count>0 THEN
  UPDATE private.access_versions SET version=version+1 WHERE user_id=auth.uid();
 END IF;
 RETURN jsonb_build_object(
  'is_admin',EXISTS(SELECT FROM private.admin_allowlist WHERE user_id=auth.uid()),
  'is_supervision',private.is_global_manager() AND EXISTS(
   SELECT FROM public.user_access ua WHERE ua.user_id=auth.uid()
    AND ua.role='Membro da supervisão das campanhas'),
  'congregation_ids',coalesce((SELECT jsonb_agg(DISTINCT ua.congregation_id ORDER BY ua.congregation_id)
   FROM public.user_access ua JOIN auth.users u ON u.id=ua.user_id
   JOIN public.congregations c ON c.id=ua.congregation_id
   WHERE ua.role='Membro da direção da campanha' AND u.id=auth.uid()
    AND u.email_confirmed_at IS NOT NULL AND lower(btrim(u.email))=ua.user_email
    AND c.archived_at IS NULL AND (NOT EXISTS(
     SELECT FROM public.ministry_contacts mc WHERE mc.user_access_id=ua.id)
     OR EXISTS(SELECT FROM public.ministry_contacts mc WHERE mc.user_access_id=ua.id
      AND mc.email=ua.user_email))),'[]'::jsonb),
  'ministry_supervision',private.is_global_manager(),
  'ministry_congregation_ids',coalesce((SELECT jsonb_agg(DISTINCT ua.congregation_id ORDER BY ua.congregation_id)
   FROM public.user_access ua JOIN auth.users u ON u.id=ua.user_id
   JOIN public.congregations c ON c.id=ua.congregation_id
   WHERE ua.role='Membro da direção da campanha' AND u.id=auth.uid()
    AND u.email_confirmed_at IS NOT NULL AND lower(btrim(u.email))=ua.user_email
    AND c.archived_at IS NULL AND (NOT EXISTS(
     SELECT FROM public.ministry_contacts mc WHERE mc.user_access_id=ua.id)
     OR EXISTS(SELECT FROM public.ministry_contacts mc WHERE mc.user_access_id=ua.id
      AND mc.email=ua.user_email))),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_get_scope() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_get_scope() TO authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_directory(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 requested_scope text; congregation uuid; requested_role text; prefix text;
 page_size integer; cursor_text text; cursor_data jsonb; after_name text; after_id uuid;
 items jsonb; item_count integer; next_value text; cursor_json jsonb;
 cursor_payload text; supplied_signature text; secret_value text; tail_item jsonb;
 valid_roles constant text[]:=ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator',
  'discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant',
  'campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'];
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['scope','congregation_id','role_code','name_prefix','limit','cursor']<>'{}'::jsonb OR
  jsonb_typeof(request->'scope') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request ? 'congregation_id' AND jsonb_typeof(request->'congregation_id') NOT IN ('string','null')) OR
  (request ? 'role_code' AND jsonb_typeof(request->'role_code') NOT IN ('string','null')) OR
  (request ? 'name_prefix' AND jsonb_typeof(request->'name_prefix') NOT IN ('string','null')) OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 requested_scope:=request->>'scope';
 IF requested_scope NOT IN ('congregation','supervision','all') THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
 IF (request->'limit')::text !~ '^[0-9]+$' THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 page_size:=(request->>'limit')::integer;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 BEGIN
  congregation:=CASE WHEN jsonb_typeof(request->'congregation_id')='string'
   THEN (request->>'congregation_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END;
 requested_role:=request->>'role_code'; prefix:=request->>'name_prefix'; cursor_text:=request->>'cursor';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix)) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF requested_role IS NOT NULL AND NOT requested_role=ANY(valid_roles) THEN RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023'; END IF;
 IF requested_scope='congregation' THEN
  IF congregation IS NULL OR (requested_role IS NOT NULL AND requested_role=ANY(
   ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy',
    'coordinationSecretary','coordinationDeputySecretary'])) THEN RAISE EXCEPTION 'invalid_filter' USING ERRCODE='22023'; END IF;
  IF NOT private.ministry_can_access(congregation) OR NOT EXISTS(
   SELECT FROM public.congregations WHERE id=congregation AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSIF requested_scope='supervision' THEN
  IF congregation IS NOT NULL OR (requested_role IS NOT NULL AND requested_role=ANY(
   ARRAY['congregationAssistant','campaignLeader','campaignDeputyLeader','teacher',
    'discipleshipSecretary','discipleshipDeputySecretary'])) THEN RAISE EXCEPTION 'invalid_filter' USING ERRCODE='22023'; END IF;
  IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSE
  IF congregation IS NOT NULL THEN RAISE EXCEPTION 'invalid_filter' USING ERRCODE='22023'; END IF;
  IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 IF cursor_text IS NOT NULL THEN
  BEGIN
   IF length(cursor_text)-length(replace(cursor_text,'.',''))<>1 THEN RAISE EXCEPTION 'bad signature'; END IF;
   cursor_payload:=split_part(cursor_text,'.',1); supplied_signature:=split_part(cursor_text,'.',2);
   SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
   IF supplied_signature<>encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex') THEN RAISE EXCEPTION 'bad signature'; END IF;
   cursor_data:=convert_from(decode(cursor_payload,'base64'),'UTF8')::jsonb;
   after_id:=(cursor_data->>'id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
  IF cursor_data-ARRAY['uid','scope','congregation_id','role_code','name_prefix','name','id']<>'{}'::jsonb OR
   cursor_data->>'uid'<>auth.uid()::text OR cursor_data->>'scope'<>requested_scope OR
   cursor_data->>'congregation_id' IS DISTINCT FROM congregation::text OR
   cursor_data->>'role_code' IS DISTINCT FROM requested_role OR cursor_data->>'name_prefix' IS DISTINCT FROM prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' OR
   jsonb_typeof(cursor_data->'id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  after_name:=cursor_data->>'name';
 END IF;
 WITH visible AS (
  SELECT c.id,c.name,c.normalized_name,c.scope,c.congregation_id,c.role_code,c.phone_e164,
   c.birth_date,c.email,c.archived_at,c.revision,
   CASE WHEN private.is_global_manager() THEN c.user_access_id ELSE NULL END AS user_access_id
  FROM public.ministry_contacts c
  WHERE ((requested_scope='all') OR (requested_scope='supervision' AND c.scope='supervision') OR
   (requested_scope='congregation' AND c.scope='congregation' AND c.congregation_id=congregation))
   AND (requested_role IS NULL OR c.role_code=requested_role)
   AND (prefix IS NULL OR c.normalized_name LIKE lower(prefix)||'%')
   AND (after_name IS NULL OR (c.normalized_name,c.id)>(after_name,after_id))
 ), page AS (SELECT * FROM visible ORDER BY normalized_name,id LIMIT page_size+1)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'normalized_name',p.normalized_name,
   'scope',p.scope,'congregation_id',p.congregation_id,'role_code',p.role_code,'phone_e164',p.phone_e164,
   'birth_date',p.birth_date,'email',p.email,'archived_at',p.archived_at,'revision',p.revision,
   'user_access_id',p.user_access_id) ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
  INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail_item:=items->(page_size-1);
  cursor_json:=jsonb_build_object('uid',auth.uid(),'scope',requested_scope,'congregation_id',congregation,
   'role_code',requested_role,'name_prefix',prefix,'name',tail_item->>'normalized_name','id',tail_item->>'id');
  cursor_payload:=replace(encode(convert_to(cursor_json::text,'UTF8'),'base64'),E'\n','');
  SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
  next_value:=cursor_payload||'.'||encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex');
 ELSE next_value:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_value);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_directory(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_directory(jsonb) TO authenticated;

CREATE FUNCTION public.ieadpe_ministry_get_contact(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_text text; congregation uuid; contact_id uuid; contact_row public.ministry_contacts;
        access_row public.user_access; detail jsonb; access_detail jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['scope','congregation_id','contact_id']<>'{}'::jsonb OR
  NOT request ?& ARRAY['scope','contact_id'] OR jsonb_typeof(request->'scope') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'contact_id') IS DISTINCT FROM 'string' OR
  (request ? 'congregation_id' AND jsonb_typeof(request->'congregation_id') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 scope_text:=request->>'scope';
 BEGIN
  contact_id:=(request->>'contact_id')::uuid;
  congregation:=CASE WHEN jsonb_typeof(request->'congregation_id')='string'
   THEN (request->>'congregation_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF scope_text NOT IN ('congregation','supervision') OR
  (scope_text='congregation' AND congregation IS NULL) OR
  (scope_text='supervision' AND congregation IS NOT NULL) THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
 IF scope_text='congregation' THEN
  IF NOT private.ministry_can_access(congregation) OR NOT EXISTS(
   SELECT FROM public.congregations WHERE id=congregation AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSIF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO contact_row FROM public.ministry_contacts c
  WHERE c.id=contact_id AND c.scope=scope_text AND c.congregation_id IS NOT DISTINCT FROM congregation;
 IF contact_row.id IS NULL THEN RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
 IF private.is_global_manager() AND contact_row.user_access_id IS NOT NULL THEN
  SELECT * INTO access_row FROM public.user_access WHERE id=contact_row.user_access_id;
  IF access_row.id IS NULL OR contact_row.email IS NULL OR access_row.user_email<>contact_row.email OR
   (access_row.user_id IS NOT NULL AND NOT EXISTS(SELECT FROM auth.users u WHERE u.id=access_row.user_id
    AND u.email_confirmed_at IS NOT NULL AND lower(btrim(u.email))=access_row.user_email)) THEN
   RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
  access_detail:=jsonb_build_object('id',access_row.id,'user_email',access_row.user_email,
   'role',access_row.role,'congregation_id',access_row.congregation_id,'user_id',access_row.user_id);
 ELSE access_detail:=NULL; END IF;
 detail:=jsonb_build_object('id',contact_row.id,'name',contact_row.name,'normalized_name',contact_row.normalized_name,
  'scope',contact_row.scope,'congregation_id',contact_row.congregation_id,'role_code',contact_row.role_code,
  'phone_e164',contact_row.phone_e164,'birth_date',contact_row.birth_date,'email',contact_row.email,
  'archived_at',contact_row.archived_at,'revision',contact_row.revision,
  'user_access_id',CASE WHEN private.is_global_manager() THEN contact_row.user_access_id ELSE NULL END,
  'created_at',contact_row.created_at,'updated_at',contact_row.updated_at,'updated_by',contact_row.updated_by);
 RETURN jsonb_build_object('contact',detail,'access',access_detail);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_contact(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_contact(jsonb) TO authenticated;

CREATE FUNCTION private.ministry_save_contact_with_email(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 actor uuid:=auth.uid(); receipt private.mutation_receipts; digest text; response jsonb;
 target uuid; congregation uuid; scope_text text; role_text text; record_name text; normalized text;
 phone_text text; birth date; email_text text; expected integer; revision_value integer;
 contact public.ministry_contacts; access_row public.user_access;
 allowed_roles constant text[]:=ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator',
  'discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant',
  'campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'];
 trim_chars constant text:=U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','scope','congregation_id','name','role_code','phone_e164','birth_date','email','expected_revision']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','scope','congregation_id','name','role_code','phone_e164','birth_date','email'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'scope') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'name') IS DISTINCT FROM 'string' OR jsonb_typeof(payload->'role_code') NOT IN ('string','null') OR
  jsonb_typeof(payload->'phone_e164') NOT IN ('string','null') OR jsonb_typeof(payload->'birth_date') NOT IN ('string','null') OR
  jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') OR
  (payload ? 'email' AND jsonb_typeof(payload->'email') NOT IN ('string','null')) OR
  (payload ? 'expected_revision' AND (jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
   (payload->'expected_revision')::text !~ '^[1-9][0-9]*$')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 BEGIN
  target:=(payload->>'id')::uuid;
  congregation:=CASE WHEN jsonb_typeof(payload->'congregation_id')='string'
   THEN (payload->>'congregation_id')::uuid ELSE NULL END;
  expected:=CASE WHEN payload ? 'expected_revision' THEN (payload->>'expected_revision')::integer ELSE NULL END;
  scope_text:=payload->>'scope'; role_text:=payload->>'role_code';
  record_name:=btrim(payload->>'name',trim_chars); normalized:=lower(record_name);
  phone_text:=payload->>'phone_e164';
  email_text:=CASE WHEN jsonb_typeof(payload->'email')='string'
   THEN lower(btrim(payload->>'email')) ELSE NULL END;
  IF jsonb_typeof(payload->'birth_date')='string' THEN
   IF payload->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   birth:=(payload->>'birth_date')::date;
  END IF;
 EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
 END;
 IF scope_text NOT IN ('congregation','supervision') OR
  (scope_text='congregation' AND congregation IS NULL) OR
  (scope_text='supervision' AND congregation IS NOT NULL) THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
 IF scope_text='congregation' THEN
  IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.congregations WHERE id=congregation AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 ELSIF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF record_name='' OR length(record_name)>200 OR
  (phone_text IS NOT NULL AND phone_text !~ '^\+[1-9][0-9]{1,14}$') OR
  (email_text IS NOT NULL AND (email_text='' OR email_text NOT LIKE '%@%')) OR
  (role_text IS NOT NULL AND NOT (role_text=ANY(allowed_roles) AND
   ((scope_text='congregation' AND role_text=ANY(ARRAY['congregationAssistant','campaignLeader',
    'campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'])) OR
    (scope_text='supervision' AND role_text=ANY(ARRAY['campaignSupervisor','campaignDeputy',
     'discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary']))))) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_save_contact_with_email.operation_id;
 IF FOUND THEN
  IF receipt.command<>'save_contact' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO contact FROM public.ministry_contacts WHERE id=target FOR UPDATE;
 IF payload ? 'expected_revision' THEN
  IF contact.id IS NULL OR contact.scope<>scope_text OR contact.congregation_id IS DISTINCT FROM congregation THEN
   RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
  IF contact.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF contact.archived_at IS NOT NULL THEN RAISE EXCEPTION 'contact_archived' USING ERRCODE='22023'; END IF;
  IF contact.user_access_id IS NOT NULL THEN
   SELECT * INTO access_row FROM public.user_access WHERE id=contact.user_access_id;
   IF access_row.id IS NULL OR email_text IS NULL OR email_text IS DISTINCT FROM contact.email OR
    email_text IS DISTINCT FROM access_row.user_email THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
  END IF;
  UPDATE public.ministry_contacts SET name=record_name,normalized_name=normalized,role_code=role_text,
   phone_e164=phone_text,birth_date=birth,email=email_text,revision=revision+1,
   updated_at=now(),updated_by=actor WHERE id=target RETURNING revision INTO revision_value;
 ELSE
  IF contact.id IS NOT NULL THEN RAISE EXCEPTION 'record_exists' USING ERRCODE='23505'; END IF;
  INSERT INTO public.ministry_contacts(id,congregation_id,scope,name,normalized_name,role_code,phone_e164,
   birth_date,email,updated_by)
  VALUES(target,congregation,scope_text,record_name,normalized,role_text,phone_text,birth,email_text,actor);
  revision_value:=1;
 END IF;
 response:=jsonb_build_object('id',target,'revision',revision_value);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'save_contact',digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'registry_conflict' USING ERRCODE='23505';
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
END $$;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_save_contact(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_save_contact_with_email(operation_id,payload)
$$;
REVOKE ALL ON FUNCTION private.ministry_save_contact_with_email(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb) TO authenticated;

CREATE FUNCTION private.ministry_save_contact_with_access(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 actor uuid:=auth.uid(); receipt private.mutation_receipts; digest text; response jsonb;
 target_contact uuid; requested_access uuid; effective_access uuid; old_access_id uuid; access_scope_id uuid;
 congregation uuid; scope_text text; role_text text; access_role text; record_name text; normalized text;
 phone_text text; birth date; email_text text; access_email text; expected integer; revision_value integer;
 old_contact public.ministry_contacts; contact public.ministry_contacts; access_row public.user_access;
 old_uid uuid; target_uid uuid; lock_email text; email_changed boolean; access_id_is_explicit boolean;
 allowed_roles constant text[]:=ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator',
  'discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant',
  'campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'];
 trim_chars constant text:=U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff';
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','expected_revision','scope','congregation_id','name','role_code','phone_e164',
   'birth_date','email','access']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['scope','congregation_id','name','role_code','phone_e164','birth_date','email','access'] OR
  (payload ? 'id' AND jsonb_typeof(payload->'id') IS DISTINCT FROM 'string') OR
  (payload ? 'expected_revision' AND (jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
   (payload->'expected_revision')::text !~ '^[1-9][0-9]*$')) OR
  jsonb_typeof(payload->'scope') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') OR
  jsonb_typeof(payload->'name') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'role_code') NOT IN ('string','null') OR
  jsonb_typeof(payload->'phone_e164') NOT IN ('string','null') OR
  jsonb_typeof(payload->'birth_date') NOT IN ('string','null') OR
  jsonb_typeof(payload->'email') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'access') IS DISTINCT FROM 'object' OR
  (payload->'access')-ARRAY['id','user_email','role','congregation_id']<>'{}'::jsonb OR
  NOT (payload->'access') ?& ARRAY['user_email','role','congregation_id'] OR
  ((payload->'access') ? 'id' AND jsonb_typeof(payload->'access'->'id') IS DISTINCT FROM 'string') OR
  jsonb_typeof(payload->'access'->'user_email') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'access'->'role') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'access'->'congregation_id') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF payload ? 'expected_revision' AND NOT payload ? 'id' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(711039001);
 BEGIN
  target_contact:=CASE WHEN payload ? 'id' THEN (payload->>'id')::uuid ELSE gen_random_uuid() END;
  requested_access:=CASE WHEN payload->'access' ? 'id' THEN (payload->'access'->>'id')::uuid ELSE NULL END;
  congregation:=CASE WHEN jsonb_typeof(payload->'congregation_id')='string'
   THEN (payload->>'congregation_id')::uuid ELSE NULL END;
  access_scope_id:=CASE WHEN jsonb_typeof(payload->'access'->'congregation_id')='string'
   THEN (payload->'access'->>'congregation_id')::uuid ELSE NULL END;
  expected:=CASE WHEN payload ? 'expected_revision' THEN (payload->>'expected_revision')::integer ELSE NULL END;
  scope_text:=payload->>'scope'; role_text:=payload->>'role_code'; access_role:=payload->'access'->>'role';
  record_name:=btrim(payload->>'name',trim_chars); normalized:=lower(record_name); phone_text:=payload->>'phone_e164';
  email_text:=lower(btrim(payload->>'email')); access_email:=lower(btrim(payload->'access'->>'user_email'));
  IF jsonb_typeof(payload->'birth_date')='string' THEN
   IF payload->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   birth:=(payload->>'birth_date')::date;
  END IF;
 EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
 END;
 IF scope_text NOT IN ('congregation','supervision') OR
  (scope_text='congregation' AND congregation IS NULL) OR
  (scope_text='supervision' AND congregation IS NOT NULL) THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
 IF email_text='' OR email_text NOT LIKE '%@%' OR access_email IS DISTINCT FROM email_text OR
  record_name='' OR length(record_name)>200 OR
  (phone_text IS NOT NULL AND phone_text !~ '^\+[1-9][0-9]{1,14}$') OR
  (role_text IS NOT NULL AND NOT (role_text=ANY(allowed_roles) AND
   ((scope_text='congregation' AND role_text=ANY(ARRAY['congregationAssistant','campaignLeader',
    'campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'])) OR
    (scope_text='supervision' AND role_text=ANY(ARRAY['campaignSupervisor','campaignDeputy',
     'discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary']))))) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF access_role NOT IN ('Membro da direção da campanha','Membro da supervisão das campanhas') OR
  (scope_text='congregation' AND (access_role<>'Membro da direção da campanha' OR
   access_scope_id IS DISTINCT FROM congregation)) OR
  (scope_text='supervision' AND (access_role<>'Membro da supervisão das campanhas' OR
   jsonb_typeof(payload->'access'->'congregation_id') IS DISTINCT FROM 'null')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;

 -- The global access mutex precedes email and sorted UID locks. Read linked IDs
 -- only after the mutex so access edits and verified-email binding serialize.
 SELECT * INTO old_contact FROM public.ministry_contacts WHERE id=target_contact;
 old_access_id:=old_contact.user_access_id;
 access_id_is_explicit:=payload->'access' ? 'id';
 IF access_id_is_explicit THEN effective_access:=requested_access;
 ELSIF NOT payload ? 'expected_revision' THEN effective_access:=NULL;
 ELSE effective_access:=old_access_id; END IF;
 IF effective_access IS NOT NULL THEN SELECT * INTO access_row FROM public.user_access WHERE id=effective_access; END IF;
 FOR lock_email IN
  SELECT DISTINCT email_value FROM unnest(ARRAY[email_text,old_contact.email,access_row.user_email]) AS emails(email_value)
  WHERE email_value IS NOT NULL ORDER BY email_value
 LOOP PERFORM pg_advisory_xact_lock(hashtextextended(lock_email,0)); END LOOP;
 SELECT id INTO target_uid FROM auth.users WHERE lower(btrim(email))=email_text
  AND email_confirmed_at IS NOT NULL ORDER BY id LIMIT 1;
 PERFORM private.lock_access(ARRAY[actor,old_uid,access_row.user_id,target_uid]);
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF scope_text='congregation' THEN
  PERFORM 1 FROM public.congregations WHERE id=congregation AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_save_contact_with_access.operation_id;
 IF FOUND THEN
  IF receipt.command<>'save_contact_with_access' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;

 IF payload ? 'expected_revision' AND old_access_id IS NULL AND NOT access_id_is_explicit THEN
  RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
 IF old_access_id IS NOT NULL AND access_id_is_explicit AND requested_access<>old_access_id THEN
  RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;

 SELECT * INTO contact FROM public.ministry_contacts WHERE id=target_contact FOR UPDATE;
 IF payload ? 'expected_revision' THEN
  IF contact.id IS NULL OR contact.scope<>scope_text OR contact.congregation_id IS DISTINCT FROM congregation THEN
   RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
  IF contact.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
  IF contact.archived_at IS NOT NULL THEN RAISE EXCEPTION 'contact_archived' USING ERRCODE='22023'; END IF;
 ELSE
  IF contact.id IS NOT NULL THEN RAISE EXCEPTION 'record_exists' USING ERRCODE='23505'; END IF;
  IF effective_access IS NULL AND EXISTS(SELECT FROM public.user_access ua WHERE ua.user_email=email_text
   AND ua.role=access_role AND ua.congregation_id IS NOT DISTINCT FROM access_scope_id) THEN
   RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
 END IF;
 IF effective_access IS NOT NULL THEN
  SELECT * INTO access_row FROM public.user_access WHERE id=effective_access FOR UPDATE;
  IF access_row.id IS NULL THEN RAISE EXCEPTION 'access_not_found' USING ERRCODE='22023'; END IF;
  IF access_row.role<>access_role OR access_row.congregation_id IS DISTINCT FROM access_scope_id THEN
   RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
  IF access_row.id<>coalesce(old_access_id,'00000000-0000-0000-0000-000000000000') AND EXISTS(
   SELECT FROM public.ministry_contacts c WHERE c.user_access_id=access_row.id) THEN
   RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
  email_changed:=access_row.user_email IS DISTINCT FROM email_text;
  IF email_changed THEN
   IF NOT access_id_is_explicit THEN RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
   IF target_uid IS NULL THEN RAISE EXCEPTION 'verified_email_required' USING ERRCODE='22023'; END IF;
   old_uid:=access_row.user_id;
   UPDATE public.user_access SET user_email=email_text,user_id=target_uid,updated_at=now()
    WHERE id=access_row.id;
  ELSE
   IF access_row.user_id IS NOT NULL THEN
    IF target_uid IS NULL THEN RAISE EXCEPTION 'verified_email_required' USING ERRCODE='22023'; END IF;
    IF target_uid<>access_row.user_id THEN RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
   END IF;
  END IF;
 ELSE
  INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
   VALUES(email_text,NULL,access_role,access_scope_id)
   RETURNING id INTO effective_access;
 END IF;
 IF payload ? 'expected_revision' THEN
  UPDATE public.ministry_contacts SET name=record_name,normalized_name=normalized,role_code=role_text,
   phone_e164=phone_text,birth_date=birth,email=email_text,user_access_id=effective_access,
   revision=revision+1,updated_at=now(),updated_by=actor WHERE id=target_contact RETURNING revision INTO revision_value;
 ELSE
  INSERT INTO public.ministry_contacts(id,congregation_id,scope,name,normalized_name,role_code,phone_e164,
   birth_date,email,user_access_id,updated_by)
  VALUES(target_contact,congregation,scope_text,record_name,normalized,role_text,phone_text,
   birth,email_text,effective_access,actor);
  revision_value:=1;
 END IF;
 IF email_changed THEN
  UPDATE private.access_versions SET version=version+1 WHERE user_id IN (old_uid,target_uid);
 END IF;
 response:=jsonb_build_object('id',target_contact,'revision',revision_value,'access_id',effective_access);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'save_contact_with_access',digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'registry_conflict' USING ERRCODE='23505';
 WHEN check_violation OR foreign_key_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
END $$;

CREATE FUNCTION public.ieadpe_ministry_save_contact_with_access(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_save_contact_with_access(operation_id,payload)
$$;
REVOKE ALL ON FUNCTION private.ministry_save_contact_with_access(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_save_contact_with_access(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_save_contact_with_access(uuid,jsonb) TO authenticated;

CREATE FUNCTION private.ministry_revoke_contact_access(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 actor uuid:=auth.uid(); receipt private.mutation_receipts; digest text; response jsonb;
 target uuid; congregation uuid; scope_text text; expected integer; revision_value integer;
 contact public.ministry_contacts; access_row public.user_access; access_id uuid; lock_email text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','scope','congregation_id','expected_revision']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','scope','congregation_id','expected_revision'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'scope') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') OR
  jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
  (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(711039001);
 BEGIN
  target:=(payload->>'id')::uuid;
  congregation:=CASE WHEN jsonb_typeof(payload->'congregation_id')='string'
   THEN (payload->>'congregation_id')::uuid ELSE NULL END;
  expected:=(payload->>'expected_revision')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 scope_text:=payload->>'scope';
 IF scope_text NOT IN ('congregation','supervision') OR
  (scope_text='congregation' AND congregation IS NULL) OR
  (scope_text='supervision' AND congregation IS NOT NULL) THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ministry_revoke_contact_access.operation_id;
 IF FOUND THEN
  IF receipt.command<>'revoke_contact_access' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO contact FROM public.ministry_contacts WHERE id=target;
 IF contact.id IS NULL OR contact.scope<>scope_text OR contact.congregation_id IS DISTINCT FROM congregation THEN
  RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
 access_id:=contact.user_access_id;
 IF access_id IS NOT NULL THEN SELECT * INTO access_row FROM public.user_access WHERE id=access_id; END IF;
 FOR lock_email IN SELECT DISTINCT email_value FROM unnest(ARRAY[contact.email,access_row.user_email]) AS emails(email_value)
  WHERE email_value IS NOT NULL ORDER BY email_value
 LOOP PERFORM pg_advisory_xact_lock(hashtextextended(lock_email,0)); END LOOP;
 PERFORM private.lock_access(ARRAY[actor,access_row.user_id]);
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO contact FROM public.ministry_contacts WHERE id=target FOR UPDATE;
 IF contact.id IS NULL OR contact.scope<>scope_text OR contact.congregation_id IS DISTINCT FROM congregation THEN
  RAISE EXCEPTION 'contact_not_found' USING ERRCODE='22023'; END IF;
 IF contact.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
 IF contact.user_access_id IS NULL OR access_row.id IS NULL OR access_row.id<>contact.user_access_id OR
  contact.email IS NULL OR contact.email<>access_row.user_email THEN
  RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
 UPDATE public.ministry_contacts SET user_access_id=NULL,revision=revision+1,updated_at=now(),updated_by=actor
  WHERE id=target RETURNING revision INTO revision_value;
 DELETE FROM public.user_access WHERE id=access_id;
 IF access_row.user_id IS NOT NULL THEN
  UPDATE private.access_versions SET version=version+1 WHERE user_id=access_row.user_id;
 END IF;
 response:=jsonb_build_object('id',target,'revision',revision_value,'revoked_access_id',access_id);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'revoke_contact_access',digest,response);
 RETURN response;
END $$;

CREATE FUNCTION public.ieadpe_ministry_revoke_contact_access(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.ministry_revoke_contact_access(operation_id,payload)
$$;
REVOKE ALL ON FUNCTION private.ministry_revoke_contact_access(uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_revoke_contact_access(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_revoke_contact_access(uuid,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION private.change_access(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 access_id uuid; old_row public.user_access; target_uid uuid; normalized_email text;
 requested_role text; scope_id uuid; receipt private.mutation_receipts; response jsonb; digest text;
 linked_contact public.ministry_contacts; revision_value integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF command_name NOT IN ('save_access','revoke_access') OR operation_id IS NULL OR payload IS NULL OR
  jsonb_typeof(payload)<>'object' OR EXISTS(SELECT FROM jsonb_object_keys(payload) k
   WHERE k NOT IN ('id','user_email','role','congregation_id')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF command_name='revoke_access' AND (NOT payload ? 'id' OR payload-'id'<>'{}'::jsonb OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string') THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN access_id:=(payload->>'id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 IF command_name='revoke_access' AND access_id IS NULL THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(711039001);
 IF access_id IS NOT NULL THEN SELECT * INTO old_row FROM public.user_access WHERE id=access_id; END IF;
 normalized_email:=CASE WHEN command_name='save_access' THEN lower(btrim(payload->>'user_email')) ELSE old_row.user_email END;
 IF normalized_email IS NOT NULL THEN PERFORM pg_advisory_xact_lock(hashtextextended(normalized_email,0)); END IF;
 SELECT id INTO target_uid FROM auth.users WHERE lower(btrim(email))=normalized_email
  AND email_confirmed_at IS NOT NULL ORDER BY id LIMIT 1;
 PERFORM private.lock_access(ARRAY[auth.uid(),old_row.user_id,target_uid]);
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=auth.uid() AND r.operation_id=change_access.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF access_id IS NOT NULL AND old_row.id IS NULL THEN RAISE EXCEPTION 'access_not_found' USING ERRCODE='22023'; END IF;
 IF command_name='save_access' THEN
  IF payload-ARRAY['id','user_email','role','congregation_id']<>'{}'::jsonb OR
   NOT payload ?& ARRAY['user_email','role','congregation_id'] OR
   jsonb_typeof(payload->'user_email') IS DISTINCT FROM 'string' OR
   jsonb_typeof(payload->'role') IS DISTINCT FROM 'string' OR
   jsonb_typeof(payload->'congregation_id') NOT IN ('string','null') THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  requested_role:=payload->>'role';
  BEGIN scope_id:=CASE WHEN jsonb_typeof(payload->'congregation_id')='string'
   THEN (payload->>'congregation_id')::uuid ELSE NULL END;
  EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
  IF normalized_email IS NULL OR normalized_email='' OR normalized_email NOT LIKE '%@%' OR
   requested_role NOT IN ('Membro da direção da campanha','Membro da supervisão das campanhas') OR
   (requested_role='Membro da direção da campanha' AND scope_id IS NULL) OR
   (requested_role='Membro da supervisão das campanhas' AND scope_id IS NOT NULL) THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF scope_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.congregations WHERE id=scope_id AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
  IF access_id IS NOT NULL AND EXISTS(SELECT FROM public.ministry_contacts WHERE user_access_id=access_id) THEN
   SELECT * INTO linked_contact FROM public.ministry_contacts WHERE user_access_id=access_id FOR UPDATE;
   IF linked_contact.email IS DISTINCT FROM old_row.user_email OR
    old_row.user_email IS DISTINCT FROM normalized_email OR old_row.role IS DISTINCT FROM requested_role OR
    old_row.congregation_id IS DISTINCT FROM scope_id THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
   IF target_uid IS NULL AND old_row.user_id IS NOT NULL THEN
    RAISE EXCEPTION 'verified_email_required' USING ERRCODE='22023'; END IF;
   IF target_uid IS NOT NULL AND old_row.user_id IS NOT NULL AND target_uid<>old_row.user_id THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
  END IF;
  IF access_id IS NULL THEN
   INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
    VALUES(normalized_email,target_uid,requested_role,scope_id) RETURNING id INTO access_id;
  ELSE
   UPDATE public.user_access SET user_email=normalized_email,user_id=target_uid,
    role=requested_role,congregation_id=scope_id,updated_at=now() WHERE id=access_id;
  END IF;
 ELSE
  IF access_id IS NULL THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  SELECT * INTO linked_contact FROM public.ministry_contacts WHERE user_access_id=access_id FOR UPDATE;
  IF linked_contact.id IS NOT NULL THEN
   IF linked_contact.email IS DISTINCT FROM old_row.user_email THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
   UPDATE public.ministry_contacts SET user_access_id=NULL,revision=revision+1,
    updated_at=now(),updated_by=auth.uid() WHERE id=linked_contact.id RETURNING revision INTO revision_value;
  END IF;
  DELETE FROM public.user_access WHERE id=access_id;
 END IF;
 UPDATE private.access_versions SET version=version+1 WHERE user_id IN (old_row.user_id,target_uid);
 response:=jsonb_build_object('id',access_id);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(auth.uid(),operation_id,command_name,digest,response);
 RETURN response;
END $$;
REVOKE ALL ON FUNCTION private.change_access(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;

COMMIT;


