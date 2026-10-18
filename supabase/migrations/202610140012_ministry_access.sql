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

-- Ministry lists and detail reads must pass through bounded, scope-aware RPCs.
-- Table privileges stay closed so clients cannot scan unbounded directories or
-- read the frozen session roster directly.
REVOKE ALL ON public.ministry_grants,public.ministry_contacts,public.ministry_role_slots,
 public.ministry_students,public.ministry_classes,public.ministry_enrollments,
 public.ministry_sessions,public.ministry_session_roster,public.ministry_attendance
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.ministry_supervisor(),private.ministry_can_access(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.ministry_supervisor(),private.ministry_can_access(uuid) TO authenticated;

-- Composite FKs cannot validate a nullable congregation_id: PostgreSQL skips
-- the FK check when any referencing column is null. Validate both scope and
-- role against the referenced contact while holding a stable row lock.
CREATE FUNCTION private.validate_ministry_role_slot_contact() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE contact public.ministry_contacts;
BEGIN
 IF NEW.contact_id IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO contact FROM public.ministry_contacts WHERE id=NEW.contact_id FOR UPDATE;
 IF NOT FOUND OR contact.scope IS DISTINCT FROM NEW.scope OR
    contact.congregation_id IS DISTINCT FROM NEW.congregation_id OR
    contact.role_code IS DISTINCT FROM NEW.role_code THEN
  RAISE EXCEPTION 'invalid_role_holder' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.validate_ministry_role_slot_contact() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ministry_role_slot_contact_scope
 BEFORE INSERT OR UPDATE OF scope,congregation_id,role_code,contact_id ON public.ministry_role_slots
 FOR EACH ROW EXECUTE FUNCTION private.validate_ministry_role_slot_contact();

CREATE FUNCTION private.preserve_ministry_role_slot_contact() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (NEW.scope,NEW.congregation_id,NEW.role_code) IS DISTINCT FROM
    (OLD.scope,OLD.congregation_id,OLD.role_code) AND EXISTS(
      SELECT FROM public.ministry_role_slots s WHERE s.contact_id=OLD.id AND
       (s.scope,s.congregation_id,s.role_code) IS DISTINCT FROM
       (NEW.scope,NEW.congregation_id,NEW.role_code)) THEN
  RAISE EXCEPTION 'role_holder_assigned' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.preserve_ministry_role_slot_contact() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ministry_contact_preserve_role_slot
 BEFORE UPDATE OF scope,congregation_id,role_code ON public.ministry_contacts
 FOR EACH ROW EXECUTE FUNCTION private.preserve_ministry_role_slot_contact();

CREATE FUNCTION public.ieadpe_ministry_list_directory(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 requested_scope text; congregation uuid; requested_role text; prefix text;
 page_size integer; cursor_text text; cursor_data jsonb; after_name text; after_id uuid;
 items jsonb; item_count integer; next_value text; tail_item jsonb; cursor_json jsonb;
 cursor_payload text; supplied_signature text; secret_value text;
 valid_roles constant text[]:=ARRAY['campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary'];
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['scope','congregation_id','role_code','name_prefix','limit','cursor']<>'{}'::jsonb OR
  jsonb_typeof(request->'scope') IS DISTINCT FROM 'string' OR jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
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

CREATE FUNCTION private.ministry_read_cursor_encode(cursor_data jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE cursor_payload text; secret_value text;
BEGIN
 SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
 cursor_payload:=replace(encode(convert_to(cursor_data::text,'UTF8'),'base64'),E'\n','');
 RETURN cursor_payload||'.'||encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex');
END $$;
CREATE FUNCTION private.ministry_read_cursor_decode(cursor_text text,resource_name text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE cursor_payload text; supplied_signature text; secret_value text; cursor_data jsonb;
BEGIN
 IF cursor_text IS NULL THEN RETURN NULL; END IF;
 BEGIN
  IF length(cursor_text)-length(replace(cursor_text,'.',''))<>1 THEN RAISE EXCEPTION 'bad cursor'; END IF;
  cursor_payload:=split_part(cursor_text,'.',1); supplied_signature:=split_part(cursor_text,'.',2);
  SELECT secret INTO secret_value FROM private.ministry_cursor_secret WHERE singleton;
  IF supplied_signature<>encode(sha256(convert_to(secret_value||'.'||cursor_payload,'UTF8')),'hex') THEN RAISE EXCEPTION 'bad signature'; END IF;
  cursor_data:=convert_from(decode(cursor_payload,'base64'),'UTF8')::jsonb;
 EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 IF cursor_data->>'uid' IS DISTINCT FROM auth.uid()::text OR cursor_data->>'resource' IS DISTINCT FROM resource_name THEN
  RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
 RETURN cursor_data;
END $$;
REVOKE ALL ON FUNCTION private.ministry_read_cursor_encode(jsonb),private.ministry_read_cursor_decode(text,text) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.ieadpe_ministry_list_class_students(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; class_uuid uuid; page_size integer; cursor_text text; cursor_data jsonb;
 after_name text; after_student uuid; after_enrollment uuid; items jsonb; item_count integer; tail jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','class_id','limit','cursor']<>'{}'::jsonb OR
    jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR jsonb_typeof(request->'class_id') IS DISTINCT FROM 'string' OR
    jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
    (request->'limit')::text !~ '^[0-9]+$' OR
    (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=(request->>'congregation_id')::uuid; class_uuid:=(request->>'class_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT FROM public.ministry_classes c WHERE c.id=class_uuid AND c.congregation_id=congregation) THEN RAISE EXCEPTION 'class_not_found' USING ERRCODE='22023'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'class_students');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','class_id','name','student_id','enrollment_id']<>'{}'::jsonb OR
    cursor_data->>'congregation_id' IS DISTINCT FROM congregation::text OR cursor_data->>'class_id' IS DISTINCT FROM class_uuid::text OR
    jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_student:=(cursor_data->>'student_id')::uuid; after_enrollment:=(cursor_data->>'enrollment_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id AS student_id,s.name,s.normalized_name,s.phone_e164,s.birth_date,s.address,s.education,s.marital_status,
   s.new_convert,s.water_baptized,s.wants_baptism,s.archived_at,s.revision AS student_revision,s.created_at AS student_created_at,
   s.updated_at AS student_updated_at,s.updated_by AS student_updated_by,e.id AS enrollment_id,e.start_date,e.end_date,e.status AS enrollment_status,
   e.revision AS enrollment_revision,e.created_at AS enrollment_created_at,e.updated_at AS enrollment_updated_at,e.updated_by AS enrollment_updated_by
  FROM public.ministry_enrollments e JOIN public.ministry_students s ON s.id=e.student_id AND s.congregation_id=e.congregation_id
  WHERE e.congregation_id=congregation AND e.class_id=class_uuid AND e.status='active'
   AND (after_name IS NULL OR (s.normalized_name,s.id,e.id)>(after_name,after_student,after_enrollment))
  ORDER BY s.normalized_name,s.id,e.id LIMIT page_size+1
 ), packed AS (
  SELECT jsonb_build_object('student',jsonb_build_object('id',student_id,'congregation_id',congregation,'name',name,
    'normalized_name',normalized_name,'phone_e164',phone_e164,'birth_date',birth_date,'address',address,'education',education,
    'marital_status',marital_status,'new_convert',new_convert,'water_baptized',water_baptized,'wants_baptism',wants_baptism,
    'archived_at',archived_at,'revision',student_revision,'created_at',student_created_at,'updated_at',student_updated_at,'updated_by',student_updated_by),
   'enrollment',jsonb_build_object('id',enrollment_id,'congregation_id',congregation,'student_id',student_id,'class_id',class_uuid,
    'start_date',start_date,'end_date',end_date,'status',enrollment_status,'revision',enrollment_revision,
    'created_at',enrollment_created_at,'updated_at',enrollment_updated_at,'updated_by',enrollment_updated_by)) AS item,
   normalized_name,student_id,enrollment_id FROM page
 )
 SELECT coalesce(jsonb_agg(item ORDER BY normalized_name,student_id,enrollment_id),'[]'::jsonb),count(*) INTO items,item_count FROM packed;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  cursor_data:=jsonb_build_object('uid',auth.uid(),'resource','class_students','congregation_id',congregation,'class_id',class_uuid,
   'name',tail->'student'->>'normalized_name','student_id',tail->'student'->>'id','enrollment_id',tail->'enrollment'->>'id');
  cursor_text:=private.ministry_read_cursor_encode(cursor_data);
 ELSE cursor_text:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',cursor_text);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_class_students(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_class_students(jsonb) TO authenticated;

CREATE FUNCTION public.ieadpe_ministry_get_session_attendance(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; session_uuid uuid; session_row public.ministry_sessions; result jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','session_id']<>'{}'::jsonb OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR jsonb_typeof(request->'session_id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=(request->>'congregation_id')::uuid; session_uuid:=(request->>'session_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO session_row FROM public.ministry_sessions WHERE id=session_uuid AND congregation_id=congregation;
 IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found' USING ERRCODE='22023'; END IF;
 SELECT jsonb_build_object('session',jsonb_build_object('id',s.id,'congregation_id',s.congregation_id,'revision',s.revision,
   'created_at',s.created_at,'updated_at',s.updated_at,'updated_by',s.updated_by,'class_id',s.class_id,'date',s.session_date,
   'topic',s.topic,'status',s.status,'roster_frozen',s.roster_frozen,'lesson_index',s.lesson_index,'lesson_part',s.lesson_part,
   'lesson_finished',s.lesson_finished),
  'roster',coalesce((SELECT jsonb_agg(jsonb_build_object('enrollment_id',r.enrollment_id,'student_id',r.student_id,
    'student_name',r.student_name,'status',coalesce(a.status,'unmarked')) ORDER BY r.enrollment_id)
   FROM public.ministry_session_roster r LEFT JOIN public.ministry_attendance a ON a.session_id=r.session_id AND a.enrollment_id=r.enrollment_id
   WHERE r.session_id=s.id AND r.congregation_id=s.congregation_id),'[]'::jsonb)) INTO result
 FROM public.ministry_sessions s WHERE s.id=session_uuid AND s.congregation_id=congregation;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_session_attendance(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_session_attendance(jsonb) TO authenticated;

CREATE FUNCTION public.ieadpe_ministry_get_enrollment_progress(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; enrollment_uuid uuid; marks record; denominator integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','enrollment_id']<>'{}'::jsonb OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR jsonb_typeof(request->'enrollment_id') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=(request->>'congregation_id')::uuid; enrollment_uuid:=(request->>'enrollment_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT FROM public.ministry_enrollments e WHERE e.id=enrollment_uuid AND e.congregation_id=congregation) THEN RAISE EXCEPTION 'enrollment_not_found' USING ERRCODE='22023'; END IF;
 SELECT count(*) FILTER(WHERE a.status='present')::integer AS present,
  count(*) FILTER(WHERE a.status='absent')::integer AS absent,count(*) FILTER(WHERE a.status='excused')::integer AS excused
 INTO marks FROM public.ministry_attendance a JOIN public.ministry_sessions s ON s.id=a.session_id AND s.congregation_id=a.congregation_id
 WHERE a.enrollment_id=enrollment_uuid AND a.congregation_id=congregation AND s.status='finalized';
 denominator:=marks.present+marks.absent;
 RETURN jsonb_build_object('enrollment_id',enrollment_uuid,'present',marks.present,'absent',marks.absent,'excused',marks.excused,
  'denominator',denominator,'percentage',CASE WHEN denominator=0 THEN NULL ELSE marks.present::numeric/denominator END,
  'rounded_percentage',CASE WHEN denominator=0 THEN NULL ELSE round(marks.present::numeric*100/denominator)::integer END);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_enrollment_progress(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_enrollment_progress(jsonb) TO authenticated;

CREATE FUNCTION public.ieadpe_ministry_get_overview(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; through_date date;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id']<>'{}'::jsonb OR
  NOT request ? 'congregation_id' OR jsonb_typeof(request->'congregation_id') NOT IN ('string','null') THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=CASE WHEN jsonb_typeof(request->'congregation_id')='string' THEN (request->>'congregation_id')::uuid ELSE NULL END;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF congregation IS NULL THEN
  IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSIF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 through_date:=(now() AT TIME ZONE 'America/Recife')::date;
 RETURN jsonb_build_object('students',(SELECT count(*) FROM public.ministry_students s WHERE congregation IS NULL OR s.congregation_id=congregation),
  'classes',(SELECT count(*) FROM public.ministry_classes c WHERE congregation IS NULL OR c.congregation_id=congregation),
  'open_sessions',(SELECT count(*) FROM public.ministry_sessions s WHERE s.status='open' AND (congregation IS NULL OR s.congregation_id=congregation)),
  'through_date',through_date);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_get_overview(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_get_overview(jsonb) TO authenticated;

CREATE FUNCTION public.ieadpe_ministry_list_pending_sessions(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; page_size integer; cursor_text text; cursor_data jsonb; after_congregation uuid; after_date date; after_id uuid;
 through_date date; items jsonb; item_count integer; tail jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','limit','cursor']<>'{}'::jsonb OR
  NOT request ? 'congregation_id' OR jsonb_typeof(request->'congregation_id') NOT IN ('string','null') OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=CASE WHEN jsonb_typeof(request->'congregation_id')='string' THEN (request->>'congregation_id')::uuid ELSE NULL END;
  page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF congregation IS NULL THEN
  IF NOT private.ministry_supervisor() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 ELSIF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 through_date:=(now() AT TIME ZONE 'America/Recife')::date; cursor_text:=request->>'cursor';
 cursor_data:=private.ministry_read_cursor_decode(cursor_text,'pending_sessions');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','last_congregation_id','date','id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM congregation::text THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_congregation:=(cursor_data->>'last_congregation_id')::uuid; after_date:=(cursor_data->>'date')::date; after_id:=(cursor_data->>'id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id,s.congregation_id,s.class_id,c.name AS class_name,s.session_date,s.topic
  FROM public.ministry_sessions s JOIN public.ministry_classes c ON c.id=s.class_id AND c.congregation_id=s.congregation_id
  WHERE s.status='open' AND s.session_date<=through_date AND (congregation IS NULL OR s.congregation_id=congregation)
   AND (after_date IS NULL OR (s.congregation_id,s.session_date,s.id)>(after_congregation,after_date,after_id))
  ORDER BY s.congregation_id,s.session_date,s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'class_id',p.class_id,'class_name',p.class_name,
   'congregation_id',p.congregation_id,'date',p.session_date,'topic',p.topic,'status','open') ORDER BY p.congregation_id,p.session_date,p.id),'[]'::jsonb),
  count(*) INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  cursor_data:=jsonb_build_object('uid',auth.uid(),'resource','pending_sessions','congregation_id',congregation,
   'last_congregation_id',tail->>'congregation_id','date',tail->>'date','id',tail->>'id');
  cursor_text:=private.ministry_read_cursor_encode(cursor_data);
 ELSE cursor_text:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',cursor_text);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_pending_sessions(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_pending_sessions(jsonb) TO authenticated;
