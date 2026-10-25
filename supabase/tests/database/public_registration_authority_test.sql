BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;

-- Scope A: local direction. Scope B: different local direction.
-- No-grant: authenticated but no user_access row. Global: campaign supervision.
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('aa000000-0000-4000-8000-000000000001','authority-scope-a@example.test',now()),
 ('aa000000-0000-4000-8000-000000000002','authority-scope-b@example.test',now()),
 ('aa000000-0000-4000-8000-000000000003','authority-none@example.test',now()),
 ('aa000000-0000-4000-8000-000000000004','authority-global@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('bb000000-0000-4000-8000-000000000001','Authority Scope A'),
 ('bb000000-0000-4000-8000-000000000002','Authority Scope B'),
 ('bb000000-0000-4000-8000-000000000003','Authority Archived');
UPDATE public.congregations SET archived_at=now()
 WHERE id='bb000000-0000-4000-8000-000000000003';
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('authority-scope-a@example.test','aa000000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','bb000000-0000-4000-8000-000000000001'),
 ('authority-scope-b@example.test','aa000000-0000-4000-8000-000000000002',
  'Membro da direção da campanha','bb000000-0000-4000-8000-000000000002'),
 ('authority-global@example.test','aa000000-0000-4000-8000-000000000004',
  'Membro da supervisão das campanhas',NULL);

CREATE TEMP TABLE counts_before AS SELECT
 (SELECT count(*) FROM public.converts) AS converts,
 (SELECT count(*) FROM public.ministry_people) AS people,
 (SELECT count(*) FROM public.weekly_reports) AS weekly_reports,
 (SELECT count(*) FROM private.mutation_receipts) AS receipts,
 (SELECT count(*) FROM public.photo_assets) AS photos,
 (SELECT coalesce(sum(conversion_count),0) FROM private.congregation_week_guards) AS guard_count;
CREATE TEMP TABLE payload(value jsonb);
INSERT INTO payload VALUES(jsonb_build_object(
 'congregation_id','bb000000-0000-4000-8000-000000000001',
 'person',jsonb_build_object('name','No Grant Attempt','phone',NULL,
  'birth_date',NULL,'address',NULL),
 'convert',jsonb_build_object('landmark','Square','gender','male',
  'conversion_date','2026-10-01','worship_type','Culto regular','age',NULL,
  'photo_asset_id',NULL)));
CREATE TEMP TABLE created(label text PRIMARY KEY,value jsonb);
CREATE TEMP TABLE drafts(label text PRIMARY KEY,id uuid,path text);
GRANT SELECT ON payload TO anon,authenticated;
GRANT ALL ON created,drafts TO authenticated;

-- Anonymous and authenticated actors without matching authority are denied
-- before any official row, person, receipt or weekly counter is written.
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_convert(
   'cc000000-0000-4000-8000-000000000001',(SELECT value FROM payload));
  RAISE EXCEPTION 'ASSERTION: anonymous official create succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_convert(
   'cc000000-0000-4000-8000-000000000002',(SELECT value FROM payload));
  RAISE EXCEPTION 'ASSERTION: unauthenticated actor official create succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000003',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_convert(
   'cc000000-0000-4000-8000-000000000003',(SELECT value FROM payload));
  RAISE EXCEPTION 'ASSERTION: authenticated account without grant created an official convert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_convert(
   'cc000000-0000-4000-8000-000000000004',(SELECT value FROM payload));
  RAISE EXCEPTION 'ASSERTION: cross-congregation actor created an official convert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_convert(
   'cc000000-0000-4000-8000-000000000005',
   jsonb_set((SELECT value FROM payload),'{congregation_id}',
    to_jsonb('bb000000-0000-4000-8000-000000000003'::text)));
  RAISE EXCEPTION 'ASSERTION: archived congregation accepted an official create';
 EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;

SELECT pg_temp.assert_true(
 (SELECT count(*) FROM public.converts)=(SELECT converts FROM counts_before) AND
 (SELECT count(*) FROM public.ministry_people)=(SELECT people FROM counts_before) AND
 (SELECT count(*) FROM public.weekly_reports)=(SELECT weekly_reports FROM counts_before) AND
 (SELECT count(*) FROM private.mutation_receipts)=(SELECT receipts FROM counts_before) AND
 (SELECT coalesce(sum(conversion_count),0) FROM private.congregation_week_guards)=(SELECT guard_count FROM counts_before),
 'denied official creates leave person, convert, receipt, report and weekly counts unchanged');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.converts WHERE name='No Grant Attempt'),
 'denied official creates persist no convert');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM private.mutation_receipts WHERE operation_id IN(
 'cc000000-0000-4000-8000-000000000001'::uuid,'cc000000-0000-4000-8000-000000000002'::uuid,
 'cc000000-0000-4000-8000-000000000003'::uuid,'cc000000-0000-4000-8000-000000000004'::uuid,
 'cc000000-0000-4000-8000-000000000005'::uuid)),
 'denied official creates leave no mutation receipt');

-- Own-scope and global creation still use the canonical unified person/convert
-- transaction and keep the existing exact result envelope.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
INSERT INTO created VALUES('scope_a',public.ieadpe_create_convert(
 'cc000000-0000-4000-8000-000000000010',(SELECT value FROM payload)));
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000004',true);
INSERT INTO created VALUES('global_b',public.ieadpe_create_convert(
 'cc000000-0000-4000-8000-000000000011',
 jsonb_set((SELECT value FROM payload),'{congregation_id}',
  to_jsonb('bb000000-0000-4000-8000-000000000002'::text))));
RESET ROLE;

SELECT pg_temp.assert_true(
 (SELECT value ?& ARRAY['id','person_id','revision','person_revision'] AND
  value-ARRAY['id','person_id','revision','person_revision']='{}'::jsonb AND
  (value->>'revision')::integer=1 AND (value->>'person_revision')::integer=1 AND
  value->>'id'<>value->>'person_id'
  FROM created WHERE label='scope_a'),
 'scoped official create returns the exact unified result fields');
SELECT pg_temp.assert_true(
 (SELECT c.congregation_id='bb000000-0000-4000-8000-000000000001' AND
  c.name='No Grant Attempt' AND c.created_by='aa000000-0000-4000-8000-000000000001' AND
  c.revision=1 AND c.internal_id=c.id::text AND c.person_id=(r.value->>'person_id')::uuid AND
  p.congregation_id=c.congregation_id AND p.name='No Grant Attempt' AND p.revision=1
  FROM public.converts c JOIN public.ministry_people p ON p.id=c.person_id
  JOIN created r ON r.label='scope_a' AND c.id=(r.value->>'id')::uuid),
 'scoped official create writes one canonical person and convert inside the grant scope');
SELECT pg_temp.assert_true(
 (SELECT c.congregation_id='bb000000-0000-4000-8000-000000000002' AND
  c.person_id=(r.value->>'person_id')::uuid AND p.congregation_id=c.congregation_id AND
  p.revision=1 AND c.revision=1
  FROM public.converts c JOIN public.ministry_people p ON p.id=c.person_id
  JOIN created r ON r.label='global_b' AND c.id=(r.value->>'id')::uuid),
 'global manager official create writes canonical data in any active congregation');
SELECT pg_temp.assert_true(
 (SELECT coalesce(sum(conversion_count),0)=(SELECT guard_count+2 FROM counts_before)
  FROM private.congregation_week_guards),
 'authorized creates increment their weekly guards');

-- Authorization is rechecked before a receipt can be replayed.
DELETE FROM public.user_access WHERE user_id='aa000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_convert(
   'cc000000-0000-4000-8000-000000000010',(SELECT value FROM payload));
  RAISE EXCEPTION 'ASSERTION: revoked grant recovered a prior create receipt';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(
 (SELECT count(*) FROM public.converts)=(SELECT converts+2 FROM counts_before),
 'revoked grant cannot create a duplicate while replaying its old operation');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('authority-scope-a@example.test','aa000000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','bb000000-0000-4000-8000-000000000001');

-- Photo draft and upload are independently gated by active scope authority.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000003',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_photo_draft(
   'cc000000-0000-4000-8000-000000000020','{}');
  RAISE EXCEPTION 'ASSERTION: no-grant account created a photo draft';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(
 (SELECT count(*) FROM public.photo_assets)=(SELECT photos FROM counts_before),
 'denied photo draft leaves no pending asset');
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN
  PERFORM public.ieadpe_create_photo_draft(
   'cc000000-0000-4000-8000-000000000021','{}');
  RAISE EXCEPTION 'ASSERTION: anonymous photo draft succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
INSERT INTO drafts(label,id) SELECT 'a1',
 (public.ieadpe_create_photo_draft('cc000000-0000-4000-8000-000000000022','{}')->>'id')::uuid;
UPDATE drafts SET path=(SELECT a.path FROM public.photo_assets a WHERE a.id=drafts.id)
 WHERE label='a1';
INSERT INTO storage.objects(bucket_id,name,metadata)
 SELECT 'convert-photos',path,'{"contentLength":123,"mimetype":"image/jpeg"}'
 FROM drafts WHERE label='a1';
INSERT INTO drafts(label,id) SELECT 'a2',
 (public.ieadpe_create_photo_draft('cc000000-0000-4000-8000-000000000023','{}')->>'id')::uuid;
UPDATE drafts SET path=(SELECT a.path FROM public.photo_assets a WHERE a.id=drafts.id)
 WHERE label='a2';
RESET ROLE;
SELECT pg_temp.assert_true(
 (SELECT count(*)=1 FROM storage.objects) AND
 (SELECT count(*)=(SELECT photos+2 FROM counts_before) FROM public.photo_assets),
 'authorized scope creates drafts and uploads its pending object');
DELETE FROM public.user_access WHERE user_id='aa000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 BEGIN
  INSERT INTO storage.objects(bucket_id,name,metadata)
   SELECT 'convert-photos',path,'{"contentLength":123,"mimetype":"image/jpeg"}'
   FROM drafts WHERE label='a2';
  RAISE EXCEPTION 'ASSERTION: revoked scope uploaded a pending object';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.ieadpe_create_photo_draft(
   'cc000000-0000-4000-8000-000000000024','{}');
  RAISE EXCEPTION 'ASSERTION: revoked scope created another photo draft';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(
 (SELECT count(*)=1 FROM storage.objects) AND
 (SELECT count(*)=(SELECT photos+2 FROM counts_before) FROM public.photo_assets),
 'revoked scope cannot upload or create another draft');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('authority-scope-a@example.test','aa000000-0000-4000-8000-000000000001',
  'Membro da direção da campanha','bb000000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000001',true);
INSERT INTO storage.objects(bucket_id,name,metadata)
 SELECT 'convert-photos',path,'{"contentLength":123,"mimetype":"image/jpeg"}'
 FROM drafts WHERE label='a2';
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM storage.objects),
 'restored scope completes its legitimate pending upload');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aa000000-0000-4000-8000-000000000004',true);
INSERT INTO drafts(label,id) SELECT 'global',
 (public.ieadpe_create_photo_draft('cc000000-0000-4000-8000-000000000025','{}')->>'id')::uuid;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=(SELECT photos+3 FROM counts_before) FROM public.photo_assets),
 'global manager still creates photo drafts');

ROLLBACK;
