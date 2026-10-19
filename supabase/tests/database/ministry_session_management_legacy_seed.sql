BEGIN;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('97000000-0000-0000-0000-000000000090','session-legacy@example.test',now());
INSERT INTO public.congregations(id,name) VALUES
 ('97000000-0000-0000-0000-000000000091','Session Legacy');
INSERT INTO public.user_access(user_email,user_id,role,congregation_id) VALUES
 ('session-legacy@example.test','97000000-0000-0000-0000-000000000090','Membro da direção da campanha','97000000-0000-0000-0000-000000000091');
INSERT INTO public.ministry_grants(user_id,congregation_id,role,active) VALUES
 ('97000000-0000-0000-0000-000000000090','97000000-0000-0000-0000-000000000091','ministry_staff',true);
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,end_date,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000092','97000000-0000-0000-0000-000000000091','Legacy class','legacy class','2026-01-01','2026-01-31','97000000-0000-0000-0000-000000000090');
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,status,updated_by) VALUES
 ('97000000-0000-0000-0000-000000000093','97000000-0000-0000-0000-000000000091','97000000-0000-0000-0000-000000000092','2026-02-01','open','97000000-0000-0000-0000-000000000090');
COMMIT;
