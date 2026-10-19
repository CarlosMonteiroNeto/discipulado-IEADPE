BEGIN;
SET LOCAL TIME ZONE 'Pacific/Kiritimati';
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES ('60000000-0000-0000-0000-000000000001','lifecycle@example.test',now());
INSERT INTO private.admin_allowlist VALUES ('60000000-0000-0000-0000-000000000001');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type)
VALUES ('60000000-0000-0000-0000-000000000002','lifecycle','Synthetic','Square','male',private.business_today()-100,'Synthetic');
SELECT set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_transition_convert('60000000-0000-0000-0000-000000000003','{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}');
SELECT pg_temp.assert_true((SELECT visit_count=1 AND was_visited_once AND last_visit_date=(now() AT TIME ZONE 'America/Sao_Paulo')::date FROM public.converts),'visit increments once using server date');
-- Canonical retries survive state changes, but fresh visits cannot bypass due dates.
SELECT public.ieadpe_transition_convert('60000000-0000-0000-0000-000000000003','{"action":"visit","id":"60000000-0000-0000-0000-000000000002"}');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.convert_events),'retry emits one event');
CREATE FUNCTION pg_temp.reject_transition(body jsonb,expected text,op uuid DEFAULT gen_random_uuid()) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN PERFORM public.ieadpe_transition_convert(op,body);
  RAISE EXCEPTION 'ASSERTION: transition unexpectedly accepted: %',body;
 EXCEPTION WHEN SQLSTATE '22023' OR SQLSTATE '42501' THEN
  IF SQLERRM<>expected THEN RAISE EXCEPTION 'ASSERTION: expected %, got %',expected,SQLERRM; END IF;
 END;
END $$;
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}','visit_not_due');
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"stop"}','discipleship_inactive');
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"complete"}','completion_not_due');
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"deviate"}','insufficient_visits');
DO $$ DECLARE field text; BEGIN
 FOREACH field IN ARRAY ARRAY['created_by','done_by_email','created_at','event_date','visit_count','last_visit_date','discipleship_start_date','event_type'] LOOP
  PERFORM pg_temp.reject_transition(jsonb_build_object('id','60000000-0000-0000-0000-000000000002','action','visit',field,'spoof'),'invalid_payload');
 END LOOP;
END $$;
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"start"}','operation_conflict','60000000-0000-0000-0000-000000000003');
SELECT public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"start"}');
SELECT pg_temp.assert_true((SELECT is_in_discipleship AND discipleship_start_date=(now() AT TIME ZONE 'America/Sao_Paulo')::date FROM public.converts),'start uses server business date');
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"start"}','discipleship_active');
SELECT public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"stop"}');
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.convert_events),'stop creates no event');
SELECT public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"start"}');
RESET ROLE;
-- Exercise exact policy boundaries on synthetic historical data.
DO $$ DECLARE active boolean; visited boolean; days integer; threshold integer; start_date date; BEGIN
 FOR active IN SELECT unnest(ARRAY[false,true]) LOOP
  FOR visited IN SELECT unnest(ARRAY[false,true]) LOOP
   threshold:=CASE WHEN NOT visited THEN 1 WHEN active THEN 30 ELSE 7 END;
   FOR days IN threshold-1..threshold LOOP
    UPDATE public.converts SET was_visited_once=visited,is_in_discipleship=active,
     last_visit_date=CASE WHEN visited THEN private.business_today()-days ELSE NULL END,
     conversion_date=CASE WHEN visited THEN conversion_date ELSE private.business_today()-days END;
    IF days<threshold THEN
     PERFORM pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}','visit_not_due');
    ELSE
     PERFORM public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}');
    END IF;
   END LOOP;
  END LOOP;
 END LOOP;
 UPDATE public.converts SET was_visited_once=false,last_visit_date=NULL,conversion_date=private.business_today()-1;
 PERFORM public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}');
 FOR start_date IN SELECT unnest(ARRAY[NULL::date,private.business_today()-89,private.business_today()+1]) LOOP
  UPDATE public.converts SET is_in_discipleship=true,discipleship_start_date=start_date;
  PERFORM pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"complete"}','completion_not_due');
 END LOOP;
 UPDATE public.converts SET is_in_discipleship=false,discipleship_start_date=private.business_today()-100;
 PERFORM pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"complete"}','completion_not_due');
 UPDATE public.converts SET is_in_discipleship=true,discipleship_start_date=private.business_today()-90;
END $$;
-- Failure of either dependent insert must roll back the state and other insert.
CREATE FUNCTION pg_temp.fail_lifecycle_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'synthetic_insert_failure' USING ERRCODE='23514'; END $$;
DO $$ DECLARE table_name text; before_row jsonb; receipt_count integer; event_count integer; BEGIN
 FOREACH table_name IN ARRAY ARRAY['public.convert_events','private.mutation_receipts'] LOOP
  SELECT to_jsonb(c) INTO before_row FROM public.converts c;
  SELECT count(*) INTO receipt_count FROM private.mutation_receipts;
  SELECT count(*) INTO event_count FROM public.convert_events;
  EXECUTE format('CREATE TRIGGER synthetic_insert_failure BEFORE INSERT ON %s FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_lifecycle_insert()',table_name);
  BEGIN
   PERFORM public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"complete"}');
   RAISE EXCEPTION 'ASSERTION: injected insert failure did not propagate';
  EXCEPTION WHEN check_violation THEN
   IF SQLERRM<>'synthetic_insert_failure' THEN RAISE; END IF;
  END;
  PERFORM pg_temp.assert_true((SELECT to_jsonb(c)=before_row FROM public.converts c),'dependent failure rolls back convert');
  PERFORM pg_temp.assert_true((SELECT count(*)=receipt_count FROM private.mutation_receipts),'dependent failure rolls back receipt');
  PERFORM pg_temp.assert_true((SELECT count(*)=event_count FROM public.convert_events),'dependent failure rolls back event');
  EXECUTE format('DROP TRIGGER synthetic_insert_failure ON %s',table_name);
 END LOOP;
END $$;
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_transition_convert('60000000-0000-0000-0000-000000000004','{"id":"60000000-0000-0000-0000-000000000002","action":"complete"}');
SELECT public.ieadpe_transition_convert('60000000-0000-0000-0000-000000000004','{"action":"complete","id":"60000000-0000-0000-0000-000000000002"}');
SELECT pg_temp.assert_true((SELECT is_discipleship_completed AND NOT is_in_discipleship AND NOT is_deviated FROM public.converts),'completion at 90 calendar dates is terminal');
DO $$ DECLARE action text; BEGIN
 FOREACH action IN ARRAY ARRAY['visit','start','stop','complete','deviate'] LOOP
  PERFORM pg_temp.reject_transition(jsonb_build_object('id','60000000-0000-0000-0000-000000000002','action',action),'convert_terminal');
 END LOOP;
 BEGIN UPDATE public.convert_events SET convert_name='Tampered';
  RAISE EXCEPTION 'ASSERTION: event snapshot mutable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.converts SET name='Renamed',is_discipleship_completed=false,is_in_discipleship=true,visit_count=3;
SET LOCAL ROLE authenticated;
SELECT public.ieadpe_transition_convert(gen_random_uuid(),'{"id":"60000000-0000-0000-0000-000000000002","action":"deviate"}');
SELECT pg_temp.assert_true((SELECT is_deviated AND NOT is_in_discipleship FROM public.converts),'deviation at three visits terminates active discipleship');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.convert_events WHERE event_type='discipleship_completed' AND convert_name='Synthetic'),'completion snapshot survives rename and retry');
SELECT pg_temp.assert_true((SELECT bool_and(created_by='60000000-0000-0000-0000-000000000001' AND done_by_email='lifecycle@example.test' AND event_date=(now() AT TIME ZONE 'America/Sao_Paulo')::date AND created_at=now()) FROM public.convert_events),'event metadata derives from server actor and clock');
RESET ROLE;
UPDATE public.converts SET is_deviated=false,deleted_at=now();
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"start"}','convert_terminal');
DELETE FROM private.admin_allowlist;
SET LOCAL ROLE authenticated;
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}','forbidden','60000000-0000-0000-0000-000000000003');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*)=11 FROM private.mutation_receipts),'only successful mutations leave receipts');
SELECT set_config('request.jwt.claim.sub','',true);
SELECT pg_temp.reject_transition('{"id":"60000000-0000-0000-0000-000000000002","action":"visit"}','unauthorized');
ROLLBACK;
