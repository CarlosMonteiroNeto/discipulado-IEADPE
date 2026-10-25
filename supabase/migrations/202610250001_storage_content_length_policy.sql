-- Storage 1.80.2 evaluates INSERT RLS before upload using metadata.contentLength.
-- For multipart uploads this is the whole HTTP body, including framing/fields;
-- allow 8 KiB of envelope beyond the bucket's 1 MiB file limit. Storage enforces
-- the actual file-part limit from storage.buckets.file_size_limit.
-- Keep the existing MIME, owner, draft-state, and expiry restrictions.
DROP POLICY IF EXISTS convert_photo_insert ON storage.objects;
CREATE POLICY convert_photo_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='convert-photos' AND
 metadata->>'mimetype'='image/jpeg' AND
 CASE WHEN jsonb_typeof(metadata->'contentLength')='number' THEN
  (metadata->>'contentLength')::numeric BETWEEN 1 AND 1056768 ELSE false END AND
 EXISTS(SELECT FROM public.photo_assets a WHERE a.path=name AND a.owner_id=auth.uid()
  AND a.status='pending' AND a.expires_at>now()));
