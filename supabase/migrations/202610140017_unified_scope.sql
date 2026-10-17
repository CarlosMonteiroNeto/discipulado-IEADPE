-- One identity can hold independent campaign and discipleship grants.
-- Keep those capabilities separate in the server-derived session snapshot.
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
  'ministry_congregation_ids',coalesce((SELECT jsonb_agg(DISTINCT g.congregation_id ORDER BY g.congregation_id)
    FROM public.ministry_grants g JOIN public.congregations c ON c.id=g.congregation_id
    WHERE g.user_id=auth.uid() AND g.active AND g.role='ministry_staff'
      AND c.archived_at IS NULL),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_get_scope() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_get_scope() TO authenticated;
