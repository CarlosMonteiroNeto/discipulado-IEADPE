BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
SELECT pg_temp.assert_true(EXISTS(SELECT FROM storage.buckets WHERE id='convert-photos' AND NOT public
 AND file_size_limit=1048576 AND allowed_mime_types=ARRAY['image/jpeg']), 'private JPEG 1MiB bucket');
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('80000000-0000-0000-0000-000000000001','uploader@example.test',now()),
 ('80000000-0000-0000-0000-000000000002','manager@example.test',now()),
 ('80000000-0000-0000-0000-000000000003','other@example.test',now());
INSERT INTO private.admin_allowlist VALUES('80000000-0000-0000-0000-000000000002');
CREATE TEMP TABLE photos(label text PRIMARY KEY,id uuid,path text);
CREATE TEMP TABLE target(id uuid);
GRANT ALL ON photos,target TO authenticated;
SELECT set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
INSERT INTO photos(label,id) SELECT 'old',(public.ieadpe_create_photo_draft('81000000-0000-0000-0000-000000000001','{}')->>'id')::uuid;
SELECT pg_temp.assert_true((SELECT id=(public.ieadpe_create_photo_draft('81000000-0000-0000-0000-000000000001','{}')->>'id')::uuid FROM photos), 'same draft operation returns same ID');
UPDATE photos SET path=(SELECT a.path FROM public.photo_assets a WHERE a.id=photos.id);
SELECT pg_temp.assert_true((SELECT a.owner_id=auth.uid() AND a.status='pending' AND a.expires_at=now()+interval '1 hour'
 AND a.path=auth.uid()::text||'/'||a.id::text||'.jpg' FROM public.photo_assets a JOIN photos p ON p.id=a.id), 'draft exact owner path and one hour expiry');
DO $$ DECLARE p text:=(SELECT path FROM photos); BEGIN
 BEGIN PERFORM public.ieadpe_create_photo_draft(gen_random_uuid(),'{"path":"override"}');
  RAISE EXCEPTION 'ASSERTION: caller chose draft path'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('convert-photos',p||'x','{"size":123,"mimetype":"image/jpeg"}');
  RAISE EXCEPTION 'ASSERTION: arbitrary path uploaded'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('convert-photos',p,'{"size":1048577,"mimetype":"image/jpeg"}');
  RAISE EXCEPTION 'ASSERTION: oversize uploaded'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('convert-photos',p,'{"size":123,"mimetype":"image/png"}');
  RAISE EXCEPTION 'ASSERTION: non JPEG uploaded'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
INSERT INTO storage.objects(bucket_id,name,metadata) SELECT 'convert-photos',path,'{"size":123,"mimetype":"image/jpeg"}' FROM photos;
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM storage.objects), 'owner reads pending bytes metadata');
DO $$ BEGIN
 BEGIN INSERT INTO storage.objects(bucket_id,name,metadata) SELECT 'convert-photos',path,'{"size":123,"mimetype":"image/jpeg"}' FROM photos
 ON CONFLICT(bucket_id,name) DO UPDATE SET metadata=excluded.metadata;
 RAISE EXCEPTION 'ASSERTION: upsert succeeded'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000003',true);
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM storage.objects), 'other actor cannot read pending object');
DO $$ BEGIN
 BEGIN INSERT INTO storage.objects(bucket_id,name,metadata) SELECT 'convert-photos',path,'{"size":123,"mimetype":"image/jpeg"}' FROM photos;
 RAISE EXCEPTION 'ASSERTION: cross owner insert'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000001',true);
INSERT INTO target SELECT (public.ieadpe_create_convert(gen_random_uuid(),jsonb_build_object(
 'name','Synthetic','landmark','Square','gender','male','conversion_date','2020-01-01','worship_type','01',
 'photo_asset_id',(SELECT id FROM photos WHERE label='old')))->>'id')::uuid;
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM storage.objects), 'registrar loses photo ownership read after attach');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.photo_assets), 'registrar cannot read attached metadata');
SELECT set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000002',true);
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM storage.objects), 'current scope reads attached photo from another uploader');
RESET ROLE;
-- Regression for Task 5: all four attachment rejections use actual convert RPCs.
DO $$ DECLARE bad_id uuid; kind text; old_id uuid:=(SELECT id FROM photos WHERE label='old');
 convert_id uuid:=(SELECT id FROM target); BEGIN
 PERFORM set_config('request.jwt.claim.sub','80000000-0000-0000-0000-000000000002',true);
 FOREACH kind IN ARRAY ARRAY['owner','state','expiry','object'] LOOP
  bad_id:=gen_random_uuid();
  INSERT INTO public.photo_assets(id,owner_id,path,status,expires_at) VALUES(bad_id,
   CASE WHEN kind='owner' THEN '80000000-0000-0000-0000-000000000003'::uuid ELSE auth.uid() END,
   auth.uid()::text||'/'||bad_id::text||'.jpg', CASE WHEN kind='state' THEN 'detached' ELSE 'pending' END,
   now()+CASE WHEN kind='expiry' THEN interval '-1 second' ELSE interval '1 hour' END);
  IF kind<>'object' THEN INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('convert-photos',auth.uid()::text||'/'||bad_id::text||'.jpg','{"size":123,"mimetype":"image/jpeg"}'); END IF;
  BEGIN PERFORM public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object('id',convert_id,'photo_asset_id',bad_id));
   RAISE EXCEPTION 'ASSERTION: invalid attachment accepted: %',kind; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM pg_temp.assert_true((SELECT photo_asset_id=old_id FROM public.converts WHERE id=convert_id), 'failed replacement preserves old photo: '||kind);
 END LOOP;
END $$;
SET LOCAL ROLE authenticated;
INSERT INTO photos(label,id) SELECT 'new',(public.ieadpe_create_photo_draft(gen_random_uuid(),'{}')->>'id')::uuid;
UPDATE photos SET path=(SELECT a.path FROM public.photo_assets a WHERE a.id=photos.id) WHERE label='new';
INSERT INTO storage.objects(bucket_id,name,metadata) SELECT 'convert-photos',path,'{"size":123,"mimetype":"image/jpeg"}' FROM photos WHERE label='new';
SELECT public.ieadpe_edit_convert(gen_random_uuid(),jsonb_build_object('id',(SELECT id FROM target),'photo_asset_id',(SELECT id FROM photos WHERE label='new')));
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM storage.objects WHERE name=(SELECT path FROM photos WHERE label='old')), 'replacement hides detached old bytes');
RESET ROLE;
DELETE FROM private.admin_allowlist WHERE user_id='80000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM storage.objects WHERE name=(SELECT path FROM photos WHERE label='new')), 'revoked uploader cannot read attached object through ownership');
RESET ROLE;
INSERT INTO private.admin_allowlist VALUES('80000000-0000-0000-0000-000000000002');
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_detach_photo('81000000-0000-0000-0000-000000000002',jsonb_build_object('id',(SELECT id FROM target)));
SELECT public.ieadpe_detach_photo('81000000-0000-0000-0000-000000000002',jsonb_build_object('id',(SELECT id FROM target)));
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM storage.objects WHERE name=(SELECT path FROM photos WHERE label='new')), 'detach hides bytes');
SELECT pg_temp.assert_true((SELECT photo_asset_id IS NULL FROM public.converts WHERE id=(SELECT id FROM target)), 'detach clears convert reference');
SET LOCAL ROLE anon;
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM storage.objects),'anonymous has no object reads');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_create_photo_draft(gen_random_uuid(),'{}');
  RAISE EXCEPTION 'ASSERTION: anonymous draft'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.photo_assets WHERE status='detached' AND id IN(SELECT id FROM photos)), 'both replaced photos detached for later Storage API maintenance');
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_purge_photo_asset((SELECT id FROM photos WHERE label='old'));
 RAISE EXCEPTION 'ASSERTION: metadata removed before Storage API removal'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_purge_photo_asset((SELECT id FROM photos WHERE label='old'));
 RAISE EXCEPTION 'ASSERTION: client invoked operator cleanup'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- Synthetic fixture models Storage API removal; production never deletes these rows directly.
DELETE FROM storage.objects WHERE name IN(SELECT path FROM photos);
SELECT public.ieadpe_purge_photo_asset((SELECT id FROM photos WHERE label='old'));
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.photo_assets WHERE id=(SELECT id FROM photos WHERE label='old')), 'metadata purged after object removal');
ROLLBACK;
