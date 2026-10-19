BEGIN;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('95100000-0000-4000-8000-000000000001','p1-staff@example.test',now());

INSERT INTO public.congregations(id,name) VALUES
 ('95200000-0000-4000-8000-000000000001','P1 Congregation A'),
 ('95200000-0000-4000-8000-000000000002','P1 Congregation B');

INSERT INTO public.converts(
 id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id,
 address,phone,created_by,deleted_at
) VALUES
 ('95300000-0000-4000-8000-000000000001','p1-convert-linked','Canonical From Convert','Landmark A','female','2026-10-01','Sunday',
  '95200000-0000-4000-8000-000000000001','Rua da Aurora','(81) 99999-0001','95100000-0000-4000-8000-000000000001',NULL),
 ('95300000-0000-4000-8000-000000000002','p1-convert-unmatched','Unmatched Convert','Landmark B','male','2026-10-02','Wednesday',
  '95200000-0000-4000-8000-000000000001',NULL,NULL,'95100000-0000-4000-8000-000000000001',NULL),
 ('95300000-0000-4000-8000-000000000003','p1-convert-deleted','Deleted Convert','Landmark C','female','2026-10-03','Sunday',
  '95200000-0000-4000-8000-000000000001',NULL,NULL,'95100000-0000-4000-8000-000000000001',now()),
 ('95300000-0000-4000-8000-000000000004','p1-convert-other-scope','Other Scope Convert','Landmark D','male','2026-10-04','Saturday',
  '95200000-0000-4000-8000-000000000002',NULL,NULL,'95100000-0000-4000-8000-000000000001',NULL);

INSERT INTO public.converts(
 id,internal_id,name,landmark,gender,conversion_date,worship_type,congregation_id,
 created_by,created_at,updated_at
) VALUES (
 '95300000-0000-4000-8000-000000000005','p1-convert-overlong',
 repeat('Overlong Legacy Convert ',10)||'Tail','Landmark E','female','2026-10-05','Sunday',
 '95200000-0000-4000-8000-000000000001','95100000-0000-4000-8000-000000000001',
 '2020-01-02 03:04:05+00','2020-02-03 04:05:06+00');

INSERT INTO public.ministry_students(
 id,congregation_id,name,normalized_name,phone_e164,birth_date,address,education,updated_by,
 convert_id,promoted_at,convert_snapshot
) VALUES
 ('95400000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001',
  'Legacy Student Snapshot','legacy student snapshot','+15555550001','2010-02-28',
  '{"street":"Old Street","district":null,"city":null,"postal_code":null,"state_code":null}',
  'Ensino fundamental','95100000-0000-4000-8000-000000000001',
  '95300000-0000-4000-8000-000000000001','2026-10-05',
  '{"name":"Legacy Student Snapshot","phone":"+15555550001","address":"Old Street"}'),
 ('95400000-0000-4000-8000-000000000002','95200000-0000-4000-8000-000000000001',
  'Unmatched Convert','unmatched convert',NULL,NULL,NULL,NULL,
  '95100000-0000-4000-8000-000000000001',NULL,NULL,NULL),
 ('95400000-0000-4000-8000-000000000003','95200000-0000-4000-8000-000000000001',
  'Other Scope Convert','other scope convert',NULL,NULL,NULL,NULL,
  '95100000-0000-4000-8000-000000000001',
  '95300000-0000-4000-8000-000000000004','2026-10-06',
  '{"name":"Other Scope Convert","phone":null,"address":null}');

INSERT INTO public.ministry_classes(
 id,congregation_id,name,normalized_name,start_date,updated_by
) VALUES(
 '95500000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001',
 'P1 Existing Class','p1 existing class','2026-01-01','95100000-0000-4000-8000-000000000001');
INSERT INTO public.ministry_enrollments(
 id,congregation_id,student_id,class_id,start_date,updated_by
) VALUES(
 '95600000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001',
 '95400000-0000-4000-8000-000000000001','95500000-0000-4000-8000-000000000001',
 '2026-01-01','95100000-0000-4000-8000-000000000001');
COMMIT;
