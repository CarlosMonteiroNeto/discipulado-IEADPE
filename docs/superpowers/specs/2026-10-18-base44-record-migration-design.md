# Base44 Record Migration — Design Spec

Status: approved for execution by the user's request to export the Base44 records and migrate them into the Supabase-backed IEADPE app. The Base44 app remains the read-only source until reconciliation is complete.

## Goal and source

Import the completed `ieadpe-converts-full-backup` JSON into the empty Supabase project used by the unified Flutter app. Preserve source IDs, congregation relationships, lifecycle history, timestamps, and report rows. Make retries idempotent and keep the source unchanged. Do not create auth users or activate the exported `UserAccess` grants.

The verified export has 24 congregations, 50 converts, 13 events, 10 weekly reports, 30 access rows, and zero feedback rows. Eight event convert IDs do not exist in the export. These events remain queryable history with a null canonical convert UUID and their original Base44 convert ID and name. No person row is fabricated or matched by name.

The target schema requires clean outer whitespace for convert names and landmarks. The export has 27 convert names and 21 landmarks with leading or trailing ASCII spaces. The import trims only those outer spaces (no inner text changes); the original export remains unchanged and retained for exact source comparison.

## Data flow

1. Validate the complete export offline: exact format/version/entity set, unique IDs, field types, and all resolvable congregation references. Do not print or commit any export values.
2. Add additive Supabase migrations that record Base44 source IDs on canonical entities, permit legacy events without a surviving convert, update event read policy to scope by congregation, and create private tables for pending access rows, import receipts, and raw Feedback archival.
3. Generate one SQL transaction from the validated export. Deterministic UUIDs derive from `(base44, entity, source ID)`; a SHA-256 file digest identifies the import. Preserve source timestamps. Set unresolvable auth creator UUIDs to null.
4. Insert congregations, converts, events, weekly reports, and pending access rows in dependency order. Seed weekly guard counters from canonical convert rows. Preserve orphan events with legacy references. Store `UserAccess` only in a private review table; never insert those rows into `public.user_access` or create auth users. Preserve each Feedback object in a private JSON archive because the current export has no Feedback rows and its legacy field contract has not been established.
5. Run the generated transaction first with `ROLLBACK`, assert expected counts and mappings, then run the same SQL with `COMMIT`. Verify target counts, source-key uniqueness, event linkage/orphan counts, weekly reports, pending-grant count, and app visibility under RLS.

## Contracts and safety

- The import is all-or-nothing and may be rerun. A repeated digest is a no-op; different data for an already-used Base44 source key fails instead of overwriting.
- `converts.internal_id` and separate `legacy_base44_id` preserve the original convert key; all target UUIDs are stable across retries.
- Congregation ID references map by the exported Base44 congregation ID, never by name.
- Legacy orphan events are readable only to users with access to their mapped congregation. Existing linked event reads retain the active-parent check.
- Pending access records live in the non-API-exposed `private` schema with no grants. A later human review is required before any are copied into active access.
- Raw Feedback exports are retained as private JSON source records with source IDs and import digest; API roles have no table access. Do not map unverified source fields into the app's feedback workflow.
- Weekly overview reads use active convert rows as the source of truth; guard rows remain mutation counters and are reconciled during import or migration.
- `created_by` cannot be mapped to Supabase Auth identities and stays null. Original creator metadata stays in a private migration audit table and is not treated as an authenticated actor.
- Photos are not downloaded; the export contains no usable photo URLs. Feedback has no source rows.
- Base44 remains available unchanged for rollback and comparison.

## Verification

Use synthetic Python tests for export validation and generated SQL behavior; SQL database tests for null-convert event policy and stable source keys; Flutter tests for parsing and displaying orphan events; and hosted SQL Editor dry run followed by committed import. Reconcile exactly 127 source rows across canonical tables and the private pending-grant table, with 30 grants inactive and 8 events marked unlinked. The original Base44 JSON is excluded from repository files, fixtures, query output, and logs.

## Rollback

Before commit, `ROLLBACK` leaves no data or schema changes. After commit, rollback keeps the Base44 source authoritative and removes only rows bearing the migration's recorded Base44 source keys and digest, after a fresh dependent-row check; never delete rows by name or clear an entire table. No app cutover or Base44 deletion is part of this operation.
