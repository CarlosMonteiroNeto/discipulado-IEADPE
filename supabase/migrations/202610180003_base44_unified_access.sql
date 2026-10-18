CREATE OR REPLACE FUNCTION private.ministry_supervisor() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT private.is_global_manager()
$$;

CREATE OR REPLACE FUNCTION private.ministry_can_access(scope_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND scope_id IS NOT NULL AND (
  private.is_global_manager() OR (
   EXISTS(SELECT FROM public.congregations c WHERE c.id=scope_id AND c.archived_at IS NULL) AND
   private.can_access_congregation(scope_id)))
$$;
REVOKE ALL ON FUNCTION private.ministry_supervisor(),private.ministry_can_access(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.ministry_supervisor(),private.ministry_can_access(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_get_scope() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE verified_email text; bound_count integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 -- Keep the existing grant-discovery -> email -> UID lock order so verified
 -- email binding cannot race a grant edit or return a stale access snapshot.
 PERFORM pg_advisory_xact_lock(711039001);
 SELECT lower(btrim(email)) INTO verified_email FROM auth.users
 WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL;
 IF verified_email IS NOT NULL THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(verified_email,0));
 END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 UPDATE public.user_access SET user_id=auth.uid(),updated_at=now()
 WHERE user_id IS NULL AND user_email=verified_email;
 GET DIAGNOSTICS bound_count=ROW_COUNT;
 IF bound_count>0 THEN
  UPDATE private.access_versions SET version=version+1 WHERE user_id=auth.uid();
 END IF;
 RETURN jsonb_build_object(
  'is_admin',EXISTS(SELECT FROM private.admin_allowlist WHERE user_id=auth.uid()),
  'is_supervision',EXISTS(SELECT FROM public.user_access WHERE user_id=auth.uid()
    AND role='Membro da supervisão das campanhas'),
  'congregation_ids',coalesce((SELECT jsonb_agg(DISTINCT congregation_id ORDER BY congregation_id)
    FROM public.user_access WHERE user_id=auth.uid()
      AND role='Membro da direção da campanha'),'[]'::jsonb),
  'ministry_supervision',private.ministry_supervisor(),
  'ministry_congregation_ids',coalesce((SELECT jsonb_agg(DISTINCT ua.congregation_id ORDER BY ua.congregation_id)
    FROM public.user_access ua JOIN public.congregations c ON c.id=ua.congregation_id
    WHERE ua.user_id=auth.uid() AND ua.role='Membro da direção da campanha'
      AND c.archived_at IS NULL),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_get_scope() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_get_scope() TO authenticated;

CREATE OR REPLACE FUNCTION public.ieadpe_ministry_list_congregations(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE page_size integer; after_id uuid; items jsonb; item_count integer; tail_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 IF request IS NULL OR jsonb_typeof(request)<>'object' OR
    request-ARRAY['limit','cursor']<>'{}'::jsonb OR
    jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
    (request->'limit')::text !~ '^[0-9]+$' OR
    (request ? 'cursor' AND jsonb_typeof(request->'cursor') NOT IN ('string','null')) THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END IF;
 BEGIN
  page_size:=(request->>'limit')::integer;
  IF nullif(request->>'cursor','') IS NOT NULL THEN after_id:=(request->>'cursor')::uuid; END IF;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
 END;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023'; END IF;
 IF NOT private.ministry_supervisor() AND NOT EXISTS(
    SELECT FROM public.congregations c
    WHERE c.archived_at IS NULL AND private.ministry_can_access(c.id)
 ) THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 WITH page AS (
  SELECT c.id,c.name FROM public.congregations c
  WHERE c.archived_at IS NULL AND private.ministry_can_access(c.id)
    AND (after_id IS NULL OR c.id>after_id)
  ORDER BY c.id LIMIT page_size+1
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) ORDER BY p.id),'[]'::jsonb),count(*)
 INTO items,item_count FROM page p;
 IF item_count>page_size THEN
  tail_id:=((items->(page_size-1))->>'id')::uuid;
  items:=items-page_size;
  RETURN jsonb_build_object('items',items,'next_cursor',tail_id);
 END IF;
 RETURN jsonb_build_object('items',items,'next_cursor',NULL);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_list_congregations(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_list_congregations(jsonb) TO authenticated;
