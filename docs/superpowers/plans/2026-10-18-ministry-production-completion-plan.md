# Complete Ministry Delivery Implementation Plan

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](../specs/2026-10-20-ministry-corrective-release-design.md), [current plan](2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox tracking.

**Goal:** Make the integrated discipleship module visible and fully operable in the Android app against hosted Supabase.

**Architecture:** Complete existing Flutter ministry workflows over the existing Supabase RPC contracts. Diagnose and activate the hosted backend explicitly, migrate legacy records if they exist, and verify the exact delivered APK.

**Tech Stack:** Flutter/Dart, Supabase Auth/PostgreSQL/Storage, existing SQL/Python and Flutter verification tools.

**Spec:** docs/superpowers/specs/2026-10-18-ministry-production-completion-design.md

## Revised execution order and mandatory shared-data slice

Execution order: Task 1 -> contract gate -> design foundation -> Task 2A (shared people) -> Task 2B (team/access) -> Task 3 (classes/enrollment) -> Task 3B (derived follow-up) -> Task 4 (lessons/attendance UI) -> Task 5 (hosted activation/data) -> Task 6 (delivery). Each named slice is a separate implementer/reviewer unit. Reminder recurrence is resolved from Base44 source. The contract gate resolves remaining schema/policy choices before dependent code; a vague inventory is not permission to improvise incompatible interfaces.

## Agent execution protocol

- Orchestrator dispatches fresh subagents with fork_turns=none: implementer model gpt-6-luna, reasoning_effort=max; reviewer model gpt-6.1-sol, reasoning_effort=low. Check actual availability before execution; report an unavailable requested model rather than silently substituting. Do not execute product changes during this plan-review request.
- Create/reuse an isolated authorized worktree and follow repository instructions. One writer at a time for shared schemas, contracts, routing and theme. Parallelize read-only research only; dependent slices are sequential.
- Maintain docs/verification/ministry-execution-ledger.md with slice ID, base/head SHA, actual agent model/effort, changed files, exact checks/exit codes, review findings, fixes and local/hosted/device status. No credentials or personal records.
- Implementer brief includes the exact task, approved contracts, dependencies and relevant skill paths/revisions, files allowed, acceptance cases and verification commands. Return implementation summary, commit SHA, tests and limitations. A reviewer receives the same requirements plus base/head diff and evidence; review specification compliance, security, data integrity, usability and maintainability.
- After each slice, Sol returns findings with severity, file/line, reproducible trigger and expected behavior. Luna fixes every critical/important finding; Sol re-reviews fixes and affected behavior until none remain. Do not downgrade/waive a finding merely to finish. Remaining minor findings receive explicit disposition. Run broad final review in Task 6 even after all slice reviews pass.
- Start with narrow regression tests, verify intended RED, implement, then run relevant GREEN checks. Environment/test failures require root-cause investigation; no silent baseline exemptions. Read-only inventory/design documentation uses consistency/evidence review rather than artificial TDD tests.
- Suggested commands from repo root: flutter analyze --no-pub; flutter test --concurrency=1 <owned test paths>; python scripts/test_database.py <owned scenario.sql>; final gate powershell -File scripts/verify_unified.ps1 (inspect its parameters/prerequisites first). Record actual commands, not suggested-command success. Build configuration uses only public Supabase values through a private temporary defines file; never hard-code privileged credentials.
- Hosted writes, import and delivery require available credentials and existing session authorization; prepare reviewable SQL/mapping/artifact first. If user-only authentication/mapping blocks one phase, record the exact blocker and continue independent authorized work; never mark the whole delivery complete.

### Contract gate after Task 1

Create docs/integration/ministry-completion-contracts.md and a schema/field mapping before dispatching UI/schema slices. Sol Low must approve zero critical/important contract findings. Include exact table/column ownership, canonical person identity and academic link cardinality, legacy record mapping, RPC names/payloads/responses/error codes, operation/revision semantics, route/return parameters and per-role read/write matrix. Inspect original Firebase source at Git revision 4acb563 as well as retained Base44 source.

The contract must explicitly resolve: non-new-convert persistence without invented conversion fields; canonical edit propagation and historical snapshots; manual discipleship flags versus active enrollment/withdrawal; earliest valid start date and manual 90-day completion; cancellation/backdated attendance; congregation reassignment with historical class records; team archival versus access revocation. Record product assumptions distinctly from user-approved rules. Preserve legacy state without broadening access; obtain user input only when existing requirements/evidence cannot safely decide a consequential policy. No downstream agent may receive unresolved field/RPC signatures.

### Dispatch manifest and prerequisite completion

I1 drafts docs/verification/ministry-task-manifest.md; C1 finalizes its interfaces and obtains review. For each unit below specify exact existing/new files, consumed/produced RPC signatures and model types, acceptance test names, commands, expected outcomes and predecessor commit. Do not dispatch a code unit until its manifest entry and completion contract are reviewed. This discovery-first gate is deliberate: existing contracts still contain obsolete independent grants and cannot serve as final interfaces unchanged.

| Unit | Dependency | Bounded deliverable and reviewer acceptance |
| --- | --- | --- |
| I1 inventory | none | Exact local/hosted/source evidence and blockers, no product writes |
| C1 contracts | I1 | Reviewed field/schema/RPC/permission mapping and resolved policy table |
| V1 theme | C1 | Shared tokens/component gallery with responsive/accessibility evidence |
| P1 identity | C1 | Forward compatible canonical identity/link migration and SQL tests; no fabricated conversion data or name merges |
| P2 registration | P1,V1 | Two entry points, shared fields, registration-only create-without-read tests |
| P3 academic detail/link | P2 | Academic details and automatic unique link on enrollment, replay/conflict coverage |
| E1 team schema/reconciliation | C1 | Contact/access linkage and safe import mapping; no privilege inferred from job title |
| E2 team UI/lifecycle | E1,V1 | Unified team entry, authorized grant/edit/revoke and historical teacher retention |
| A1 classes | P3,E2 | Class create/edit/status/detail with teacher reference |
| A2 enrollment | A1 | Enrollment/closure, capacity and duplicate boundaries, canonical person selection |
| F1 follow-up backend | A2 | Server-derived enrollment/attendance state through existing session commands, cancellation/replay/boundary SQL tests |
| L1 lessons | A1,A2,V1 | Class-bound session create/list/cancel navigation |
| L2 attendance/progress | L1,F1 | Draft/finalize/read-only history and consistent progress/alerts in production UI |
| H1 hosted activation | P1–L2 | Reviewed exact migrations applied, authenticated scope and HTTP allow/deny evidence |
| H2 legacy data | H1 | Verified absence or rehearsed/reconciled import with unresolved rows preserved |
| D1 delivery | H1,H2 | Whole-product review, required gates, exact APK verification and actual delivery evidence |

These units split the conceptual tasks below; dispatch one unit per fresh Luna agent and one Sol review, not the whole conceptual Task 2. F1 tests existing backend finalization/cancellation commands without depending on new UI; defer its UI end-to-end acceptance to L2. Each manifest entry has the task's RED/GREEN steps, implementation, reviewer gate and commit. Documentation-only units use review rather than TDD.

Policy recommendations for C1 (record as proposed, not user-confirmed): directory-only contacts may omit email; enabled login requires verified-email assignment. Preserve existing local contact-edit rights while only global managers grant access. Effective discipleship is active enrollment OR retained explicit manual historical state; closing enrollment removes only its own active contribution, never invents completion/deviation. Multiple classes preserve participation while any enrollment remains active. Use earliest evidenced qualifying start for the 90-day safeguard; never invent missing dates. Canceled attendance removes its initial-contact contribution unless another valid contact/presence remains. Ordinary congregation changes must not silently relocate historical enrollments; provide an explicit reviewed transfer operation or reject with an actionable explanation. Validate these against current invariants and obtain human clarification only for a consequential conflict the evidence cannot settle.

### Amend Task 2: One registration entry and canonical identity

Task 2A reuses/extracts shared person fields from lib/features/converts/convert_form.dart and register_page.dart. Keep two contextual entries: default simplified new-convert registration and authorized student registration, with safe return destination. The non-new-convert path omits conversion requirements and follow-up obligations. Inspect existing save/update and handoff SQL and implement only the schema/interface selected at the contract gate. Document canonical ownership in docs/integration/ministry-completion-contracts.md; do not reintroduce the legacy standalone identity form.

- [ ] Add RED tests proving both entry points use shared person components and one canonical identity, while registration-only users cannot read records or use the protected student path. Non-new-converts create no fabricated conversion event, date or visit warning.
- [ ] Make academic creation/reuse automatic during enrollment, using an explicit unique person link and server-side permission checks. Add a forward migration only after auditing existing unlinked students and selecting a non-destructive transition.
- [ ] Verify edits to canonical name/contact are reflected in both modules; preserve intentional frozen historical snapshots. Test duplicate operation replay and legacy ambiguous matches without name-only merging.
- [ ] Keep team/teacher management and academic detail/progress from the original task; remove standalone student identity CRUD from its acceptance criteria.

### Task 3B: Couple enrollment and attendance to convert follow-up

**Files:** inspect/modify lib/domain/models.dart, convert_policy.dart, features/converts/convert_card.dart, features/home/home_repository.dart, ministry repositories, docs/integration/ministry-contracts.md; add forward SQL migration(s) under supabase/migrations and regression cases under supabase/tests/database; extend test/domain/convert_policy_test.dart and production workflow integration tests. Exact SQL functions/read projections must be identified in Task 1 before edits.

**Interfaces:** enrollment publishes effective discipleship state; finalized present attendance publishes qualifying follow-up on lesson date; all convert reads/filters/reports receive the same server-derived projection. Preserve actual visit counters and dates. Document field names, historical/manual precedence, recurrence interval and enrollment-ending semantics before coding.

- [ ] Carry recovered Base44 rules into the contracts: 1-day initial contact, 7-day non-discipleship follow-up, 30-day discipleship follow-up; qualifying finalized presence satisfies contact and resets the effective follow-up clock on lesson date. Present and confirm how manual historical discipleship state and closed enrollments interact. Do not infer graduation/deviation from enrollment closure.
- [ ] Add boundary tests at 0/1, 6/7 and 29/30 days and manual-completion boundary 89/90 days. Verify "Desviou-se" remains an explicit confirmed action requiring at least three actual recorded visits/contacts under the existing counter semantics; attendance never increments that counter or automatically marks deviation. Test the no-prior-visit plus qualifying-presence case so initial-contact precedence cannot reintroduce a 1-day alert for an attending student.
- [ ] Write RED SQL and domain tests: enrollment sets Em discipulado; referral alone does not; finalized present clears initial/due visit warning; draft/absent/justified do not; real visit counters remain unchanged.
- [ ] Implement atomic server-side state/projection changes under existing locks/revisions/idempotency. Client-only flag synchronization is insufficient. Ensure policies, dashboard aggregates, list filters and reports use the same effective follow-up rule.
- [ ] Add tests for latest of visit/presence, backdated lesson, recurrence boundary, session cancellation, multiple valid presences, enrollment closure, replay, concurrent finalizations and cross-congregation denial. Cancellation removes only its own contribution.
- [ ] Verify the production journey: shared register -> enroll -> convert card updates -> lesson present/finalize -> visit warning clears -> fresh session confirms persisted consistent state. Include withdrawal and canceled-session cases.
- [ ] Review with Sol 6.1 Low; fix critical/important findings with Luna 6 Max, reverify and commit before hosted activation.

Tasks 4–6 must cover this coupled journey, not only isolated module CRUD. Task 5 must reconcile existing manual flags, real visits, academic links and any imported attendance before activation. Completion requires visible automatic updates in both modules on the delivered app.

## Global Constraints

- Confirmed registration UX: default simplified new-convert entry remains available to authenticated registration-only users; authorized staff get a separate student entry using shared person components, including non-new-convert registration without invented conversion data. Apply this clarification to Tasks 2, 3B and 6; older single-entry wording is superseded.
- Confirmed visual standard: every ministry screen/form/dialog follows the approved Base44 restoration design and existing shared theme/widgets. Each UI task includes synthetic phone/desktop screenshots and large-text review; no legacy Firebase styling. Verify WhatsApp icons/actions, consistent panels/navigation and text-labeled attendance states.

- Preserve the Base44-derived shared permissions and technical-admin global access. Enforce authorization on the server.
- Portuguese UI; English technical documents. Reuse current visual components and Free-tier backend.
- No privileged secrets in application artifacts, repository, logs or reports. No name-only identity merges.
- Preserve revisions, idempotency, frozen rosters, finalized attendance, archival history and existing domain invariants.
- Execution preferences from the user: implementation Luna 6 Max; review Sol 6.1 Low. Resolve every critical/important finding with another implementation/review cycle. Record actual models and do not substitute silently.
- Commit each verified slice. This planning task neither deploys nor implements product changes.

## Review Focus

### Mandatory design foundation before UI implementation

Execute Task 1 investigation, then this foundation before Tasks 2–4. Specification: docs/integration/unified-design-system.md. Inspect and pin the actual Superpowers engineering overlays and Apple Design source available at execution; apply relevant requirements rather than relying on skill names in older plans.

**Files:** extend lib/ui/unified_theme.dart and base44_widgets.dart; add a focused theme-extension/token file only if needed; reuse app_shell.dart and brand_header.dart. Add a test/development-only component gallery and responsive/semantics tests under test/widgets. Do not add a second competing theme.

- [ ] Audit current shared theme/components against the contract; record concrete gaps and resolve token values with an interactive synthetic component preview before broad screen changes.
- [ ] Centralize spacing, typography, radii, semantic colors, sizing and component states; preserve approved Base44 branding. Review the foundation with the user's requested reviewer model.
- [ ] Check gallery at 360/768/1440 and 200% text, focus/semantics, contrast and reduced motion; investigate failures before accepting the foundation.
- [ ] Require each subsequent UI slice to consume these tokens/components, retain visual evidence, and fix critical/important findings. Include both the convert module and ministry module in final consistency review.

1. Correct account still sees no ministry entry because hosted scope differs from local fixtures: Tasks 1 and 5 verify actual scope and navigation.
2. Forms cannot operate from an empty database: Tasks 2–4 prove onboarding without preseeded business records.
3. Navigation silently changes congregation/class: Tasks 3–4 assert identity continuity and cross-scope denial.
4. Timeout/retry or revision conflict duplicates or overwrites records: Tasks 2–4 exercise replay and stale revisions.
5. Finalization, cancellation or later enrollment corrupts history/progress: Task 4 tests frozen rosters and read-only finalized sessions.

### Task 1: Establish exact feature and hosted-state inventory

**Files:** create docs/verification/ministry-completion-inventory.md; read existing ministry UI/data/domain, docs/integration/ministry-contracts.md, supabase/migrations, old Firebase implementation from retained source/Git history.

**Interfaces:** existing ieadpe_get_scope response and RPC payload/return contracts remain authoritative.

- [ ] Confirm checkout, project instructions, exact source APK commit and latest Supabase project identity.
- [ ] Map every original student/team/class/enrollment/attendance workflow to current UI, repository and RPC; classify implemented, partial, absent or obsolete with file evidence.
- [ ] Inspect hosted migration ledger and relevant function definitions read-only. Obtain authenticated scope through the app; record roles/ID counts only. Distinguish hidden route, missing schema and empty records.
- [ ] Inventory legacy Firebase records/export availability. Record counts or verified absence; do not assume data exists or read credentials into output.
- [ ] Record exact missing migrations/capabilities and update later task file maps if evidence requires it. Document any required user-only access without blocking independent local work.
- [ ] Review the inventory and commit it. Task complete only when unknown hosted/data items are explicitly identified, never marked passed by inference.

### Task 2: Complete student and necessary team management

**Task 2B (separate dispatch/review after 2A):** implement the unified Team entry described in docs/integration/unified-input-inventory.md. Include lib/features/admin/access_panel.dart, lib/data/access_repository.dart, ministry contact models/contracts and new forward migrations where required. The standalone access editor must lead to the same linked Team workflow, not duplicate person entry. Resolve directory-only email and local contact-edit policy at the contract gate. Add tests for existing email-only assignments, directory-only contacts, verified binding, duplicate emails, organizational-role replacement, email reassignment, archive versus explicit access revocation, cross-congregation denial, and prevention of local/global privilege escalation. Verify contact/access atomicity and stale-revision/replay handling. Preserve historical teacher references after access revocation. This slice has its own RED/GREEN, Sol review/fix loop and commit before Task 3.

**Task 2A files:** modify lib/features/ministry/ui/students_page.dart, lib/app.dart, lib/features/converts/convert_form.dart, register_page.dart and lib/features/ministry/data/ministry_repository.dart; create lib/features/ministry/ui/student_detail_page.dart and a shared person-fields component only where extraction is needed; add focused tests under test/features/ministry/ui and data. No separate duplicate student identity form.

**Interfaces:** typed methods consume the reviewed completion contracts, reusing existing RPCs when compatible. Student detail exposes canonical person/academic IDs and congregation for enrollment. Enrollment automatically creates/reuses the academic link; standalone referral does not set discipleship state. Existing outdated independent-grant contracts must be reconciled at the contract gate.

- [ ] Add failing workflow tests for empty-state create, edit, validation, archive constraints, stale revision and ambiguous retry; confirm each intended RED assertion.
- [ ] Implement forms/details and teacher/contact management needed for class creation; add bounded read/detail support only if existing contracts lack it, with SQL allow/deny tests.
- [ ] Connect existing-person selection, automatic academic linking at enrollment and authorized non-new-convert registration using shared fields; preserve separate academic history without duplicate identity entry.
- [ ] Run focused UI/data/SQL tests; verify scope loss clears forms, no PII logging and keyboard/large-text usability.
- [ ] Review with Sol Low, fix important/critical findings with Luna Max, reverify and commit.

### Task 3: Complete class and enrollment management

**Files:** modify lib/features/ministry/ui/classes_page.dart and data/ministry_repository.dart; create ui/class_form.dart and class_detail_page.dart beside existing pages; add focused UI/data tests and extend existing ministry academic SQL tests only where needed.

**Interfaces:** existing save_class, class-status, enroll and close_enrollment RPC contracts; selected congregation/class/student IDs and expected_revision explicitly passed to every action.

- [ ] Add RED tests for create/edit class, teacher selection, enrollment from an empty class, duplicate enrollment, capacity 99/100/101, enrollment closure and cross-congregation rejection.
- [ ] Implement class details and enrollment actions with bounded eligible-student lookup, field validation and supported state transitions. Preserve archived/completed history.
- [ ] Verify refresh, pagination, timeout replay and stale revision preserve the correct class/congregation and do not duplicate enrollment.
- [ ] Run relevant UI/repository/academic SQL tests; review/fix loop and commit.

### Task 4: Complete lesson creation and attendance lifecycle

**Files:** modify ministry/ui/attendance_page.dart, class_detail_page.dart, app.dart and ministry/data/ministry_repository.dart; create ministry/ui/session_form.dart and session_list.dart; extend test/features/ministry/ui/ministry_journey_test.dart and applicable SQL tests.

**Interfaces:** create_session/cancel_session/save_attendance RPCs and getSessionAttendance; propagate selected class/session IDs rather than opening an unrelated global pending list. Existing attendance statuses and progress formula remain authoritative.

- [ ] Write RED journey tests: create dated lesson -> frozen roster -> draft -> finalize -> reopen persisted read-only marks/progress. Include cancellation, zero roster behavior from contract and new enrollment after session creation.
- [ ] Implement lesson creation/list/detail navigation, draft/finalize/cancel actions and persisted history/progress display. Require explicit destructive-action confirmation where appropriate.
- [ ] Test finalized-edit denial, scope revocation, retry with same operation ID and stale revision without lost marks. Resolve any demonstrated backend gap with a new forward migration and regression tests.
- [ ] Run focused tests and full Flutter analysis/tests plus affected SQL/concurrency checks; review/fix loop and commit.

### Task 5: Activate hosted integration and reconcile legacy data

**Files:** update docs/operations/unified-migration.md, unified-release.md and docs/verification/ministry-completion-inventory.md; modify scripts/rehearse_ministry_migration.py or create a dedicated real-import builder only after source mapping is established. Add migration tests for actual supported export shape.

**Interfaces:** trusted operator migration channel; hosted ieadpe_get_scope; existing stable legacy source keys and import reconciliation contract. Credentials stay outside client code.

- [ ] Recheck target and missing migration list from Task 1. Establish recoverable backup/rollback evidence; locally apply and test the exact pending migration sequence.
- [ ] Apply only missing reviewed migrations, including 202610180003 when absent. Verify hosted definitions, authenticated admin/supervisor/direction scope, congregation directory and real HTTP own/foreign-scope enforcement.
- [ ] If legacy records exist, create a private export and dry-run mapping, resolve ambiguous congregation/person matches explicitly, rehearse import/rollback and reconcile every entity/link/history count before committing import. Retain source/export. If none exist, record evidence and test blank-state onboarding.
- [ ] Refresh the actual client session and verify the Discipulado entry and named congregation selection. Record executed hosted evidence without personal records/secrets.
- [ ] Review/fix loop and commit operational evidence. Missing credentials or unresolved mappings remain named blockers; other tasks may continue.

### Task 6: Verify and deliver the working Android app

**Files:** extend integration_test/unified_journey_test.dart and existing browser runner as needed; create docs/verification/ministry-delivery-report.md; update Android version metadata in pubspec.yaml for the new delivered artifact.

**Interfaces:** production root/router and repositories, hosted project, APK package/version/certificate continuity and existing Taildrop destination.

- [ ] Run automated full-path tests through production widgets/routes and real local Supabase: fresh student/class/enrollment/session/attendance plus convert handoff. Include global/scoped roles, cross-scope denial, revocation and finalized-edit denial.
- [ ] Run required analysis, Flutter/SQL gates and record actual outcomes. Investigate every failure; distinguish local coverage from hosted/device evidence.
- [ ] Exercise the hosted workflow with isolated authorized records and verify persistence after a new session. Confirm there is no SQL/manual fixture prerequisite for ordinary operators.
- [ ] Perform Sol 6.1 Low whole-product review; use Luna 6 Max for corrections and repeat until zero critical/important findings. Keep nonblocking findings explicit.
- [ ] Build a versioned APK with public configuration only, verify hash/package/version/certificate and test navigation at phone width and large text. Verify install/update on an available Android target; require observed/user-confirmed physical-device results before claiming that category passed.
- [ ] Deliver the verified APK via Taildrop, with concise steps to reach Discipulado. Record remaining external blockers honestly. Merge/push when authorized and distinguish Git delivery, hosted activation and APK delivery in the report.

## Definition of done

All required workflows are accessible and usable from the same installed app; shared permissions are active in hosted Supabase; data is persisted and protected; legacy-data status is reconciled; the exact delivered artifact is identified; no critical/important review findings remain. Unexecuted hosted/device checks prevent a claim of complete delivery.
