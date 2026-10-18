CREATE FUNCTION private.is_global_manager() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND (
 EXISTS(SELECT FROM private.admin_allowlist WHERE user_id=auth.uid()) OR
 EXISTS(SELECT FROM public.user_access WHERE user_id=auth.uid() AND role='Membro da supervisão das campanhas'))
$$;
CREATE FUNCTION private.can_access_congregation(scope_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND (private.is_global_manager() OR
 EXISTS(SELECT FROM public.user_access WHERE user_id=auth.uid()
 AND role='Membro da direção da campanha' AND congregation_id=scope_id))
$$;
-- All future business RPCs must lock actor/affected UIDs with this helper BEFORE authorization.
CREATE FUNCTION private.lock_access(user_ids uuid[]) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE locked_uid uuid;
BEGIN
 FOR locked_uid IN SELECT DISTINCT u FROM unnest(user_ids) u WHERE u IS NOT NULL ORDER BY u LOOP
  INSERT INTO private.access_versions(user_id) VALUES(locked_uid) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM private.access_versions WHERE user_id=locked_uid FOR UPDATE;
 END LOOP;
END $$;
CREATE FUNCTION private.sync_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.profiles(id,display_name,avatar_url)
 VALUES(NEW.id,NEW.raw_user_meta_data->>'full_name',NEW.raw_user_meta_data->>'avatar_url')
 ON CONFLICT(id) DO UPDATE SET display_name=excluded.display_name,avatar_url=excluded.avatar_url;
 INSERT INTO private.access_versions(user_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$;
CREATE TRIGGER identity_profile AFTER INSERT OR UPDATE OF raw_user_meta_data ON auth.users
 FOR EACH ROW EXECUTE FUNCTION private.sync_identity();
INSERT INTO public.profiles(id,display_name,avatar_url)
 SELECT id,raw_user_meta_data->>'full_name',raw_user_meta_data->>'avatar_url' FROM auth.users ON CONFLICT DO NOTHING;
INSERT INTO private.access_versions(user_id) SELECT id FROM auth.users ON CONFLICT DO NOTHING;

CREATE POLICY profiles_self ON public.profiles FOR SELECT TO authenticated USING(id=auth.uid());
CREATE POLICY congregations_active ON public.congregations FOR SELECT TO authenticated
 USING(archived_at IS NULL OR private.is_global_manager());
CREATE POLICY access_self_or_manager ON public.user_access FOR SELECT TO authenticated
 USING(user_id=auth.uid() OR private.is_global_manager());
CREATE POLICY converts_scope ON public.converts FOR SELECT TO authenticated
 USING(deleted_at IS NULL AND private.can_access_congregation(congregation_id));
CREATE POLICY events_scope ON public.convert_events FOR SELECT TO authenticated
 USING(private.can_access_congregation(congregation_id) AND EXISTS(
 SELECT FROM public.converts c WHERE c.id=convert_id AND c.deleted_at IS NULL));
CREATE POLICY weeks_scope ON public.weekly_reports FOR SELECT TO authenticated
 USING(private.can_access_congregation(congregation_id));
CREATE POLICY feedback_manager ON public.feedback FOR SELECT TO authenticated USING(private.is_global_manager());
CREATE POLICY photos_scope ON public.photo_assets FOR SELECT TO authenticated USING(
 (status='pending' AND owner_id=auth.uid() AND expires_at>now()) OR
 (status='attached' AND EXISTS(SELECT FROM public.converts c WHERE c.id=convert_id AND c.deleted_at IS NULL
 AND private.can_access_congregation(c.congregation_id))));

CREATE FUNCTION public.ieadpe_get_scope() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE verified_email text; bound_count integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 -- Binding and grant editing share discovery serialization. Take this BEFORE
 -- reading identities so an editor cannot retain a pre-binding old user_id.
 -- Order: grant-discovery mutex -> email mutex -> sorted UID version rows.
 PERFORM pg_advisory_xact_lock(711039001);
 SELECT lower(btrim(email)) INTO verified_email FROM auth.users WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL;
 -- Same email mutex is used by grant changes; no email from JWT/user_metadata is trusted.
 IF verified_email IS NOT NULL THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(verified_email,0));
 END IF;
 PERFORM private.lock_access(ARRAY[auth.uid()]);
 UPDATE public.user_access SET user_id=auth.uid(),updated_at=now()
 WHERE user_id IS NULL AND user_email=verified_email;
 GET DIAGNOSTICS bound_count=ROW_COUNT;
 IF bound_count>0 THEN UPDATE private.access_versions SET version=version+1 WHERE user_id=auth.uid(); END IF;
 RETURN jsonb_build_object(
 'is_admin',EXISTS(SELECT FROM private.admin_allowlist WHERE user_id=auth.uid()),
 'is_supervision',EXISTS(SELECT FROM public.user_access WHERE user_id=auth.uid() AND role='Membro da supervisão das campanhas'),
 'congregation_ids',coalesce((SELECT jsonb_agg(DISTINCT congregation_id) FROM public.user_access
 WHERE user_id=auth.uid() AND role='Membro da direção da campanha'),'[]'::jsonb));
END $$;

-- Shared transactional implementation keeps save/revoke lock and receipt ordering identical.
CREATE FUNCTION private.change_access(command_name text, operation_id uuid, payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE access_id uuid; old_row public.user_access; target_uid uuid; normalized_email text;
 requested_role text; scope_id uuid; receipt private.mutation_receipts; response jsonb; digest text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT FROM jsonb_object_keys(payload) k WHERE k NOT IN ('id','user_email','role','congregation_id')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 IF command_name='revoke_access' AND (NOT payload ? 'id' OR payload-'id'<>'{}'::jsonb) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 access_id := (payload->>'id')::uuid;
 IF command_name='revoke_access' AND access_id IS NULL THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 -- Serialize access edits AND pending binding before discovering affected users.
 -- get_scope uses the same mutex, then email mutex, then sorted UID version rows.
 -- Business writes use only lock_access; this mutex never follows UID locks.
 PERFORM pg_advisory_xact_lock(711039001);
 IF access_id IS NOT NULL THEN SELECT * INTO old_row FROM public.user_access WHERE id=access_id; END IF;
 normalized_email := CASE WHEN command_name='save_access' THEN lower(btrim(payload->>'user_email')) ELSE old_row.user_email END;
 IF normalized_email IS NOT NULL THEN PERFORM pg_advisory_xact_lock(hashtextextended(normalized_email,0)); END IF;
 SELECT id INTO target_uid FROM auth.users WHERE lower(btrim(email))=normalized_email AND email_confirmed_at IS NOT NULL ORDER BY id LIMIT 1;
 PERFORM private.lock_access(ARRAY[auth.uid(),old_row.user_id,target_uid]);
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 digest := encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=auth.uid() AND r.operation_id=change_access.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF access_id IS NOT NULL AND old_row.id IS NULL THEN RAISE EXCEPTION 'access_not_found' USING ERRCODE='22023'; END IF;
 IF command_name='save_access' THEN
  requested_role:=payload->>'role'; scope_id:=(payload->>'congregation_id')::uuid;
  IF normalized_email IS NULL OR normalized_email NOT LIKE '%@%' OR requested_role IS NULL OR
   requested_role NOT IN ('Membro da direção da campanha','Membro da supervisão das campanhas') OR
   (requested_role='Membro da direção da campanha' AND scope_id IS NULL) OR
   (requested_role='Membro da supervisão das campanhas' AND scope_id IS NOT NULL) THEN
   RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
  IF scope_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.congregations WHERE id=scope_id AND archived_at IS NULL) THEN
   RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
  IF access_id IS NULL THEN
   INSERT INTO public.user_access(user_email,user_id,role,congregation_id)
   VALUES(normalized_email,target_uid,requested_role,scope_id) RETURNING id INTO access_id;
  ELSE
   UPDATE public.user_access SET user_email=normalized_email,user_id=target_uid,role=requested_role,
   congregation_id=scope_id,updated_at=now() WHERE id=access_id;
  END IF;
 ELSE
  DELETE FROM public.user_access WHERE id=access_id;
 END IF;
 UPDATE private.access_versions SET version=version+1 WHERE user_id IN (old_row.user_id,target_uid);
 response:=jsonb_build_object('id',access_id);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(auth.uid(),operation_id,command_name,digest,response);
 RETURN response;
END $$;
CREATE FUNCTION public.ieadpe_save_access(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.change_access('save_access',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_revoke_access(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.change_access('revoke_access',operation_id,payload) $$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_global_manager(),private.can_access_congregation(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_get_scope(),public.ieadpe_save_access(uuid,jsonb),public.ieadpe_revoke_access(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_get_scope(),public.ieadpe_save_access(uuid,jsonb),public.ieadpe_revoke_access(uuid,jsonb) TO authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC,anon,authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA private REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
