BEGIN;

-- Referral lists render the canonical structured address as nullable text. The
-- component order is part of the existing public string contract; blank
-- components are omitted and an all-blank address stays null.
CREATE FUNCTION private.ministry_referral_address(address jsonb) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN address IS NULL OR jsonb_typeof(address)<>'object' THEN NULL
  ELSE nullif(concat_ws(', ',
   nullif(btrim(address->>'street'),''),
   nullif(btrim(address->>'district'),''),
   nullif(btrim(address->>'city'),''),
   nullif(btrim(address->>'state_code'),''),
   nullif(btrim(address->>'postal_code'),'')),'')
 END
$$;
REVOKE ALL ON FUNCTION private.ministry_referral_address(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_convert_student_candidates(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; name_prefix text; cursor_text text; cursor_data jsonb;
 after_name text; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','name_prefix','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','name_prefix','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'name_prefix') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 name_prefix:=request->>'name_prefix';
 IF name_prefix='' OR length(name_prefix)>200 OR name_prefix<>btrim(name_prefix) THEN RAISE EXCEPTION 'invalid_prefix' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT FROM private.admin_allowlist a WHERE a.user_id=auth.uid()) AND
  NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations WHERE id=scope_id AND archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'convert_student_candidates');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','name_prefix','name','student_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   cursor_data->>'name_prefix' IS DISTINCT FROM name_prefix OR
   jsonb_typeof(cursor_data->'name') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_name:=cursor_data->>'name'; after_id:=(cursor_data->>'student_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT s.id,coalesce(p.name,s.name) AS name,
   coalesce(p.normalized_name,s.normalized_name) AS normalized_name,
   CASE WHEN p.id IS NULL THEN s.phone_e164 ELSE p.phone END AS phone,
   CASE WHEN p.id IS NULL THEN s.address ELSE p.address END AS address
  FROM public.ministry_students s
  LEFT JOIN public.ministry_people p ON p.id=s.person_id AND p.congregation_id=s.congregation_id
  WHERE s.congregation_id=scope_id AND s.archived_at IS NULL AND s.convert_id IS NULL
   AND left(coalesce(p.normalized_name,s.normalized_name),length(lower(name_prefix)))=lower(name_prefix)
   AND (after_name IS NULL OR (coalesce(p.normalized_name,s.normalized_name),s.id)>(after_name,after_id))
  ORDER BY coalesce(p.normalized_name,s.normalized_name),s.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('student_id',p.id,'name',p.name,
  'phone',p.phone,'address',p.address) ORDER BY p.normalized_name,p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','convert_student_candidates','congregation_id',scope_id,
   'name_prefix',name_prefix,'name',lower(tail->>'name'),'student_id',tail->>'student_id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_convert_referrals(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scope_id uuid; page_size integer; cursor_text text; cursor_data jsonb;
 after_date date; after_id uuid; items jsonb; item_count integer; tail jsonb; next_cursor text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR request-ARRAY['congregation_id','limit','cursor']<>'{}'::jsonb OR
  NOT request ?& ARRAY['congregation_id','limit','cursor'] OR
  jsonb_typeof(request->'congregation_id') IS DISTINCT FROM 'string' OR
  jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR (request->'limit')::text !~ '^[0-9]+$' OR
  (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 BEGIN scope_id:=(request->>'congregation_id')::uuid; page_size:=(request->>'limit')::integer;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT FROM private.admin_allowlist a WHERE a.user_id=auth.uid()) AND
  NOT private.ministry_can_access(scope_id) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.congregations WHERE id=scope_id AND archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 cursor_text:=request->>'cursor'; cursor_data:=private.ministry_read_cursor_decode(cursor_text,'convert_referrals');
 IF cursor_data IS NOT NULL THEN
  IF cursor_data-ARRAY['uid','resource','congregation_id','conversion_date','convert_id']<>'{}'::jsonb OR
   cursor_data->>'congregation_id' IS DISTINCT FROM scope_id::text OR
   jsonb_typeof(cursor_data->'conversion_date') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END IF;
  BEGIN after_date:=(cursor_data->>'conversion_date')::date; after_id:=(cursor_data->>'convert_id')::uuid;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023'; END;
 END IF;
 WITH page AS (
  SELECT c.id,coalesce(p.name,c.name) AS name,
   CASE WHEN p.id IS NULL THEN c.phone ELSE p.phone END AS phone,
   CASE WHEN p.id IS NULL THEN c.address
    ELSE private.ministry_referral_address(p.address) END AS address,
   c.conversion_date
  FROM public.converts c
  LEFT JOIN public.ministry_people p ON p.id=c.person_id AND p.congregation_id=c.congregation_id
  WHERE c.congregation_id=scope_id AND c.deleted_at IS NULL
   AND NOT EXISTS(SELECT FROM public.ministry_students s WHERE s.convert_id=c.id)
   AND (after_date IS NULL OR (c.conversion_date,c.id)<(after_date,after_id))
  ORDER BY c.conversion_date DESC,c.id DESC LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('convert_id',p.id,'congregation_id',scope_id,
  'name',p.name,'phone',p.phone,'address',p.address,'conversion_date',p.conversion_date)
  ORDER BY p.conversion_date DESC,p.id DESC),'[]'::jsonb),count(*) INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  items:=items-(item_count-1); tail:=items->(page_size-1);
  next_cursor:=private.ministry_read_cursor_encode(jsonb_build_object('uid',auth.uid(),
   'resource','convert_referrals','congregation_id',scope_id,
   'conversion_date',tail->>'conversion_date','convert_id',tail->>'convert_id'));
 ELSE next_cursor:=NULL; END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_convert_student_candidates(jsonb),
 public.ieadpe_ministry_list_convert_referrals(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_convert_student_candidates(jsonb),
 public.ieadpe_ministry_list_convert_referrals(jsonb) TO authenticated;

COMMIT;
