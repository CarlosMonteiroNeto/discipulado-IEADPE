# Base44 Unified Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Base44 direction and supervision assignments the same effective ministry permissions as their campaign scope, including global technical admins.

**Architecture:** Add a forward SQL migration that changes the two ministry authorization helpers, the scope projection and the congregation-directory eligibility check. Retain existing RPC/RLS call sites, identity binding, response contracts and Flutter scope consumers. Migrate old tests to the shared authority and prove client navigation from server-shaped snapshots.

**Tech Stack:** PostgreSQL/Supabase SQL, Python disposable database harness, Flutter/Dart tests.

**Spec:** `docs/superpowers/specs/2026-10-18-base44-unified-access-design.md`

## Global Constraints

- `private.base44_user_access_pending` is audit only.
- Existing `ministry_grants` rows may remain, but their presence, role, active flag, insertion, update or deletion cannot grant or revoke effective access.
- Do not synthesize user_access assignments from ministry_grants.
- Keep signatures, SECURITY DEFINER, empty search_path, function grants, RLS policies, table privilege restrictions, payload validation, pagination, cursor binding, access locks and mutation replay ordering intact.
- Implementation must not apply SQL to hosted Supabase.
- No data import, Auth account creation, record deletion, separate grant editor or ministry_grants backfill belongs here.

## Review Focus

1. An unverified email or forged metadata matches an assignment: deny until auth.users confirms the email (Task 1 binding regression).
2. A revoked actor replays a previously successful operation while retaining ministry_supervision grants: deny before receipt return (Task 2 replay regression).
3. Multiple/duplicate and mixed global/direction assignments: deduplicated sorted scope, global precedence, no grant-derived additions (Task 1 matrix).
4. Direction assignment points at an archived congregation: no ministry scope/picker result; globals retain historical authorization (Task 1 archive matrix).
5. A stale client page or pagination cursor survives reassignment: next server request enforces the new congregation and refreshed client routes reflect scope (Tasks 1 and 3).

---

## File map

Create `supabase/migrations/202610180003_base44_unified_access.sql` for production behavior and `supabase/tests/database/base44_unified_access_test.sql` for the new matrix. Modify `supabase/tests/database/unified_scope_test.sql` to replace obsolete independent-grant expectations. Update existing ministry fixtures in Task 2, keeping their original behavioral coverage. Modify only Flutter tests in Task 3 unless a demonstrated response-contract defect requires a minimal consumer fix. Never stage unrelated worktree edits.

### Task 1: Shared server authority and complete scope contract

**Files:**
- Create: `supabase/migrations/202610180003_base44_unified_access.sql`
- Create: `supabase/tests/database/base44_unified_access_test.sql`
- Modify: `supabase/tests/database/unified_scope_test.sql`
- Modify: `scripts/verify_unified.ps1`, `scripts/verify_unified.sh` (SQL scenario lists)

**Interfaces:**
- Consumes: `private.is_global_manager() RETURNS boolean`, `private.can_access_congregation(scope_id uuid) RETURNS boolean`, `private.lock_access(user_ids uuid[]) RETURNS void`.
- Produces: unchanged `private.ministry_supervisor() RETURNS boolean`, `private.ministry_can_access(scope_id uuid) RETURNS boolean`, `public.ieadpe_get_scope() RETURNS jsonb`, `public.ieadpe_ministry_list_congregations(request jsonb) RETURNS jsonb` using the spec's shared authority.

- [ ] **Step 1: Write SQL matrix assertions.** Use existing BEGIN/ROLLBACK and pg_temp.assert_true conventions. Seed A/B/archived congregations and confirmed identities: allowlist-only, supervision-only, direction A, directions A+B, no assignment with stale active staff/supervision grants. Use exact roles `Membro da direção da campanha` and `Membro da supervisão das campanhas`. Keep grant-only and pending-audit-only actors negative. For pending audit fixtures copy required column shapes from `202610180001_base44_history.sql`; create no production records.

  Assert, under the corresponding authenticated actor:
  ```sql
  SELECT pg_temp.assert_true(private.ministry_supervisor(), 'allowlist-only global');
  SELECT pg_temp.assert_true(private.ministry_can_access(NULL)=false, 'null scope denied');
  -- For direction A, with A/B UUID literals from the fixture:
  -- ministry_can_access(A)=true; ministry_can_access(B)=false;
  -- get_scope().ministry_congregation_ids=[A]; ministry_supervision=false.
  -- For globals without direction: ministry_supervision=true; ministry IDs=[].
  ```
  Add assertions for all five scope field types and exact sorted arrays, mixed roles/global precedence, grant toggles/deletions having no effect, anonymous helper denial and anonymous scope execution denial. Archive A: direction loses helper/scope access and directory eligibility; global retains helper access but picker excludes A. Empty active catalog for global returns items=[] rather than forbidden.

- [ ] **Step 2: Add binding and isolation assertions.** Reuse `access_test.sql`/`catalog_test.sql` auth fixture patterns: unbound normalized email assignment remains denied for unconfirmed auth.users even with forged metadata, confirmed sign-in binds it through get_scope, increments version once, repeated scope load does not increment again. Pending audit rows alone never bind/grant. Change direction A to B through the existing access RPC as a global actor: refreshed scope contains only B; an A request using an old cursor or stale scope is denied before returning records. Exercise `ieadpe_ministry_list_congregations` own-only and global results, preserving page limit/cursor assertions from `ministry_congregations_test.sql`.

- [ ] **Step 3: Run RED locally.** Run `python scripts/test_database.py base44_unified_access_test.sql`. Expected: failure at the new allowlist-only or direction-without-ministry_grants assertion, proving the missing authority. If fixture/schema/environment fails first, investigate that cause before claiming intentional RED.

- [ ] **Step 4: Implement the four function replacements in the new migration.** Copy current scope binding body verbatim from `202610140017_unified_scope.sql`; replace only ministry projection as specified. ministry_supervisor delegates to is_global_manager; ministry_can_access requires UID/non-null and preserves staff archive filtering. Replace direct grant precheck in the directory function from `202610140018_ministry_congregation_directory.sql` with global or an existing accessible active congregation. Preserve complete validation/paging body and ACLs. Historical SQL files remain unchanged.

- [ ] **Step 5: Replace obsolete unified_scope assertions.** Use user_access assignments for the positive matrix; preserve stale ministry_grants only to prove they are ignored. Revocation deletes the active assignment, not toggles a grant. Add the new SQL filename to both verify_unified scenario arrays.

- [ ] **Step 6: Run GREEN locally.** Run `python scripts/test_database.py base44_unified_access_test.sql`, then `python scripts/test_database.py unified_scope_test.sql`, `python scripts/test_database.py access_test.sql` and `python scripts/test_database.py catalog_test.sql`. Expected: each prints `PASS: <scenario>` and exits 0. Inspect `rg -n 'ministry_grants' supabase/migrations` and confirm no latest effective authorization definition still reads it; historical definitions/table declarations are expected.

- [ ] **Step 7: Commit.** Stage only Task 1 files and commit `feat: unify ministry authorization with Base44 access`.

### Task 2: Preserve ministry RPC, revocation and concurrency guarantees

**Files:**
- Modify: `supabase/tests/database/ministry_access_test.sql`, `ministry_registry_test.sql`, `ministry_academic_test.sql`, `ministry_ui_reads_test.sql`, `ministry_congregations_test.sql`, `convert_student_link_test.sql` (all under `supabase/tests/database/`)
- Modify: `scripts/database_ministry_registry_concurrency.py`, `scripts/database_ministry_academic_concurrency.py`, `scripts/database_convert_student_concurrency.py`

**Interfaces:**
- Consumes: Task 1 ministry helpers and unchanged public RPC signatures/payloads.
- Produces: existing SQL scenarios and concurrency runners exercising user_access-based authorization without weakening revision, replay, roster, cursor, or handoff contracts.

- [ ] **Step 1: Add regression assertions before changing fixtures.** In registry test retain successful contact operation receipt, revoke its user_access row, leave an active ministry_supervision grant, then replay the exact operation ID/payload and expect insufficient_privilege (`42501`), not receipt success. Restore the user_access assignment before subsequent existing registry cases. In the remaining scenarios add own-congregation success and B denial using their existing valid payloads for student, class/enrollment, session/attendance and handoff operations; change only congregation/entity IDs to isolate authorization. Retain direct-table privilege denial assertions and RLS policy helper coverage in ministry_access_test.

- [ ] **Step 2: Run RED locally.** Run `python scripts/test_database.py ministry_registry_test.sql`. Expected: existing grant-only positive fixture now raises forbidden, demonstrating a stale fixture after Task 1. Confirm the failing line and classify it before fixture migration; do not remove revocation/replay assertions.

- [ ] **Step 3: Migrate positive fixtures.** Replace grant-only staff fixtures with user_access(user_email,user_id,role,congregation_id) direction rows and global ministry fixtures with supervision rows. Use emails already inserted in auth.users. Replace active-flag revocation/restoration with deletion/reinsertion of that same user_access assignment. In all three concurrency scripts seed direction user_access rather than ministry_grants; preserve scheduling, lock assertions, receipts and expected revisions. Leave explicit legacy-grant negative fixtures present.

- [ ] **Step 4: Run GREEN locally.** For each of the six listed SQL files run `python scripts/test_database.py <filename>`; expected `PASS: <filename>` and exit 0. Run `python scripts/test_database.py --ministry-registry-concurrency`, `python scripts/test_database.py --ministry-academic-concurrency`, and `python scripts/test_database.py --convert-student-concurrency`; expected exit 0 and their existing PASS messages. Investigate failures through their SQL and lock paths before modifying expectations.

- [ ] **Step 5: Commit.** Stage only Task 2 files and commit `test: preserve ministry guarantees under unified assignments`.

### Task 3: Scope-driven Flutter navigation and final local evidence

**Files:**
- Modify: `test/features/auth/auth_repository_test.dart`, `test/widgets/unified_navigation_test.dart`
- Conditional consumer fixes only if a new assertion fails: `lib/features/auth/auth_repository.dart`, `lib/domain/models.dart`, `lib/routing/router.dart`.

**Interfaces:**
- Consumes: Task 1's unchanged five-field scope JSON through `AuthRepository`'s existing scope load and `AccessScope`; `routesFor(AccessScope scope) -> List<String>`.
- Produces: regression evidence that the existing shell and routes expose shared ministry scope and enforce its removal on refresh.

- [ ] **Step 1: Add scope parsing and route assertions.** Feed existing mocked scope RPC transport these snapshots: admin `{is_admin:true,is_supervision:false,congregation_ids:[],ministry_supervision:true,ministry_congregation_ids:[]}`; supervision with is_supervision=true/is_admin=false; direction with both ID arrays=['A'] and both supervision flags=false; revoked all-false/empty. Assert parsed flags/sets, ministry routes for first three, `/admin` only for globals, and no ministry routes after revoked snapshot. Assert direction canAccessMinistry('A') true and ('B') false. Keep malformed-snapshot rejection tests. The existing campaign-only test describes a partial server snapshot: rename it to describe missing ministry fields in the constructed AccessScope rather than suggesting independent grants remain the policy; keep its fail-closed assertion.
  ```dart
  expect(routesFor(AccessScope(congregationIds: ['A'], ministryCongregationIds: ['A'])), contains('/ministry/students'));
  expect(routesFor(AccessScope(congregationIds: ['A'], ministryCongregationIds: ['A'])), isNot(contains('/admin')));
  expect(routesFor(AccessScope()), isNot(contains('/ministry')));
  ```
  Update existing shell widget fixture labels from grants to server scope and verify Discipulado selector remains visible for global and direction snapshots.

- [ ] **Step 2: Run focused tests.** Run `flutter test test/features/auth/auth_repository_test.dart test/widgets/unified_navigation_test.dart`. Expected all tests pass. Existing consumers may already satisfy the contract; do not invent a RED failure. If an assertion fails, capture exact failure, trace JSON parsing/routes and implement only the minimal consumer correction, then rerun the same command.

- [ ] **Step 3: Run final local verification.** Run `powershell -NoProfile -File scripts/verify_unified.ps1`. Expected report `build/verification/unified-report.md` contains passing required gates, including the newly registered SQL scenario. Investigate every unexpected failure before classifying it. Confirm no hosted SQL or Taildrop step occurred; report local evidence and any genuine environment blocker. Review `git diff --check` and scoped diff for permission-source regressions and unrelated edits.

- [ ] **Step 4: Commit.** Stage only Task 3 tests and demonstrated minimal consumer fixes; commit `test: verify Base44 scope drives ministry navigation`.

## Plan self-review and handoff

Coverage: Task 1 owns authority, scope, binding, archives, directory and assignment changes; Task 2 owns all affected fixture semantics, RPC boundaries, stale receipt replay and concurrency; Task 3 owns client contract and navigation. All five Review Focus risks have explicit assertions in their owning task. Interfaces retain existing signatures and response types. Tasks each have an independently reviewable verification cycle; no product implementation is included in this plan document.

This plan is for review only. No tests or implementation are run while producing these documents. Preserve the previously chosen execution method if implementation is later requested; obtain plan review before starting implementation as required by writing-plans guidance. Hosted rollout remains a separate operational action.
