CREATE SCHEMA private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
CREATE TABLE public.profiles (
 id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 display_name text, avatar_url text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE private.admin_allowlist (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE TABLE private.access_versions (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 version bigint NOT NULL DEFAULT 0
);
CREATE TABLE private.mutation_receipts (
 actor_uid uuid NOT NULL REFERENCES auth.users(id), operation_id uuid NOT NULL,
 command text NOT NULL, payload_hash text NOT NULL, result jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(actor_uid,operation_id)
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.admin_allowlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.access_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.mutation_receipts ENABLE ROW LEVEL SECURITY;
-- Bootstrap is an operator action using a verified UID, never email/user_metadata:
-- INSERT INTO private.admin_allowlist(user_id)
-- SELECT id FROM auth.users WHERE id = '<verified-operator-uid>'::uuid
-- AND email_confirmed_at IS NOT NULL;
-- Remove with DELETE using that UID. Never expose an allowlist RPC to clients.
