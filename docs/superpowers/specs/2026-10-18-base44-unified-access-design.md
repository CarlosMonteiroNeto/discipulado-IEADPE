# Base44 Unified Access Design

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](2026-10-20-ministry-corrective-release-design.md), [current plan](../plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

Date: 2026-10-18
Status: User-confirmed policy; implementation pending.

## Goal and authority

Use access assignments imported from Base44 and activated in `public.user_access` as the shared permission source for converts and ministry. `private.base44_user_access_pending` is audit only. The operations record reports 30 imported assignments (28 direction, 2 supervision); these are historical reconciliation counts, not a new hosted verification or a hard-coded authorization condition.

| Identity | Effective ministry access |
| --- | --- |
| UID in `private.admin_allowlist` | Global, even without a user_access row |
| `Membro da supervisão das campanhas` in user_access | Global |
| `Membro da direção da campanha` in user_access | Its assigned active congregation(s) only |
| Only ministry_grants or private pending audit rows | None |
| Anonymous/unbound identity | None until the existing verified-email binding succeeds |

Multiple direction assignments form a union. Global authority wins over scoped assignments. Existing `ministry_grants` rows may remain, but their presence, role, active flag, insertion, update or deletion cannot grant or revoke effective access. Do not synthesize user_access assignments from ministry_grants.

## Investigation and extension points

Repository/worktree: `ieadpe-supabase-pipeline/App discipulado`, branch `implementation/supabase-free`; baseline documentation commit `705b27f`. Existing unrelated edits are outside this change.

- `202610140003_access.sql`: `private.is_global_manager()` already recognizes allowlisted UIDs and Base44 supervision; `private.can_access_congregation(uuid)` recognizes Base44 direction assignments. `private.change_access` owns assignment edits and access-version serialization.
- `202610140012_ministry_access.sql`: `private.ministry_supervisor()` and `private.ministry_can_access(uuid)` currently authorize from ministry_grants. All ministry table read policies use these helpers; table privileges remain closed to clients and bounded RPCs perform reads.
- `202610140017_unified_scope.sql`: `public.ieadpe_get_scope()` keeps campaign and ministry authority separate, deriving ministry IDs from ministry_grants.
- `202610140018_ministry_congregation_directory.sql`: `public.ieadpe_ministry_list_congregations(jsonb)` has a direct ministry_grants eligibility precheck, independently of its helper-filtered result rows.
- `lib/features/auth/auth_repository.dart`, `lib/domain/models.dart`, `lib/routing/router.dart`, `lib/app.dart`, and `lib/widgets/app_shell.dart` already consume the five scope fields. `hasMinistryAccess` exposes ministry routes; `isGlobalManager` governs `/admin`.
- SQL scenarios and three ministry concurrency fixture scripts seed ministry_grants. `ministry_registry_test.sql` tests revocation/replay by toggling its active flag; that assertion must move to the active authority rather than be removed.

Cause: independent authorization sources and a directory precheck, not missing imported assignments or a Flutter-only routing defect.

## Server design

Add one forward migration, `supabase/migrations/202610180003_base44_unified_access.sql`; do not rewrite historical migrations.

Keep signatures, SECURITY DEFINER, empty search_path, function grants, RLS policies, table privilege restrictions, payload validation, pagination, cursor binding, access locks and mutation replay ordering intact.

`private.ministry_supervisor() RETURNS boolean` delegates to `private.is_global_manager()`. `private.ministry_can_access(scope_id uuid) RETURNS boolean` requires authenticated UID and non-null scope_id, then allows global managers or `private.can_access_congregation(scope_id)` for an existing non-archived congregation. This retains staff archive restrictions and global historical access. Do not change the campaign helper's existing null/archive semantics.

Replace the directory eligibility precheck with global authority or existence of at least one non-archived congregation accepted by ministry_can_access. Keep its active-only result filter and 1–100 limit contract. An account with no effective active scope receives `42501`; a global account with no active congregations receives an empty page.

Preserve `ieadpe_get_scope()` JSON fields and types:

- `is_admin`: allowlist membership boolean.
- `is_supervision`: Base44 supervision boolean.
- `congregation_ids`: existing sorted distinct campaign direction UUID strings.
- `ministry_supervision`: ministry_supervisor boolean (thus true for technical admins too).
- `ministry_congregation_ids`: sorted distinct assigned non-archived direction congregation UUID strings; empty array without scoped assignments, including globals without direction assignments.

Preserve verified-email lookup from auth.users.email_confirmed_at, normalization, binding only unbound matching user_access rows, advisory mutex 711039001, email mutex, sorted UID access locks and conditional version increment. Editable metadata/JWT email cannot grant access. Revocation or reassignment affects subsequent server checks and scope reloads; no promise of immediate removal from an already-rendered page. Server calls remain authoritative even with stale client scope.

## Client and data boundaries

Keep the existing scope response and Flutter model contract. Prove global admin/supervisor and assigned direction navigation through scope parsing and route tests; add product changes only if those tests expose a contract mismatch. Direction accounts must not gain `/admin`. No data import, Auth account creation, record deletion, separate grant editor or ministry_grants backfill belongs here.

## Acceptance and verification

Local regression tests must cover allowlist-only admin, supervision without ministry grants, direction without ministry grants, union/deduplication, mixed global/scoped roles, null/anonymous denial, active versus archived congregations, verified versus unverified email binding, and pending-audit-only denial. Keep stale active staff and supervision grants in negative cases; toggling/deleting them must not alter effective access.

Under authenticated execution, test cross-congregation read/write denial (`42501`) and own-congregation success through representative student, class/enrollment, attendance/session, directory and convert handoff RPCs. Preserve RLS helper coverage and assert clients retain no direct ministry table privileges. Test revocation before receipt replay and reassignment after a scope refresh. Update legacy fixtures to user_access without weakening their original revision, concurrency, cursor or validation assertions.

Run the narrow SQL scenario first, then affected existing SQL/concurrency scenarios and Flutter auth/navigation tests, then the repository verification script. Investigate unexpected failures before changing expectations. Implementation must not apply SQL to hosted Supabase. Hosted rollout is a separate authorized operational step after local evidence and review. This document work runs no tests and changes no product code.

## Assumptions and review

Archive behavior is intentionally preserved from existing ministry helpers: direction excludes archived congregations; global accounts retain historical access; congregation picker lists active congregations only. Multiple assignments remain supported by the existing access contract. No change to the campaign permission model is requested.

Self-review: active versus audit authority, admin versus supervisor flags, null scope, archive behavior, stale grants, binding, directory eligibility and client/server boundaries are consistent. The implementation plan covers each requirement and retains existing regression semantics.
