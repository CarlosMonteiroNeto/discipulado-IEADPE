-- Preserve Base44 source identity and historical events with deleted converts.
ALTER TABLE public.congregations
 ADD COLUMN legacy_base44_id text UNIQUE;
ALTER TABLE public.converts
 ADD COLUMN legacy_base44_id text UNIQUE;
ALTER TABLE public.convert_events
 ADD COLUMN legacy_base44_id text UNIQUE,
 ADD COLUMN legacy_convert_id text,
 ALTER COLUMN convert_id DROP NOT NULL;
ALTER TABLE public.convert_events
 ADD CONSTRAINT convert_events_legacy_target_check
 CHECK (convert_id IS NOT NULL OR (legacy_convert_id IS NOT NULL AND legacy_convert_id<>''));
ALTER TABLE public.weekly_reports
 ADD COLUMN legacy_base44_id text UNIQUE;

DROP POLICY events_scope ON public.convert_events;
CREATE POLICY events_scope ON public.convert_events FOR SELECT TO authenticated
 USING(private.can_access_congregation(congregation_id) AND
  (convert_id IS NULL OR EXISTS(
   SELECT FROM public.converts c WHERE c.id=convert_id AND c.deleted_at IS NULL)));

CREATE TABLE private.base44_user_access_pending (
 legacy_base44_id text PRIMARY KEY,
 user_email text NOT NULL,
 role text NOT NULL CHECK(role IN ('Membro da direção da campanha','Membro da supervisão das campanhas')),
 congregation_id uuid,
 legacy_congregation_id text,
 created_at timestamptz,
 updated_at timestamptz,
 import_digest text NOT NULL
);

CREATE TABLE private.base44_source_metadata (
 entity_name text NOT NULL,
 legacy_base44_id text NOT NULL,
 created_by_id text,
 created_by text,
 is_sample boolean,
 source_created_date text,
 source_updated_date text,
 import_digest text NOT NULL,
 PRIMARY KEY(entity_name,legacy_base44_id)
);

CREATE TABLE private.base44_migration_imports (
 source text NOT NULL CHECK(source='base44'),
 export_digest text NOT NULL,
 record_counts jsonb NOT NULL,
 imported_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(source,export_digest)
);
ALTER TABLE private.base44_user_access_pending ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.base44_source_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.base44_migration_imports ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION private.base44_stable_uuid(entity_name text, source_id text)
RETURNS uuid LANGUAGE sql IMMUTABLE STRICT SET search_path='' AS $$
 SELECT (substr(md5('base44:'||entity_name||':'||source_id),1,8)||'-'||
         substr(md5('base44:'||entity_name||':'||source_id),9,4)||'-'||
         substr(md5('base44:'||entity_name||':'||source_id),13,4)||'-'||
         substr(md5('base44:'||entity_name||':'||source_id),17,4)||'-'||
         substr(md5('base44:'||entity_name||':'||source_id),21,12))::uuid
$$;
REVOKE ALL ON FUNCTION private.base44_stable_uuid(text,text) FROM PUBLIC,anon,authenticated;

-- private schema has no PostgREST exposure; keep migration-only personal data inaccessible
-- to app roles, including service-role API clients.
REVOKE ALL ON private.base44_user_access_pending,
 private.base44_source_metadata,private.base44_migration_imports
 FROM PUBLIC,anon,authenticated,service_role;
