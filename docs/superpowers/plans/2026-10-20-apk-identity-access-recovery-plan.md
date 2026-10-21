# APK Identity and Access Recovery Implementation Plan — draft

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the Google-session greeting and safe Team entry, then establish the evidence needed for convert recovery and a new APK candidate.

**Architecture:** Existing session metadata supplies display text; existing server scope continues to control navigation. Read-only contract diagnosis separates a client defect from a hosted deployment discrepancy before any data fix.

**Tech Stack:** Flutter/Dart, Supabase PostgreSQL/PostgREST, existing local Android toolchain.

**Spec:** `docs/superpowers/specs/2026-10-20-apk-identity-access-recovery-design.md`.

**Status:** Draft for review; not executable until the bounded design/spec and this plan are approved. Author: Sol 6.1 / low using `writing-plans`. User-selected execution remains Luna/medium supervising OpenCode CLI; one Sol/low reviewer. No commit or push is authorized by this draft.

## Global Constraints

- Preserve current uncommitted L1 work and its release blockers.
- Presentation metadata never changes authority; do not manufacture Ministry scope or weaken RLS/decoders.
- Do not call `ieadpe_get_scope()` as a read-only probe because it writes bindings.
- No hosted write, migration, import, publication or signing-policy change is included.

## Review Focus

- Missing/non-string Google metadata gives a neutral greeting rather than a visitor role implication (Task 2).
- Admin true with Ministry false stays in Admin and can refresh without gaining authority (Task 3).
- Valid Ministry scope still opens Team and registrar scope remains denied (Task 3).
- Missing RPC/projection and permission errors remain visible diagnostic failures rather than empty data (Task 1).
- A candidate APK must be tied to its source/configuration and real backend verification before a functional claim (Task 4).

### Task 1: Record backend compatibility evidence

**Files:** Create `docs/verification/apk-identity-access-diagnostics.md`; inspect existing auth/convert repositories and migrations only.

**Interfaces:** Consume existing RPC definitions and the spec's read-only boundary; produce an evidence matrix with `confirmed`, `mismatch`, or `unknown` per scope, convert RPC/projection and APK/backend identity.

- [ ] Record local expected function signatures/projection and observed APK/backend version, without credentials.
- [ ] If an authorized read-only connection exists, inspect `pg_catalog`, column metadata and migration version inventory in a read-only transaction; observe an existing application scope response only if available. Do not invoke the scope RPC as a probe.
- [ ] Classify exact HTTP/SQLSTATE/decoder failure evidence. If access is absent, retain `unknown`; if hosted mismatch is confirmed, draft a separate alignment proposal instead of changing hosted state under this plan.

### Task 2: Wire the authenticated display name

**Files:** Create `lib/features/auth/session_display_name.dart`, `test/features/auth/session_display_name_test.dart`; modify `lib/app.dart`, `lib/features/home/home_page.dart`, existing Home/app wiring tests.

**Interfaces:** Add `String? sessionDisplayName(Map<String, dynamic>? metadata)` selecting trimmed nonblank `full_name`, then `name`; make `HomePage.name` nullable with neutral `Olá!` fallback. Pass the current session's metadata-derived name through `_ProtectedFeatures` to Home.

- [ ] Write assertions for `full_name`, fallback `name`, whitespace, null/non-string values, and real app wiring; observe the intended failing assertions.
- [ ] Have OpenCode implement the exact selection/greeting contract without touching access flags.
- [ ] Run `flutter test --no-pub --concurrency=1 test/features/auth/session_display_name_test.dart test/features/home/home_page_test.dart test/workflows_test.dart`; require exit 0 and verify identity refresh does not retain a prior user's name.

### Task 3: Keep an unavailable Team entry in Admin

**Files:** Modify `lib/features/admin/access_panel.dart`, `admin_page.dart`; extend `test/features/admin/admin_page_test.dart` and `test/features/auth/auth_flow_test.dart` as needed.

**Interfaces:** `AccessPanel` receives required `bool canOpenTeam` and `Future<void> Function() onScopeRefresh` in addition to `onOpenTeam`; Admin supplies `scope.hasMinistryAccess` and its existing callback. Preserve `AccessScope` and `routesFor` semantics.

- [ ] Write failing UI assertions: inconsistent admin-only scope shows the exact spec message, cannot invoke Team navigation, and `Atualizar acesso` calls refresh; valid Ministry scope invokes Team; registrar never obtains Admin/Team routes.
- [ ] Have OpenCode implement the safe entry and exact pt-BR copy; retain Admin context on the unavailable path.
- [ ] Run `flutter test --no-pub --concurrency=1 test/features/admin/admin_page_test.dart test/features/auth/auth_flow_test.dart test/workflows_test.dart`; require exit 0. Check the message/action at 360px and 200% text.

### Task 4: Review and build the candidate

**Files:** Update the diagnostic report, execution ledger and cross-device handoff; APK output stays outside tracked source.

- [ ] Run formatter checks on changed Dart files, targeted tests above and `git diff --check`; record exact outcomes. Compare analyzer diagnostics with the recorded baseline rather than auto-fixing unrelated code.
- [ ] Obtain the sole Sol/low review; send Critical/Major/Important findings to the same Luna/medium OpenCode coder and re-review until none remain.
- [ ] Use the repository's existing approved Android configuration/build process. Record APK version, source HEAD plus uncommitted delta, configuration identity without secrets, and artifact SHA-256.
- [ ] Verify with the real Google-admin session against the intended backend: appropriate greeting, authorized convert read result and Team entry. If hosted compatibility or session access is unavailable, report a candidate plus the exact pending gate; do not claim the data-loading problem resolved.

Self-review: each known local defect has an independent regression task; hosted diagnosis is evidence collection with a bounded deliverable, not an unspecified product fix. The user has already selected the execution method; request review of the concrete design and plan before dispatching implementation.


## 2026-10-20 ownership clarification

Retain this bounded draft as historical/reference material, not an additional executable queue. Task 8 in the [existing corrective plan](2026-10-20-ministry-corrective-release-plan.md) owns greeting/Team work; Tasks 12/H1/H2/H3/D1 own compatibility/recovery/activation/legacy/Android. See that plan's completion map and bounded delivery addendum before execution. OpenCode and the premature candidate-build step above are superseded by the user's native Luna Medium implementation / native Sol 6.1 low review pipeline and no-build-now instruction. Review documents first. No commit/push is authorized.
