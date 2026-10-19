BEGIN;

-- Contact detail gives non-managers only the link state needed to decide
-- whether the directory email can be edited. Assignment identity remains
-- global-manager-only.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_get_contact(request jsonb) RETURNS jsonb
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
  'access_linked',contact_row.user_access_id IS NOT NULL,
  'created_at',contact_row.created_at,'updated_at',contact_row.updated_at,'updated_by',contact_row.updated_by);
 RETURN jsonb_build_object('contact',detail,'access',access_detail);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_contact(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_contact(jsonb) TO authenticated;

-- This read supplies exact unlinked assignment choices only to global
-- managers. It never exposes user IDs and does not select by email.
CREATE FUNCTION public.ieadpe_ministry_list_access_candidates(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 requested_scope text; congregation uuid; requested_role text; page_size integer;
 cursor_text text; cursor_data jsonb; after_id uuid; items jsonb; item_count integer;
 next_value text; cursor_json jsonb; cursor_payload text; supplied_signature text;
 secret_value text; tail_item jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['scope','congregation_id','role','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['scope','congregation_id','role','limit','cursor'] OR
  jsonb_typeof(request->'scope') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'role') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  jsonb_typeof(request->'congregation_id') NOT IN ('string','null') OR
  jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 requested_scope:=request->>'scope'; requested_role:=request->>'role'; cursor_text:=request->>'cursor';
 IF (request->'limit')::text !~ '^[0-9]+$' THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 page_size:=(request->>'limit')::integer;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 BEGIN
  congregation:=CASE WHEN jsonb_typeof(request->'congregation_id')='string'
   THEN (request->>'congregation_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END;
 IF requested_scope NOT IN ('congregation','supervision') OR
  (requested_scope='congregation' AND
   (congregation IS NULL OR requested_role<>'Membro da direção da campanha')) OR
  (requested_scope='supervision' AND
   (congregation IS NOT NULL OR requested_role<>'Membro da supervisão das campanhas')) THEN
  RAISE EXCEPTION 'invalid_filter' USING ERRCODE='22023'; END IF;
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF requested_scope='congregation' AND NOT EXISTS(
  SELECT FROM public.congregations WHERE id=congregation AND archived_at IS NULL) THEN
  RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;

 IF cursor_text IS NOT NULL THEN
  BEGIN
   IF length(cursor_text)-length(replace(cursor_text,'.',''))<>1 THEN RAISE EXCEPTION 'bad signature'; END IF;
   cursor_payload:=split_part(cursor_text,'.',1); supplied_signature:=split_part(cursor_text,'.',2);
   SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
   IF supplied_signature<>encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex') THEN
    RAISE EXCEPTION 'bad signature'; END IF;
   cursor_data:=convert_from(decode(cursor_payload,'base64'),'UTF8')::jsonb;
   after_id:=(cursor_data->>'id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
  IF cursor_data-ARRAY['uid','scope','congregation_id','role','id']<>'{}'::jsonb OR
   cursor_data->>'uid'<>auth.uid()::text OR cursor_data->>'scope'<>requested_scope OR
   cursor_data->>'congregation_id' IS DISTINCT FROM congregation::text OR
   cursor_data->>'role' IS DISTINCT FROM requested_role OR
   jsonb_typeof(cursor_data->'id') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
 END IF;

 WITH page AS (
  SELECT ua.id,ua.user_email,ua.role,ua.congregation_id
  FROM public.user_access ua
  WHERE ua.role=requested_role AND ua.congregation_id IS NOT DISTINCT FROM congregation
   AND (after_id IS NULL OR ua.id>after_id)
   AND NOT EXISTS(SELECT FROM public.ministry_contacts mc WHERE mc.user_access_id=ua.id)
  ORDER BY ua.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'email',p.user_email,'role',p.role,
  'scope',requested_scope,'congregation_id',p.congregation_id) ORDER BY p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail_item:=items->(page_size-1);
  cursor_json:=jsonb_build_object('uid',auth.uid(),'scope',requested_scope,
   'congregation_id',congregation,'role',requested_role,'id',tail_item->>'id');
  cursor_payload:=replace(encode(convert_to(cursor_json::text,'UTF8'),'base64'),E'\n','');
  SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
  next_value:=cursor_payload||'.'||encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex');
 ELSE next_value:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_value);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_access_candidates(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_access_candidates(jsonb) TO authenticated;

COMMIT;
