CREATE TABLE public.congregations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(name=btrim(name) AND name<>''),
 archived_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.user_access (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_email text NOT NULL CHECK(user_email=lower(btrim(user_email)) AND user_email LIKE '%@%'),
 user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 role text NOT NULL CHECK(role IN ('Membro da direção da campanha','Membro da supervisão das campanhas')),
 congregation_id uuid REFERENCES public.congregations(id),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK ((role='Membro da direção da campanha' AND congregation_id IS NOT NULL) OR
        (role='Membro da supervisão das campanhas' AND congregation_id IS NULL)),
 UNIQUE NULLS NOT DISTINCT(user_email,role,congregation_id)
);
CREATE INDEX user_access_user_scope ON public.user_access(user_id,congregation_id);
CREATE TABLE public.converts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), internal_id text NOT NULL UNIQUE CHECK(btrim(internal_id)<>''),
 name text NOT NULL CHECK(name=btrim(name) AND name<>''),
 landmark text NOT NULL CHECK(landmark=btrim(landmark) AND landmark<>''),
 gender text NOT NULL CHECK(gender IN ('male','female')),
 conversion_date date NOT NULL CHECK(conversion_date <= (now() AT TIME ZONE 'America/Sao_Paulo')::date),
 worship_type text NOT NULL CHECK(worship_type=btrim(worship_type) AND worship_type<>''),
 congregation_id uuid REFERENCES public.congregations(id), photo_url text, photo_asset_id uuid,
 address text, phone text, age integer CHECK(age BETWEEN 0 AND 150),
 last_visit_date date, was_visited_once boolean NOT NULL DEFAULT false,
 visit_count integer NOT NULL DEFAULT 0 CHECK(visit_count>=0),
 is_in_discipleship boolean NOT NULL DEFAULT false, discipleship_start_date date,
 is_discipleship_completed boolean NOT NULL DEFAULT false, is_deviated boolean NOT NULL DEFAULT false,
 created_by uuid REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE INDEX converts_scope_date ON public.converts(congregation_id,conversion_date DESC,id) WHERE deleted_at IS NULL;
CREATE INDEX converts_name_lower ON public.converts(lower(name));
CREATE TABLE public.convert_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), convert_id uuid NOT NULL REFERENCES public.converts(id),
 convert_name text, congregation_id uuid REFERENCES public.congregations(id),
 event_type text NOT NULL CHECK(event_type IN ('visit','discipleship_started','discipleship_completed','deviated')),
 event_date date NOT NULL, done_by_email text, created_by uuid REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX events_scope_date ON public.convert_events(congregation_id,event_date DESC,id);
CREATE TABLE public.weekly_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), congregation_id uuid NOT NULL REFERENCES public.congregations(id),
 week_start date NOT NULL CHECK(extract(isodow FROM week_start)=1),
 confirmed_by_email text NOT NULL, confirmed_by_name text,
 created_by uuid REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(congregation_id,week_start)
);
CREATE TABLE public.feedback (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_email text, user_name text,
 message text NOT NULL CHECK(message=btrim(message) AND length(message) BETWEEN 1 AND 5000),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','read','resolved')),
 created_by uuid REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.photo_assets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL REFERENCES auth.users(id),
 path text NOT NULL UNIQUE, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','attached','detached')),
 convert_id uuid REFERENCES public.converts(id), expires_at timestamptz NOT NULL DEFAULT now()+interval '1 hour',
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.converts ADD CONSTRAINT converts_photo_asset_fk FOREIGN KEY(photo_asset_id) REFERENCES public.photo_assets(id);
CREATE TABLE private.congregation_week_guards (
 congregation_id uuid NOT NULL REFERENCES public.congregations(id), week_start date NOT NULL,
 conversion_count integer NOT NULL DEFAULT 0 CHECK(conversion_count>=0), PRIMARY KEY(congregation_id,week_start)
);
ALTER TABLE private.congregation_week_guards ENABLE ROW LEVEL SECURITY;
-- Supabase-managed Storage enables RLS on storage.objects; the project owner
-- cannot alter that managed table's RLS flag on hosted projects.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['congregations','user_access','converts','convert_events','weekly_reports','feedback','photo_assets'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 END LOOP;
END $$;
REVOKE ALL ON public.profiles,public.congregations,public.user_access,public.converts,
 public.convert_events,public.weekly_reports,public.feedback,public.photo_assets FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.profiles,public.congregations,public.user_access,public.converts,
 public.convert_events,public.weekly_reports,public.feedback,public.photo_assets TO authenticated;
