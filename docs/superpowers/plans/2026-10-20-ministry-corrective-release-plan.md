# Ministry Corrective Release Implementation Plan

> **Current review entry:** Read the “2026-10-20 completion map and bounded delivery addendum” below before the historical status/protocol. It reconciles completion, replaces OpenCode with the user-selected native Luna Medium / Sol 6.1 low method, and does not authorize execution or an APK build now.

> **Execution method selected by the user:** adapted pipeline. This Codex session is strategist, director, arbiter and whole-product reviewer. OpenCode CLI is the coder worker. A native `gpt-6.1-sol` / low-effort subagent reviews each stage. This supersedes the packaged automatic Script CEO dispatch/model/commit defaults; the engineering acceptance and verification gates remain mandatory.

**Goal:** Correct the identified integrity/compatibility gaps, complete operator-facing attendance/progress, and prepare a proven hosted activation and Android delivery.

**Architecture:** Preserve the existing Flutter/Supabase model and Base44 theme. Use narrowly owned forward migrations, canonical bounded projections, a composed immutable pending-attendance controller, explicit cancellation/replacement lineage, and reusable persisted-progress presentation.

**Tech Stack:** Existing Flutter/Dart dependencies, PostgreSQL/Supabase RPC/Auth/private Storage, Python SQL/runner tooling, local Chromium and the existing Android toolchain. No new application package or paid service.

**Spec:** [Corrective release design](../specs/2026-10-20-ministry-corrective-release-design.md).

**Machine plan:** [Local tasks JSON](2026-10-20-ministry-corrective-release-plan.json). It carries complete task interfaces, exact owned paths, acceptance, dependencies and verification commands; it is not an authorization to mutate the hosted project. Bootstrap and operational stages below are deliberately outside automatic local-task execution.

**Status:** User authorized implementation. B1–B3 and combined bootstrap have Sol/director approval: 459 Flutter tests pass, analyzer has zero diagnostics and the final candidate is stable. Task 1 has scoped approval (461 tests, zero diagnostics); Task 2 is approved (465 tests, zero diagnostics); Task 3 is in progress. See `docs/verification/2026-10-20-corrective-execution.md` for scoped evidence and remaining runtime/activation blockers.

## Global constraints

- Preserve the application baseline `f2fffca489fd36f55957bba49736cb35dd31d5a6` and read parent requirements at `origin/main@c71534d`; rebase/integrate deliberately if HEAD changes, preserving existing work.
- Technical artifacts in English, product UI in Portuguese, existing Base44 theme, existing dependency lock and Supabase Free. No unrelated refactor or replacement backend.
- Finalized attendance is immutable for new operations, with exact receipt replay retained. Correct by acknowledged cancellation and a linked new session, preserving original history.
- Canonical operational identity comes from `ministry_people`; legacy fallback applies only to unlinked rows. Never merge by name, rewrite frozen snapshots, fabricate conversion dates or convert attendance into home visits.
- Retry an ambiguous command with the exact same operation ID, payload, revision and action; authorization loss clears protected state and discards late replies.
- Forward migrations only. Preserve strict public payload/result types, RLS/grants, lock ordering, idempotency, current one-active-enrollment and historical capacity invariants.
- New test files belong to each JSON task's `verification.new_test_files`; SQL/Python scenario files are explicitly owned in `touches` and executed through contained Dart wrappers/authoritative commands. This keeps the installed Flutter RED adapter meaningful without pretending SQL is a Dart test file.
- Bootstrap failures are disclosed and repaired; no hidden waiver or red full-suite approval. Local, hosted, legacy and device evidence have separate states.
- Read-only Sol stage reviewers do not implement. Only director arbitration may change task acceptance; fixes return to the same OpenCode task session. No silent fallback from CLI/provider errors to Codex coding.
- No commit/push/merge, hosted repair/application/import or Android publication is implied by this planning task or by packaged script defaults. Preserve the user's existing changes and do not expose credentials/private records.

## Execution protocol for this environment

Use the actual delegation skill at `/workspace/.agents/skills/opencode-cli-delegation/SKILL.md` (recovered verbatim from the user's `environment-fixes.zip`); source skill bundle is `/workspace/.config/opencode/vendor/superpowers@ace9e92ac19d7cb485e8d946ee7b828177e46d08`. Read only the applicable engineering overlays listed in the spec for each work unit.

1. Director records `git status`, branch/base SHA, all pre-existing tracked/untracked paths and an evidence digest. Work on an isolated authorized checkout or the established branch with one writer. Do not overwrite these planning/review documents.
2. Director writes a bounded brief outside product files. It states: pipeline coder role, task ID, spec refs, allowed source/new test files, dependencies, exact contracts, required RED/GREEN/verification, relevant skill file paths, no hosted access/no commit/push, and structured result schema.
3. Invoke OpenCode from the resolved project root using an argument array, requested model `opencode/deepseek-v4.1-flash-free`, JSON output and a unique task title. Attach only the brief/necessary non-secret files. Keep ordinary proxy/CA/provider configuration; omit privileged Supabase variables from local coder subprocesses. Do not inspect or copy OpenCode credentials.
4. A fresh work unit gets a fresh CLI session. Capture its real session ID from the event stream. Corrections use that exact `--session` plus the same model; never `--continue` blindly into an unrelated last session. Use `--standalone` only after the documented managed-service/port conflict. Authentication/model/provider errors stop that work unit with BLOCKED, not a replacement model.
5. Expected coder result is structured JSON: `status` (`completed`, `blocked`, `test_defect`), `task_id`, `changed_files`, `summary`, `tests` (command, exit code, raw evidence path, RED/GREEN role), `session_id`, `issues`, `self_review`. Reconcile it with actual process exit, Git diff/new files, tool output and test results. A self-reported completed status cannot approve the task.
6. Director runs/inspects authoritative focused and full gates and prepares a review package bound to HEAD plus content hashes, including new files. Send it to a clean-context native reviewer requested as `gpt-6.1-sol`, `reasoning_effort=low`. Reviewer returns APPROVED/SEND_BACK/ESCALATE with severity, file/line, reproducible trigger, acceptance/test gaps and minor disposition.
7. Director arbitrates contradictory tests/contracts, sends every Critical/Important finding to the same OpenCode coder session, reruns affected checks and obtains a new stage review. A native subagent may transport a coder brief/results, but must not replace CLI product coding. The parent session performs the final combined review and preserves all rulings.
8. Keep an append-only execution record under the ignored plan workspace, with brief/review paths, hashes, worker identities, exact commands/exits, scope changes and remaining blockers. Do not fabricate the installed Script CEO ledger events. Publish a sanitized tracked execution summary at stage boundaries. No automatic commit or push.

Suggested argument-safe invocation shape (not executed as a product task by this document):

```python
subprocess.run([
    opencode_executable, 'run',
    '--model', 'opencode/deepseek-v4.1-flash-free',
    '--format', 'json', '--title', task_title,
    '--file', str(brief_path),
    'Act as this pipeline task coder. Read the attached bounded brief and return actual changes and evidence.'
], cwd=project_root, env=coder_environment, check=False)
```

The brief's directory restrictions are application instructions, not an OS sandbox guarantee. Preserve actual managed tool policies and do not weaken them to make a worker start.

## B0 — Environment and baseline entry

**Owners:** director prepares/validates; any bounded environment repair is explicit. No product change during this document-authoring stage.

- [ ] Verify CLI version/model availability with a no-tool/no-edit readiness request and record its actual exit/session result. Verify reviewer availability through the native subagent tool. Template profile declarations are not live-model proof.
- [ ] Verify trusted portable hooks. Existing project hooks point to Windows paths; do not execute them as if valid on Linux, silently discard inherited restrictions, or activate packaged Terra/Sol example defaults. Confirm the adapted protocol instead of starting a second automatic executor.
- [ ] Verify Flutter/Dart, Java/Android, PostgreSQL, PowerShell, Chromium/driver and loopback Supabase prerequisites as needed. Repair local executable modes via the supported installation/workspace process; `bash scripts/cmd` is valid for its currently non-executable copy.
- [ ] Pin SDK and test font provenance; retain the current lockfile. Capture an exact fresh baseline (commands, tool versions, file hashes, raw failures) before fixing it.
- [ ] Record the known expected baseline: import failures, two golden suites and 36 analyzer diagnostics. Any additional failure is investigated, not assumed inherited.
- [ ] Resolve test commands from the existing Flutter project; new Dart database/operations wrappers invoke the specific SQL/Python tests and retain child exit codes. Do not feed `.sql` files to the Flutter test runner or install an unrelated Python toolchain just to satisfy a name.

## B1 — Restore importer/schema compatibility

**Own files:** create `supabase/migrations/202610200001_import_revision_compatibility.sql` and `supabase/tests/database/import_revision_compatibility_test.sql`; extend `supabase/tests/database/import_test.sql`, `scripts/database_import_concurrency.py` and `test/database/task_16_test.dart`; add `test/database/import_revision_compatibility_test.dart` using the existing contained database harness. Recheck unused migration number.

**Contract:** existing `ieadpe_import_convert(operation_id uuid,payload jsonb)->jsonb`; no accepted client revision/person field is added. Existing result/replay/duplicate/tombstone contracts stay intact. New legacy rows have revision 1/person_id null; canonical reconciliation remains a separately audited stable-ID operation.

- [x] Add/reproduce a valid accepted import after all migrations with the mandatory revision column; observe SQLSTATE 23502 in the current code. Add duplicate, tombstone, lost-response replay, concurrent same legacy ID and counter/zero-confirmation transaction-order assertions.
- [x] Have the CLI coder replace the importer in a forward migration, explicitly initializing the inserted composite record's revision, retaining every prior validation/lock/result/receipt rule.
- [x] Run `python3 scripts/test_database.py import_revision_compatibility_test.sql`, `python3 scripts/test_database.py import_test.sql`, `python3 scripts/test_database.py --import-concurrency`, and the two Task 16/wrapper Flutter files. Expect all to pass with no double count/link/revision reset.
- [x] Obtain Sol 6.1/low review of actual diff/evidence. Other baseline failures remain explicitly open; this is not ordinary full-green pipeline completion.

## B2 — Make visual verification portable and review its mismatches

**Own files:** new `test/support/sdk_fonts.dart`; `test/widgets/ministry_component_gallery_test.dart`, `test/features/ministry/ui/team_lifecycle_test.dart`, `test/features/ministry/ui/session_visual_test.dart`, `test/features/ministry/ui/class_management_test.dart`; affected goldens only after actual comparison; `docs/verification/l1/visual-review.md` and a small font/SDK provenance record.

- [x] Reproduce Linux case-sensitive font lookup with real SDK filenames. Use one test helper `Future<void> loadSdkFont(String family,List<String> candidateNames)` that discovers the actual SDK font and fails clearly when absent; do not depend on manually installed lower-case aliases.
- [x] Compare committed/actual/diff captures for the 3.64% Ministry gallery and 2.63% Team mismatch. Determine font/SDK/rendering drift versus a real UI defect before changing goldens.
- [x] Fix the cause within the existing Base44 presentation contract; pin/generate references only after synthetic visual review at 360/768/1440 and 200% text. Do not raise tolerances, skip tests or accept missing labels/icons.
- [x] Route normal generated screenshots to `build/verification`; test runs must not silently overwrite tracked documentation captures. Promotion into tracked evidence is a reviewed explicit action.
- [x] Run the four focused Flutter files, inspect all affected captures, and obtain Sol visual/code review. Record what automation proves and the remaining human/device checks.

## B3 — Clear diagnostics and establish a green bootstrap candidate

**Own paths:** only the Dart files named by the 36 diagnostics in the recorded analyzer output, plus directly related formatting. Current families include `lib/app.dart`, convert repository/gateway/form, Ministry repositories/forms/session list/student detail/team page and the named Ministry tests. Enumerate exact files into the bounded coder brief before dispatch; this is not directory-wide cleanup authority.

- [x] Run `flutter analyze --no-pub`, classify each diagnostic and repair narrowly (unused imports/casts/parameters, overridden annotations, braces, deprecated callback and safe mounted/context handling). Do not change tests or API contracts to conceal analyzer output.
- [x] For behavior-sensitive mounted/deprecated-callback changes, add a focused lifecycle/back assertion; purely mechanical lint cleanup does not need mirror-image tests.
- [x] Execute the full sequential Flutter suite and analyzer after B1/B2/B3. Expected result is zero failures and zero diagnostics, not the former 450/4 baseline.
- [x] Obtain a combined Sol 6.1/low bootstrap review with full green evidence, then director disposition. Only then are ordinary task approvals eligible. No baseline waiver has been approved.

## Local corrective task schedule

Start with one writer at a time. `depends_on` is authoritative; exact `touches` and registered new test paths define scope. Shared model/codec/server contract producers land before consumers. The latest user-selected director/CLI/reviewer protocol owns dispatch; installed deterministic validation/command helpers remain useful without invoking Script CEO.

| Task | Outcome | Dependencies |
|---|---|---|
| 1 | Use canonical identity in bounded handoff projections | Bootstrap only |
| 2 | Enforce immutable finalization and linked replacement on the server | 1 |
| 3 | Own attendance retries as an immutable pending command | 2 |
| 4 | Connect read-only attendance and cancellation/replacement UX | 2, 3 |
| 5 | Expose bounded enrollment history with strict typed transport | 2 |
| 6 | Present persisted enrollment progress in student and class context | 4, 5 |
| 7 | Restore scope compatibility and align legacy contact fixtures | 1, 2, 5 |
| 8 | Finish safe session greeting and Admin Team entry | 7 |
| 9 | Make browser-runner contract tests portable | Bootstrap only |
| 10 | Drive both verification gates from one complete case manifest | 5, 7, 9 |
| 11 | Verify the current coupled journey in local Chromium with bounded cleanup | 1, 4, 6, 7, 8, 9, 10 |
| 12 | Prepare exact hosted-state inspection and local upgrade rehearsal | 2, 5, 7, 10 |

Each local task follows the checklist below. Bootstrap's fresh full green result is an entry condition, not a promised outcome. No external authentication, missing Docker service or blocked provider is waived by the plan.

### Task 1: Use canonical identity in bounded handoff projections

Repair referral and candidate lookup after person edits without changing their public envelopes or historical snapshots.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s05-canonical-handoff-reads`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `supabase/migrations/202610200002_canonical_handoff_reads.sql`
- `supabase/tests/database/canonical_handoff_reads_test.sql`
- `supabase/tests/database/convert_student_link_test.sql`
- `test/features/ministry/ui/ministry_handoff_repository_test.dart`

**New registered test files:**

- `test/database/canonical_handoff_reads_test.dart`

**Interfaces consumed:** Existing list_convert_referrals and list_convert_student_candidates(request jsonb) contracts; save_person(uuid,jsonb).

**Interfaces produced:** Forward migration 202610200002; identical RPC request/result keys with corrected canonical operational identity.

**Acceptance:**

- A synthetic save_person rename appears immediately in convert detail, student detail, referral list and candidate prefix search; old prefix no longer matches the linked student.
- Linked null phone/address remain null instead of falling back to compatibility snapshots; unlinked legacy rows retain their original fallback.
- Referral address remains nullable text with nonblank street,district,city,state_code,postal_code joined by comma-space; candidate address retains its strict structured type.
- Foreign/revoked/anonymous readers remain denied; projections contain only existing allowlisted fields.
- Signed cursor binding, ordering, limits 1/100 and 101-row pagination use the canonical normalized name and reject tampering or foreign actor/scope.
- Stored convert/student snapshots and frozen roster labels are unchanged; no name-based match is created.
- Update the old address assertion only to the documented canonical/provenance contract, preserving exact snapshot assertions.

**Work steps:**

- [x] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [x] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [x] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [x] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [x] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [x] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 scripts/test_database.py canonical_handoff_reads_test.sql
python3 scripts/test_database.py convert_student_link_test.sql
flutter test --no-pub --concurrency=1 test/database/canonical_handoff_reads_test.dart test/features/ministry/ui/ministry_handoff_repository_test.dart
```

### Task 2: Enforce immutable finalization and linked replacement on the server

Replace finalized-correction behavior with the user-selected immutable policy and a backward-compatible explicit replacement reference.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s06-immutable-finalization-and-replacement`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `supabase/migrations/202610200003_attendance_integrity.sql`
- `supabase/tests/database/attendance_integrity_test.sql`
- `supabase/tests/database/ministry_academic_test.sql`
- `supabase/tests/database/ministry_follow_up_test.sql`
- `supabase/tests/database/ministry_session_management_test.sql`
- `scripts/database_ministry_academic_concurrency.py`
- `scripts/database_ministry_follow_up_concurrency.py`
- `lib/features/ministry/domain/ministry_models.dart`
- `lib/features/ministry/data/ministry_codec.dart`
- `lib/features/ministry/data/ministry_repository.dart`
- `lib/data/supabase_gateway.dart`
- `test/features/ministry/data/ministry_repository_test.dart`
- `test/features/ministry/domain/ministry_models_test.dart`
- `test/data/supabase_gateway_ministry_contract_test.dart`
- `docs/integration/ministry-completion-contracts.md`
- `docs/integration/ministry-contracts.md`

**New registered test files:**

- `test/database/attendance_integrity_test.dart`

**Interfaces consumed:** Existing save_attendance(uuid,jsonb), cancel_session(uuid,jsonb), create_session(uuid,jsonb); Session and MinistrySessionSummary.

**Interfaces produced:** Migration 202610200003; optional createSession(..., String? replacesSessionId); nullable replacesSessionId on Session/MinistrySessionSummary; existing mutation result envelopes retained. Session and MinistrySessionSummary also expose nullable replacementSessionId; detail/summary envelopes include nullable replaces_session_id and replacement_session_id.

**Acceptance:**

- Both finalize=false and finalize=true under a NEW operation reject a finalized call as session_finalized (23514), preserving roster, marks, revisions, receipts and derived facts.
- An identical successful finalization replay returns the original receipt after finalization; a changed payload conflicts; revoked authority denies replay.
- Cancellation retains the original roster/marks and removes only its derived contribution; authentic visits and other valid presence remain effective.
- Optional replaces_session_id on create_session accepts only a canceled same-congregation/class/date predecessor with no direct replacement; null/absent keeps ordinary create semantics.
- A nullable RESTRICT FK, unique non-null predecessor index and immutable linkage prevent forks, rewrites and self/cyclic links; exact create replay remains valid after later state changes.
- Completed/archived class history remains readable/cancellable but new replacements obey active class/period restrictions; concurrent replacement attempts produce one child.
- Session detail and class-session summaries return nullable replaces_session_id; strict DTO/gateway/codecs are updated consistently; historical rows decode null.
- Keep frozen-roster membership and business-date finalization; replacement uses normal eligible roster on its first save and never copies marks.
- On first roster freeze, capture the current same-congregation canonical person name for linked students; only unlinked legacy students use the compatibility name. Renames after a freeze never rewrite retained roster labels. Cover rename-before-freeze, rename-after-freeze and legacy fallback without changing eligibility or lock order.
- Replace the old finalized-correction-success assertion because the user selected a superseding policy; include same-session save/cancel races and both commit orders.
- Every session detail/summary returns authoritative nullable replacement_session_id computed from the direct child, even when parent and child are on separate pages or the child is canceled; no unbounded pagination is needed to decide eligibility.

**Work steps:**

- [x] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [x] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [x] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [x] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [x] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [x] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 scripts/test_database.py attendance_integrity_test.sql
python3 scripts/test_database.py ministry_academic_test.sql
python3 scripts/test_database.py ministry_follow_up_test.sql
python3 scripts/test_database.py ministry_session_management_test.sql --seed-before-migration 202610190009_ministry_session_management.sql --seed-scenario ministry_session_management_legacy_seed.sql
python3 scripts/test_database.py --ministry-academic-concurrency
python3 scripts/test_database.py --ministry-follow-up-concurrency
flutter test --no-pub --concurrency=1 test/database/attendance_integrity_test.dart test/features/ministry/data/ministry_repository_test.dart test/features/ministry/domain/ministry_models_test.dart test/data/supabase_gateway_ministry_contract_test.dart
```


**Director fixture arbitration:** Task 2 fixture arbitration: strict class-session summary envelopes now require the two nullable linkage keys. Permit adding null linkage keys only to existing summary fixtures in lesson_session_test.dart, session_navigation_test.dart, session_visual_test.dart and ministry_journey_test.dart. Preserve test assertions, comparator/goldens and application behavior. Actual first full suite failed 26 tests in the first three files on the changed wire shape; the journey fixture uses the same producer contract. No product UI change is authorized by this narrow expansion.

### Task 3: Own attendance retries as an immutable pending command

Introduce a small composed controller that preserves exact intent across ambiguous responses and discards obsolete protected work.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s07-attendance-operation-ownership`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s10-architecture-sequence`

**Files owned:**

- `lib/features/ministry/ui/attendance_save_controller.dart`

**New registered test files:**

- `test/features/ministry/ui/attendance_save_controller_test.dart`

**Interfaces consumed:** MinistryRepository.command({name,operationId,payload}); SessionNavigationContext; gateway protected boundary and injectable operation ID factory.

**Interfaces produced:** AttendanceSaveController.submit({context,expectedRevision,marks,finalize}) -> Future<void>; retryPending() -> Future<void>; clear() -> void; immutable PendingAttendanceSave and read-only pending/isBusy/hasUnknownResult state.

**Acceptance:**

- Capture operation ID, expected revision, deep-copied marks, selected congregation/class/session, protected generation and finalize exactly once.
- Timeout/network/5xx retains the captured command and unknown state; retryPending sends byte-equivalent logical payload with the SAME operation ID and action.
- Changing the caller-owned marks map after capture cannot change the pending payload; alternate submit while unresolved is rejected.
- Acknowledgement clears pending state; a proven non-committing rejection requires fresh read and explicit decision before a different request.
- Operation conflict does not masquerade as success or prove non-commit; clear/identity change discards pending protected data and late responses.
- No persistent/offline queue, global mutable state or new package is introduced; use composition and the existing repository/boundary ports.
- The selected AttendancePage owns the controller: same-page rebuild/resume retains pending intent, deliberate pop warns then disposes/clears it, return starts from a fresh read, and security invalidation clears immediately without a blocking warning.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
flutter test --no-pub --concurrency=1 test/features/ministry/ui/attendance_save_controller_test.dart
```

### Task 4: Connect read-only attendance and cancellation/replacement UX

Integrate exact retries and immutable presentation into the existing class-bound lesson flow without losing scope or return position.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s06-immutable-finalization-and-replacement`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s07-attendance-operation-ownership`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `lib/features/ministry/ui/attendance_page.dart`
- `lib/features/ministry/ui/session_list.dart`
- `lib/features/ministry/ui/session_form.dart`
- `test/features/ministry/ui/lesson_session_test.dart`
- `test/features/ministry/ui/session_navigation_test.dart`
- `test/features/ministry/ui/session_visual_test.dart`
- `docs/verification/l1/visual-review.md`

**New registered test files:**

- `test/features/ministry/ui/attendance_history_test.dart`

**Interfaces consumed:** Task 2 lineage-aware repository/models; Task 3 controller; existing SessionNavigationContext and selected-session navigation.

**Interfaces produced:** Production immutable attendance/retry UI and explicit cancel-then-create replacement flow; same router and selected class/session identity.

**Acceptance:**

- Finalized/canceled sessions render labeled read-only marks and no enabled edit/save actions; open sessions still support draft/finalize.
- Finalization explains immutability; no success is announced before acknowledgement. On unknown outcome, mark changes and alternate actions are disabled and retry preserves the original action.
- Confirmed cancellation shows exact class/date/topic; replacement stays disabled until cancellation is acknowledged.
- Eligible canceled rows offer Registrar substituta, prefill fixed class/date and pass replacesSessionId; original history remains visible and linked.
- A canceled parent with a child cannot create another direct replacement; replacing a canceled child forms the next chain link.
- Back, pagination return, same-scope resume, scope loss, identity/congregation change and obsolete replies preserve established protected-navigation guarantees.
- Leaving an unknown request explains it may have completed; returning performs a fresh read and no automatic resend.
- Apple Design familiarity/agency/feedback apply through existing Base44 components: immediate standard feedback, meaningful text states, keyboard focus, no artificial delays, reduced motion and usable 360/768/1440 layouts at 200% text.
- Pagination-separated parent/child fixtures hide Registrar substituta on the parent using replacementSessionId; a stale eligible read followed by another actor creating a child yields a conflict and authoritative refresh, without automatic reparenting or a new operation-ID retry.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
flutter test --no-pub --concurrency=1 test/features/ministry/ui/attendance_history_test.dart test/features/ministry/ui/lesson_session_test.dart test/features/ministry/ui/session_navigation_test.dart test/features/ministry/ui/session_visual_test.dart
```

### Task 5: Expose bounded enrollment history with strict typed transport

Add only the missing student-enrollment read, retaining the existing progress RPC and authorization boundaries.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s08-enrollment-history-and-progress`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `supabase/migrations/202610200004_student_enrollment_history.sql`
- `supabase/tests/database/student_enrollment_history_test.sql`
- `lib/features/ministry/data/ministry_codec.dart`
- `lib/features/ministry/data/ministry_repository.dart`
- `lib/data/supabase_gateway.dart`
- `test/features/ministry/data/ministry_repository_test.dart`
- `test/data/supabase_gateway_ministry_contract_test.dart`
- `docs/integration/ministry-completion-contracts.md`

**New registered test files:**

- `test/database/student_enrollment_history_test.dart`

**Interfaces consumed:** Existing Ministry access/cursor helpers and getEnrollmentProgress({congregationId,enrollmentId}) -> EnrollmentProgress.

**Interfaces produced:** Migration 202610200004; ieadpe_ministry_list_student_enrollments(request jsonb) -> jsonb; StudentEnrollmentSummary; MinistryRepository.listStudentEnrollments({required String congregationId,required String studentId,int limit=50,String? cursor}). StudentEnrollmentSummary is defined in lib/features/ministry/data/ministry_codec.dart with the existing read-summary DTOs.

**Acceptance:**

- Exact request is congregation_id,student_id,limit,cursor; response items contain only id,class_id,class_name,start_date,end_date,status,revision plus next_cursor.
- Return same-scope active/completed/withdrawn enrollment history ordered start_date DESC,id DESC; 1..100 limits, limit+1 continuation and 101-row traversal are bounded.
- Signed cursor binds actor/resource student_enrollments/congregation/student/date/id; wrong actor/student/scope or tampering fails.
- Authorize before student lookup; anonymous/foreign/revoked access and malformed envelopes/types/limits are denied with the specified safe errors.
- StudentEnrollmentSummary and listStudentEnrollments strictly validate keys, UUIDs, positive revision, enums and date-only values; obsolete responses fail closed.
- No new direct table grant and no N+1 progress computation is added.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 scripts/test_database.py student_enrollment_history_test.sql
flutter test --no-pub --concurrency=1 test/database/student_enrollment_history_test.dart test/features/ministry/data/ministry_repository_test.dart test/data/supabase_gateway_ministry_contract_test.dart
```

### Task 6: Present persisted enrollment progress in student and class context

Use the bounded history and existing progress RPC to finish the normal operator workflow, including closed history and cancellation refresh.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s08-enrollment-history-and-progress`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `lib/features/ministry/ui/enrollment_progress_panel.dart`
- `lib/features/ministry/ui/student_detail_page.dart`
- `lib/features/ministry/ui/class_enrollment_panel.dart`
- `lib/features/ministry/ui/class_detail_page.dart`
- `test/features/ministry/ui/student_academic_link_test.dart`
- `test/features/ministry/ui/enrollment_lifecycle_test.dart`

**New registered test files:**

- `test/features/ministry/ui/enrollment_progress_test.dart`

**Interfaces consumed:** StudentEnrollmentSummary/listStudentEnrollments from Task 5; existing getEnrollmentProgress and EnrollmentProgress denominator/percentage/roundedPercentage.

**Interfaces produced:** EnrollmentProgressPanel({required MinistryRepository repository,required String congregationId,required String enrollmentId}); reusable production history/progress presentation.

**Acceptance:**

- Student detail pages active and closed enrollment history; an explicit selection loads only that enrollment progress, not every row.
- Class roster/detail exposes the same reused progress panel for the selected enrollment, retaining class/congregation return context.
- Present/absent/excused values come from fresh server reads; denominator present+absent, zero denominator displays Sem aulas avaliadas, and canceled/unfinalized sessions do not count.
- After finalization/cancellation/replacement, revisiting refreshes persisted progress/follow-up; no local counter increments fabricate state.
- Loading/empty/error/retry/stale/forbidden states are actionable; pagination and late reply generation checks prevent cross-student or cross-scope display.
- Base44 familiarity and grouping, immediate feedback, named controls, focus/keyboard order, reduced motion and 200% text work at 360/768/1440.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
flutter test --no-pub --concurrency=1 test/features/ministry/ui/enrollment_progress_test.dart test/features/ministry/ui/student_academic_link_test.dart test/features/ministry/ui/enrollment_lifecycle_test.dart test/features/ministry/ui/class_management_test.dart
```

### Task 7: Restore scope compatibility and align legacy contact fixtures

Resolve the documented archived campaign-scope regression while preserving current verified bindings and Ministry restrictions.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s09-scope-compatibility-and-account-presentation`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `supabase/migrations/202610200005_campaign_scope_compatibility.sql`
- `supabase/tests/database/base44_unified_access_test.sql`
- `supabase/tests/database/ministry_registry_test.sql`
- `supabase/tests/database/teacher_contact_detail_test.sql`
- `supabase/tests/database/unified_scope_test.sql`
- `test/features/auth/auth_repository_test.dart`
- `test/widgets/unified_navigation_test.dart`
- `docs/integration/ministry-completion-contracts.md`

**Interfaces consumed:** Existing ieadpe_get_scope() JSON fields and verified binding semantics; archived scope contract from Base44 access design.

**Interfaces produced:** Forward migration 202610200005 and coherent scope/fixture evidence; unchanged public scope keys and no client-manufactured authority.

**Acceptance:**

- Campaign congregation_ids retain assigned archived direction IDs; Ministry IDs/picker exclude archived congregations and Ministry writes remain denied.
- Keep verified Auth/contact-email predicates, binding/access locks, version behavior, global allowlist authority and user_access as the sole assignment source.
- An old ministry_grants row cannot grant/revoke effective authority; metadata/title cannot grant privilege.
- Old contact fixtures supply explicit email:null where appropriate; retain stale revision, revoked replay, own/foreign and teacher birth-date assertions.
- All four formerly drifting standalone scope/contact scenarios pass under the explicit contract; do not weaken assertions to accept permission errors.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 scripts/test_database.py base44_unified_access_test.sql
python3 scripts/test_database.py ministry_registry_test.sql
python3 scripts/test_database.py teacher_contact_detail_test.sql
python3 scripts/test_database.py unified_scope_test.sql
flutter test --no-pub --concurrency=1 test/features/auth/auth_repository_test.dart test/widgets/unified_navigation_test.dart
```

### Task 8: Finish safe session greeting and Admin Team entry

Apply the existing bounded recovery proposal without confusing display metadata with authorization or hiding backend failures.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s09-scope-compatibility-and-account-presentation`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `lib/features/auth/session_display_name.dart`
- `lib/features/home/home_page.dart`
- `lib/app.dart`
- `lib/features/admin/access_panel.dart`
- `lib/features/admin/admin_page.dart`
- `test/features/home/home_page_test.dart`
- `test/features/admin/admin_page_test.dart`
- `test/features/auth/auth_flow_test.dart`
- `test/workflows_test.dart`

**New registered test files:**

- `test/features/auth/session_display_name_test.dart`

**Interfaces consumed:** Existing AuthRepository session metadata, AccessScope.hasMinistryAccess and existing scope-refresh callback.

**Interfaces produced:** String? sessionDisplayName(Map<String,dynamic>? metadata); nullable HomePage.name; AccessPanel required canOpenTeam and Future<void> Function() onScopeRefresh in addition to onOpenTeam.

**Acceptance:**

- Select trimmed nonblank string full_name then name; null/malformed values show Olá!; never use email or metadata as a role.
- Actual app wiring passes the active identity display name and clears it on identity change; no prior name survives a new session.
- AccessPanel receives canOpenTeam and onScopeRefresh; admin-only inconsistent scope stays in Admin with the exact spec warning and Atualizar acesso.
- Valid Ministry scope opens Team; registrars still cannot reach Admin/Team; no scope flags or router grant semantics are broadened.
- Convert RPC errors stay visible as failures, not empty lists or unrestricted table-read fallbacks.
- Neutral greeting and recovery action are readable with visible focus/keyboard access at phone width and 200% text; preserve Base44 theme and immediate feedback.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
flutter test --no-pub --concurrency=1 test/features/auth/session_display_name_test.dart test/features/home/home_page_test.dart test/features/admin/admin_page_test.dart test/features/auth/auth_flow_test.dart test/workflows_test.dart
```

### Task 9: Make browser-runner contract tests portable

Exercise actual Windows and POSIX resolver branches independently of host OS without changing correct production platform behavior.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s02-engineering-baseline-and-execution-boundaries`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `scripts/test_unified_journey_runner.py`
- `scripts/test_unified_gate.py`
- `test/operations/configuration_test.dart`

**New registered test files:**

- `test/operations/corrective_runner_test.dart`

**Interfaces consumed:** Existing _supabase_executable/_chromedriver_executable and loopback runner/gate contracts.

**Interfaces produced:** Portable tests with host-independent fixtures; existing production resolver contract retained.

**Acceptance:**

- Windows fallback tests select/mock the Windows branch and construct matching temporary paths; POSIX tests prove Windows LOCALAPPDATA does not override PATH behavior.
- Run the former 23/25 runner/gate cases with zero failures on Linux; Windows behavior is tested explicitly rather than bypassed.
- Preserve local-only endpoint guard, bounded preflight, capability/Origin checks, exit 1 FAIL and exit 2 BLOCKED semantics.
- No test requires project credentials, makes remote calls or swallows a missing executable as PASS.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 -m unittest discover -s scripts -p 'test_unified_*.py'
flutter test --no-pub --concurrency=1 test/operations/corrective_runner_test.dart test/operations/configuration_test.dart
```

### Task 10: Drive both verification gates from one complete case manifest

Prevent Bash/PowerShell divergence and require all standalone SQL, seeded upgrade and concurrency acceptance.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `scripts/verification_cases.json`
- `scripts/verification_cases.py`
- `scripts/verify_unified.sh`
- `scripts/verify_unified.ps1`
- `scripts/test_verification_cases.py`
- `scripts/test_unified_gate.py`
- `.github/workflows/verify-unified.yml`
- `docs/verification/unified-matrix.md`

**New registered test files:**

- `test/operations/corrective_gate_test.dart`

**Interfaces consumed:** Existing test_database.py contained-path/seed arguments; run_unified_journey.py fail-closed status; scenarios from Tasks 1/2/5/7.

**Interfaces produced:** verification_cases.json with sql entries {scenario,seed_before_migration?,seed_scenario?} and concurrency entries {flag}; verification_cases.py emits/validates argument arrays for both shells.

**Acceptance:**

- Manifest records every standalone *_test.sql scenario exactly once, with explicit pre-migration seeds for canonical_person_link_test and ministry_session_management_test.
- Include all existing nine concurrency suites and new attendance/replacement races; stale or unlisted standalone scenarios cause a coverage failure.
- Both platform gates consume identical argv cases and preserve child exit status; local health/browser checks reject hosted URLs before probes.
- SQL/Python focused tests are also called from Dart wrapper tests so the resolved Flutter runtime cannot silently skip them.
- Manifest validation is credential-free and covers missing file, duplicate entry, path traversal, wrong seed target/order and race omission.
- CI pins compatible Flutter/fonts and Chrome/ChromeDriver, starts local Supabase and keeps full raw evidence without secret output; no hosted project is used.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 -m unittest discover -s scripts -p 'test_verification_cases.py'
python3 -m unittest discover -s scripts -p 'test_unified_gate.py'
flutter test --no-pub --concurrency=1 test/operations/corrective_gate_test.dart
```

### Task 11: Verify the current coupled journey in local Chromium with bounded cleanup

Replace the obsolete unscoped-create/transfer journey and prove persistent identity, immutable attendance, replacement and automatic follow-up through production UI.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s05-canonical-handoff-reads`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s06-immutable-finalization-and-replacement`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s08-enrollment-history-and-progress`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s11-verification-and-release-gates`

**Files owned:**

- `integration_test/unified_journey_test.dart`
- `scripts/run_unified_journey.py`
- `scripts/test_unified_journey_runner.py`
- `test/workflows_test.dart`
- `docs/verification/unified-final-report.md`

**Interfaces consumed:** Completed production contracts/UI and loopback-only fixture runner; existing real local Auth Admin API for synthetic identities.

**Interfaces produced:** Updated integration test and bounded lineage/canonical cleanup; new dated executed result in unified-final-report.

**Acceptance:**

- Registrar selects an allowed active congregation at create and cannot inspect protected lists; student registration without conversion fields creates no conversion/visit obligation.
- Production UI creates/selects a canonical person, edits identity, enrolls once, creates lesson, drafts/finalizes, reopens read-only persisted marks/progress and shows effective discipleship/follow-up.
- Explicit convert handoff still works with canonical lookup; no congregation transfer is attempted in the typed edit form.
- A new finalize=true AND finalize=false write to finalized attendance is denied with unchanged storage; exact receipt replay succeeds.
- Cancel original then create linked same-date replacement; retained original roster/marks remain unchanged; only finalized non-canceled replacement contributes to progress/follow-up.
- Cross-congregation reads/writes, existing-token revocation, identity/scope changes and obsolete replies are denied/cleared using actual local Auth and HTTP.
- Cleanup removes only run-owned attendance/rosters/enrollments/students/converts/persons/dependencies in FK-safe order, including replacement lineage; unrelated fixtures survive partial failures.
- A real compatible local Supabase HTTP stack plus Chromium/driver execution yields PASS; unavailable prerequisites remain BLOCKED and cannot close browser acceptance.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 -m unittest discover -s scripts -p 'test_unified_journey_runner.py'
flutter test --no-pub --concurrency=1 test/workflows_test.dart
python3 scripts/run_unified_journey.py
```

### Task 12: Prepare exact hosted-state inspection and local upgrade rehearsal

Produce an auditable activation package while keeping this pipeline local-only and detecting the already-present/unrecorded Base44 changes.

**Spec:** `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s12-hosted-activation-and-recovery`, `docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md#s13-legacy-evidence-and-android-delivery`

**Files owned:**

- `scripts/inspect_hosted_contracts.py`
- `scripts/rehearse_hosted_upgrade.py`
- `scripts/test_hosted_upgrade.py`
- `docs/operations/unified-migration.md`
- `docs/operations/unified-release.md`
- `docs/verification/ministry-completion-inventory.md`
- `docs/verification/ministry-corrective-activation-package.md`

**New registered test files:**

- `test/operations/hosted_upgrade_preparation_test.dart`

**Interfaces consumed:** Expanded hosted evidence, all corrected migrations, existing local test fixtures and the parent release/migration runbooks.

**Interfaces produced:** Read-only inspector and loopback-only rehearsal CLI; reviewable activation package with version classification and exact ordered migration/checksum list.

**Acceptance:**

- Inventory tool has explicit --project-ref and --output, READ ONLY catalog queries, no scope RPC, token printing, personal rows or apply mode; credentials use the managed channel.
- Classify recorded+present, fully-equivalent unrecorded, absent and partial/conflicting states per version; inspect indexes/policies/grants and data transformations, not only one column or ledger row.
- Rehearsal refuses non-loopback targets and never defaults to hosted; seed a disposable production-shaped baseline through 202610180002 with ledger through 018.
- Demonstrate that blindly replaying existing Base44 DDL fails; independently prove equivalent objects and guard reconciliation before producing a reviewable ledger-repair proposal.
- Exact ordered local upgrade includes 202610180003, all nine October 19 migrations and all five corrective October 20 migrations; test partial resume and stop on deliberate catalog drift.
- Upgrade preserves counts, stable IDs, manual states, snapshots, scope/replay rules and current RPC envelopes; expected hashes and roles are recorded without private records.
- Activation package names target/source/migration digests, backup/restore checks, old-client compatibility/write-pause plan, monitoring and rollback/stop conditions; no hosted writes or ledger repair is executed.
- Unknown Firebase source and unavailable APK/device evidence remain explicit blockers; do not infer source absence from empty Ministry tables or invent supported import shapes.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, resumes the same OpenCode coder session for Critical/Important corrections and records the re-review. No commit/push without separate user authorization.

**Focused verification** (expected PASS, except the initial meaningful RED):

```text
python3 -m unittest discover -s scripts -p 'test_hosted_upgrade.py'
flutter test --no-pub --concurrency=1 test/operations/hosted_upgrade_preparation_test.dart
```

## Local closing gate

- [ ] Director verifies all task families, exact contracts, candidate hashes, full-suite/analyzer results and Sol review outcomes; every Critical/Important finding is closed, with explicit minor disposition.
- [ ] Run `bash scripts/verify_unified.sh` and `pwsh -NoProfile -File scripts/verify_unified.ps1` against the same prepared local stack; retain complete command logs. Any FAIL/BLOCKED/INCOMPLETE keeps local acceptance open.
- [ ] Execute the real Chromium journey with local Auth/Storage; mocked HTTP/widget evidence alone cannot close it. Verify cleanup after success and partial failure.
- [ ] Run `flutter build web --no-pub` plus `python3 scripts/web_preflight.py build/web`. Run the applicable Android build only with public configuration and the existing approved signing process.
- [ ] Perform director whole-product review across canonical registration, Team, classes, enrollment, immutable attendance/replacements, progress and conversion follow-up. A collection of individually approved tasks is not assembled-product approval.
- [ ] Write `docs/verification/ministry-corrective-local-report.md` with source/candidate identity, command/exit/evidence table, requirement R01-R11 disposition, live/fixture distinction and outstanding operational/device blockers. No hosted activation or completed delivery claim follows automatically.

## H1 — Prove recovery and reconcile the exact hosted upgrade package

**Predecessors:** all local tasks/closing acceptance and the reviewable activation package from Task 12. **Files:** `docs/verification/ministry-corrective-activation-package.md`, `docs/operations/unified-migration.md`, `docs/operations/unified-release.md`.

- [ ] Refresh project identity, ledger, columns/constraints/indexes/policies/grants/function hashes and aggregate risk counts through the authorized read-only channel. Never call binding `ieadpe_get_scope` as inventory.
- [ ] Obtain an authorized encrypted database backup and applicable private Storage inventory/backup, outside Git. Restore to an isolated destination and verify counts, constraints, stable links/history and required object access. Record hashes/location authority and recovery procedure, not private contents.
- [ ] Verify every effect of the unrecorded `202610180001/002` changes. If any effect is partial/conflicting, stop for a dedicated reviewed repair; if equivalent, prepare exact ledger reconciliation through the verified channel. Do not blindly replay existing CREATE/ALTER or mark unknown DDL applied.
- [ ] Rehearse the ordered pending sequence: `202610180003`, October 19 `001` through `009`, then October 20 `001` through `005`. Preserve old/new client compatibility or define an explicit write pause/update boundary; new nested create/edit envelopes must not break an active old APK silently.
- [ ] Present the final concrete target/source/migration-hash/backup/rollback package for user authorization **before hosted writes**. This plan and PAT availability do not themselves authorize cutover. If no recovery or exact-state proof is available, record BLOCKED and continue independent artifact work.

## H2 — Authorized activation and real-role acceptance

**Predecessor:** separately authorized H1 package. **Files:** the same operations/inventory/activation documents and `docs/verification/ministry-corrective-hosted-report.md`.

- [ ] Apply only the approved ledger repair and verified missing forward migrations through the confirmed operator channel, recording each result. Stop on drift/failure; do not proceed with a partially incompatible app.
- [ ] Verify required table/RPC shapes, RLS/grants and schema cache. Confirm the formerly missing convert-list RPC is present, while anonymous own-table/directory probes remain denied.
- [ ] Exercise real technical-admin, supervision, direction and denied identities using isolated traceable records. Verify current and foreign congregation HTTP reads/writes, existing-token revocation, scope booleans/counts and named picker/navigation. Do not widen permissions to make a test pass.
- [ ] Complete create-once -> canonical edit -> enroll -> lesson/draft/finalize -> reopen read-only/progress -> warning clears -> cancel/replacement -> fresh-session persistence; explicit convert handoff remains covered separately.
- [ ] Verify Google callback/login/cancel/logout, actual Storage upload/read own/foreign denial, and exact configured return paths. Account PAT success is not Auth-session evidence.
- [ ] Clean only run-owned fixtures in dependency/lineage order and record the result. On data-integrity/authorization/recovery failure, halt new writes and use the reviewed recovery path; never delete source history to make reconciliation pass.

## H3 — Legacy reconciliation

**Predecessor:** compatible hosted model plus an authorized source export or verifiable source-absence record. **Files:** operations migration runbook and supported-source mapping/rehearsal evidence; implementation of a new importer requires a bounded brief for the actual exported schema.

- [ ] Determine original Firebase/source availability separately from current empty Ministry tables. Preserve stable source IDs and source/export retention.
- [ ] Map congregation/person/academic/history identities explicitly. Retain unresolved rows; no name-only merge or fabricated conversion/baptism/presence values.
- [ ] Rehearse repeat import and rollback on an isolated target and reconcile all entity/link/history counts plus manual/derived states. Canonicalize legacy imports by reviewed stable keys before claiming editable canonical coverage for them.
- [ ] Obtain authorization for the concrete reconciled import package before real import. If the source is unavailable, keep H3 BLOCKED; do not invent a shape or state that no records existed.

## D1 — Exact Android candidate and delivery

**Predecessors:** local green, compatible authorized hosted state and an explicit legacy disposition. **Files:** `pubspec.yaml` version, delivery report, existing Android signing/configuration process; binaries/private defines stay outside source control.

- [ ] Record intended project/public configuration and identify the installed APK if possible. Build a versioned candidate using only public URL/key and the approved existing certificate; no service/PAT/Google secrets in defines/artifacts.
- [ ] Record source SHA plus candidate delta, SHA-256, package, version/build and signing certificate continuity. Verify web routing and exact OAuth return configuration separately when delivering web.
- [ ] Observe install/update on an available Android target, login return, proper greeting/Admin Team behavior, 200% text, back/resume, revoked access and persisted full journey after reopening. User-confirmed physical-device observations are explicit evidence; widget captures are not substitutes.
- [ ] Director performs final assembled review with stage Sol findings and live/device evidence, then writes `docs/verification/ministry-corrective-delivery-report.md`. Mark local/hosted/legacy/device categories independently.
- [ ] Commit/push/merge, APK publication and delivery destination require the corresponding user instruction; no historical Taildrop or packaged push default is silently reused.

## Traceability and completion

| Requirement | Implementing work | Acceptance category |
|---|---|---|
| R01 import compatibility | B1, Task 12, H3 | SQL/replay/race, upgrade and supported-source reconciliation |
| R02 canonical operational identity | Task 1, Task 11 | SQL minimal projection, current-name lookup and production journey |
| R03 immutable finalized call/replacement | Tasks 2/4/11 | New-operation denial, exact replay, cancellation lineage and persisted history |
| R04 exact ambiguous retry | Tasks 3/4/11 | Lost response, changed intent exclusion, identity/scope invalidation |
| R05 persisted history/progress | Tasks 5/6/11 | Bounded histories, selected-enrollment progress, canceled exclusion and fresh reopen |
| R06 authority/compatibility | Task 7, Task 12, H1/H2 | Archived scope contract, actual schema/ledger and real-role allow/deny |
| R07 safe presentation/recovery | Task 8, H2/D1 | Metadata-neutral greeting, valid/invalid Team scope and real session |
| R08 verification quality | B0-B3, Tasks 9/10/11, local closing | Full raw results, seeded SQL/races, portable gates and real browser |
| R09 recovery/activation | Task 12, H1/H2 | Rehearsed exact upgrade, restore evidence and reviewed target package |
| R10 legacy status | H3 | Stable-ID reconciliation or explicit remaining blocker |
| R11 exact delivered artifact | D1 | Hash/package/version/certificate and observed device journey |

Definition of Ready per unit: accepted relevant spec, exact interfaces/owned files, predecessor evidence and necessary capabilities. Definition of Done: observed intended behavior/denials, meaningful tests and current gate evidence, resolved Critical/Important review findings and honest category disposition. No unit counts as done because code exists, a worker says completed or unrelated tests pass. All full-delivery categories must pass for a complete delivery claim.

Planning self-review must validate the JSON with the installed canonical validator, every spec anchor/path, dependency acyclicity, new-test path ownership, and R01-R11 coverage. A valid JSON means structurally compatible planning data, not a successful pipeline/model/provider run. No product tests are claimed from document validation.


## 2026-10-20 completion map and bounded delivery addendum

Author: native Sol 6.1 low. Assessment only; no tests/builds/remote writes were performed for this document. Existing plan/spec remain the owners; no new plan is necessary. Read [S15 acceptance and approval boundaries](../specs/2026-10-20-ministry-corrective-release-design.md#s15-completion-assessment-and-bounded-delivery-clarification--2026-10-20). Preserve the dirty branch and no-commit/no-push constraint.

### Task-by-task completion assessment

Statuses distinguish scoped approval from branch/release acceptance. Coder `completed` is not approval. The director supplied the recorded native Sol low verdicts for T01–T10 and T12 after correction-6; where the durable report still says pending, the approval is attributed to that director record and must be attached to the final evidence index, not invented inside an older worker report.

| Unit | Status | Evidence inspected / exact remaining boundary |
|---|---|---|
| B0 | Partial environment readiness; browser/platform prerequisites blocked | `build/verification/corrective-release/B0/local-stack-review.md`; Flutter/SQL tooling usable, full local Supabase image extraction capacity blocked. Android SDK installed, no attached target. Replace obsolete CLI readiness with native agent readiness. |
| B1 | Approved local | `docs/verification/2026-10-20-corrective-execution.md` B1; `build/verification/corrective-release/B1/review.md` and review hashes. Import SQL/replay/concurrency evidence; no real legacy import. |
| B2 | Approved local | Same execution report B2; `B2/review.md`, `promotion-review.md`, font provenance and reviewed visual captures. Real device/accessibility acceptance separate. |
| B3 / combined bootstrap | Approved historical local checkpoint | Execution B3 and `B3/review.md`: 459 tests, zero diagnostics, stable candidate. Does not replace current full-suite gate. |
| T01 canonical identity | Approved local | Execution Task 1; `T01/review.md`, candidate hashes, SQL/Dart evidence; 461-test checkpoint. Hosted RPC absent. |
| T02 finalization/replacement | Approved local | Execution Task 2; `T02/review.md`/JSON, hashes; nine gates, 465 tests. Real-session/browser/device unexecuted. |
| T03 immutable pending command | Approved scoped, director-recorded Sol verdict | `T03/coder-report.json` corrective pass2 and c1–c4 RED/GREEN logs; report itself correctly retains pending approval. Earlier SEND_BACK findings must not be mistaken for final verdict. Attach final director/Sol record before closing ledger. |
| T04 attendance UX | Approved scoped, director-recorded Sol verdict | `T04/coder-report.json`, production-boundary loopback regressions; worker report retains pending reviewer wording. Browser/screen-reader/device not covered by these tests. |
| T05 enrollment history | Approved scoped, director-recorded Sol verdict | `T05/coder-report.json`, migration `202610200004`, strict bounded SQL/transport tests; no full-suite or live browser claim from this unit. |
| T06 persisted progress UI | Approved scoped, director-recorded Sol verdict | `T06/coder-report.json`, correction-1 focused RED/GREEN and analyzer; full browser persistence/device still open. |
| T07 authority compatibility | Approved scoped, director-recorded Sol verdict | `T07/coder-report.json`, migration `202610200005`, SQL/Dart fixture corrections; hosted authority remains old. |
| T08 greeting/safe Team | Approved scoped, director-recorded Sol verdict | `T08/coder-report.json`; existing `session_display_name.dart`, app/Home/Admin tests. Original APK draft now a reference, not unfinished duplicate work. Real Google session still pending. |
| T09 portable runner | Approved scoped, director-recorded Sol verdict | `T09/coder-report.json`, Python/Flutter runner tests; no full local browser claim. |
| T10 complete verification manifest | Approved scoped, director-recorded Sol verdict | `T10/coder-report.json`, `scripts/verification_cases.json`, Python/Dart gates. Stubs prove runner contracts, not actual full stack/CI passage. |
| T11 coupled Chromium journey | Incomplete / blocked | No T11 executed acceptance report found. `integration_test/unified_journey_test.dart` still needs the exact current journey plus actual local Auth/Storage/Chromium run and cleanup proof. Full stack capacity is a blocker. |
| T12 hosted preparation | Approved local with 006 + real checkpoints | Durable `build/verification/corrective-release/T12/continuation-006/sol-final-review.md`: exact 16 migrations through 006, 17 actual catalog checkpoints, derived manifest and real loopback rehearsal approved locally. Correction-6 preparation remains historical. Hosted inventory/parity, ledger repair and activation remain unapproved. |
| T04–T07 assembled checkpoint | FAIL / unresolved branch acceptance | `CHECKPOINT-T04-T07/checkpoint-report.json`: full suite 528 pass/1 failure in `test/database/task_3_test.dart`, analyzer exit 0; isolated race rerun passed. Retain both; do not relabel full run green. |
| Local closing | Incomplete | No complete current two-platform gate + actual local journey + final source-bound full-green report. Earlier expanded-review SQL/visual/analysis gaps require explicit current dispositions, not automatic inheritance as present defects or implicit closure. |
| H1 recovery/exact package | Blocked | No encrypted-backup/isolated-restore evidence; ledger/schema mismatch; fresh complete hosted fingerprints and Base44 data/guard equivalence pending. T12 preparation is a dependency, not H1 completion. |
| H2 activation/real roles | Blocked, unapproved mutation | Target healthy but required identity/RPC/authority absent; current converts HTTP 404. Health endpoints do not prove allowed roles, OAuth or Storage policies. |
| H3 legacy reconciliation | Blocked | Firebase export or verified source absence unproven; current zero academic totals cannot waive it. Supported-source mapping/repeat import/reconciliation required. |
| D1 installed/downloadable APK | Blocked | Debug signing configured, no release certificate decision, no attached target and no APK. Aborted debug run exit 143 is not test/build failure. Signing/install/full hosted journey/download evidence absent. |

### Does the existing scope cover functional delivery?

Yes at the outcome level: Tasks 1–12, local closing, H1/H2/H3 and D1 already cover the product corrections, recovery, activation, legacy and Android delivery. It is not complete in execution. Do not create duplicate feature tasks or regenerate approved code. The bounded gaps are precision of OAuth configuration approval, signing ownership/recovery/update proof, final independent review, and downloadable-byte identity. The following subordinate checklists refine H1–D1; they do not add a replacement backend or new product feature.

### Execution and verification policy for remaining work

Native Luna Medium implements one bounded task at a time; a fresh native Sol 6.1 low reviewer checks each task read-only. An independent final reviewer checks the assembled product/evidence and unresolved findings. Do not use OpenCode or historical CLI session-resume instructions. Reviewer findings return to that task's native implementer. The director owns approval arbitration and evidence indexing; no automatic commits/pushes. Read applicable engineering skills when execution is approved; planning review is the current stop point.

For a new behavioral defect, record named assertion/runtime RED with at least one test actually run, implement the minimum correction, then GREEN plus relevant SQL/HTTP/UI regression. Reuse valid approved RED/GREEN evidence when candidate hashes match. Environment checks, read-only inventory, backup operations and artifact inspection need direct evidence, not artificial failing product tests. Run focused task commands first; run integration/full gates at shared-boundary checkpoints, after relevant changes, and once on the final candidate. Do not rerun 529 tests for every document/tool check. No red full-suite waiver is implied.

### Addendum L0: Reconcile approvals and close local assembly (existing T11/local closing)

**Files:** modify `integration_test/unified_journey_test.dart`, `scripts/run_unified_journey.py`, `scripts/test_unified_journey_runner.py` only under T11 scope; update `docs/verification/ministry-corrective-local-report.md` and execution summary. Consume completed task interfaces from this plan/JSON; produce a source/hash-bound local acceptance index.

- [ ] Attach final T03–T10/T12 approval records and hashes; reconcile stale status/checklists without deleting worker history. Validate machine-plan coverage with `python3 -m unittest discover -s scripts -p 'test_verification_cases.py'`; exit 0 required. Do not treat the old JSON CLI executor metadata as current dispatch authority.

  **Dated reconciliation note (2026-10-21):** the manifest/fixture validation passed 8/8 (exit 0), and the new [approval reconciliation index](../../../build/verification/corrective-release/L0/approval-reconciliation/approval-index.json) attaches the director-attributed scoped approval source and current identity limits for T03–T10. However, durable individual final Sol review artifacts for T03–T10 were not located, so the attachment condition is not met and this checkbox intentionally remains open. T04-P and T12-006 have separate durable local approvals; neither replaces the missing named-task records. This note does not alter historical worker reports or close L0.
- [ ] Investigate the retained access-lock failure using original failure/isolated logs and deterministic concurrency assertions. If product/test correction is required, create a bounded RED/GREEN brief for the actual cause; never skip/relax the race assertion.
- [ ] Complete T11's exact assertions: production registration/canonical edit/enroll/draft/finalize/read-only/progress/cancel/replacement/fresh session plus scope loss and cleanup. Follow T11 owned files/commands; run `python3 scripts/run_unified_journey.py` against a complete loopback stack, require exit 0 and run-owned cleanup proof.
- [ ] Run `flutter test --no-pub --concurrency=1` and `flutter analyze --no-pub` on final stable candidate, require all tests pass and zero diagnostics. Run both existing unified shell gates against that same stack; preserve exit/log/category results. Any required BLOCKED/FAIL remains open.
- [ ] Review 360/768/1440, 200% text, error/empty/loading, keyboard and reduced-motion evidence; run web build/preflight as existing closing gate requires. Record current disposition for every expanded-review finding, distinguishing fixed local from unexecuted live proof.
- [ ] Sol low reviews local assembly; director records source SHA plus dirty-file hashes, commands/exits, approval links and remaining H/D gates. Do not mark overall delivery complete.

### Addendum H0: Recovery/source package before H1/H2 mutations

**Files:** existing activation package and migration/release runbooks; protected dumps/source exports remain outside repository. Consume T12 classification and current hosted read-only snapshot; produce exact package for G1/G2 in S15.

- [ ] Refresh inventory using an authorized read-only managed channel; record target/project, ledger, complete semantic fingerprints and aggregate link/count invariants. Never probe binding scope RPC as inventory. PAT is not SQL credentials.
- [ ] Obtain encrypted DB/Auth-recovery material and Storage inventory/bytes/policies, record digests/custodian; restore in isolated approved infrastructure and prove counts/constraints/RLS/links/history/object access. Measure restore time and obtain owner-approved recovery point/time objectives.
- [ ] Inspect original Firebase/source export or independently verifiable absence; reconcile stable IDs, archived/tombstoned/history totals and ambiguous mappings plus Base44/current data. Dry-run repeat import in isolation; unknown source remains BLOCKED. If actual schema requires new importer behavior, author a bounded source-specific spec/task before product code.
- [ ] Prove every 180001/180002 DDL/data/guard effect, propose exact ledger commands only for fully equivalent versions, pin 15 forward migrations/checksums and resume/drift criteria. Unknown state stops; no blind ledger repair/push.
- [ ] Present concrete maintenance owner/window, old-writer pause proof, backup/restore/source evidence, SQL order/checksums, monitoring, rollback/reconciliation commands and stop conditions. Ask for target-specific G1 authorization only after this package exists. Permission grants/import require their own G2 package and approval.
- [ ] After separately authorized execution, perform existing H2 live-role/Storage/persisted journey checks with run-owned records; halt on authority/integrity mismatch and follow reviewed recovery procedure. Record local/hosted/legacy states separately.

### Addendum O1: Exact Google/admin identity configuration (H2 refinement)

**Files:** `docs/operations/google-oauth.md`, activation package and `docs/verification/ministry-corrective-hosted-report.md`; inspect existing `lib/features/auth/auth_repository.dart` and Android manifest; change product auth files only for a demonstrated bounded regression. Consume S15 A1/A2 and server authority; produce config identity plus real-session evidence.

- [ ] Read existing OAuth runbook; inspect Google Cloud/Supabase project ownership, provider/web client identity, basic scopes and callback configuration using protected operator evidence. Record exact setting diff and intended account/grant scope with no keys/emails/UIDs in public evidence.
- [ ] Confirm service callback `https://voqmtnqjrbugpazcimvh.supabase.co/auth/v1/callback` separately from Android `ieadpe://login/auth/callback`; localhost/provider-enabled evidence alone does not pass. Present any console/provider/grant mutations as explicit G2 approvals with exact before/after diff and test/rollback procedure.
- [ ] After authorized changes and compatible backend, test fresh/existing Google login, cancel/denial/back, cold/warm Android callback, expired/replayed/missing-verifier handling, offline/online logout, user switch and revoked-grant resume. Capture sanitized codes/outcomes only, no callback tokens/verifiers.
- [ ] Verify intended global manager's real scope and greeting/converts/Team; direction/supervision/registrar and foreign scope obey server rules. Sol low reviews actual results; unresolved real-session access keeps H2/D1 blocked.

### Addendum D0: Release key custody and platform readiness (D1 prerequisite)

**Files:** `android/app/build.gradle.kts`, `pubspec.yaml`, `docs/operations/unified-release.md`, delivery report; private key/properties stay outside source. Consume package identity/public backend config; produce approved certificate/version/toolchain identity.

- [ ] Locate prior distributed APK/certificate evidence and package owner decision; inspect existing certificate continuity before proposing a key. Record package `br.org.ieadpe.ieadpe_converts`, chosen monotonic version code and supported min/target SDK/ABIs from resolved toolchain, not guessed constants.
- [ ] Prepare exact signing diff replacing debug release signing, key custodian/encrypted backup/restore policy and update compatibility consequences. Obtain explicit G3 authorization before key generation/signing-policy change; do not expose private material.
- [ ] Prepare an authorized Google-capable Android emulator and physical device, browser/callback connectivity and storage capacity. Record API/device/browser versions and `adb devices -l` proof. Missing targets remain BLOCKED.
- [ ] After G3 approval configure release signing privately, prove keystore recovery/expected public certificate and ensure no debug certificate is accepted by release gate. Pin SDK/JDK/Flutter/Gradle/dependency/public config identity without credential values.

### Addendum D2: Exact artifact, installed acceptance and verified download (D1 refinement)

**Files:** existing release runbook and `docs/verification/ministry-corrective-delivery-report.md`; output APK outside tracked source; product changes only through a bounded corrective task. Consume local/H1–H3/O1/D0 evidence; produce S15 A9 evidence manifest and reviewed G4 publication package.

- [ ] Only after execution/build authorization and prerequisites, run `flutter build apk --release --no-pub --dart-define-from-file=<private-public-settings.json>` via argument-safe invocation; settings contain only public URL/publishable key. Require exit 0 and actual APK existence. Never count the prior exit-143 abort as this result.
- [ ] Run Android SDK `apksigner verify --verbose --print-certs <apk>` and `aapt dump badging <apk>` (or installed equivalent); require expected release certificate/package/version/SDK/ABIs. Record SHA-256/size, source SHA plus reviewed dirty delta hashes, configuration identity and toolchain/dependency versions.
- [ ] Install exact bytes fresh on emulator and physical target; record installed package/version/certificate and compare with artifact. Update an approved preceding same-certificate version; verify continuity and retained intended local state. If no compatible prior version exists, disclose that limitation and obtain release-policy disposition rather than fabricate an update pass.
- [ ] Run A1–A8 against intended hosted backend on installed APK, including fresh-session persisted academic journey, scope revocation, 200% text/back/resume, Storage policy and SAF XLSX cancellation/write/reopen with accents. Record device/browser/API and sanitized outcomes, not personal screenshots.
- [ ] Independent final reviewer reads full assembled diff, task reviews, source/artifact identity and local/hosted/legacy/device matrix; resolve Critical/Important findings and explicit minor disposition. A collection of task approvals cannot replace this review.
- [ ] Prepare G4 review package: exact APK digest/certificate/source, full acceptance logs, release notes/limitations, destination/access audience/retention and rollback/removal/update procedure. Obtain explicit publication/deployment authorization for the exact destination and artifact; no upload before approval.
- [ ] After authorization, publish exact bytes; download using intended recipient access, verify HTTP success, filename/MIME/size/SHA-256 match and install downloaded copy. Report working URL, checksum, package/version/certificate and supported Android version; failed/expired/inaccessible download keeps delivery incomplete.

### Coverage and self-review

S15 A1/A2 -> T08/O1/H2/D2; A3/A4/A5 -> T01/T07/T11/H2/H3; A6/A7 -> T02–T06/T11/H2; A8 -> local closing/H2/D2; A9 -> D0/D2. G0 is review of this assessment/addendum; G1/G2/G3/G4 remain explicit future actions with concrete evidence prerequisites. No additional feature task is justified by this assessment. The APK draft remains a historical Task 8 reference; executing its old queue would duplicate approved work.

Self-review checked all units B0–B3/T01–T12/local closing/H1–H3/D1, source-versus-hosted evidence, stale report wording, no secret values and no duplicate implementation queue. The machine JSON remains historical local-task scope; this reviewed Markdown addendum governs operational refinements and current native dispatch. No existing checkbox was falsely marked complete.

**Exact review question:** Does this completion map accurately capture the existing plan's approved local work and remaining acceptance gates, and do the bounded delivery clarifications cover the functional downloadable APK you intend, using native Luna Medium implementation and Sol 6.1 low task reviews plus independent final review?


## T04-P: bounded first-save roster preview correction — 2026-10-21

**Owner:** Sol 6.1 low authors brief/spec/plan and independently reviews; native Luna Medium implements. **Spec:** S16 above and existing S06/S07/S11. This is corrective work within T04's promised open draft/finalize/replacement interface; SQL ownership below is the explicit bounded extension to the original T04 file list. It does not reopen completed tasks wholesale or authorize hosted migrations. Do not use OpenCode, commit/push, build APKs or run full suites before L0.

**Files authorized for implementation:**

- Create `supabase/migrations/202610200006_attendance_roster_preview.sql` — read-only projection of eligible preview in existing attendance RPC. Number confirmed locally free on 2026-10-21; recheck before creation.
- Create `supabase/tests/database/attendance_roster_preview_test.sql` — actual SQL eligibility, no-DML, first-save, drift and authority tests.
- Create `test/database/attendance_roster_preview_test.dart` — existing contained disposable-SQL wrapper convention, child exit propagated.
- Modify `lib/features/ministry/ui/attendance_page.dart` — preview/frozen/empty text and controls using existing rosterFrozen only.
- Modify `test/features/ministry/ui/attendance_history_test.dart`, `test/features/ministry/ui/lesson_session_test.dart` — UI first-save/ack/reload/scope regression coverage.
- Modify `test/features/ministry/ui/session_visual_test.dart` only for directly affected preview assertions; inspect any reference difference, no automatic golden promotion.
- Modify `scripts/verification_cases.json` only to register the new standalone SQL scenario using existing manifest schema; no runner redesign.
- Modify `docs/integration/ministry-completion-contracts.md` only for S16 read-preview semantics without envelope changes. Spec/plan/brief remain Sol-owned.

**Interfaces consumed:** existing `getSessionAttendance({required congregationId,required sessionId}) -> MinistryRoster`, existing Session.rosterFrozen, marks map and AttendanceSaveController. **Produces:** identical typed transport with S16 preview semantics; writer/controller signatures, locks, receipts and strict decoders unchanged. No new library, table or RPC endpoint.

- [ ] Capture preexisting dirty-file hashes/status; read S16 and existing first-freeze SQL. Verify 006 remains free and target is owned disposable loopback before SQL.
- [ ] Write `attendance_roster_preview_test.sql` and wrapper assertions for open/unfrozen ordinary and replacement sessions with eligible enrollments but zero stored roster/marks. Execute valid SQL RED: authorized read expected nonempty eligible unmarked rows currently returns empty. Missing DB/compile errors are BLOCKED/test defects, not RED.
- [x] Implement the exact S16 function replacement in forward migration only; preserve complete existing session envelope, access checks, search_path and grants. Prove no new schema/table access and no read DML. Do not edit historical migrations or writer code.
- [x] Test date endpoint inclusivity, closed historical eligibility, excluded future/expired/foreign rows, canonical pre-freeze names and legacy fallback, zero eligible, frozen-empty, terminal unfrozen and stored snapshot preservation. Test actual first draft with returned IDs, fresh read, explicit finalize/replay and terminal denial. Change eligibility between preview/save; prove roster_mismatch and no partial stored changes.
- [ ] Write UI RED/GREEN for preview copy/controls, empty-finalization prevention, no pre-ack frozen claim, acknowledged reload, terminal read-only and late-scope-response discard. Implement minimal AttendancePage changes; do not alter controller rejection classification.
- [x] Register new SQL scenario in existing verification manifest and document unchanged envelope plus preview semantics in exact contracts. Run focused tests below; record each exit and raw evidence.
- [x] Sol independently reviews actual diff/hash-bound RED/GREEN, permission/envelope invariants and no-seeded-roster first-save proof. Record scoped verdict; blocked SQL remains explicit. No task approval substitutes for T11 actual browser/L0 acceptance.

**Focused verification (expected exit 0 after meaningful RED):**

```text
python3 scripts/test_database.py attendance_roster_preview_test.sql
python3 scripts/test_database.py attendance_integrity_test.sql
flutter test --no-pub --concurrency=1 test/database/attendance_roster_preview_test.dart test/features/ministry/ui/attendance_history_test.dart test/features/ministry/ui/lesson_session_test.dart
python3 -m unittest discover -s scripts -p 'test_verification_cases.py'
flutter analyze --no-pub lib/features/ministry/ui/attendance_page.dart test/database/attendance_roster_preview_test.dart test/features/ministry/ui/attendance_history_test.dart test/features/ministry/ui/lesson_session_test.dart
```

Run focused session visual test only if affected; format changed Dart and `git diff --check`. Do not run broad/full gates now. Missing owned DB => SQL BLOCKED, not mock PASS. No hosted credentials/queries/migrations are needed or authorized.

**Dependent release gates:** T11 resumes against production first-save behavior without privileged roster setup. T12 owner must add 006 to exact migration order/checksums, semantic snapshots/classification/rehearsal and activation package under a separately scoped review; the existing 15-migration preparation does not cover 006. Do not silently modify T12 tools/manifests in this task. L0 later reruns assembled current full suite/analyzer/local browser gates; H1/H2 retain exact-state, restore and explicit authorization requirements. No hosted migration is executed under this addendum.

**Report:** `build/verification/corrective-release/T04-first-save/coder-report.json` and `implementation-summary.md`, with owned file hashes/source identity, command/exit/raw RED/GREEN evidence, no-DML/first-save/drift/authority matrix, manifest coverage, blocked gates and `approval_status: pending_independent_sol_review`. Brief: `build/verification/corrective-release/T04-first-save/sol-corrective-brief.md`.

Self-review: same RPC/envelope/permission boundary; only open-unfrozen read semantics change. New SQL ownership and release dependency are explicit; no hosted execution or automatic closure of T11/T12/L0 is implied.

**Machine-plan reconciliation:** the existing JSON remains unchanged and describes original Tasks 1–12, including original T04 ownership. T04-P is an explicit supplemental Markdown unit with its own files, registered new-test wrapper and brief; it must not be dispatched as unchanged JSON Task 4 or through its historical OpenCode executor. JSON Task 4 alone is insufficient authority for the new SQL files. Native dispatch must attach S16/T04-P/brief together. JSON migration identities through 005 remain historical dependencies, not a complete 006 cutover chain. This documents the deliberate supplement rather than claiming JSON already contains it.

### T04-P local closing record — 2026-10-21

**APPROVED_LOCAL**, per [durable Sol review](../../../build/verification/corrective-release/T04-first-save/sol-final-review.md). This dated record supersedes earlier SQL-blocked status for the reviewed local candidate while preserving the original checklists/history. Real SQL `revocation-fixture/real-sql-green.log` exited 0 (SHA-256 `04ee04a3d1d5046dbd5136c1717fb4cc2d55e026ba59c5d16119776346922daf`); attendance integrity SQL passed, contained focused Flutter tests 43/43, session visual 6/6, manifest tests 8/8 and scoped analyzer clean, as linked in that review. Migration 006 digest: `a422ca796a1ec3fade9cdc6cce82d8dd06cbfce890801e274fcb40f9080bdaeb`; corrected fixture digest: `ac89601fe02a4ee3287d270be956c78c0eb9b431f7e17ef0d028a647e4b48ed0`.

The original test-first SQL RED and UI RED/GREEN checkboxes remain unchecked as historical process evidence: the retained UI negative control is a **post-implementation mutation probe**, not reconstructed historical TDD RED. Later temporal/revocation fixture REDs and real SQL GREEN are valid specific correction evidence, not proof of the original missing-preview RED. The initial-preflight checkbox is likewise retained pending a complete contemporaneous capture rather than inferred from final candidate hashes. Functional local approval does not rewrite those history limitations.

T12's dependent 006 integration now has separate [APPROVED_LOCAL review](../../../build/verification/corrective-release/T12/continuation-006/sol-final-review.md), with 17 real checkpoints and derived manifest SHA-256 `2e05cbb0a747d4b34321c6a60f5838e13f043c3d733ec314a299bddc99742fc9`. No hosted migration, parity/ledger repair, restore or release approval follows. T11 browser/cleanup/sentinel, current L0 assembled acceptance, H1/H2/H3, device/signing/APK/download gates remain pending.
