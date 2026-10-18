BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION: %',label; END IF; END $$;
SELECT pg_temp.assert_true(NOT has_table_privilege('anon','private.base44_feedback_archive','SELECT')
 AND NOT has_table_privilege('authenticated','private.base44_feedback_archive','SELECT')
 AND NOT has_table_privilege('service_role','private.base44_feedback_archive','SELECT'),
 'raw archived feedback is unavailable to API roles');
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('18000000-0000-0000-0000-000000000001','history-direction@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('18000000-0000-0000-0000-000000000002','History A'),
 ('18000000-0000-0000-0000-000000000003','History B');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('history-direction@example.test','18000000-0000-0000-0000-000000000001',
  'Membro da direção da campanha','18000000-0000-0000-0000-000000000002');
INSERT INTO public.converts(id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id)
 VALUES('18000000-0000-0000-0000-000000000004','history-convert','Synthetic','Square','female','2020-01-01','Oração',
 '18000000-0000-0000-0000-000000000002');
INSERT INTO public.convert_events(id,convert_id,congregation_id,event_type,event_date)
 VALUES('18000000-0000-0000-0000-000000000005','18000000-0000-0000-0000-000000000004',
  '18000000-0000-0000-0000-000000000002','visit','2020-01-02');
INSERT INTO public.convert_events(id,legacy_base44_id,legacy_convert_id,convert_name,congregation_id,event_type,event_date)
 VALUES('18000000-0000-0000-0000-000000000006','base44-event','deleted-base44-convert','Historical name',
  '18000000-0000-0000-0000-000000000002','visit','2020-01-03');
INSERT INTO public.convert_events(id,legacy_base44_id,legacy_convert_id,convert_name,congregation_id,event_type,event_date)
 VALUES('18000000-0000-0000-0000-000000000007','base44-event-b','deleted-base44-convert-b','Historical name B',
  '18000000-0000-0000-0000-000000000003','visit','2020-01-04');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','18000000-0000-0000-0000-000000000001',true);
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM public.convert_events),
 'congregation member sees linked and legacy orphan events');
SELECT pg_temp.assert_true((SELECT convert_id IS NULL AND legacy_convert_id='deleted-base44-convert'
 FROM public.convert_events WHERE id='18000000-0000-0000-0000-000000000006'),
 'legacy event keeps the original reference without an invented convert');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.convert_events WHERE id='18000000-0000-0000-0000-000000000007'),
 'congregation member cannot read a specific event from another congregation');
ROLLBACK;
