-- Bucket limits are enforced by Storage HTTP; the INSERT policy also validates metadata.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('convert-photos','convert-photos',false,1048576,ARRAY['image/jpeg']);

CREATE FUNCTION public.ieadpe_create_photo_draft(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); receipt private.mutation_receipts; asset_id uuid;
 digest text; response jsonb;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
 IF operation_id IS NULL OR payload IS NULL OR payload<>'{}'::jsonb THEN
  RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 PERFORM private.lock_access(ARRAY[actor]);
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 SELECT * INTO receipt FROM private.mutation_receipts r
 WHERE r.actor_uid=actor AND r.operation_id=ieadpe_create_photo_draft.operation_id;
 IF FOUND THEN
  IF receipt.command<>'create_photo_draft' OR receipt.payload_hash<>digest THEN
   RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023'; END IF;
  RETURN receipt.result;
 END IF;
 asset_id:=gen_random_uuid();
 INSERT INTO public.photo_assets(id,owner_id,path)
 VALUES(asset_id,actor,actor::text||'/'||asset_id::text||'.jpg');
 response:=jsonb_build_object('id',asset_id);
 INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
 VALUES(actor,operation_id,'create_photo_draft',digest,response);
 RETURN response;
END $$;

-- Use the existing transaction and authorization path, including week guards.
CREATE FUNCTION public.ieadpe_detach_photo(operation_id uuid,payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF payload IS NULL OR jsonb_typeof(payload)<>'object' OR payload-'id'<>'{}'::jsonb
  OR NOT payload ? 'id' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 RETURN private.convert_command('edit_convert',operation_id,payload||'{"photo_asset_id":null}'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_create_photo_draft(uuid,jsonb),public.ieadpe_detach_photo(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ieadpe_create_photo_draft(uuid,jsonb),public.ieadpe_detach_photo(uuid,jsonb) TO authenticated;

GRANT USAGE ON SCHEMA storage TO authenticated,anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO anon;
CREATE POLICY convert_photo_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='convert-photos' AND
 metadata->>'mimetype'='image/jpeg' AND
 CASE WHEN jsonb_typeof(metadata->'size')='number' THEN
  (metadata->>'size')::numeric BETWEEN 1 AND 1048576 ELSE false END AND
 EXISTS(SELECT FROM public.photo_assets a WHERE a.path=name AND a.owner_id=auth.uid()
  AND a.status='pending' AND a.expires_at>now()));
CREATE POLICY convert_photo_read ON storage.objects FOR SELECT TO authenticated USING(
 bucket_id='convert-photos' AND EXISTS(SELECT FROM public.photo_assets a WHERE a.path=name));
-- No UPDATE/DELETE policy: upsert and client deletion cannot overwrite attached images.

-- Operator-only second cleanup phase. Storage API removal must finish first.
CREATE FUNCTION public.ieadpe_purge_photo_asset(asset_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE asset public.photo_assets;
BEGIN
 PERFORM 1 FROM public.converts WHERE photo_asset_id=asset_id ORDER BY id FOR UPDATE;
 SELECT * INTO asset FROM public.photo_assets WHERE id=asset_id FOR UPDATE;
 IF asset.id IS NULL THEN RETURN; END IF;
 IF NOT (asset.status='detached' OR (asset.status='pending' AND asset.expires_at<=now()))
  OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='convert-photos' AND name=asset.path)
  OR EXISTS(SELECT FROM public.converts WHERE photo_asset_id=asset.id AND deleted_at IS NULL) THEN
  RAISE EXCEPTION 'photo_not_ready_for_cleanup' USING ERRCODE='22023'; END IF;
 UPDATE public.converts SET photo_asset_id=NULL WHERE photo_asset_id=asset.id AND deleted_at IS NOT NULL;
 DELETE FROM public.photo_assets WHERE id=asset.id;
END $$;
REVOKE ALL ON FUNCTION public.ieadpe_purge_photo_asset(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ieadpe_purge_photo_asset(uuid) TO service_role;
GRANT USAGE ON SCHEMA public TO service_role;
GRANT SELECT ON public.photo_assets TO service_role;
