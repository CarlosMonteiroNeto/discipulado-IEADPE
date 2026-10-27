BEGIN;

CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERTION: %', label;
  END IF;
END $$;

CREATE FUNCTION pg_temp.expect_failure(
  statement text,
  expected_state text,
  expected_message text,
  label text
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE IS DISTINCT FROM expected_state OR
       (expected_message IS NOT NULL AND SQLERRM IS DISTINCT FROM expected_message) THEN
      RAISE EXCEPTION 'ASSERTION: % raised % (%) instead of % (%)',
        label, SQLSTATE, SQLERRM, expected_state, coalesce(expected_message, 'any');
    END IF;
    RETURN;
  END;
  RAISE EXCEPTION 'ASSERTION: % was accepted', label;
END $$;

CREATE FUNCTION pg_temp.draft(scope_id uuid, person_name text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'congregation_id', scope_id::text,
    'person', jsonb_build_object(
      'name', person_name, 'phone', NULL, 'birth_date', NULL, 'address', NULL
    ),
    'convert', jsonb_build_object(
      'landmark', 'Praça Central', 'gender', 'male',
      'conversion_date', ((now() AT TIME ZONE 'America/Sao_Paulo')::date)::text,
      'worship_type', 'Culto regular', 'age', NULL
    )
  )
$$;

CREATE FUNCTION pg_temp.review_payload(
  submission_id uuid,
  expected_revision integer,
  decision text,
  corrected_draft jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object(
    'id', submission_id::text,
    'expected_revision', expected_revision,
    'decision', decision
  ) || CASE WHEN corrected_draft IS NULL THEN '{}'::jsonb
            ELSE jsonb_build_object('draft', corrected_draft) END
$$;

CREATE FUNCTION pg_temp.seed_pending(
  submission_id uuid,
  scope_id uuid,
  person_name text,
  created_at timestamptz,
  expires_at timestamptz
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE draft_value jsonb := pg_temp.draft(scope_id, person_name);
BEGIN
  INSERT INTO private.public_intake_submissions(
    id, congregation_id, network_hash, draft, draft_digest, status,
    revision, created_at, expires_at
  ) VALUES (
    submission_id, scope_id, repeat('a', 64), draft_value,
    encode(sha256(convert_to(draft_value::text, 'UTF8')), 'hex'),
    'pending', 1, created_at, expires_at
  );
END $$;

CREATE FUNCTION pg_temp.call_list(request jsonb) RETURNS jsonb
LANGUAGE sql AS $$ SELECT public.ieadpe_list_pending_intake(request) $$;
CREATE FUNCTION pg_temp.call_get(request jsonb) RETURNS jsonb
LANGUAGE sql AS $$ SELECT public.ieadpe_get_pending_intake(request) $$;
CREATE FUNCTION pg_temp.call_review(operation_id uuid, payload jsonb) RETURNS jsonb
LANGUAGE sql AS $$ SELECT public.ieadpe_review_pending_intake(operation_id, payload) $$;

CREATE TEMP TABLE review_clock(value timestamptz NOT NULL);
INSERT INTO review_clock VALUES ('2026-10-25 12:00:00+00');
CREATE OR REPLACE FUNCTION private.public_intake_now() RETURNS timestamptz
LANGUAGE sql STABLE SET search_path='' AS $$ SELECT value FROM pg_temp.review_clock $$;
UPDATE private.public_intake_settings SET decision_retention = interval '90 days';

INSERT INTO auth.users(id, email, email_confirmed_at) VALUES
  ('da000000-0000-4000-8000-000000000001', 'review-a@example.test', now()),
  ('da000000-0000-4000-8000-000000000002', 'review-b@example.test', now()),
  ('da000000-0000-4000-8000-000000000003', 'review-none@example.test', now()),
  ('da000000-0000-4000-8000-000000000004', 'review-global@example.test', now());

INSERT INTO public.congregations(id, name) VALUES
  ('db000000-0000-4000-8000-000000000001', 'Review Scope A'),
  ('db000000-0000-4000-8000-000000000002', 'Review Scope B'),
  ('db000000-0000-4000-8000-000000000003', 'Review Archive Candidate');

INSERT INTO public.user_access(user_email, user_id, role, congregation_id) VALUES
  ('review-a@example.test', 'da000000-0000-4000-8000-000000000001',
   'Membro da direção da campanha', 'db000000-0000-4000-8000-000000000001'),
  ('review-a@example.test', 'da000000-0000-4000-8000-000000000001',
   'Membro da direção da campanha', 'db000000-0000-4000-8000-000000000003'),
  ('review-b@example.test', 'da000000-0000-4000-8000-000000000002',
   'Membro da direção da campanha', 'db000000-0000-4000-8000-000000000002'),
  ('review-global@example.test', 'da000000-0000-4000-8000-000000000004',
   'Membro da supervisão das campanhas', NULL);

SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000001',
  'db000000-0000-4000-8000-000000000001', 'Pending Alpha',
  '2026-10-25 10:00:00+00', '2026-11-24 10:00:00+00'
);
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000002',
  'db000000-0000-4000-8000-000000000001', 'Pending Beta',
  '2026-10-25 10:01:00+00', '2026-11-24 10:01:00+00'
);
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000003',
  'db000000-0000-4000-8000-000000000002', 'Pending Other Scope',
  '2026-10-25 10:02:00+00', '2026-11-24 10:02:00+00'
);
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000004',
  'db000000-0000-4000-8000-000000000001', 'Expired Payload',
  '2026-10-25 09:00:00+00', '2026-10-25 11:59:59+00'
);
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000005',
  'db000000-0000-4000-8000-000000000003', 'Archived Payload',
  '2026-10-25 10:03:00+00', '2026-11-24 10:03:00+00'
);
UPDATE public.congregations SET archived_at = '2026-10-25 11:00:00+00'
WHERE id = 'db000000-0000-4000-8000-000000000003';

CREATE TEMP TABLE rpc_results(label text PRIMARY KEY, value jsonb NOT NULL);
GRANT ALL ON rpc_results TO authenticated, anon;

SELECT pg_temp.assert_true(
  to_regprocedure('public.ieadpe_list_pending_intake(jsonb)') IS NOT NULL AND
  to_regprocedure('public.ieadpe_get_pending_intake(jsonb)') IS NOT NULL AND
  to_regprocedure('public.ieadpe_review_pending_intake(uuid,jsonb)') IS NOT NULL,
  'all scoped pending-review RPCs exist'
);
SELECT pg_temp.assert_true(
  has_function_privilege('authenticated', 'public.ieadpe_list_pending_intake(jsonb)', 'EXECUTE') AND
  has_function_privilege('authenticated', 'public.ieadpe_get_pending_intake(jsonb)', 'EXECUTE') AND
  has_function_privilege('authenticated', 'public.ieadpe_review_pending_intake(uuid,jsonb)', 'EXECUTE') AND
  NOT has_function_privilege('anon', 'public.ieadpe_list_pending_intake(jsonb)', 'EXECUTE') AND
  NOT has_function_privilege('anon', 'public.ieadpe_get_pending_intake(jsonb)', 'EXECUTE') AND
  NOT has_function_privilege('anon', 'public.ieadpe_review_pending_intake(uuid,jsonb)', 'EXECUTE'),
  'only authenticated callers receive review RPC execute grants'
);

SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.ieadpe_list_pending_intake(
      '{"congregation_id":"db000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb
    );
    RAISE EXCEPTION 'ASSERTION: anon listed pending intake';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000003', true);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_list('{"congregation_id":"db000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb)$$,
  '42501', 'forbidden', 'authenticated no-grant reviewer cannot list'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_get('{"id":"dc000000-0000-4000-8000-000000000001"}'::jsonb)$$,
  '42501', 'forbidden', 'authenticated no-grant reviewer cannot detail-read'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000020'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000001',1,'reject'))$$,
  '42501', 'forbidden', 'authenticated no-grant reviewer cannot decide'
);
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000002', true);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_list('{"congregation_id":"db000000-0000-4000-8000-000000000001","limit":10,"cursor":null}'::jsonb)$$,
  '42501', 'forbidden', 'other-congregation reviewer cannot list'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_get('{"id":"dc000000-0000-4000-8000-000000000001"}'::jsonb)$$,
  '42501', 'forbidden', 'other-congregation reviewer cannot detail-read'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000021'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000001',1,'reject'))$$,
  '42501', 'forbidden', 'other-congregation reviewer cannot decide'
);
RESET ROLE;

-- A local reviewer sees only active, non-expired rows in the selected scope.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000001', true);
INSERT INTO rpc_results VALUES ('a_page_1', public.ieadpe_list_pending_intake(
  '{"congregation_id":"db000000-0000-4000-8000-000000000001","limit":1,"cursor":null}'::jsonb
));
INSERT INTO rpc_results VALUES ('a_detail', public.ieadpe_get_pending_intake(
  '{"id":"dc000000-0000-4000-8000-000000000001"}'::jsonb
));
INSERT INTO rpc_results VALUES ('official_search', public.ieadpe_ministry_list_converts(
  '{"congregation_id":"db000000-0000-4000-8000-000000000001","name_prefix":"Pending","limit":10,"cursor":null}'::jsonb
));
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_list('{"congregation_id":"db000000-0000-4000-8000-000000000001","limit":10,"cursor":null,"extra":true}'::jsonb)$$,
  '22023','invalid_request','list contract rejects unknown request fields'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000022'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000001',1,'reject') || '{"extra":true}'::jsonb)$$,
  '22023','invalid_payload','review contract rejects unknown request fields'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000023'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000001',1,'approve',
      pg_temp.draft('db000000-0000-4000-8000-000000000002','Changed Scope')) )$$,
  '22023','invalid_payload','corrected approval cannot change congregation'
);
SELECT pg_temp.assert_true(
  (SELECT value ?& ARRAY['items','next_cursor'] AND
    value - ARRAY['items','next_cursor'] = '{}'::jsonb AND
    jsonb_array_length(value->'items') = 1 AND
    value->'items'->0->>'id' = 'dc000000-0000-4000-8000-000000000001' AND
    value->'items'->0->>'congregation_id' = 'db000000-0000-4000-8000-000000000001' AND
    value->'items'->0->>'name' = 'Pending Alpha' AND
    value->'items'->0->>'revision' = '1' AND
    jsonb_typeof(value->'next_cursor') = 'string'
   FROM rpc_results WHERE label = 'a_page_1'),
  'local list is exact, oldest-first and exposes only its permitted summary'
);
SELECT pg_temp.assert_true(
  (SELECT value ?& ARRAY['id','congregation_id','congregation_name','submitted_at',
                         'expires_at','name','revision','draft'] AND
    value - ARRAY['id','congregation_id','congregation_name','submitted_at',
                  'expires_at','name','revision','draft'] = '{}'::jsonb AND
    value->>'id' = 'dc000000-0000-4000-8000-000000000001' AND
    value->>'congregation_name' = 'Review Scope A' AND
    value->'draft'->'person'->>'name' = 'Pending Alpha'
   FROM rpc_results WHERE label = 'a_detail'),
  'authorized detail includes the exact pending draft projection'
);
SELECT pg_temp.assert_true(
  (SELECT jsonb_array_length(value->'items')=0
   FROM rpc_results WHERE label='official_search'),
  'ordinary official reports exclude pending-only submissions'
);
INSERT INTO rpc_results VALUES ('a_page_2', public.ieadpe_list_pending_intake(
  jsonb_build_object(
    'congregation_id','db000000-0000-4000-8000-000000000001',
    'limit',1,'cursor',(SELECT value->>'next_cursor' FROM rpc_results WHERE label='a_page_1')
  )
));
RESET ROLE;

SELECT pg_temp.assert_true(
  (SELECT value->'items'->0->>'id' = 'dc000000-0000-4000-8000-000000000002' AND
          value->'next_cursor' = 'null'::jsonb
   FROM rpc_results WHERE label='a_page_2'),
  'cursor continues oldest-first within the bound congregation'
);
SELECT pg_temp.assert_true(
  NOT EXISTS (SELECT FROM public.converts WHERE name IN
    ('Pending Alpha','Pending Beta','Pending Other Scope')),
  'pending rows do not appear in official convert records'
);

-- Forged/replayed cursors cannot change their caller or selected scope.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000004', true);
INSERT INTO rpc_results VALUES ('global_all', public.ieadpe_list_pending_intake(
  '{"congregation_id":null,"limit":100,"cursor":null}'::jsonb
));
INSERT INTO rpc_results VALUES ('global_page_1', public.ieadpe_list_pending_intake(
  '{"congregation_id":null,"limit":1,"cursor":null}'::jsonb
));
INSERT INTO rpc_results VALUES ('global_page_2', public.ieadpe_list_pending_intake(
  jsonb_build_object('congregation_id',NULL,'limit',1,
    'cursor',(SELECT value->'next_cursor' FROM rpc_results WHERE label='global_page_1'))
));
SELECT pg_temp.assert_true(
  (SELECT jsonb_array_length(value->'items') = 3 AND
          NOT EXISTS (SELECT FROM jsonb_array_elements(value->'items') item
                      WHERE item->>'id' IN
                        ('dc000000-0000-4000-8000-000000000004',
                         'dc000000-0000-4000-8000-000000000005'))
   FROM rpc_results WHERE label='global_all'),
  'global reviewer lists all active scopes but excludes expired and archived items'
);
SELECT pg_temp.assert_true(
  (SELECT value->'items'->0->>'id' FROM rpc_results WHERE label='global_page_2')=
  (SELECT value->'items'->1->>'id' FROM rpc_results WHERE label='global_all'),
  'global cursor continues oldest-first within the bound all-scope view'
);
SELECT pg_temp.expect_failure(
  format($q$SELECT pg_temp.call_list(%L::jsonb)$q$,
    jsonb_build_object('congregation_id','db000000-0000-4000-8000-000000000001',
      'limit',1,'cursor',(SELECT value->>'next_cursor' FROM rpc_results WHERE label='global_page_1'))::text),
  '22023', 'invalid_cursor', 'global cursor is bound to its selected congregation'
);
SELECT pg_temp.expect_failure(
  format($q$SELECT pg_temp.call_list(%L::jsonb)$q$,
    jsonb_build_object('congregation_id','db000000-0000-4000-8000-000000000001',
      'limit',1,'cursor',(SELECT value->>'next_cursor' FROM rpc_results WHERE label='a_page_1'))::text),
  '22023', 'invalid_cursor', 'cursor is bound to its original reviewer'
);
RESET ROLE;

-- Authenticated in-scope approval uses the canonical create transaction.
CREATE TEMP TABLE before_official AS SELECT
  (SELECT count(*) FROM public.converts) AS converts,
  (SELECT count(*) FROM public.ministry_people) AS people,
  (SELECT coalesce(sum(conversion_count),0) FROM private.congregation_week_guards) AS weekly;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000001', true);
INSERT INTO rpc_results VALUES ('approved', public.ieadpe_review_pending_intake(
  'dd000000-0000-4000-8000-000000000001',
  pg_temp.review_payload(
    'dc000000-0000-4000-8000-000000000001',1,'approve',
    jsonb_set(pg_temp.draft('db000000-0000-4000-8000-000000000001',
      'Corrected Confidential Person'),'{convert,landmark}','"Biblioteca"'::jsonb)
  )
));
INSERT INTO rpc_results VALUES ('rejected', public.ieadpe_review_pending_intake(
  'dd000000-0000-4000-8000-000000000002',
  pg_temp.review_payload('dc000000-0000-4000-8000-000000000002',1,'reject')
));
RESET ROLE;

SELECT pg_temp.assert_true(
  (SELECT value ?& ARRAY['id','status','official_convert_id'] AND
          value - ARRAY['id','status','official_convert_id'] = '{}'::jsonb AND
          value->>'id' = 'dc000000-0000-4000-8000-000000000001' AND
          value->>'status' = 'approved' AND
          (value->>'official_convert_id')::uuid IS NOT NULL
   FROM rpc_results WHERE label='approved'),
  'approval returns the exact canonical official result contract'
);
SELECT pg_temp.assert_true(
  (SELECT value->>'status'='rejected' AND value->'official_convert_id'='null'::jsonb
   FROM rpc_results WHERE label='rejected'),
  'rejection records no official convert ID'
);
SELECT pg_temp.assert_true(
  (SELECT status='approved' AND draft IS NULL AND payload_erased_at IS NOT NULL AND revision=2
   FROM private.public_intake_submissions
   WHERE id='dc000000-0000-4000-8000-000000000001') AND
  (SELECT status='rejected' AND draft IS NULL AND payload_erased_at IS NOT NULL AND revision=2
   FROM private.public_intake_submissions
   WHERE id='dc000000-0000-4000-8000-000000000002'),
  'approval/rejection erase the pending payload and advance revision atomically'
);
SELECT pg_temp.assert_true(
  (SELECT count(*)=1 AND
          bool_and(c.created_by='da000000-0000-4000-8000-000000000001') AND
          bool_and(c.name='Corrected Confidential Person') AND
          bool_and(c.photo_asset_id IS NULL) AND
          bool_and(p.name='Corrected Confidential Person')
   FROM public.converts c JOIN public.ministry_people p ON p.id=c.person_id
   WHERE c.id=(SELECT (value->>'official_convert_id')::uuid
               FROM rpc_results WHERE label='approved')) AND
  (SELECT count(*)=(SELECT converts+1 FROM before_official) FROM public.converts) AND
  (SELECT count(*)=(SELECT people+1 FROM before_official) FROM public.ministry_people) AND
  (SELECT coalesce(sum(conversion_count),0)=(SELECT weekly+1 FROM before_official)
   FROM private.congregation_week_guards),
  'approval uses auth.uid, canonical person/convert creation, null photo and one weekly count'
);
SELECT pg_temp.assert_true(
  (SELECT outcome='approved' AND reviewer_uid='da000000-0000-4000-8000-000000000001' AND
          official_convert_id=(SELECT (value->>'official_convert_id')::uuid
                               FROM rpc_results WHERE label='approved') AND
          retained_until=decided_at+interval '90 days' AND
          corrected_draft_digest ~ '^[0-9a-f]{64}$' AND
          to_jsonb(d)::text NOT ILIKE '%Corrected Confidential Person%'
   FROM private.public_intake_decisions d
   WHERE submission_id='dc000000-0000-4000-8000-000000000001') AND
  (SELECT outcome='rejected' AND reviewer_uid='da000000-0000-4000-8000-000000000001' AND
          official_convert_id IS NULL AND retained_until=decided_at+interval '90 days' AND
          to_jsonb(d)::text NOT ILIKE '%Pending Beta%'
   FROM private.public_intake_decisions d
   WHERE submission_id='dc000000-0000-4000-8000-000000000002'),
  'decision metadata uses configured retention and contains no personal payload'
);
SELECT pg_temp.assert_true(
  NOT EXISTS (SELECT FROM private.mutation_receipts r
    WHERE r.actor_uid='da000000-0000-4000-8000-000000000001' AND
      r.operation_id IN ('dd000000-0000-4000-8000-000000000001',
                         'dd000000-0000-4000-8000-000000000002') AND
      (r.result::text ILIKE '%Corrected Confidential Person%' OR
       r.result::text ILIKE '%Pending Beta%')),
  'review operation receipts do not retain PII'
);

-- Same-operation replay and same-draft alternate operation are exactly-once.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000001', true);
INSERT INTO rpc_results VALUES ('approved_replay', public.ieadpe_review_pending_intake(
  'dd000000-0000-4000-8000-000000000001',
  pg_temp.review_payload(
    'dc000000-0000-4000-8000-000000000001',1,'approve',
    jsonb_set(pg_temp.draft('db000000-0000-4000-8000-000000000001',
      'Corrected Confidential Person'),'{convert,landmark}','"Biblioteca"'::jsonb)
  )
));
INSERT INTO rpc_results VALUES ('approved_alt', public.ieadpe_review_pending_intake(
  'dd000000-0000-4000-8000-000000000003',
  pg_temp.review_payload(
    'dc000000-0000-4000-8000-000000000001',1,'approve',
    jsonb_set(pg_temp.draft('db000000-0000-4000-8000-000000000001',
      'Corrected Confidential Person'),'{convert,landmark}','"Biblioteca"'::jsonb)
  )
));
SELECT pg_temp.assert_true(
  (SELECT value->>'official_convert_id'=(SELECT value->>'official_convert_id'
                                         FROM rpc_results WHERE label='approved')
   FROM rpc_results WHERE label='approved_replay') AND
  (SELECT value=(SELECT value FROM rpc_results WHERE label='approved')
   FROM rpc_results WHERE label='approved_alt') AND
  (SELECT count(*)=1 FROM public.converts
   WHERE id=(SELECT (value->>'official_convert_id')::uuid
             FROM rpc_results WHERE label='approved')),
  'identical approval replay keeps one canonical convert result'
);
SELECT pg_temp.expect_failure(
  format($q$SELECT pg_temp.call_review(%L::uuid,%L::jsonb)$q$,
    'dd000000-0000-4000-8000-000000000001',
    pg_temp.review_payload(
      'dc000000-0000-4000-8000-000000000001',1,'approve',
      jsonb_set(pg_temp.draft('db000000-0000-4000-8000-000000000001',
        'Different Confidential Person'),'{convert,landmark}','"Biblioteca"'::jsonb)
    )::text),
  '22023','operation_conflict','same review operation cannot bind a changed payload'
);
SELECT pg_temp.expect_failure(
  format($q$SELECT pg_temp.call_review(%L::uuid,%L::jsonb)$q$,
    'dd000000-0000-4000-8000-000000000004',
    pg_temp.review_payload(
      'dc000000-0000-4000-8000-000000000001',1,'approve',
      jsonb_set(pg_temp.draft('db000000-0000-4000-8000-000000000001',
        'Different Confidential Person'),'{convert,landmark}','"Biblioteca"'::jsonb)
    )::text),
  '22023','operation_conflict','alternate approval cannot replace corrected draft'
);

-- A terminal rejection cannot be replaced by a later approval.
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000005'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000002',1,'approve',
      pg_temp.draft('db000000-0000-4000-8000-000000000001','Late approval')))$$,
  '22023','operation_conflict','rejected item cannot later be approved'
);

-- A different scope/caller cannot use a prior cursor, and stale revisions fail.
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000004', true);
SELECT pg_temp.expect_failure(
  format($q$SELECT pg_temp.call_list(%L::jsonb)$q$,
    jsonb_build_object('congregation_id','db000000-0000-4000-8000-000000000002',
      'limit',1,'cursor',(SELECT value->>'next_cursor' FROM rpc_results WHERE label='a_page_1'))::text),
  '22023','invalid_cursor','cursor cannot be reused in another scope'
);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000002', true);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000006'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000003',99,'reject'))$$,
  '40001','stale_revision','review rejects a stale pending revision'
);
RESET ROLE;

-- Expired and archived submissions never produce official data.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000001', true);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000007'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000004',1,'reject'))$$,
  '22023','expired_submission','expired pending item cannot be decided'
);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000008'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000005',1,'reject'))$$,
  '42501','forbidden','archived congregation cannot be reviewed'
);
RESET ROLE;
SELECT pg_temp.assert_true(
  NOT EXISTS(SELECT FROM private.public_intake_decisions
    WHERE submission_id IN ('dc000000-0000-4000-8000-000000000004',
                            'dc000000-0000-4000-8000-000000000005')) AND
  (SELECT count(*)=1 FROM public.converts
   WHERE id=(SELECT (value->>'official_convert_id')::uuid
             FROM rpc_results WHERE label='approved')),
  'expired/archived reviews leave official records and decisions unchanged'
);

-- A grant revoked before review is rechecked before either data or receipt.
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000008',
  'db000000-0000-4000-8000-000000000001', 'Revoked Scope Payload',
  '2026-10-25 10:06:00+00', '2026-11-24 10:06:00+00'
);
DELETE FROM public.user_access WHERE user_id='da000000-0000-4000-8000-000000000001'
  AND congregation_id='db000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000001', true);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000009'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000008',1,'reject'))$$,
  '42501','forbidden','revoked reviewer cannot decide an open submission'
);
SELECT pg_temp.expect_failure(
  format($q$SELECT pg_temp.call_review(%L::uuid,%L::jsonb)$q$,
    'dd000000-0000-4000-8000-000000000001',
    pg_temp.review_payload(
      'dc000000-0000-4000-8000-000000000001',1,'approve',
      jsonb_set(pg_temp.draft('db000000-0000-4000-8000-000000000001',
        'Corrected Confidential Person'),'{convert,landmark}','"Biblioteca"'::jsonb)
    )::text),
  '42501','forbidden','review replay rechecks current scope authority'
);
RESET ROLE;
SELECT pg_temp.assert_true(
  (SELECT status='pending' AND draft IS NOT NULL AND revision=1
   FROM private.public_intake_submissions
   WHERE id='dc000000-0000-4000-8000-000000000008') AND
  NOT EXISTS(SELECT FROM private.mutation_receipts
    WHERE actor_uid='da000000-0000-4000-8000-000000000001'
      AND operation_id='dd000000-0000-4000-8000-000000000009'),
  'revoked review writes neither decision nor operation receipt'
);

-- The fixed retention policy is enforced and cleanup removes a decision exactly
-- at the expiry boundary, not one instant earlier.
SELECT pg_temp.expect_failure(
  $$UPDATE private.public_intake_settings SET decision_retention=interval '89 days'$$,
  '23514',NULL,'decision metadata retention cannot be set below 90 days'
);
SELECT pg_temp.expect_failure(
  $$UPDATE private.public_intake_settings SET decision_retention=interval '91 days'$$,
  '23514',NULL,'decision metadata retention cannot be set above 90 days'
);
SELECT pg_temp.expect_failure(
  $$UPDATE private.public_intake_settings SET decision_retention=interval '3 months'$$,
  '23514',NULL,'calendar months cannot alias the fixed 90-day decision retention'
);
SELECT pg_temp.expect_failure(
  $$UPDATE private.public_intake_settings SET decision_retention=interval '2160 hours'$$,
  '23514',NULL,'hours cannot alias the fixed 90-day decision retention'
);
SELECT pg_temp.expect_failure(
  $$UPDATE private.public_intake_settings SET decision_retention=interval '129600 minutes'$$,
  '23514',NULL,'minutes cannot alias the fixed 90-day decision retention'
);
SELECT pg_temp.expect_failure(
  $$UPDATE private.public_intake_settings SET decision_retention=interval '7776000 seconds'$$,
  '23514',NULL,'seconds cannot alias the fixed 90-day decision retention'
);
UPDATE private.public_intake_settings SET decision_retention=interval '90 days';
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000006',
  'db000000-0000-4000-8000-000000000002', 'Retention Boundary',
  '2026-10-25 10:04:00+00', '2026-11-24 10:04:00+00'
);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000002', true);
INSERT INTO rpc_results VALUES ('retention_reject', public.ieadpe_review_pending_intake(
  'dd000000-0000-4000-8000-000000000010',
  pg_temp.review_payload('dc000000-0000-4000-8000-000000000006',1,'reject')
));
RESET ROLE;
SELECT pg_temp.assert_true(
  (SELECT retained_until=decided_at+interval '90 days' AND
          retained_until='2027-01-23 12:00:00+00'::timestamptz
   FROM private.public_intake_decisions
   WHERE submission_id='dc000000-0000-4000-8000-000000000006'),
  'decision retention uses the exact configured 90-day boundary'
);
UPDATE review_clock SET value=(
  SELECT retained_until-interval '1 microsecond'
  FROM private.public_intake_decisions
  WHERE submission_id='dc000000-0000-4000-8000-000000000006'
);
SELECT private.public_intake_cleanup();
SELECT pg_temp.assert_true(
  EXISTS(SELECT FROM private.public_intake_decisions
    WHERE submission_id='dc000000-0000-4000-8000-000000000006'),
  'decision is retained until the configured instant'
);
UPDATE review_clock SET value=(
  SELECT retained_until
  FROM private.public_intake_decisions
  WHERE submission_id='dc000000-0000-4000-8000-000000000006'
);
SELECT private.public_intake_cleanup();
SELECT pg_temp.assert_true(
  NOT EXISTS(SELECT FROM private.public_intake_decisions
    WHERE submission_id='dc000000-0000-4000-8000-000000000006'),
  'decision is eligible for cleanup exactly at retained_until'
);

-- Inject a canonical-create failure and prove the review transaction rolls back
-- every official write, queue transition and receipt.
UPDATE review_clock SET value='2026-10-25 12:00:00+00';
SELECT pg_temp.seed_pending(
  'dc000000-0000-4000-8000-000000000007',
  'db000000-0000-4000-8000-000000000002', 'Atomic Rollback',
  '2026-10-25 10:05:00+00', '2026-11-24 10:05:00+00'
);
CREATE OR REPLACE FUNCTION public.ieadpe_create_convert(operation_id uuid, payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RAISE EXCEPTION 'injected_canonical_failure' USING ERRCODE='22023';
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'da000000-0000-4000-8000-000000000002', true);
SELECT pg_temp.expect_failure(
  $$SELECT pg_temp.call_review('dd000000-0000-4000-8000-000000000011'::uuid,
    pg_temp.review_payload('dc000000-0000-4000-8000-000000000007',1,'approve',
      pg_temp.draft('db000000-0000-4000-8000-000000000002','Atomic Rollback')))$$,
  '22023','injected_canonical_failure','canonical failure aborts approval'
);
RESET ROLE;
CREATE OR REPLACE FUNCTION public.ieadpe_create_convert(operation_id uuid, payload jsonb)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
  SELECT private.convert_registration_command('create_convert', operation_id, payload)
$$;
SELECT pg_temp.assert_true(
  (SELECT status='pending' AND draft->'person'->>'name'='Atomic Rollback' AND
          payload_erased_at IS NULL AND revision=1
   FROM private.public_intake_submissions
   WHERE id='dc000000-0000-4000-8000-000000000007') AND
  NOT EXISTS(SELECT FROM private.public_intake_decisions
    WHERE submission_id='dc000000-0000-4000-8000-000000000007') AND
  NOT EXISTS(SELECT FROM private.mutation_receipts
    WHERE actor_uid='da000000-0000-4000-8000-000000000002'
      AND operation_id='dd000000-0000-4000-8000-000000000011') AND
  NOT EXISTS(SELECT FROM public.converts WHERE name='Atomic Rollback'),
  'canonical failure rolls back official creation, decision, receipt and erasure'
);

ROLLBACK;
