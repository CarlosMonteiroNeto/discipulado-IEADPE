BEGIN;

-- T5 stores only a digest for the reviewed correction. The submitted JSON is
-- erased from the queue row as part of the same transaction as the decision.
ALTER TABLE private.public_intake_decisions
  ADD COLUMN corrected_draft_digest text NOT NULL
    CHECK(corrected_draft_digest ~ '^[0-9a-f]{64}$');
COMMENT ON COLUMN private.public_intake_decisions.corrected_draft_digest IS
  'T5 digest of the approved corrected draft, or a null-draft sentinel for rejection; never stores personal fields.';

CREATE FUNCTION private.public_intake_review_cursor_encode(
  actor_uid uuid, congregation_id uuid, submitted_at timestamptz, submission_id uuid
) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT translate(
    encode(convert_to(jsonb_build_object(
      'actor_uid', actor_uid::text,
      'congregation_id', congregation_id,
      'submitted_at', submitted_at,
      'id', submission_id::text
    )::text, 'UTF8'), 'base64'), E'+/=\n', '-_')
$$;

CREATE FUNCTION private.public_intake_review_cursor_decode(cursor_value text)
RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE standard_value text; padding integer; decoded jsonb;
BEGIN
  IF cursor_value IS NULL THEN RETURN NULL; END IF;
  IF length(cursor_value) > 512 OR cursor_value !~ '^[A-Za-z0-9_-]+$' THEN
    RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023';
  END IF;
  standard_value := translate(cursor_value, '-_', '+/');
  padding := (4 - length(standard_value) % 4) % 4;
  decoded := convert_from(decode(standard_value || repeat('=', padding), 'base64'), 'UTF8')::jsonb;
  IF jsonb_typeof(decoded) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023';
  END IF;
  RETURN decoded;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023';
END $$;

CREATE FUNCTION private.public_intake_review_operation_id(submission_id uuid)
RETURNS uuid
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE value text;
BEGIN
  value := substr(encode(sha256(convert_to(
    'ieadpe:public-intake-review:v1:' || submission_id::text, 'UTF8'
  )), 'hex'), 1, 32);
  RETURN (substr(value,1,8) || '-' || substr(value,9,4) || '-' ||
          substr(value,13,4) || '-' || substr(value,17,4) || '-' ||
          substr(value,21,12))::uuid;
END $$;

CREATE FUNCTION public.ieadpe_list_pending_intake(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  actor uuid := auth.uid(); scope_id uuid; page_size integer; cursor_value jsonb;
  after_at timestamptz; after_id uuid; items jsonb; next_cursor text;
  has_more boolean; item_count integer; last_at timestamptz; last_id uuid;
  at_time timestamptz := private.public_intake_now();
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
  PERFORM private.lock_access(ARRAY[actor]);
  IF request IS NULL OR jsonb_typeof(request)<>'object' OR
     request-ARRAY['congregation_id','limit','cursor']<>'{}'::jsonb OR
     NOT request ?& ARRAY['congregation_id','limit','cursor'] OR
     jsonb_typeof(request->'congregation_id') NOT IN ('string','null') OR
     jsonb_typeof(request->'limit') IS DISTINCT FROM 'number' OR
     (request->>'limit') !~ '^[0-9]+$' OR
     jsonb_typeof(request->'cursor') NOT IN ('string','null') THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
  END IF;
  BEGIN
    page_size := (request->>'limit')::integer;
    IF jsonb_typeof(request->'congregation_id')='string' THEN
      scope_id := (request->>'congregation_id')::uuid;
    END IF;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
  END;
  IF page_size NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'invalid_limit' USING ERRCODE='22023';
  END IF;
  IF scope_id IS NULL THEN
    IF NOT private.is_global_manager() THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
    END IF;
  ELSE
    IF NOT private.can_access_congregation(scope_id) THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
    END IF;
    PERFORM 1 FROM public.congregations c
      WHERE c.id=scope_id AND c.archived_at IS NULL FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  END IF;

  cursor_value := private.public_intake_review_cursor_decode(request->>'cursor');
  IF cursor_value IS NOT NULL THEN
    IF cursor_value-ARRAY['actor_uid','congregation_id','submitted_at','id']<>'{}'::jsonb OR
       NOT cursor_value ?& ARRAY['actor_uid','congregation_id','submitted_at','id'] OR
       cursor_value->>'actor_uid' IS DISTINCT FROM actor::text OR
       (scope_id IS NULL AND
         cursor_value->'congregation_id' IS DISTINCT FROM 'null'::jsonb) OR
       (scope_id IS NOT NULL AND
         cursor_value->'congregation_id' IS DISTINCT FROM to_jsonb(scope_id)) OR
       jsonb_typeof(cursor_value->'submitted_at') IS DISTINCT FROM 'string' OR
       jsonb_typeof(cursor_value->'id') IS DISTINCT FROM 'string' THEN
      RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023';
    END IF;
    BEGIN
      after_at := (cursor_value->>'submitted_at')::timestamptz;
      after_id := (cursor_value->>'id')::uuid;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'invalid_cursor' USING ERRCODE='22023';
    END;
  END IF;

  SELECT EXISTS(
    SELECT FROM private.public_intake_submissions s
      JOIN public.congregations c ON c.id=s.congregation_id AND c.archived_at IS NULL
    WHERE s.status='pending' AND s.expires_at>at_time AND
      (scope_id IS NULL OR s.congregation_id=scope_id) AND
      (after_at IS NULL OR (s.created_at,s.id)>(after_at,after_id))
    ORDER BY s.created_at,s.id OFFSET page_size LIMIT 1
  ) INTO has_more;
  WITH page AS (
    SELECT s.id,s.congregation_id,c.name AS congregation_name,
      s.created_at AS submitted_at,s.expires_at,
      s.draft->'person'->>'name' AS name,s.revision
    FROM private.public_intake_submissions s
      JOIN public.congregations c ON c.id=s.congregation_id AND c.archived_at IS NULL
    WHERE s.status='pending' AND s.expires_at>at_time AND
      (scope_id IS NULL OR s.congregation_id=scope_id) AND
      (after_at IS NULL OR (s.created_at,s.id)>(after_at,after_id))
    ORDER BY s.created_at,s.id LIMIT page_size
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id',p.id,'congregation_id',p.congregation_id,
      'congregation_name',p.congregation_name,'submitted_at',p.submitted_at,
      'expires_at',p.expires_at,'name',p.name,'revision',p.revision
    ) ORDER BY p.submitted_at,p.id),'[]'::jsonb),count(*)
    INTO items,item_count FROM page p;
  next_cursor := NULL;
  IF has_more AND item_count>0 THEN
    last_at := (items->(item_count-1)->>'submitted_at')::timestamptz;
    last_id := (items->(item_count-1)->>'id')::uuid;
    next_cursor := private.public_intake_review_cursor_encode(actor,scope_id,last_at,last_id);
  END IF;
  RETURN jsonb_build_object('items',items,'next_cursor',next_cursor);
END $$;

CREATE FUNCTION public.ieadpe_get_pending_intake(request jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid := auth.uid(); target uuid; row_value private.public_intake_submissions%ROWTYPE;
 at_time timestamptz := private.public_intake_now(); congregation_name text;
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
  PERFORM private.lock_access(ARRAY[actor]);
  IF request IS NULL OR jsonb_typeof(request)<>'object' OR
     request-ARRAY['id']<>'{}'::jsonb OR NOT request ? 'id' OR
     jsonb_typeof(request->'id') IS DISTINCT FROM 'string' THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
  END IF;
  BEGIN target := (request->>'id')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023';
  END;
  SELECT * INTO row_value FROM private.public_intake_submissions s
    WHERE s.id=target AND s.status='pending' AND s.expires_at>at_time;
  IF NOT FOUND THEN RAISE EXCEPTION 'pending_not_found' USING ERRCODE='22023'; END IF;
  IF NOT private.can_access_congregation(row_value.congregation_id) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;
  SELECT c.name INTO congregation_name FROM public.congregations c
    WHERE c.id=row_value.congregation_id AND c.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object(
    'id',row_value.id,'congregation_id',row_value.congregation_id,
    'congregation_name',congregation_name,'submitted_at',row_value.created_at,
    'expires_at',row_value.expires_at,'name',row_value.draft->'person'->>'name',
    'revision',row_value.revision,'draft',row_value.draft
  );
END $$;

CREATE FUNCTION public.ieadpe_review_pending_intake(operation_id uuid, payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  actor uuid := auth.uid(); target uuid; expected integer; decision text; outcome text;
  corrected jsonb; canonical_payload jsonb; corrected_digest text; payload_digest text;
  reserved_operation_id uuid; review_row private.public_intake_submissions%ROWTYPE;
  decision_row private.public_intake_decisions%ROWTYPE; operation_receipt private.mutation_receipts%ROWTYPE;
  settings private.public_intake_settings%ROWTYPE; official_result jsonb;
  official_id uuid; response jsonb; at_time timestamptz := private.public_intake_now();
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
  IF operation_id IS NULL OR payload IS NULL OR jsonb_typeof(payload)<>'object' THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
  END IF;
  IF payload-ARRAY['id','expected_revision','decision','draft']<>'{}'::jsonb OR
     NOT payload ?& ARRAY['id','expected_revision','decision'] OR
     jsonb_typeof(payload->'id') IS DISTINCT FROM 'string' OR
     jsonb_typeof(payload->'expected_revision') IS DISTINCT FROM 'number' OR
     (payload->'expected_revision')::text !~ '^[1-9][0-9]*$' OR
     jsonb_typeof(payload->'decision') IS DISTINCT FROM 'string' OR
     payload->>'decision' NOT IN ('approve','reject') THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
  END IF;
  decision := payload->>'decision';
  IF (decision='approve' AND (NOT payload ? 'draft' OR
       jsonb_typeof(payload->'draft') IS DISTINCT FROM 'object')) OR
     (decision='reject' AND payload ? 'draft') THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
  END IF;
  BEGIN
    target := (payload->>'id')::uuid;
    expected := (payload->>'expected_revision')::integer;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
  END;
  corrected := CASE WHEN decision='approve' THEN payload->'draft' ELSE NULL END;
  IF decision='approve' THEN
    corrected_digest := encode(sha256(convert_to(corrected::text,'UTF8')),'hex');
    outcome := 'approved';
  ELSE
    corrected_digest := encode(sha256(convert_to('null','UTF8')),'hex');
    outcome := 'rejected';
  END IF;
  payload_digest := encode(sha256(convert_to(payload::text,'UTF8')),'hex');

  -- The established order is actor access lock, then pending-row lock. This
  -- serializes grant revocation against review before scope is read.
  PERFORM private.lock_access(ARRAY[actor]);
  SELECT * INTO review_row FROM private.public_intake_submissions s
    WHERE s.id=target FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'pending_not_found' USING ERRCODE='22023'; END IF;
  IF NOT private.can_access_congregation(review_row.congregation_id) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM public.congregations c
    WHERE c.id=review_row.congregation_id AND c.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'forbidden' USING ERRCODE='42501'; END IF;

  SELECT * INTO operation_receipt FROM private.mutation_receipts r
    WHERE r.actor_uid=actor AND r.operation_id=ieadpe_review_pending_intake.operation_id;
  IF FOUND THEN
    IF operation_receipt.command<>'review_pending_intake' OR
       operation_receipt.payload_hash<>payload_digest THEN
      RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023';
    END IF;
    RETURN operation_receipt.result;
  END IF;

  SELECT * INTO decision_row FROM private.public_intake_decisions d
    WHERE d.submission_id=target;
  IF FOUND THEN
    IF decision_row.outcome<>outcome OR
       decision_row.corrected_draft_digest<>corrected_digest THEN
      RAISE EXCEPTION 'operation_conflict' USING ERRCODE='22023';
    END IF;
    response := jsonb_build_object(
      'id',target,'status',decision_row.outcome,
      'official_convert_id',decision_row.official_convert_id
    );
    INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
      VALUES(actor,operation_id,'review_pending_intake',payload_digest,response);
    RETURN response;
  END IF;

  IF review_row.status<>'pending' OR review_row.draft IS NULL THEN
    RAISE EXCEPTION 'pending_not_actionable' USING ERRCODE='22023';
  END IF;
  IF review_row.expires_at<=at_time THEN
    RAISE EXCEPTION 'expired_submission' USING ERRCODE='22023';
  END IF;
  IF review_row.revision<>expected THEN
    RAISE EXCEPTION 'stale_revision' USING ERRCODE='40001';
  END IF;
  IF decision='approve' THEN
    IF corrected->>'congregation_id' IS DISTINCT FROM review_row.congregation_id::text OR
       NOT private.public_intake_draft_valid(corrected) THEN
      RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023';
    END IF;
    canonical_payload := corrected || jsonb_build_object(
      'convert',(corrected->'convert') || jsonb_build_object('photo_asset_id',NULL)
    );
    reserved_operation_id := private.public_intake_review_operation_id(target);
    official_result := public.ieadpe_create_convert(reserved_operation_id,canonical_payload);
    official_id := (official_result->>'id')::uuid;
  END IF;
  SELECT * INTO settings FROM private.public_intake_settings WHERE singleton FOR SHARE;
  IF NOT FOUND OR settings.decision_retention<>interval '90 days' THEN
    RAISE EXCEPTION 'intake_unavailable' USING ERRCODE='22023';
  END IF;
  UPDATE private.public_intake_submissions SET
    status=outcome,draft=NULL,payload_erased_at=at_time,revision=revision+1
    WHERE id=target;
  INSERT INTO private.public_intake_decisions(
    submission_id,outcome,reviewer_uid,official_convert_id,decided_at,retained_until,
    corrected_draft_digest
  ) VALUES (
    target,outcome,actor,official_id,at_time,at_time+settings.decision_retention,
    corrected_digest
  );
  response := jsonb_build_object(
    'id',target,'status',outcome,'official_convert_id',official_id
  );
  INSERT INTO private.mutation_receipts(actor_uid,operation_id,command,payload_hash,result)
    VALUES(actor,operation_id,'review_pending_intake',payload_digest,response);
  RETURN response;
END $$;

REVOKE ALL ON FUNCTION private.public_intake_review_cursor_encode(uuid,uuid,timestamptz,uuid),
  private.public_intake_review_cursor_decode(text),
  private.public_intake_review_operation_id(uuid)
  FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.ieadpe_list_pending_intake(jsonb),
  public.ieadpe_get_pending_intake(jsonb),
  public.ieadpe_review_pending_intake(uuid,jsonb)
  FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.ieadpe_list_pending_intake(jsonb),
  public.ieadpe_get_pending_intake(jsonb),
  public.ieadpe_review_pending_intake(uuid,jsonb) TO authenticated;

COMMENT ON FUNCTION public.ieadpe_list_pending_intake(jsonb) IS
  'T5 oldest-first active pending queue. Scope and caller are embedded in opaque cursors and revalidated on every page.';
COMMENT ON FUNCTION public.ieadpe_get_pending_intake(jsonb) IS
  'T5 exact names-and-draft detail projection for currently authorized campaign reviewers.';
COMMENT ON FUNCTION public.ieadpe_review_pending_intake(uuid,jsonb) IS
  'T5 atomic scoped approval/rejection. Approval calls canonical official registration; decision metadata contains only IDs and digests.';

COMMIT;
