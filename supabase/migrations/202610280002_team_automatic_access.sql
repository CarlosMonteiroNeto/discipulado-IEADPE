BEGIN;
-- Contact email grants the contact's scope. Existing matching grants are linked;
-- unrelated congregation grants are never replaced. A revoked link is not
-- recreated by an unrelated edit that leaves its email unchanged.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_save_contact(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; target_uid uuid; email_value text; existing public.ministry_contacts;
        saved public.ministry_contacts; access_row public.user_access; result jsonb; role_value text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(711039001);
 BEGIN
  target:=(payload->>'id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 email_value:=CASE WHEN jsonb_typeof(payload->'email')='string' THEN lower(btrim(payload->>'email')) ELSE NULL END;
 IF email_value IS NOT NULL THEN PERFORM pg_advisory_xact_lock(hashtextextended(email_value,0)); END IF;
 SELECT id INTO target_uid FROM auth.users WHERE email_confirmed_at IS NOT NULL AND lower(btrim(email))=email_value ORDER BY id LIMIT 1;
 PERFORM private.lock_access(ARRAY[actor,target_uid]);
 SELECT * INTO existing FROM public.ministry_contacts WHERE id=target;
 result:=private.ministry_save_contact_with_email(operation_id,payload);
 SELECT * INTO saved FROM public.ministry_contacts WHERE id=target FOR UPDATE;
 IF saved.email IS NOT NULL AND saved.user_access_id IS NULL AND
    (existing.id IS NULL OR existing.email IS DISTINCT FROM saved.email) THEN
  role_value:=CASE WHEN saved.scope='supervision' THEN 'Membro da supervisão das campanhas' ELSE 'Membro da direção da campanha' END;
  SELECT * INTO access_row FROM public.user_access ua WHERE ua.user_email=saved.email AND ua.role=role_value
   AND ua.congregation_id IS NOT DISTINCT FROM saved.congregation_id FOR UPDATE;
  IF access_row.id IS NOT NULL THEN
   IF EXISTS(SELECT FROM public.ministry_contacts c WHERE c.user_access_id=access_row.id AND c.id<>target) OR
      (access_row.user_id IS NOT NULL AND access_row.user_id IS DISTINCT FROM target_uid) THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='22023'; END IF;
   IF access_row.user_id IS NULL AND target_uid IS NOT NULL THEN
    UPDATE public.user_access SET user_id=target_uid,updated_at=now() WHERE id=access_row.id;
   END IF;
  ELSE
   INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
    VALUES(saved.email,target_uid,role_value,saved.congregation_id) RETURNING * INTO access_row;
  END IF;
  UPDATE public.ministry_contacts SET user_access_id=access_row.id WHERE id=target;
  IF target_uid IS NOT NULL THEN UPDATE private.access_versions SET version=version+1 WHERE user_id=target_uid; END IF;
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb) TO authenticated;
COMMIT;
