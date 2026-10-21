# Unified Discipulado Integration Roadmap

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](../specs/2026-10-20-ministry-corrective-release-design.md), [current plan](2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

Status: implementation integrated; release evidence remains incomplete. The 19-task convert implementation remains the baseline. Work is being executed in the managed worktree `C:/Users/Carlos_Neto/.codex/worktrees/ieadpe-supabase-pipeline/App discipulado` on `implementation/supabase-free`; do not restart the completed convert tasks. Commits through `84ef689` compose the Supabase ministry port, handoff, shared shell, explicitly selected and bounded congregation paging, and verification entry points. No production deployment or private-record migration is claimed.

## Current execution state (2026-10-17)

| Slice | Status | Evidence / remaining work |
|---|---|---|
| 0. Shared contracts | Complete | `docs/integration/ministry-contracts.md`, `handoff-contract.md`, `ministry-sequence.md` and `handoff-sequence.md`; synthetic-only mapping. |
| 1. Shared identity and congregation extension | Complete for local app | Server-derived scope, migration 018 directory RPC, explicit congregation choice with one-page-at-a-time browsing, scoped route guards and revoke/cache tests. Live user provisioning remains release work. |
| 2. Ministry data/invariants | Complete for local app | Migrations 011–018, typed repositories, SQL and independent-session race checks. Firebase production export is not included. |
| 3. Convert flow composition | Complete | Existing convert feature remains under the shared app/session guard; focused workflow and route regressions pass. |
| 4. Convert-to-student handoff | Complete for local synthetic behavior | Atomic one-to-one link, provenance policy, candidate review, idempotency and scoped UI are covered by SQL/widget tests. |
| 5. Migration tooling | Complete for synthetic rehearsal | Deterministic rehearsal and rollback runbook; no private data was exported or imported. |
| 6. Unified quality/release | Implementation complete; release evidence incomplete | Local/CI gate, matrix and release preparation exist. `docs/verification/unified-final-report.md` summarizes the latest run and `build/verification/unified-report.md` contains its gate table. Hosted OAuth/Storage enforcement, integrated browser journey, human accessibility review, Android/device and backup/restore checks remain open. |

The four specs and plans below are execution artifacts already used for this implementation, not future work. Human inspection and external release prerequisites remain tracked in the quality/release plan and report.

## Goal and evidence

Build one Flutter web/Android app in which a campaign worker registers a new convert, authorized discipleship staff follow the same person through student, class, enrollment and attendance workflows, and supervisors see a coherent journey without duplicate identities.

Historical investigation snapshot (2026-10-16; current contracts/evidence are below and in the linked plans):

- The primary `App discipulado` checkout (`flutter-supabase`, commit `c54673b`) contains the captured 101-file Base44 reference and original plan. The separate managed worktree on `implementation/supabase-free` at `642047f` contains the completed Flutter implementation; its `.superpowers/sdd/.../progress.md` records all 19 tasks complete. The final report records 240 passing Flutter tests, clean analysis and web/debug APK builds, while live OAuth/Storage and on-device checks remain release verification work. Do not infer completion from the older primary checkout.
- `discipulado-IEADPE` (`main`, commit `4acb563`, one commit ahead of origin) already contains a Flutter app for team, congregations, students, classes, sessions and attendance. It uses Firebase Auth/Firestore and direct writes in Spark mode. `README.md` explicitly records advisory uniqueness, a best-effort 100-enrollment cap and amplified reads.
- Three IEADPE hardening specs exist: trust/data, verification/quality and UX/governance. Their plan JSON files are currently untracked; preserve and reconcile them, not overwrite them. The original IEADPE spec expects trusted Functions for strict invariants, whereas current Spark mode does not run Functions.
- The conversion plan uses Supabase Google OAuth and PostgreSQL RLS/RPC. IEADPE uses Firebase email/password, `users/{uid}` roles, congregation-scoped collections and a Firebase gateway. Running both backends in one app would produce two identities, two grant systems and a fragile cross-store handoff.
- IEADPE `Student` requires a congregation and carries optional `newConvert`; `Enrollment` is separate and class-bound. The convert schema permits no congregation. There is no current shared person ID or promotion contract. A convert must remain a convert record and history even after becoming a student; enrollment is a later explicit action.

## Decision and alternatives (decision implemented)

**Selected and implemented:** use the Supabase convert app as the integration base and port the IEADPE ministry workflows into its Flutter shell after defining shared identity, congregation, grants and person-link contracts. Preserve the IEADPE implementation as the behavioral and test reference. This retains the Supabase security foundation and avoids two production databases.

Alternative A, retain Firebase for everything: fewer immediate IEADPE adapter changes, but it requires rewriting the accepted convert security/photo/import design and either accepting Spark races or activating billed Functions. Alternative B, two backends behind one Flutter shell: fastest superficial UI merge, but duplicates auth, permission and transactional state. Neither is the default. Revisit the backend choice only if a concrete Supabase constraint fails a local proof, and record the decision before dependent tasks.

## Shared product contract

1. **One identity and authorization source.** Supabase Auth issues the session. Server-side grants map campaign registrar, direction, supervision and discipleship staff to permitted actions and congregation scopes. Registration permission never implies reading a convert. Define an explicit role matrix before implementation; do not map the existing Firebase `supervisor` role to all conversion powers by name alone. Admin provisioning remains trusted and outside the client.
2. **One congregation identity.** Give each congregation one UUID across both modules; import/mapping of existing Firebase IDs and Base44 names is a release migration, not a local development shortcut. Preserve original source IDs in separate unique legacy-key columns. A convert without congregation can be registered, but promotion to student waits for an authorized congregation assignment.
3. **One person journey without forced merging.** Keep distinct `converts` and `students` records and add a unique, nullable `students.convert_id` foreign key (or an equivalent one-to-one server-owned link if schema proof requires it). An authorized `promote_convert_to_student` RPC creates or links the student atomically, copies only explicitly mapped fields, and returns an idempotent result. It does not auto-enroll, infer baptism, rewrite conversion history or expose a convert to staff outside its scope. Resolve possible pre-existing student matches by explicit review, never name-only auto-merge.
4. **Field ownership.** Conversion date, worship type, visit state and campaign events remain owned by the conversion module. Student address, education, baptism answers, class enrollment and attendance remain owned by discipleship. Name, phone and congregation edits need a declared canonical owner or explicit sync policy; until that decision, display source-labelled values and avoid bidirectional write triggers.
5. **Shared boundaries.** Flutter feature repositories call typed domain ports; a single Supabase adapter handles auth, scoped reads, RPC and private Storage. PostgreSQL RLS and transactional RPCs enforce authorization and mutations. UI role checks only guide presentation. No production connection, private-record import or access grant is part of local verification.
6. **UI continuity.** Keep one router and responsive shell. Add campaign registration, convert follow-up and reports as feature routes; add an explicit convert-to-student action and a linked journey view. Keep pt-BR UI copy and English code/specs. Reuse IEADPE accessibility and responsive primitives, adjusting tokens deliberately where brands differ.

## Original roadmap amendment and dependency order (superseded)

The old convert plan remains the baseline; do not replay its 19 tasks. The proposed seven slices below were refined into the four spec/plan pairs at the end of this document and implemented in this worktree. The table is retained as the historical design rationale, not as pending instructions. Skill routing and evidence live in `docs/superpowers/skills-routing.md`, the four specs/plans, and `docs/verification/unified-matrix.md`.

| Order | Spec / plan | Deliverable and acceptance gate | Existing work to carry forward |
| --- | --- | --- | --- |
| 0 | Integration contract and migration inventory | Map roles, congregations, IDs, shared fields, route ownership and source-to-target schemas; synthetic examples cover unassigned converts and an existing student match. Decide canonical field ownership and migration cutover/rollback policy before schema tasks. | Both original specs; Base44 manifest; IEADPE domain and Firestore structure. |
| 1 | Shared identity and congregation extension | Extend the completed Supabase schema, RLS, grants, Google session, gateway and router for discipleship roles and congregation mappings; deny cross-congregation reads and revoked writes in local SQL tests. Existing convert flows still pass. | Completed convert Tasks 1-4 and 7; IEADPE trust-data spec and backend contracts. |
| 2 | IEADPE data migration and invariant recovery | Port congregation, team, student, class, enrollment, session, attendance and overview repositories/commands to PostgreSQL RPCs. Prove unique reservations, 100 total-enrollment cap, frozen roster, atomic attendance, revisions and idempotent retries with competing local sessions. Remove production Firebase adapters only after parity. | IEADPE domain, widgets, emulator scenarios and trust-data plan; preserve history semantics. |
| 3 | Convert flow composition and regression | Preserve the completed convert schema, registration/edit/lifecycle, private photos, weekly guards, events, scoped lists and Home while the IEADPE routes and grants join the same shell. Re-run registrar denial, grant revocation, retry and weekly zero-confirmation races after composition. | Completed convert Tasks 5-6, 8-13 and 17; captured Base44 behavior. |
| 4 | Convert-to-student handoff | Authorized promotion/link RPC and UI, duplicate-review flow, field mapping, deep links and linked journey. Test concurrent promotion, retry after lost response, archived/terminal convert, unassigned congregation, existing student and access changes. Enrollment stays a separate command. | New integration contract plus IEADPE student/enrollment rules. |
| 5 | Report parity and migration tooling | Preserve completed convert reports, safe XLSX and resumable conversion import; add unified scope-aware views and read-only IEADPE migration inventory/rehearsal tools. Synthetic dry runs compare counts, identities and histories; no real data moves without a separate release action. | Completed convert Tasks 14-16 and both projects' data rules. |
| 6 | Unified quality and release preparation | One reproducible gate: Dart/analyzer/build, SQL/RLS/concurrency, widget and end-to-end flows, web/Android checks, responsive/a11y review and actual evidence ledger. Document hosting, backups, OAuth setup, cutover, rollback and release-only prerequisites. | Convert Tasks 18-19; IEADPE verification-quality and UX-governance specs. |

The three IEADPE hardening plans are source evidence for slices 1, 2 and 6, not a parallel Firebase track. Their invariants and UX constraints have been ported to the Supabase plans and local proofs. Implementation followed the SDD task/review cycle with independent subagents; no Firebase runtime was added.

## Integration test journeys

- Campaign registrar creates a convert with no congregation; registration succeeds, listing is denied, and later authorized assignment enables promotion.
- Direction user can follow converts only in granted congregations; discipleship staff see linked students within scope; supervision sees both sides; revocation closes both paths.
- Promotion is retried and raced by two clients; exactly one student link results and no duplicate enrollment appears.
- A convert marked deviated/completed or archived remains historically linked; prohibited actions stay prohibited according to the explicit lifecycle matrix.
- Existing student match is presented for authorized review without name-only merging or leaking out-of-scope candidates.
- Attendance progress uses the IEADPE formula and never changes because of conversion visits; reports preserve conversion and classroom event semantics separately.
- Migration rehearsal imports synthetic legacy IDs twice, produces the same counts and link mapping, and rejects ambiguous congregation/student matches without partial identity corruption.

## Original open decisions and final disposition

- Authentication: the unified app uses the accepted Supabase Google OAuth session. Mapping existing IEADPE identities is a trusted release action; do not silently retire old accounts.
- Shared fields: handoff contracts designate conversion-owned and student-owned data; name, phone and address are provenance-labelled snapshots and do not synchronize silently.
- Historical Firebase/Base44 data: real export/import and cutover need a separate authorized migration decision. No private records moved during implementation.
- Role matrix: campaign and ministry permissions remain separate. Ministry staff get only the authorized referral projection and their congregation's ministry records; they do not gain full conversion history by default.

## Completion rule

The unified app implementation is complete only when the single app and authenticated backend support the registrar-to-classroom journey and scoped security/concurrency checks pass locally. Release approval additionally requires the integrated browser journey and external prerequisites in the generated report. Do not treat code completion as production readiness.

## Executable planning set

The four subsystem specs and JSON plans below were the execution order. Their tasks preserve a testable app and independent review gates. They were executed in the managed worktree; the three IEADPE Firebase plans were treated as inputs and were not run unchanged.

1. `../specs/2026-10-16-convert-skill-alignment-design.md` with `2026-10-16-convert-skill-alignment-plan.json`: audit completed convert code against the new skill checklists and assign concrete gaps.
2. `../specs/2026-10-16-ministry-supabase-port-design.md` with `2026-10-16-ministry-supabase-port-plan.json`: port IEADPE domain, role grants, RLS and transactional invariants.
3. `../specs/2026-10-16-unified-journey-design.md` with `2026-10-16-unified-journey-plan.json`: create the secure one-to-one handoff and compose one Flutter shell.
4. `../specs/2026-10-16-unified-quality-release-design.md` with `2026-10-16-unified-quality-release-plan.json`: run a fail-closed gate, rehearse synthetic migration and prepare release evidence.

Execution disposition: findings from Plan 1 were routed to the owned files and acceptance in Plans 3 and 4; no unrelated rewrite was made. The source fork's `origin/main@ace9e92` domain skills were loaded and routed as recorded in `docs/superpowers/skills-routing.md` before implementation.
