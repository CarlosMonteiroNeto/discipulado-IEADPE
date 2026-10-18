CREATE FUNCTION private.catalog_command(command_name text,operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); target uuid; catalog public.congregations;
 receipt private.mutation_receipts; digest text; response jsonb; catalog_name text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 IF NOT private.is_global_manager() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
 IF command_name NOT IN ('save_congregation','archive_congregation') OR
 EXISTS(SELECT FROM jsonb_object_keys(payload) k WHERE k NOT IN ('id','name')) OR
 (payload ? 'id' AND (jsonb_typeof(payload->'id')<>'string' OR payload->>'id' IS NULL)) OR
 (command_name='archive_congregation' AND (NOT payload ? 'id' OR payload-'id'<>'{}'::jsonb)) OR
 (command_name='save_congregation' AND (NOT payload ? 'name' OR jsonb_typeof(payload->'name')<>'string')) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 target:=(payload->>'id')::uuid;
 catalog_name:=btrim(payload->>'name',U&'\0009\000a\000b\000c\000d\0020\00a0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200a\2028\2029\202f\205f\3000\feff');
 IF command_name='save_congregation' AND (catalog_name='' OR length(catalog_name)>200) THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r WHERE r.actor_uid=actor AND r.operation_id=catalog_command.operation_id;
 IF FOUND THEN
  IF receipt.command<>command_name OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 IF target IS NOT NULL THEN
  SELECT * INTO catalog FROM public.congregations WHERE id=target FOR UPDATE;
  IF catalog.id IS NULL THEN RAISE EXCEPTION 'catalog_not_found' USING ERRCODE='22023'; END IF;
 END IF;
 IF command_name='archive_congregation' THEN
  UPDATE public.congregations SET archived_at=coalesce(archived_at,now()) WHERE id=target;
 ELSIF target IS NULL THEN
  INSERT INTO public.congregations(name) VALUES(catalog_name) RETURNING id INTO target;
 ELSE
  IF catalog.archived_at IS NOT NULL THEN RAISE EXCEPTION 'catalog_archived' USING ERRCODE='22023'; END IF;
  UPDATE public.congregations SET name=catalog_name WHERE id=target;
 END IF;
 response:=jsonb_build_object('id',target);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(actor,operation_id,command_name,digest,response);
 RETURN response;
END $$;
CREATE FUNCTION public.ieadpe_save_congregation(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.catalog_command('save_congregation',operation_id,payload) $$;
CREATE FUNCTION public.ieadpe_archive_congregation(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.catalog_command('archive_congregation',operation_id,payload) $$;
REVOKE ALL ON FUNCTION private.catalog_command(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.ieadpe_save_congregation(uuid,jsonb),public.ieadpe_archive_congregation(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_save_congregation(uuid,jsonb),public.ieadpe_archive_congregation(uuid,jsonb) TO authenticated;

-- Serialize new scope selections with archive. Existing references are retained.
-- Business RPCs acquire UID locks first; this trigger never discovers grants.
CREATE FUNCTION private.require_active_catalog() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE archived timestamptz;
BEGIN
 IF NEW.congregation_id IS NULL THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' THEN
  IF NEW.congregation_id IS NOT DISTINCT FROM OLD.congregation_id THEN RETURN NEW; END IF;
 END IF;
 SELECT archived_at INTO archived FROM public.congregations WHERE id=NEW.congregation_id FOR SHARE;
 IF NOT FOUND OR archived IS NOT NULL THEN RAISE EXCEPTION 'invalid_congregation' USING ERRCODE='22023'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER converts_active_catalog BEFORE INSERT OR UPDATE OF congregation_id ON public.converts
 FOR EACH ROW EXECUTE FUNCTION private.require_active_catalog();
CREATE TRIGGER access_active_catalog BEFORE INSERT OR UPDATE OF congregation_id ON public.user_access
 FOR EACH ROW EXECUTE FUNCTION private.require_active_catalog();
REVOKE ALL ON FUNCTION private.require_active_catalog() FROM PUBLIC,anon,authenticated;
