BEGIN;

CREATE TABLE public.ministry_people (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 congregation_id uuid NOT NULL REFERENCES public.congregations(id) ON DELETE RESTRICT,
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES auth.users(id),
 name text NOT NULL CHECK(name=btrim(name) AND name<>''),
 normalized_name text NOT NULL CHECK(normalized_name=lower(name)),
 phone text,
 birth_date date,
 address jsonb CHECK(address IS NULL OR
  (jsonb_typeof(address)='object' AND
   address ?& ARRAY['street','district','city','postal_code','state_code'] AND
   address-ARRAY['street','district','city','postal_code','state_code']='{}'::jsonb AND
   jsonb_typeof(address->'street') IN ('string','null') AND
   jsonb_typeof(address->'district') IN ('string','null') AND
   jsonb_typeof(address->'city') IN ('string','null') AND
   jsonb_typeof(address->'postal_code') IN ('string','null') AND
   jsonb_typeof(address->'state_code') IN ('string','null'))),
 UNIQUE(id,congregation_id)
);
CREATE INDEX ministry_people_scope_name
 ON public.ministry_people(congregation_id,normalized_name,id);
ALTER TABLE public.ministry_people ENABLE ROW LEVEL SECURITY;
CREATE POLICY ministry_people_scope_read ON public.ministry_people
 FOR SELECT TO authenticated USING(private.ministry_can_access(congregation_id));
REVOKE ALL ON public.ministry_people FROM PUBLIC,anon,authenticated;

ALTER TABLE public.converts ADD COLUMN revision integer NOT NULL DEFAULT 1 CHECK(revision>0);
ALTER TABLE public.converts ADD COLUMN person_id uuid;
ALTER TABLE public.converts ADD CONSTRAINT converts_person_scope_check
 CHECK(person_id IS NULL OR congregation_id IS NOT NULL);
ALTER TABLE public.converts ADD CONSTRAINT converts_person_scope_fk
 FOREIGN KEY(person_id,congregation_id)
 REFERENCES public.ministry_people(id,congregation_id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX converts_one_per_person
 ON public.converts(person_id) WHERE person_id IS NOT NULL;

ALTER TABLE public.ministry_students ADD COLUMN person_id uuid;
ALTER TABLE public.ministry_students ADD CONSTRAINT ministry_students_person_scope_fk
 FOREIGN KEY(person_id,congregation_id)
 REFERENCES public.ministry_people(id,congregation_id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX ministry_students_one_per_person
 ON public.ministry_students(person_id) WHERE person_id IS NOT NULL;

-- Generate a distinct canonical identity for each scoped convert. The source
-- UUID remains on its original row; an explicit mapping table connects them.
CREATE TEMP TABLE ministry_people_backfill_map (
 convert_id uuid PRIMARY KEY,
 person_id uuid NOT NULL UNIQUE
) ON COMMIT DROP;
INSERT INTO ministry_people_backfill_map(convert_id,person_id)
 SELECT c.id,gen_random_uuid()
 FROM public.converts c
 WHERE c.congregation_id IS NOT NULL
 ORDER BY c.id;

INSERT INTO public.ministry_people(
 id,congregation_id,revision,updated_by,name,normalized_name,phone,birth_date,address
)
SELECT m.person_id,c.congregation_id,1,NULL,
 c.name,lower(btrim(c.name)),
 CASE WHEN c.phone ~ '^\+[1-9][0-9]{1,14}$' THEN c.phone ELSE NULL END,
 NULL,
 CASE WHEN c.address IS NULL THEN NULL ELSE jsonb_build_object(
  'street',c.address,'district',NULL,'city',NULL,'postal_code',NULL,'state_code',NULL
 ) END
FROM ministry_people_backfill_map m
JOIN public.converts c ON c.id=m.convert_id;

UPDATE public.converts c SET person_id=m.person_id
FROM ministry_people_backfill_map m WHERE c.id=m.convert_id;

-- Preserve all student snapshots and histories. Only an explicit, same-scope
-- convert_id is evidence for the initial person link.
UPDATE public.ministry_students s SET person_id=m.person_id
FROM public.converts c
JOIN ministry_people_backfill_map m ON m.convert_id=c.id
WHERE s.convert_id=c.id
 AND s.congregation_id=c.congregation_id
 AND (SELECT count(*) FROM public.converts c2
      WHERE c2.id=s.convert_id AND c2.congregation_id=s.congregation_id)=1
 AND NOT EXISTS(
  SELECT FROM public.ministry_students other
  WHERE other.person_id=m.person_id AND other.id<>s.id
 );

CREATE FUNCTION private.prevent_ministry_student_person_rewrite() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.person_id IS NOT NULL AND NEW.person_id IS DISTINCT FROM OLD.person_id THEN
  RAISE EXCEPTION 'person_link_immutable' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.prevent_ministry_student_person_rewrite() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ministry_student_person_link_immutable
 BEFORE UPDATE OF person_id ON public.ministry_students
 FOR EACH ROW EXECUTE FUNCTION private.prevent_ministry_student_person_rewrite();

CREATE FUNCTION public.ieadpe_ministry_list_people(request jsonb) RETURNS jsonb
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
 BEGIN
  scope_id:=(request->>'congregation_id')::uuid;
  page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 prefix:=request->>'name_prefix';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix) OR length(prefix)>200) THEN
  RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor';
 cursor_data:=private.ministry_read_cursor_decode(cursor_text,'people');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','name','person_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN
   RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_id:=(cursor_data->>'person_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT p.id,p.congregation_id,p.name,p.normalized_name,p.phone,p.birth_date,p.address,p.revision
  FROM public.ministry_people p
  WHERE p.congregation_id=scope_id AND
   (prefix IS NULL OR left(p.normalized_name,length(lower(prefix)))=lower(prefix)) AND
   (after_name IS NULL OR (p.normalized_name,p.id)>(after_name,after_id))
  ORDER BY p.normalized_name,p.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'congregation_id',p.congregation_id,
  'name',p.name,'normalized_name',p.normalized_name,'phone',p.phone,'birth_date',p.birth_date,
  'address',p.address,'person_revision',p.revision) ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object(
   'uid',auth.uid(),'resource','people','congregation_id',scope_id,'name_prefix',prefix,
   'name',tail->>'normalized_name','person_id',tail->>'id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_ministry_get_person(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; person_uuid uuid; person_row public.ministry_people;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','person_id']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','person_id'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'person_id') IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN
  scope_id:=(request->>'congregation_id')::uuid;
  person_uuid:=(request->>'person_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO person_row FROM public.ministry_people p
  WHERE p.id=person_uuid AND p.congregation_id=scope_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'person_not_found' USING ERRCODE='22023'; END IF;
 RETURN jsonb_build_object('person',jsonb_build_object(
  'id',person_row.id,'congregation_id',person_row.congregation_id,
  'name',person_row.name,'normalized_name',person_row.normalized_name,
  'phone',person_row.phone,'birth_date',person_row.birth_date,'address',person_row.address,
  'created_at',person_row.created_at,'updated_at',person_row.updated_at,
  'updated_by',person_row.updated_by),
  'person_revision',person_row.revision);
END $$;

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
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 prefix:=request->>'name_prefix';
 IF prefix IS NOT NULL AND (prefix='' OR prefix<>btrim(prefix) OR length(prefix)>200) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'students');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','name','student_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
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
  WHERE s.congregation_id=scope_id AND s.archived_at IS NULL AND
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

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_class_students(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE congregation uuid; class_uuid uuid; page_size integer; cursor_text text; cursor_data jsonb;
 after_name text; after_student uuid; after_enrollment uuid; items jsonb; item_count integer; tail jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
  request-ARRAY['congregation_id','class_id','limit','cursor']<>'{}'::jsonb OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'class_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
  (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN congregation:=(request->>'congregation_id')::uuid; class_uuid:=(request->>'class_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_can_access(congregation) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT FROM public.ministry_classes c WHERE c.id=class_uuid AND c.congregation_id=congregation) THEN
  RAISE EXCEPTION 'class_not_found' USING ERRCODE='22023'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'class_students');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','class_id','name','student_id','enrollment_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM congregation::text OR
   cursor_data->>'class_id' IS DISTINCT FROM class_uuid::text OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_student:=(cursor_data->>'student_id')::uuid; after_enrollment:=(cursor_data->>'enrollment_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id AS student_id,s.person_id,p.revision AS person_revision,
   coalesce(p.name,s.name) AS name,coalesce(p.normalized_name,s.normalized_name) AS normalized_name,
   CASE WHEN p.id IS NULL THEN s.phone_e164 ELSE p.phone END AS phone_e164,
   CASE WHEN p.id IS NULL THEN s.birth_date ELSE p.birth_date END AS birth_date,
   CASE WHEN p.id IS NULL THEN s.address ELSE p.address END AS address,
   s.education,s.marital_status,s.new_convert,s.water_baptized,s.wants_baptism,
   s.archived_at,s.revision AS student_revision,s.created_at AS student_created_at,
   s.updated_at AS student_updated_at,s.updated_by AS student_updated_by,
   e.id AS enrollment_id,e.start_date,e.end_date,e.status AS enrollment_status,
   e.revision AS enrollment_revision,e.created_at AS enrollment_created_at,
   e.updated_at AS enrollment_updated_at,e.updated_by AS enrollment_updated_by
  FROM public.ministry_enrollments e
  JOIN public.ministry_students s ON s.id=e.student_id AND s.congregation_id=e.congregation_id
  LEFT JOIN public.ministry_people p ON p.id=s.person_id AND p.congregation_id=s.congregation_id
  WHERE e.congregation_id=congregation AND e.class_id=class_uuid AND e.status='active' AND
   (after_name IS NULL OR (coalesce(p.normalized_name,s.normalized_name),s.id,e.id)>(after_name,after_student,after_enrollment))
  ORDER BY coalesce(p.normalized_name,s.normalized_name),s.id,e.id LIMIT page_size+1
 ), packed AS (
  SELECT jsonb_build_object('student',jsonb_build_object('id',student_id,'person_id',person_id,
   'person_revision',person_revision,'congregation_id',congregation,'name',name,
   'normalized_name',normalized_name,'phone_e164',phone_e164,'birth_date',birth_date,
   'address',address,'education',education,'marital_status',marital_status,
   'new_convert',new_convert,'water_baptized',water_baptized,'wants_baptism',wants_baptism,
   'archived_at',archived_at,'revision',student_revision,'created_at',student_created_at,
   'updated_at',student_updated_at,'updated_by',student_updated_by),
   'enrollment',jsonb_build_object('id',enrollment_id,'congregation_id',congregation,
   'student_id',student_id,'class_id',class_uuid,'start_date',start_date,'end_date',end_date,
   'status',enrollment_status,'revision',enrollment_revision,'created_at',enrollment_created_at,
   'updated_at',enrollment_updated_at,'updated_by',enrollment_updated_by)) AS item,
   normalized_name,student_id,enrollment_id FROM page
 )
 SELECT coalesce(jsonb_agg(item ORDER BY normalized_name,student_id,enrollment_id),'[]'::jsonb),count(*)
 INTO items,item_count FROM packed;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  cursor_data:=jsonb_build_object('uid',auth.uid(),'resource','class_students',
   'congregation_id',congregation,'class_id',class_uuid,
   'name',tail->'student'->>'normalized_name','student_id',tail->'student'->>'id',
   'enrollment_id',tail->'enrollment'->>'id');
  cursor_text:=private.ministry_read_cursor_encode(cursor_data);
 ELSE cursor_text:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',cursor_text);
END $$;

CREATE FUNCTION public.ieadpe_ministry_save_person(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); receipt private.mutation_receipts; digest text; response jsonb;
 target uuid; scope_id uuid; expected integer; revision_value integer; name_value text;
 phone_value text; birth_value date; address_value jsonb; person_row public.ministry_people;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['id','congregation_id','expected_revision','person']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['id','congregation_id','expected_revision','person'] OR
  jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
  (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' OR
  jsonb_typeof(payload->'person') IS DISTINCT FROM 'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF (payload->'person')-ARRAY['name','phone','birth_date','address']<>'{}'::jsonb OR
  NOT (payload->'person') ?& ARRAY['name','phone','birth_date','address'] OR
  jsonb_typeof(payload->'person'->'name') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'person'->'phone') NOT IN ('string','null') OR
  jsonb_typeof(payload->'person'->'birth_date') NOT IN ('string','null') OR
  jsonb_typeof(payload->'person'->'address') NOT IN ('object','null') THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 address_value:=payload->'person'->'address';
 IF address_value<>'null'::jsonb AND
  (address_value-ARRAY['street','district','city','postal_code','state_code']<>'{}'::jsonb OR
   NOT address_value ?& ARRAY['street','district','city','postal_code','state_code'] OR
   EXISTS(SELECT FROM jsonb_each(address_value) a WHERE jsonb_typeof(a.value) NOT IN ('string','null'))) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid;
  scope_id:=(payload->>'congregation_id')::uuid;
  expected:=(payload->>'expected_revision')::integer;
  name_value:=btrim(payload->'person'->>'name');
  phone_value:=payload->'person'->>'phone';
  IF jsonb_typeof(payload->'person'->'birth_date')='string' THEN
   IF payload->'person'->>'birth_date' !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
   birth_value:=(payload->'person'->>'birth_date')::date;
  END IF;
 EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
 END;
 IF name_value='' OR length(name_value)>200 THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ieadpe_ministry_save_person.operation_id;
 IF FOUND THEN
  IF receipt.command<>'save_person' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO person_row FROM public.ministry_people p
  WHERE p.id=target AND p.congregation_id=scope_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'person_not_found' USING ERRCODE='22023'; END IF;
 IF person_row.revision<>expected THEN RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
 UPDATE public.ministry_people SET name=name_value,normalized_name=lower(name_value),
  phone=phone_value,birth_date=birth_value,
  address=CASE WHEN address_value='null'::jsonb THEN NULL ELSE address_value END,
  revision=revision+1,updated_at=now(),updated_by=actor
 WHERE id=target RETURNING revision INTO revision_value;
 response:=jsonb_build_object('id',target,'revision',revision_value);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'save_person',digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'registry_conflict' USING ERRCODE='23505';
 WHEN check_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
 WHEN foreign_key_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
END $$;

CREATE FUNCTION public.ieadpe_ministry_link_student_person(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); receipt private.mutation_receipts; digest text; response jsonb;
 scope_id uuid; student_uuid uuid; person_uuid uuid; expected_student integer; expected_person integer;
 student_row public.ministry_students; person_row public.ministry_people;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' OR
  payload-ARRAY['congregation_id','student_id','person_id','expected_student_revision','expected_person_revision']<>'{}'::jsonb OR
  NOT payload ?& ARRAY['congregation_id','student_id','person_id','expected_student_revision','expected_person_revision'] OR
  jsonb_typeof(payload->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'student_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'person_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(payload->'expected_student_revision') IS DISTINCT FROM 'number' OR
  (payload->'expected_student_revision')::text !~ '^[1-9][0-9]*$' OR
  jsonb_typeof(payload->'expected_person_revision') IS DISTINCT FROM 'number' OR
  (payload->'expected_person_revision')::text !~ '^[1-9][0-9]*$' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 BEGIN
  scope_id:=(payload->>'congregation_id')::uuid;
  student_uuid:=(payload->>'student_id')::uuid;
  person_uuid:=(payload->>'person_id')::uuid;
  expected_student:=(payload->>'expected_student_revision')::integer;
  expected_person:=(payload->>'expected_person_revision')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
 END;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
  WHERE r.actor_uid=actor AND r.operation_id=ieadpe_ministry_link_student_person.operation_id;
 IF FOUND THEN
  IF receipt.command<>'link_student_person' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 SELECT * INTO person_row FROM public.ministry_people p
  WHERE p.id=person_uuid AND p.congregation_id=scope_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'person_not_found' USING ERRCODE='22023'; END IF;
 SELECT * INTO student_row FROM public.ministry_students s
  WHERE s.id=student_uuid AND s.congregation_id=scope_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found' USING ERRCODE='22023'; END IF;
 IF person_row.revision<>expected_person OR student_row.revision<>expected_student THEN
  RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001'; END IF;
 IF student_row.person_id IS NOT NULL THEN RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023'; END IF;
 BEGIN
  UPDATE public.ministry_students SET person_id=person_uuid,revision=revision+1,
   updated_at=now(),updated_by=actor WHERE id=student_uuid RETURNING * INTO student_row;
 EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023';
 END;
 response:=jsonb_build_object('student_id',student_uuid,'person_id',person_uuid,
  'student_revision',student_row.revision,'person_revision',person_row.revision);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
  VALUES(actor,operation_id,'link_student_person',digest,response);
 RETURN response;
EXCEPTION
 WHEN unique_violation THEN RAISE EXCEPTION 'person_link_conflict' USING ERRCODE='22023';
 WHEN check_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
 WHEN foreign_key_violation THEN RAISE EXCEPTION 'registry_invalid' USING ERRCODE='22023';
END $$;

REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_people(jsonb),
 public.ieadpe_ministry_get_person(jsonb),
 public.ieadpe_ministry_list_students(jsonb),
 public.ieadpe_ministry_list_class_students(jsonb),
 public.ieadpe_ministry_save_person(uuid,jsonb),
 public.ieadpe_ministry_link_student_person(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_people(jsonb),
 public.ieadpe_ministry_get_person(jsonb),
 public.ieadpe_ministry_list_students(jsonb),
 public.ieadpe_ministry_list_class_students(jsonb),
 public.ieadpe_ministry_save_person(uuid,jsonb),
 public.ieadpe_ministry_link_student_person(uuid,jsonb) TO authenticated;

COMMIT;
