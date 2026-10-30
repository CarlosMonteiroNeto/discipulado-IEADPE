BEGIN;
-- Team membership owns application access.
--
-- Rules enforced here:
--   * an active member with an e-mail holds exactly one access row for the
--     member scope (local: direction of that congregation, supervision: global);
--   * changing the e-mail moves that access row to the new address;
--   * clearing the e-mail removes the access row and keeps the member;
--   * marking a member inactive removes access, reactivating restores it;
--   * backfill applies the same rules to every existing contact, skipping and
--     warning about conflicts instead of failing the migration.

CREATE OR REPLACE FUNCTION private.ministry_sync_contact_access(target uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 contact public.ministry_contacts; access_row public.user_access; old_access public.user_access;
 target_uid uuid; role_value text; email_value text; access_changed boolean:=false;
BEGIN
 SELECT * INTO contact FROM public.ministry_contacts WHERE id=target FOR UPDATE;
 IF contact.id IS NULL THEN RETURN; END IF;
 IF contact.user_access_id IS NOT NULL THEN
  SELECT * INTO old_access FROM public.user_access WHERE id=contact.user_access_id FOR UPDATE;
 END IF;
 email_value:=contact.email;
 role_value:=CASE WHEN contact.scope='supervision'
  THEN 'Membro da supervisão das campanhas' ELSE 'Membro da direção da campanha' END;

 -- Inactive or addressless members keep no access at all.
 IF email_value IS NULL OR contact.archived_at IS NOT NULL THEN
  IF contact.user_access_id IS NULL AND email_value IS NOT NULL THEN
   SELECT * INTO old_access FROM public.user_access WHERE user_email=email_value
    AND role=role_value AND congregation_id IS NOT DISTINCT FROM contact.congregation_id FOR UPDATE;
   IF old_access.id IS NOT NULL AND EXISTS (SELECT FROM public.ministry_contacts c
    WHERE c.id<>target AND c.archived_at IS NULL AND c.email=email_value
     AND c.scope=contact.scope AND c.congregation_id IS NOT DISTINCT FROM contact.congregation_id) THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='P0001';
   END IF;
  END IF;
  IF contact.user_access_id IS NOT NULL THEN
   -- Clear the link first: the contact reference restricts the delete.
   UPDATE public.ministry_contacts SET user_access_id=NULL WHERE id=target;
  END IF;
  IF old_access.id IS NOT NULL THEN
   IF EXISTS (SELECT FROM public.ministry_contacts c WHERE c.user_access_id=old_access.id AND c.id<>target) THEN
    RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='P0001';
   END IF;
   DELETE FROM public.user_access WHERE id=old_access.id;
   access_changed:=true;
  END IF;
  IF old_access.id IS NOT NULL AND old_access.user_id IS NOT NULL THEN
   UPDATE private.access_versions SET version=version+1 WHERE user_id=old_access.user_id;
  END IF;
  RETURN;
 END IF;

 SELECT id INTO target_uid FROM auth.users
  WHERE email_confirmed_at IS NOT NULL AND lower(btrim(email))=email_value
  ORDER BY id LIMIT 1;

 SELECT * INTO access_row FROM public.user_access
  WHERE user_email=email_value AND role=role_value
   AND congregation_id IS NOT DISTINCT FROM contact.congregation_id
  FOR UPDATE;

 IF access_row.id IS NOT NULL THEN
  IF EXISTS(SELECT FROM public.ministry_contacts c
   WHERE c.user_access_id=access_row.id AND c.id<>target) THEN
   RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='P0001';
  END IF;
  IF access_row.user_id IS NULL AND target_uid IS NOT NULL THEN
   UPDATE public.user_access SET user_id=target_uid,updated_at=now()
    WHERE id=access_row.id RETURNING * INTO access_row;
   access_changed:=true;
  ELSIF access_row.user_id IS NOT NULL AND target_uid IS NOT NULL
   AND access_row.user_id<>target_uid THEN
   RAISE EXCEPTION 'contact_access_conflict' USING ERRCODE='P0001';
  END IF;
 ELSIF old_access.id IS NOT NULL THEN
  -- Move the existing row so its history and references are preserved.
  UPDATE public.user_access
   SET user_email=email_value,user_id=target_uid,updated_at=now()
   WHERE id=old_access.id RETURNING * INTO access_row;
  access_changed:=true;
 ELSE
  INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
   VALUES(email_value,target_uid,role_value,contact.congregation_id)
   RETURNING * INTO access_row;
  access_changed:=true;
 END IF;

 IF contact.user_access_id IS DISTINCT FROM access_row.id THEN
  UPDATE public.ministry_contacts SET user_access_id=access_row.id WHERE id=target;
  access_changed:=true;
 END IF;
 -- Only unlink, then delete, so the restricting reference never blocks it.
 IF old_access.id IS NOT NULL AND old_access.id<>access_row.id THEN
  DELETE FROM public.user_access WHERE id=old_access.id;
  access_changed:=true;
 END IF;
 IF access_changed THEN
  UPDATE private.access_versions SET version=version+1
   WHERE user_id IN (old_access.user_id,access_row.user_id);
 END IF;
END $$;
REVOKE ALL ON FUNCTION private.ministry_sync_contact_access(uuid) FROM PUBLIC,anon,authenticated;

-- Saving a member is the single access command. Detach before delegating so the
-- registry save accepts an e-mail change, then rebuild the link from the saved
-- address. The whole statement rolls back together on any failure.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_save_contact(operation_id uuid,payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; email_value text; old_email text; old_access uuid; result jsonb;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 email_value:=CASE WHEN jsonb_typeof(payload->'email')='string'
  THEN lower(btrim(payload->>'email')) ELSE NULL END;
 PERFORM pg_advisory_xact_lock(711039001);
 IF email_value IS NOT NULL THEN PERFORM pg_advisory_xact_lock(hashtextextended(email_value,0)); END IF;
 SELECT email,user_access_id INTO old_email,old_access
  FROM public.ministry_contacts WHERE id=target;
 IF old_email IS NOT NULL AND old_email IS DISTINCT FROM email_value THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(old_email,0));
 END IF;
 PERFORM private.lock_access(ARRAY[actor,
  (SELECT user_id FROM public.user_access WHERE id=old_access),
  (SELECT id FROM auth.users WHERE email_confirmed_at IS NOT NULL AND lower(btrim(email))=email_value ORDER BY id LIMIT 1),
  (SELECT user_id FROM public.user_access WHERE user_email=email_value AND role=CASE WHEN payload->>'scope'='supervision' THEN 'Membro da supervisão das campanhas' ELSE 'Membro da direção da campanha' END AND congregation_id IS NOT DISTINCT FROM (payload->>'congregation_id')::uuid LIMIT 1)]);
 IF old_access IS NOT NULL AND old_email IS DISTINCT FROM email_value THEN
  UPDATE public.ministry_contacts SET user_access_id=NULL WHERE id=target;
 END IF;
 result:=private.ministry_save_contact_with_email(operation_id,payload);
 IF old_access IS NOT NULL AND old_email IS DISTINCT FROM email_value THEN
  UPDATE public.ministry_contacts SET user_access_id=old_access WHERE id=target;
 END IF;
 PERFORM private.ministry_sync_contact_access(target);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_save_contact(uuid,jsonb) TO authenticated;

-- Inactivation and reactivation are the access switch for a member.
CREATE OR REPLACE FUNCTION public.ieadpe_ministry_set_contact_archived(operation_id uuid,payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; email_value text; result jsonb;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 BEGIN
  target:=(payload->>'id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END;
 SELECT email INTO email_value FROM public.ministry_contacts WHERE id=target;
 PERFORM pg_advisory_xact_lock(711039001);
 IF email_value IS NOT NULL THEN PERFORM pg_advisory_xact_lock(hashtextextended(email_value,0)); END IF;
 PERFORM private.lock_access(ARRAY[actor,
  (SELECT ua.user_id FROM public.ministry_contacts c JOIN public.user_access ua ON ua.id=c.user_access_id WHERE c.id=target),
  (SELECT id FROM auth.users WHERE email_confirmed_at IS NOT NULL AND lower(btrim(email))=email_value ORDER BY id LIMIT 1),
  (SELECT ua.user_id FROM public.ministry_contacts c JOIN public.user_access ua ON ua.user_email=c.email AND ua.role=CASE WHEN c.scope='supervision' THEN 'Membro da supervisão das campanhas' ELSE 'Membro da direção da campanha' END AND ua.congregation_id IS NOT DISTINCT FROM c.congregation_id WHERE c.id=target LIMIT 1)]);
 IF payload->'archived'='true'::jsonb AND NOT EXISTS (SELECT FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=ieadpe_ministry_set_contact_archived.operation_id) THEN
  UPDATE public.ministry_role_slots SET contact_id=NULL,revision=revision+1,updated_at=now(),updated_by=actor
   WHERE contact_id=target AND archived_at IS NULL;
 END IF;
 result:=private.ministry_registry_command('set_contact_archived',operation_id,payload);
 PERFORM private.ministry_sync_contact_access(target);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_ministry_set_contact_archived(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_ministry_set_contact_archived(uuid,jsonb) TO authenticated;

-- Backfill: every active contact with an e-mail gains the scope grant; every
-- inactive contact loses it. Conflicts are warned, never fatal.
DO $$
DECLARE contact public.ministry_contacts;
BEGIN
 FOR contact IN SELECT * FROM public.ministry_contacts ORDER BY id LOOP
  BEGIN
   PERFORM private.ministry_sync_contact_access(contact.id);
  EXCEPTION WHEN SQLSTATE 'P0001' OR unique_violation THEN
   RAISE WARNING 'team access backfill skipped contact %: %', contact.id, SQLERRM;
  END;
 END LOOP;
END $$;

COMMIT;
