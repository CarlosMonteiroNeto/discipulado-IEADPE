# IEADPE Flutter + Supabase Free Design

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](2026-10-20-ministry-corrective-release-design.md), [current plan](../plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

Status: accepted backend direction; implementation pending. Supersedes the Firebase Spark baseline and all earlier backend drafts. The captured React/Vite JavaScript/JSX app is the behavior reference; Flutter is a rewrite, not an embedded React shell.

## Global Constraints

- Flutter web and Android; app UI is pt-BR; communication, comments and artifacts are English.
- Supabase Free only; no billing activation, paid add-ons or mandatory Edge Functions.
- Google OAuth is the baseline login; email/password and SMS are deferred.
- Every SDD role uses gpt-6.1-sol with low reasoning effort; no automatic escalation.
- PostgreSQL RLS and authorized transactional RPCs enforce access and business invariants.
- Preserve all 101 captured source files unchanged; use synthetic local development data.
- Production deployment, live access grants and private-record migration are separate release actions.

## Evidence and scope

At discovery, the workspace contained documentation and a complete 101-file source capture. The migration branch now contains a generated Flutter scaffold and local Git history; product implementation and parity remain to be completed. Capture paths and SHA-256 hashes are in reference/base44/manifest.json. Six entity schemas and 179 internal imports were inspected. Production data has not been exported; never place personal records in fixtures, logs or briefs.

Deliver registration/editing, shared photos, scoped convert lists, visits, discipleship, Home, weekly reports, congregation/access management, conversion charts, event history, XLSX import/export and feedback. Preserve five Admin tabs (Congregações, Acessos, Relatório, Eventos, Backup); expose feedback management through an Admin action. Base44 OAuthConsent is platform-specific and is replaced by the normal Supabase Google callback.

## Architecture and dependencies

Flutter Material 3 with Riverpod, go_router and feature repositories. Use supabase_flutter for Auth, PostgREST RPC and private Storage. SQL migrations own schema, grants, RLS, triggers and business functions. No TypeScript server or Edge Function is required for this release. Keep domain policies pure Dart for UI explanation; SQL is authoritative.

Use intl/timezone, image/image_picker, file_picker, archive/xml, file_saver, url_launcher and uuid where needed. Resolve supported versions once during bootstrap, record rationale and commit pubspec.lock. Web and Android must share domain logic and repository contracts; isolate platform file/auth adapters. Local backend verification uses Supabase CLI + Docker, pgTAP and synthetic accounts. Stop on missing local backend rather than using production as a fallback.

## Data model and authorization

PostgreSQL dates represent business dates; timestamptz represents server instants. Calculate today and Monday–Sunday periods using America/Sao_Paulo. Dart serializes date-only values as yyyy-MM-dd without converting through UTC midnight.

Public tables: profiles, congregations, converts, convert_events, user_access, weekly_reports, feedback and photo_assets. Private tables: admin_allowlist, mutation_receipts, congregation_week_guards and access_versions. Use UUID primary keys; converts.internal_id is a separate unique text key preserving legacy Base44 IDs and new UUID strings. Never cast legacy IDs to UUID. Soft deletion retains this unique key and history; archive referenced congregations rather than orphaning records.

Preserve fields from all six source schemas, with explicit SQL-to-Dart mappings. Convert fields include optional congregation/photo/address/phone/age, required name/landmark/gender/conversion_date/worship_type, last_visit_date, was_visited_once, visit_count, is_in_discipleship, discipleship_start_date, is_discipleship_completed and is_deviated. Additional server metadata includes creator, timestamps and deleted_at. Validate age 0..150, trimmed required text and conversion_date <= business today. Preserve all 64 worship choices from src/utils/worshipTypes.js.

Roles: authenticated without grants may register and submit feedback but may not list converts. Direction corresponds to “Membro da direção da campanha” and reads/mutates assigned congregations; multiple grants are allowed. Supervision corresponds to “Membro da supervisão das campanhas” and has global management access. Admin is a trusted allowlisted UID provisioned outside the client. Registration without congregation remains allowed; only global managers can later access unassigned records. Direction can register for any active congregation, matching the public registration workflow; editing existing records requires access to both old and new scope.

Bind grants to verified auth.users identities. Pending normalized-email grants may be created by global managers and bound only after matching a verified email; never use editable user_metadata for roles. Profiles may consume Google display name/avatar only. Archive/delete access is a manager RPC, not a public table write. Admin allowlist has no client mutation endpoint.

Enable RLS on every exposed table and storage.objects; revoke direct business writes. Private helpers avoid recursive policies. SECURITY DEFINER functions use an empty search_path, schema-qualified objects, auth.uid() checks and explicit EXECUTE grants (revoke PUBLIC/anon). Flutter receives only the publishable key; service-role keys and Google secrets never enter the client or repository. Access is checked against current database grants, not cached JWT roles. Refresh scope on resume and clear protected caches after logout/revocation.

## Atomic commands and concurrency

Expose rpc(command text, operation_id uuid, payload jsonb) through one Dart gateway; SQL entry points are named ieadpe_<command>(operation_id uuid, payload jsonb) returning jsonb. Each validates a strict command payload and returns only permitted fields. Receipt key is (actor_uid, operation_id); store canonical payload hash and minimal result. Same operation/payload returns its original result; changed payload with the same ID is rejected. Client retains operation IDs across retries.

Create, edit, delete, lifecycle and import mutations are transactional with receipt, event and week updates. Lock access_versions rows for actor and affected bound users in sorted UID order before authorization; grant mutation uses the same lock order so revocation and writes serialize. Then lock convert/photo rows deterministically, then week guard rows sorted by congregation/date. Database unique constraints settle competing imports. Retry only transient serialization/deadlock failures with the same operation ID, at most three attempts.

Each congregation-week guard stores conversion count. Every create/move/date edit/delete/import updates affected guards; create guards before locking in deterministic order. Confirm-zero locks the same guard and succeeds only with count zero. A conversion in that week removes the zero report in the same transaction. Reject client actor/time/event/counter overrides. Receipts for registrars expose created ID only, not a newly readable personal record.

## Business behavior

Lifecycle uses last_visit_date, falling back to conversion_date. Visit due: never visited >=1 day; previously visited outside discipleship >=7 days; in discipleship >=30 days. Red “Visita Urgente” means due and outside discipleship; green “Em dia” means not due and in discipleship; otherwise yellow “Atenção”. Overdue discipleship is yellow. Visit is allowed only when due, increments count and writes visit event. Start/restart sets today and writes discipleship_started; stop clears active discipleship without inventing an event. Completion requires active discipleship, a known start and >=90 days; writes discipleship_completed. Deviation requires >=3 visits and writes deviated. Terminal records leave active lists and reject further lifecycle actions. Deleted records leave all summaries; source Home totals otherwise include terminal records.

Weekly period is Monday through most recent Sunday, visible from Sunday 20:00 Sao Paulo. Direction confirms its own congregation; global managers see all zero-conversion congregations with confirmation status. Server time controls eligibility and week calculation.

Name search is case-insensitive substring. Filters cover source congregation/status choices. Congregations containing sede sort first, then pt-BR alphabetical; unknown congregation sorts last. Home recent conversions show last seven days, latest five. WhatsApp uses digits and Brazil prefix 55 unless present; empty/invalid phones disable the action. Registration keeps phone and congregation optional with the source orange missing-data cue.

UI follows source navy #1e3a5f to blue #2563eb header, church branding, desktop navigation, mobile sheet/bottom navigation, floating feedback, content width 896 and form width 512; responsive breakpoint 768. Port loading, empty, permission, cancellation and recoverable failure states with pt-BR copy. Avoid accidental double submissions and stale-role screens.

## Shared photos

Private convert-photos bucket, JPEG only, maximum 1 MiB per object. Client center-crops to 192x192 and encodes JPEG. create_photo_draft creates an owned pending asset with one-hour expiry and path <uid>/<photoId>.jpg. Storage INSERT policy permits only that exact pending path, with no upsert. Attach through create/edit RPC only after validating ownership, pending state and object presence; cross-user attachment is forbidden. Image dimensions are client processing, not a server guarantee.

Pending assets are readable by their owner; attached photos require access to the associated non-deleted convert, including after uploader access is revoked. Download authenticated bytes and render from memory; no public bucket or persistent signed URLs. Replacement failures preserve the old image. Storage upload and SQL cannot share one transaction: draft/upload/attach handles partial failure. Detached/expired files require an explicit maintenance command using the Storage API, followed by metadata cleanup; never delete storage.objects directly. Automatic cron cleanup is deferred and manual cleanup is documented.

## Reports, backup and feedback

Event types remain visit, discipleship_started, discipleship_completed and deviated. Preserve convert-name snapshot, congregation, business event date, server actor email and instant. History is immutable and source tables paginate beyond 1,000 records. Event report applies inclusive optional dates only after Aplicar; supports congregation filter and pt-BR column sorting. XLSX exports exactly the filtered/sorted rows with columns Convertido, Congregação, Evento, Data do Evento, Registrado por. Conversion report uses inclusive conversion dates, worship grouping (Não informado fallback), descending count, chart and Tipo de Culto/Conversões export.

Backup sheet Convertidos retains columns id_interno,nome,congregacao,endereco,ponto_referencia,telefone,idade,genero,data_conversao,tipo_culto,visitas,em_discipulado,discipulado_concluido,se_desviou. Version 2 adds data_ultima_visita,data_inicio_discipulado,visitado_ao_menos_uma_vez plus version metadata. Preserve age zero, source gender labels and Sim/Não. Old visit dates fall back to conversion; missing discipleship start remains null and cannot bypass completion eligibility. XLSX contains no binary photos and is not a full backend backup.

Global managers import validated rows through the same creation invariants, preserving internal_id and historical state without inventing past events. Existing IDs, tombstones and repeated in-file IDs are skipped; absent/invalid IDs are errors. Unknown congregation maps to null with warning, ambiguous names are errors. Each row commits independently; interrupted imports resume using stable operation IDs and report counts without personal data logs. Reject formulas, malformed archives, files above 10 MiB compressed/50 MiB expanded or 10,000 rows. Export user text as string cells. Binary .xls is deferred with an explicit pt-BR message. Web/Android save adapters must report actual saved/cancelled/failed results and place files where the user can retrieve them.

Any authenticated user submits trimmed feedback up to 5,000 characters; server derives identity. Global managers list and update pending/read/resolved states. Preserve five tabs and provide a separate feedback-management action.

## Free tier and release boundaries

Design budgets: 500 MB database, 1 GB file storage, 50,000 monthly active users, 5 GB egress plus the separately listed cached allowance. These are ceilings, not a promise that every production workload fits. Monitor dashboard usage; photos and report downloads consume bandwidth. Use 100-row pagination, scoped reads, bounded image caching and no constant full-table subscriptions. Free projects may pause after a week of inactivity; display a recoverable unavailable state and document manual resume. No fake keep-alive workaround. Free has no managed automatic backups/PITR: document manual database export and separate Storage download procedures; application XLSX alone is insufficient.

Supabase does not host the Flutter website. Prepare build/web for separate static hosting, provisionally Cloudflare Pages Free (no Workers/Functions/R2). Verify its per-file limits before deployment; Android installation/release signing is separate. Register exact production/local redirect URLs and Android deep link with PKCE, request only openid/email/profile, and test cancelled login and revoked accounts. No paid Google API is required for basic Google login. No remote resources, production imports or signing credentials are created by the local implementation plan.

## Official references checked during planning

- [Free limits](https://supabase.com/pricing)
- [Google login](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Database functions](https://supabase.com/docs/guides/database/functions)
- [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Storage access](https://supabase.com/docs/guides/storage/security/access-control)
- [Local development](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Static hosting limits](https://developers.cloudflare.com/pages/platform/limits/)

## Pipeline UI requirements

Apply the installed apple-design principles while preserving source branding: immediate press feedback, readable system typography, text scaling to 200%, keyboard/focus access, spatially consistent reversible panels and no input lock during decorative transitions. Prefer standard Flutter scroll/sheet physics; custom motion must be interruptible. Respect MediaQuery.disableAnimations with a non-spatial transition and preserve layout at 360px. Never obscure pt-BR content with gratuitous blur or motion.

## Local verification profiles

This Windows host has no Docker/WSL service. Use a portable PostgreSQL 17 instance bound to loopback for actual migration, transaction and RLS tests. The test fixture must provide only the Supabase auth/storage schema contracts needed by migrations, including auth.uid()/auth.jwt() and roles; never claim this verifies the Auth or Storage HTTP service. scripts/test_database.py owns isolated databases and runs SQL assertions with ON_ERROR_STOP; Dart database test wrappers surface failures to the Flutter gate. Use IEADPE_PG_BIN for the supervisor-installed binaries. No database fixture may contact production or silently skip when PostgreSQL is missing. Keep SQL assertion scenarios compatible with the full Supabase CLI profile for later service integration.

Google OAuth provider setup, Storage HTTP enforcement and real-device file retrieval require explicit integration evidence in the final report. Distinguish implemented code, unit/SQL checks and unrun service/device checks. No mocked test proves a live service.

Native test server: IEADPE_DATABASE_URL=postgresql://postgres@127.0.0.1:54329/postgres (disposable local trust-auth instance, loopback only). Test harness creates isolated databases, executes migrations and assertion SQL, then drops only its own databases. Plain PostgreSQL DO/RAISE assertions are acceptable in the native profile; do not fake a pgTAP implementation. Preserve full-stack integration instructions separately.

## Runtime transport boundary

The script pipeline uses the exact requested model and effort with native tools in a read-only sandbox. Attempt-bound MCP capabilities enforce declared file writes and closed scoped checks independently of local hook coverage. The source capture, pipeline control files, runtime tooling and dependency manifests remain protected. Workers may read project code and documentation to inspect predecessor interfaces. Script CEO retains dispatch, authoritative gates, ledger, commits and independent review. Tests execute project code and are not an OS sandbox against arbitrary authored test code; candidate and scope checks remain mandatory.

## Execution workflow update — 2026-10-15

The user required fallback to standard Superpowers after any additional custom pipeline issue. That condition occurred. Standard Superpowers SDD now supersedes the Runtime transport boundary section for this implementation: use native subagents, direct workspace tools, TDD, independent task reviews and final branch review, all pinned to gpt-6.1-sol/low. The accepted product requirements and local verification profiles remain binding. Custom pipeline repair is suspended and its unfinished source is preserved separately.
