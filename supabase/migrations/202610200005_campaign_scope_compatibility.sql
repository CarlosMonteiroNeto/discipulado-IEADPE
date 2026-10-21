-- Restore the established campaign scope contract: assigned direction IDs remain
-- visible after a congregation is archived, while Ministry scope and writes stay
-- limited to active congregations. Verified-email binding, lock order and access
-- version behavior are unchanged from the predecessor implementation.
BEGIN;

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
    AND (NOT EXISTS(
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

COMMIT;
