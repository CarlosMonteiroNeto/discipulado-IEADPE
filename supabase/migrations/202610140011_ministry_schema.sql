-- Ministry schema budget (planning envelope, not a tier guarantee): up to
-- 100,000 students, 25,000 contacts, 10,000 classes, and 500,000 historical
-- enrollments/sessions/attendance rows; target <= 500 MiB total DB footprint.
-- At 100 ministry users, 20 bounded reads/user/day, 50 rows average, this is
-- about 3 million returned rows/month. Monitor actual DB footprint and egress,
-- and re-evaluate before exceeding either envelope against the selected plan.
-- Shared responsibility: Supabase operates the managed Postgres/Auth platform
-- and infrastructure controls. This application owns RLS/RPC correctness,
-- grant provisioning/revocation, least-privilege testing, backups policy,
-- monitoring, retention, and incident response. No production import occurs here.

CREATE TABLE public.ministry_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 congregation_id uuid REFERENCES public.congregations(id),
 role text NOT NULL CHECK(role IN ('ministry_staff','ministry_supervision')),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((role='ministry_staff' AND congregation_id IS NOT NULL) OR
       (role='ministry_supervision' AND congregation_id IS NULL)),
 UNIQUE NULLS NOT DISTINCT(user_id,role,congregation_id)
);
CREATE INDEX ministry_grants_active_user_scope ON public.ministry_grants(user_id,congregation_id) WHERE active;

CREATE TABLE public.ministry_contacts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 congregation_id uuid REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 name text NOT NULL CHECK(name=btrim(name) AND name<>''),
 normalized_name text NOT NULL CHECK(normalized_name=btrim(normalized_name) AND normalized_name<>''),
 scope text NOT NULL CHECK(scope IN ('congregation','supervision')),
 role_code text CHECK(role_code IS NULL OR role_code IN ('campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary')),
 phone_e164 text CHECK(phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{1,14}$'),
 birth_date date,
 archived_at timestamptz,
 CHECK((scope='congregation')=(congregation_id IS NOT NULL)),
 UNIQUE(id,congregation_id),
 CHECK(role_code IS NULL OR
  (scope='congregation' AND role_code IN ('congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary')) OR
  (scope='supervision' AND role_code IN ('campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary')))
);
CREATE INDEX ministry_contacts_scope_name ON public.ministry_contacts(congregation_id,normalized_name,id) WHERE archived_at IS NULL;
CREATE INDEX ministry_contacts_supervision_name ON public.ministry_contacts(normalized_name,id) WHERE congregation_id IS NULL AND archived_at IS NULL;

CREATE TABLE public.ministry_role_slots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 congregation_id uuid REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 scope text NOT NULL CHECK(scope IN ('congregation','supervision')),
 role_code text NOT NULL CHECK(role_code IN ('campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary','congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary')),
 contact_id uuid, archived_at timestamptz,
 FOREIGN KEY(contact_id,congregation_id) REFERENCES public.ministry_contacts(id,congregation_id),
 UNIQUE(id,congregation_id),
 CHECK((scope='congregation')=(congregation_id IS NOT NULL)),
 CHECK((scope='congregation' AND role_code IN ('congregationAssistant','campaignLeader','campaignDeputyLeader','teacher','discipleshipSecretary','discipleshipDeputySecretary')) OR
       (scope='supervision' AND role_code IN ('campaignSupervisor','campaignDeputy','discipleshipCoordinator','discipleshipDeputy','coordinationSecretary','coordinationDeputySecretary')))
);
CREATE UNIQUE INDEX ministry_role_slots_live_unique ON public.ministry_role_slots(scope,congregation_id,role_code) NULLS NOT DISTINCT WHERE archived_at IS NULL;
CREATE INDEX ministry_role_slots_contact ON public.ministry_role_slots(contact_id) WHERE contact_id IS NOT NULL;

CREATE TABLE public.ministry_students (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 name text NOT NULL CHECK(name=btrim(name) AND name<>''), normalized_name text NOT NULL CHECK(normalized_name=btrim(normalized_name) AND normalized_name<>''),
 phone_e164 text CHECK(phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{1,14}$'), birth_date date,
 address jsonb CHECK(address IS NULL OR (jsonb_typeof(address)='object' AND address-ARRAY['street','district','city','postal_code','state_code']='{}'::jsonb)),
 education text, marital_status text, new_convert boolean, water_baptized boolean, wants_baptism boolean,
 archived_at timestamptz,
 UNIQUE(id,congregation_id),
 CHECK(NOT (water_baptized IS TRUE AND wants_baptism IS TRUE))
);
CREATE INDEX ministry_students_scope_name ON public.ministry_students(congregation_id,normalized_name,id) WHERE archived_at IS NULL;

CREATE TABLE public.ministry_classes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 name text NOT NULL CHECK(name=btrim(name) AND name<>''), normalized_name text NOT NULL CHECK(normalized_name=btrim(normalized_name) AND normalized_name<>''),
 teacher_contact_id uuid, start_date date NOT NULL, end_date date,
 FOREIGN KEY(teacher_contact_id,congregation_id) REFERENCES public.ministry_contacts(id,congregation_id),
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','completed','archived')),
 CHECK(end_date IS NULL OR end_date>=start_date),
 UNIQUE(id,congregation_id)
);
CREATE INDEX ministry_classes_scope_status ON public.ministry_classes(congregation_id,status,normalized_name,id);

CREATE TABLE public.ministry_enrollments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 student_id uuid NOT NULL, class_id uuid NOT NULL,
 FOREIGN KEY(student_id,congregation_id) REFERENCES public.ministry_students(id,congregation_id),
 FOREIGN KEY(class_id,congregation_id) REFERENCES public.ministry_classes(id,congregation_id),
 UNIQUE(id,congregation_id),
 start_date date NOT NULL, end_date date, status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','completed','withdrawn')),
 CHECK(end_date IS NULL OR end_date>=start_date)
);
CREATE UNIQUE INDEX ministry_enrollments_one_active_student ON public.ministry_enrollments(student_id) WHERE status='active';
CREATE INDEX ministry_enrollments_class_history ON public.ministry_enrollments(class_id,id);
CREATE INDEX ministry_enrollments_student_history ON public.ministry_enrollments(student_id,start_date DESC,id);

CREATE TABLE public.ministry_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 class_id uuid NOT NULL, session_date date NOT NULL, topic text,
 FOREIGN KEY(class_id,congregation_id) REFERENCES public.ministry_classes(id,congregation_id),
 UNIQUE(id,congregation_id),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','finalized','canceled')),
 roster_frozen boolean NOT NULL DEFAULT false, lesson_index integer CHECK(lesson_index IS NULL OR lesson_index>=0),
 lesson_part integer CHECK(lesson_part IS NULL OR lesson_part>=0), lesson_finished boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX ministry_sessions_class_date_live ON public.ministry_sessions(class_id,session_date) WHERE status<>'canceled';
CREATE INDEX ministry_sessions_scope_date ON public.ministry_sessions(congregation_id,session_date DESC,id);

CREATE TABLE public.ministry_session_roster (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 session_id uuid NOT NULL, enrollment_id uuid NOT NULL, student_id uuid NOT NULL,
 FOREIGN KEY(session_id,congregation_id) REFERENCES public.ministry_sessions(id,congregation_id),
 FOREIGN KEY(enrollment_id,congregation_id) REFERENCES public.ministry_enrollments(id,congregation_id),
 FOREIGN KEY(student_id,congregation_id) REFERENCES public.ministry_students(id,congregation_id), student_name text NOT NULL CHECK(student_name=btrim(student_name) AND student_name<>''),
 UNIQUE(session_id,enrollment_id)
);
CREATE INDEX ministry_session_roster_session_order ON public.ministry_session_roster(session_id,enrollment_id);

CREATE TABLE public.ministry_attendance (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id), legacy_firebase_id text UNIQUE CHECK(legacy_firebase_id IS NULL OR btrim(legacy_firebase_id)<>''),
 session_id uuid NOT NULL, enrollment_id uuid NOT NULL, student_id uuid NOT NULL,
 FOREIGN KEY(session_id,congregation_id) REFERENCES public.ministry_sessions(id,congregation_id),
 FOREIGN KEY(enrollment_id,congregation_id) REFERENCES public.ministry_enrollments(id,congregation_id),
 FOREIGN KEY(student_id,congregation_id) REFERENCES public.ministry_students(id,congregation_id), status text NOT NULL CHECK(status IN ('present','absent','excused','unmarked')),
 UNIQUE(session_id,enrollment_id)
);
CREATE INDEX ministry_attendance_enrollment_status ON public.ministry_attendance(enrollment_id,status,session_id);
