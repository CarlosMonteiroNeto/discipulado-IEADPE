CREATE TABLE private.ministry_cursor_secret (singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), secret text NOT NULL);
ALTER TABLE private.ministry_cursor_secret ENABLE ROW LEVEL SECURITY;
INSERT INTO private.ministry_cursor_secret(singleton,secret) VALUES(true,gen_random_uuid()::text||gen_random_uuid()::text);

CREATE FUNCTION private.ministry_supervisor() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(
  SELECT FROM public.ministry_grants g WHERE g.user_id=auth.uid() AND g.active
  AND g.role='ministry_supervision' AND g.congregation_id IS NULL)
$$;
CREATE FUNCTION private.ministry_can_access(scope_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND scope_id IS NOT NULL AND (
  private.ministry_supervisor() OR EXISTS(
   SELECT FROM public.ministry_grants g JOIN public.congregations c ON c.id=g.congregation_id
   WHERE g.user_id=auth.uid() AND g.active AND g.role='ministry_staff'
   AND g.congregation_id=scope_id AND c.archived_at IS NULL))
$$;

ALTER TABLE public.ministry_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_role_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_session_roster ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY ministry_grants_self_read ON public.ministry_grants FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY ministry_contacts_scope_read ON public.ministry_contacts FOR SELECT TO authenticated
 USING((scope='supervision' AND private.ministry_supervisor()) OR
       (scope='congregation' AND private.ministry_can_access(congregation_id)));
CREATE POLICY ministry_role_slots_scope_read ON public.ministry_role_slots FOR SELECT TO authenticated
 USING((scope='supervision' AND private.ministry_supervisor()) OR
       (scope='congregation' AND private.ministry_can_access(congregation_id)));
CREATE POLICY ministry_students_scope_read ON public.ministry_students FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));
CREATE POLICY ministry_classes_scope_read ON public.ministry_classes FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));
CREATE POLICY ministry_enrollments_scope_read ON public.ministry_enrollments FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));
CREATE POLICY ministry_sessions_scope_read ON public.ministry_sessions FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));
CREATE POLICY ministry_session_roster_scope_read ON public.ministry_session_roster FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));
CREATE POLICY ministry_attendance_scope_read ON public.ministry_attendance FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));

-- Client roles have read-only access to row-scoped business projections. All
-- writes remain reserved to trusted, scope-checking command RPCs in migration 013+.
REVOKE ALL ON public.ministry_grants,public.ministry_contacts,public.ministry_role_slots,
 public.ministry_students,public.ministry_classes,public.ministry_enrollments,
 public.ministry_sessions,public.ministry_session_roster,public.ministry_attendance
 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.ministry_contacts,public.ministry_role_slots,public.ministry_students,
 public.ministry_classes,public.ministry_enrollments,public.ministry_sessions,
 public.ministry_session_roster,public.ministry_attendance TO authenticated;
GRANT SELECT ON public.ministry_grants TO authenticated;
REVOKE ALL ON FUNCTION private.ministry_supervisor(),private.ministry_can_access(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.ministry_supervisor(),private.ministry_can_access(uuid) TO authenticated;

CREATE FUNCTION public.ieadpe_ministry_list_directory(request jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE
 requested_scope text; congregation uuid; requested_role text; prefix text;
 page_size integer; cursor_text text; cursor_data jsonb; after_name text; after_id uuid;
 items jsonb; item_count integer; next_value text; tail_item jsonb; cursor_json jsonb;
 cursor_payload text; supplied_signature text; secret_value text;
 valid_roles constant text[]:=ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'];
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['scope','congregation_id','role_code','name_prefix','limit','cursor']<>'{}'::jsonb OR
  jsonb_typeof(request->'scope') IS DISTINCT FROM 'string' OR jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request ? 'congregation_id' AND jsonb_typeof(request->'congregation_id') NOT IN ('string','null')) OR
  (request ? 'role_code' AND jsonb_typeof(request->'role_code') NOT IN ('string','null')) OR
  (request ? 'name_prefix' AND jsonb_typeof(request->'name_prefix') NOT IN ('string','null')) OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
   RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 requested_scope:=request->>'scope';
 IF requested_scope NOT IN ('congregation','supervision','all') THEN RAISE EXCEPTION 'invalid_scope' USING ERRCODE='22023'; END IF;
 page_size:=(request->>'limit')::integer;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=CASE WHEN jsonb_typeof(request->'congregation_id')='string' THEN (request->>'congregation_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END;
 requested_role:=request->>'role_code'; prefix:=request->>'name_prefix'; cursor_text:=request->>'cursor';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix)) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF requested_role IS NOT NULL AND NOT requested_role=ANY(valid_roles) THEN RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023'; END IF;
 IF requested_scope='congregation' THEN
  IF congregation IS NULL OR (requested_role IS NOT NULL AND requested_role=ANY(ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary'])) THEN
   RAISE EXCEPTION 'invalid_filter' USING ERRCODE='22023'; END IF;
  IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSIF requested_scope='supervision' THEN
  IF congregation IS NOT NULL OR (requested_role IS NOT NULL AND requested_role=ANY(ARRAY['congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'])) THEN
   RAISE EXCEPTION 'invalid_filter' USING ERRCODE='22023'; END IF;
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
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' OR jsonb_typeof(cursor_data->'id') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  after_name:=cursor_data->>'name';
 END IF;
 WITH visible AS (
  SELECT c.id,c.name,c.normalized_name,c.scope,c.congregation_id,c.role_code,c.phone_e164
  FROM public.ministry_contacts c
  WHERE ((requested_scope='all') OR (requested_scope='supervision' AND c.scope='supervision') OR
         (requested_scope='congregation' AND c.scope='congregation' AND c.congregation_id=congregation))
   AND (requested_role IS NULL OR c.role_code=requested_role)
   AND (prefix IS NULL OR c.normalized_name LIKE lower(prefix)||'%')
   AND (after_name IS NULL OR (c.normalized_name,c.id)>(after_name,after_id))
 ), page AS (
  SELECT * FROM visible ORDER BY normalized_name,id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'normalized_name',p.normalized_name,
  'scope',p.scope,'congregation_id',p.congregation_id,'role_code',p.role_code,'phone_e164',p.phone_e164)
  ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*) INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items- (item_count-1);
  DECLARE
   tail jsonb:=items->(page_size-1);
   cursor_json jsonb;
  BEGIN
   cursor_json:=jsonb_build_object('uid',auth.uid(),'scope',requested_scope,'congregation_id',congregation,
    'role_code',requested_role,'name_prefix',prefix,'name',tail->>'normalized_name','id',tail->>'id');
   cursor_payload:=replace(encode(convert_to(cursor_json::text,'UTF8'),'base64'),E'\n','');
   SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
   next_value:=cursor_payload||'.'||encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex');
  END;
 ELSE next_value:=NULL;
 END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_value);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_directory(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_directory(jsonb) TO authenticated;
