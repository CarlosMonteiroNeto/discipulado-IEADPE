BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('17000000-0000-0000-0000-000000000001','registrar@example.test',now(),'{"full_name":"Synthetic registrar"}'),
 ('17000000-0000-0000-0000-000000000002','manager@example.test',now(),'{}');
INSERT INTO private.admin_allowlist VALUES('17000000-0000-0000-0000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);
SELECT public.ieadpe_submit_feedback('17000000-0000-0000-0000-000000000003','{"message":"  Synthetic feedback  "}');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.feedback WHERE message='Synthetic feedback' AND created_by='17000000-0000-0000-0000-000000000001' AND user_email='registrar@example.test' AND user_name='Synthetic registrar' AND status='pending'),'authenticated submit inserts trimmed message and server identity');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.feedback),'registrar cannot enumerate feedback');
DO $$ DECLARE response jsonb; p jsonb; BEGIN
 response:=public.ieadpe_submit_feedback('17000000-0000-0000-0000-000000000003','{"message":"  Synthetic feedback  "}');
 PERFORM pg_temp.assert_true((SELECT count(*)=1 FROM jsonb_object_keys(response)) AND response ? 'id','registrar receives ID only');
 BEGIN PERFORM public.ieadpe_submit_feedback('17000000-0000-0000-0000-000000000003','{"message":"Changed"}'); RAISE EXCEPTION 'ASSERTION: conflicting retry accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 FOREACH p IN ARRAY ARRAY['{"message":" "}'::jsonb,jsonb_build_object('message',E'\t\n'),jsonb_build_object('message',chr(160)||chr(8195)),jsonb_build_object('message',repeat('a',5001)), '{"message":"spoof","created_by":"17000000-0000-0000-0000-000000000002"}'::jsonb,'{"message":123}'::jsonb,'{}'::jsonb] LOOP
  BEGIN PERFORM public.ieadpe_submit_feedback(gen_random_uuid(),p); RAISE EXCEPTION 'ASSERTION: invalid submit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
 BEGIN PERFORM public.ieadpe_update_feedback(gen_random_uuid(),jsonb_build_object('id',response->>'id','status','resolved')); RAISE EXCEPTION 'ASSERTION: registrar updated'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.feedback),'retry inserts only one message');
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_submit_feedback(gen_random_uuid(),'{"message":"vav"}');
SELECT public.ieadpe_submit_feedback(gen_random_uuid(),jsonb_build_object('message',repeat('😀',5000)));
RESET ROLE;
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.feedback WHERE message='vav'),'ordinary letter v survives trimming');
SELECT pg_temp.assert_true(EXISTS(SELECT FROM public.feedback WHERE length(message)=5000),'5000 astral code points accepted');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000002',true);
DO $$ DECLARE feedback_id uuid; target text; response jsonb; op uuid:=gen_random_uuid(); BEGIN
 SELECT id INTO feedback_id FROM public.feedback WHERE message='Synthetic feedback';
 FOREACH target IN ARRAY ARRAY['read','resolved','pending'] LOOP
  PERFORM public.ieadpe_update_feedback(gen_random_uuid(),jsonb_build_object('id',feedback_id,'status',target));
  PERFORM pg_temp.assert_true((SELECT status=target FROM public.feedback WHERE id=feedback_id),'strict status transition persists');
 END LOOP;
 response:=public.ieadpe_update_feedback('17000000-0000-0000-0000-000000000004',jsonb_build_object('id',feedback_id,'status','read'));
 PERFORM pg_temp.assert_true(response=public.ieadpe_update_feedback('17000000-0000-0000-0000-000000000004',jsonb_build_object('id',feedback_id,'status','read')),'status replay returns same receipt');
 BEGIN PERFORM public.ieadpe_update_feedback(op,jsonb_build_object('id',feedback_id,'status','unknown')); RAISE EXCEPTION 'ASSERTION: unknown status accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN UPDATE public.feedback SET status='resolved'; RAISE EXCEPTION 'ASSERTION: direct write allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DELETE FROM private.admin_allowlist WHERE user_id='17000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_update_feedback('17000000-0000-0000-0000-000000000004','{}'); RAISE EXCEPTION 'ASSERTION: revoked manager replayed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.ieadpe_submit_feedback(uuid,jsonb)','EXECUTE'),'anon denied');
SELECT pg_temp.assert_true(NOT has_function_privilege('authenticated','private.change_feedback(text,uuid,jsonb)','EXECUTE'),'helper private');
-- A failed receipt must roll back the feedback insert in the same transaction.
CREATE FUNCTION pg_temp.fail_feedback_receipt() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NEW.operation_id='17000000-0000-0000-0000-000000000009'::uuid THEN
  RAISE EXCEPTION 'synthetic receipt failure' USING ERRCODE='23514';
 END IF; RETURN NEW; END $$;
CREATE TRIGGER feedback_receipt_failure AFTER INSERT ON private.mutation_receipts FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_feedback_receipt();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_submit_feedback('17000000-0000-0000-0000-000000000009','{"message":"Rollback feedback"}');
 RAISE EXCEPTION 'ASSERTION: forced failure accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ BEGIN
 BEGIN PERFORM public.ieadpe_submit_feedback(gen_random_uuid(),'{"message":"Anonymous"}');
 RAISE EXCEPTION 'ASSERTION: missing auth accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM public.feedback WHERE message='Rollback feedback'),'receipt failure rolls back feedback');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT FROM private.mutation_receipts WHERE operation_id='17000000-0000-0000-0000-000000000009'),'failed receipt absent');
ROLLBACK;
