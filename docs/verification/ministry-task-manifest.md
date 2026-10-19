# Ministry Task Manifest

Status: C1 source-backed local contract draft, based on current HEAD `a1f326b9f049ba7ea0b9fbcb48f7aafdc7136fbd`; canonical identity and Team policy decisions remain open. This is not approval to dispatch affected implementation. Hosted state remains unknown. All post-C1 predecessor SHAs are pending; record the actual reviewed predecessor SHA before each dispatch.

## Execution rules

- Baseline for I1: 2ecba875591e2567cf353d7045b85da44b0a085b. Exact source APK provenance lead: 642047f2acbd826b6c25cedb4e0c28e1ed17497e; the binary is not available in this checkout.
- Use one writer at a time for shared schemas, contracts, routing and theme. Implementer/reviewer preferences from the plan are gpt-6-luna/max and gpt-6.1-sol/low; verify availability and record the actual model/effort at dispatch. This I1 execution's model/effort was not surfaced in subagent-visible metadata; the orchestrator must enter it in the ledger.
- Local RPC signatures below are observed in current migrations/client code and the historical contract. C1 must approve or replace them before any dependent slice. Mutation envelope: operation_id uuid, payload jsonb -> jsonb. Read envelope: request jsonb -> jsonb. Scope: ieadpe_get_scope() -> jsonb.
- New filenames are proposed exact paths; C1 assigns the migration timestamp and may revise paths in the reviewed manifest. Planned test names are acceptance cases to add/extend, not tests executed by I1.
- Common expected result: focused checks pass, replay/scope invariants remain intact, and no personal data or secret appears in output. Run each Flutter test file separately. Database scenarios use python scripts/test_database.py <scenario.sql>; that runner applies the local migration set to a disposable loopback database.

## Slice entries

### I1 — Local and hosted-state inventory

- Predecessor: baseline 2ecba875591e2567cf353d7045b85da44b0a085b.
- Files: create docs/verification/ministry-completion-inventory.md and docs/verification/ministry-task-manifest.md.
- Interfaces/models: inventory existing ieadpe_get_scope, ieadpe_ministry_* and ieadpe_promote_convert_to_student interfaces; MinistryContact, Student, ClassGroup, Enrollment, Session, AttendanceMark, EnrollmentProgress.
- Acceptance/check: source-to-current path and RPC map has line evidence; local facts are separated from hosted unknowns; no personal rows or credentials. Run git diff --check; expected clean. No automated test.

### C1 — Reviewed completion contracts

- Predecessor/base: current HEAD `a1f326b9f049ba7ea0b9fbcb48f7aafdc7136fbd` (I1 inventory baseline `2ecba875591e2567cf353d7045b85da44b0a085b`). Record this as the C1 documentation base; no commit was made.
- Files changed for C1: `docs/integration/ministry-completion-contracts.md` (new), `docs/verification/ministry-task-manifest.md`, and a narrow pointer in `docs/integration/ministry-contracts.md` preserving its pre-existing user edits.
- Interfaces/models: new contract records exact current local `ieadpe_get_scope`, `ieadpe_ministry_*` read/command envelopes, convert/student handoff and access RPCs, local result/error/revision/replay behavior, route allowlist, role matrix, source mapping, and lifecycle policy. No new canonical-person or contact/access-linked RPC is claimed to exist. Current `ministry_grants` is not current authority after `202610180003_base44_unified_access.sql` locally.
- Policy status: proposed neutral canonical person with 0/1 convert and student extensions; no name merging; shared contact fields have one owner; active enrollment contributes effective discipleship; finalized present attendance is follow-up on lesson date; cancellation removes only its own derived contribution; history is retained. The 90-day completion guard uses the earliest evidenced qualifying start; absent a verified start, completion stays unavailable and no date is invented. Error reporting distinguishes wrapper-emitted messages from caught SQL causes; cursor contracts vary by RPC. Policy gaps are labeled in the contract. **Dispatch blockers:** approve canonical person ownership/cardinality (P1/P2), directory-only/verified-email and local contact-edit rules, contact+access atomicity/pending-state and conflict handling (E1/E2), and precedence for legacy manual discipleship state (F1).
- Hosted status: unknown. Local migrations and source revision `4acb563` are implementation evidence only; no hosted definitions, data counts, migration state, or permissions are asserted.
- Acceptance/check: documentation evidence and policy rows are recorded; run only `git diff --check`. No tests/builds or hosted/device access.

### V1 — Shared visual foundation

- Predecessor: reviewed C1 commit SHA.
- Files: extend lib/ui/unified_theme.dart and lib/ui/base44_widgets.dart; add a small theme extension only if required; add test/widgets/ministry_component_gallery_test.dart.
- Interfaces/models: no backend RPC; shared Flutter theme and widget contracts.
- Acceptance/check: tests “gallery renders shared component states at 360/768/1440” and “gallery remains usable at 200% text”; extend test/ui/theme_contrast_test.dart and test/ui/theme_tokens_test.dart. Run flutter test --concurrency=1 test/widgets/ministry_component_gallery_test.dart and each affected test/ui file; expected no overflow, inaccessible actions or contrast failures. Retain synthetic visual evidence.

### P1 — Canonical identity/link migration

- Predecessor: reviewed C1 SHA; execute after V1 per the plan's global order.
- Files: add supabase/migrations/[next timestamp]_canonical_person_link.sql and supabase/tests/database/canonical_person_link_test.sql; update lib/features/ministry/domain/ministry_models.dart and lib/features/ministry/data/ministry_codec.dart only if the approved contract changes their representation.
- Interfaces/models: preserve ieadpe_ministry_save_student(operation_id uuid,payload jsonb)->jsonb and the approved academic link cardinality. Types: Student plus the C1-approved canonical link model.
- Acceptance/check: new SQL cases “existing links stay unique on migration,” “ambiguous legacy people are not name-merged,” and “unresolved identities remain unlinked.” Run python scripts/test_database.py canonical_person_link_test.sql; expected atomic forward migration and no fabricated conversion fields.

### P2 — Shared registration entry points

- Predecessor: reviewed P1 and V1 SHAs.
- Files: modify lib/features/ministry/ui/students_page.dart, lib/app.dart, lib/features/converts/convert_form.dart, lib/features/converts/register_page.dart and lib/features/ministry/data/ministry_repository.dart; add lib/features/people/person_fields.dart if shared extraction is needed; add test/features/ministry/ui/student_registration_entry_points_test.dart and focused repository coverage.
- Interfaces/models: preserve the current convert create/update API and approved ieadpe_ministry_save_student envelope; do not invent a new RPC before C1. Use the shared person draft and Student model.
- Acceptance/check: tests “registrar creates a convert without ministry reads,” “authorized staff registers a student through shared fields,” “non-new-convert creates no conversion event,” and “scope loss clears the protected form.” Run flutter test --concurrency=1 test/features/ministry/ui/student_registration_entry_points_test.dart and affected repository test file; expected protected read denial and no fabricated conversion data.

### P3 — Academic detail and automatic link

- Predecessor: reviewed P2 SHA.
- Files: add lib/features/ministry/ui/student_detail_page.dart; extend ministry/data/ministry_repository.dart, ministry/data/ministry_handoff_repository.dart and ministry/domain/ministry_models.dart; add test/features/ministry/ui/student_academic_link_test.dart and supabase/tests/database/student_academic_link_test.sql.
- Interfaces/models: ieadpe_ministry_list_class_students(request jsonb)->jsonb, ieadpe_ministry_save_student(operation_id,payload)->jsonb, ieadpe_ministry_enroll_student(operation_id,payload)->jsonb and ieadpe_promote_convert_to_student(operation_id,payload)->jsonb, only as approved by C1. Types: Student, Enrollment and the canonical link model.
- Acceptance/check: tests “enrollment creates or reuses one academic link,” “referral alone does not set discipleship,” “retry returns the same link,” and “ambiguous match is not merged.” Run the focused Flutter file and python scripts/test_database.py student_academic_link_test.sql; expected one unique link and safe replay/conflict handling.

### E1 — Team/access schema and reconciliation

- Predecessor: reviewed C1 SHA.
- Files: extend lib/features/ministry/domain/ministry_models.dart and docs/integration/ministry-completion-contracts.md; add a forward migration with an assigned timestamp and supabase/tests/database/ministry_contact_access_link_test.sql; create lib/data/access_repository.dart only if no compatible repository exists.
- Interfaces/models: current ieadpe_ministry_save_contact and ieadpe_ministry_set_contact_archived envelopes plus the reviewed access-grant RPCs from C1; do not infer access from RoleCode. Types: MinistryContact, ContactScope, RoleCode and the approved access-assignment type.
- Acceptance/check: SQL tests “email-only access remains unlinked safely,” “title does not grant access,” “contact/access link is atomic,” and “revocation blocks access while preserving teacher history.” Run python scripts/test_database.py ministry_contact_access_link_test.sql; expected deny-by-default and no inferred privilege.

### E2 — Unified team UI and lifecycle

- Predecessor: reviewed E1 and V1 SHAs.
- Files: modify lib/features/ministry/ui/team_page.dart, lib/features/admin/access_panel.dart, lib/data/access_repository.dart and lib/features/ministry/data/ministry_repository.dart; add lib/features/ministry/ui/team_contact_form.dart if required; add test/features/ministry/ui/team_lifecycle_test.dart.
- Interfaces/models: current ieadpe_ministry_list_directory and approved contact/access create, edit, replace, archive and revoke RPCs; MinistryContact and reviewed access-assignment type.
- Acceptance/check: tests “directory-only contact has no login,” “verified access is explicitly granted,” “role replacement retains the old contact,” “archive differs from access revoke,” and “local user cannot create global access.” Run flutter test --concurrency=1 test/features/ministry/ui/team_lifecycle_test.dart and affected access repository tests; expected scope denial and recoverable lifecycle states.

### A1 — Class management

- Predecessor: reviewed P3 and E2 SHAs.
- Files: modify lib/features/ministry/ui/classes_page.dart and lib/features/ministry/data/ministry_repository.dart; add lib/features/ministry/ui/class_form.dart, class_detail_page.dart and test/features/ministry/ui/class_management_test.dart.
- Interfaces/models: ieadpe_ministry_list_classes(request)->jsonb, ieadpe_ministry_save_class(operation_id,payload)->jsonb, ieadpe_ministry_set_class_status(operation_id,payload)->jsonb; ClassGroup, ClassStatus and MinistryContact teacher reference.
- Acceptance/check: tests “create and edit class,” “teacher must be an eligible local contact,” “archive preserves history,” “stale revision does not overwrite,” and “cross-congregation teacher is denied.” Run the focused Flutter test and python scripts/test_database.py ministry_academic_test.sql; expected correct class scope and revision.

### A2 — Enrollment management

- Predecessor: reviewed A1 SHA.
- Files: extend lib/features/ministry/ui/class_detail_page.dart and lib/features/ministry/data/ministry_repository.dart; add lib/features/ministry/ui/class_enrollment_panel.dart and test/features/ministry/ui/enrollment_lifecycle_test.dart.
- Interfaces/models: ieadpe_ministry_list_class_students(request)->jsonb, ieadpe_ministry_enroll_student(operation_id,payload)->jsonb, ieadpe_ministry_close_enrollment(operation_id,payload)->jsonb; ClassGroup, Student, Enrollment and EnrollmentStatus.
- Acceptance/check: tests “enroll first student into empty class,” “duplicate active enrollment is denied,” “capacity accepts row 100 and rejects row 101,” “close preserves history,” and “foreign congregation is denied.” Run the focused Flutter test and python scripts/test_database.py ministry_academic_test.sql; expected atomic limits, safe replay and no scope drift.

### F1 — Derived follow-up

- Predecessor: reviewed A2 SHA.
- Files: modify lib/domain/models.dart, lib/domain/convert_policy.dart, lib/features/converts/convert_card.dart, lib/features/home/home_repository.dart, ministry repositories and docs/integration/ministry-completion-contracts.md; add a forward migration and supabase/tests/database/ministry_follow_up_test.sql; extend test/domain/convert_policy_test.dart.
- Interfaces/models: approved enrollment, finalized-attendance and cancellation commands, including ieadpe_ministry_enroll_student, ieadpe_ministry_save_attendance and ieadpe_ministry_cancel_session; Convert state, Enrollment, AttendanceMark and EnrollmentProgress.
- Acceptance/check: tests “enrollment sets effective discipleship,” “referral alone does not,” “qualifying present clears contact warning without incrementing visits,” “draft/absent/excused do not count,” and 1/7/30/89/90-day boundaries. Run flutter test --concurrency=1 test/domain/convert_policy_test.dart and python scripts/test_database.py ministry_follow_up_test.sql; expected identical projection across card/list/report and cancellation replay.

### L1 — Lesson/session creation

- Predecessor: reviewed A1, A2 and V1 SHAs.
- Files: modify lib/features/ministry/ui/attendance_page.dart, class_detail_page.dart, lib/app.dart and lib/features/ministry/data/ministry_repository.dart; add lib/features/ministry/ui/session_form.dart, session_list.dart and test/features/ministry/ui/lesson_session_test.dart.
- Interfaces/models: ieadpe_ministry_create_session(operation_id,payload)->jsonb, ieadpe_ministry_cancel_session(operation_id,payload)->jsonb and ieadpe_ministry_list_pending_sessions(request)->jsonb; Session and ClassGroup.
- Acceptance/check: tests “create class-bound dated lesson,” “session uses selected class,” “duplicate date is rejected,” and “cancel preserves roster history.” Run the focused Flutter test and python scripts/test_database.py ministry_academic_test.sql; expected selected class/session continuity.

### L2 — Attendance, history and progress

- Predecessor: reviewed L1 and F1 SHAs.
- Files: modify lib/features/ministry/ui/attendance_page.dart, class_detail_page.dart, lib/features/ministry/data/ministry_repository.dart and lib/features/ministry/data/ministry_codec.dart; extend test/features/ministry/ui/ministry_journey_test.dart and add test/features/ministry/ui/attendance_history_test.dart.
- Interfaces/models: ieadpe_ministry_get_session_attendance(request)->jsonb, ieadpe_ministry_save_attendance(operation_id,payload)->jsonb and ieadpe_ministry_get_enrollment_progress(request)->jsonb; Session, AttendanceMark and EnrollmentProgress.
- Acceptance/check: tests “lesson draft freezes the exact eligible roster,” “finalize then reload returns persisted marks/progress,” “canceled session is excluded,” “finalized edit follows approved policy,” and “scope loss clears marks.” Run each focused Flutter file and python scripts/test_database.py ministry_academic_test.sql; expected server-derived consistent history.

### H1 — Hosted activation

- Predecessor: reviewed P1 through L2 SHAs and authorized operator access.
- Files: update docs/operations/unified-migration.md, docs/operations/unified-release.md and docs/verification/ministry-completion-inventory.md; use reviewed migrations already produced by earlier slices.
- Interfaces/models: hosted ieadpe_get_scope(), migration ledger and reviewed function definitions; no hosted signature is assumed from local files alone.
- Acceptance/check: read-only migration inventory and function inspection first; then only explicitly authorized reviewed migrations. Verify admin/supervisor/direction scope booleans and ID counts, own/foreign HTTP allow/deny, backup/recovery evidence, and refreshed navigation. Expected hosted definitions match reviewed local contracts. No hosted access was available in I1.

### H2 — Legacy data reconciliation

- Predecessor: reviewed H1 SHA plus an authorized source export or verified absence.
- Files: update docs/verification/ministry-completion-inventory.md and docs/operations/unified-migration.md; modify scripts/rehearse_ministry_migration.py or add a dedicated importer only after the Firebase export shape and identity mapping are reviewed; add a fixture and test for that exact export shape.
- Interfaces/models: no Firebase import RPC or supported export shape is confirmed by I1. Reuse an existing Base44 importer only after C1 proves it is compatible. Map stable source IDs to Student/MinistryContact/ClassGroup/Enrollment/Session/AttendanceMark with unresolved rows preserved.
- Acceptance/check: metadata count and dry-run report reconcile each entity/link/history count; ambiguous people remain separate; rollback rehearsal succeeds; import occurs only after a separate authorization. If source access is absent, keep the blocker and verify empty-state onboarding without claiming production absence.

### D1 — Full verification and Android delivery

- Predecessor: reviewed H1 and H2 SHAs.
- Files: extend integration_test/unified_journey_test.dart and the existing browser runner; create docs/verification/ministry-delivery-report.md; update pubspec.yaml version metadata.
- Interfaces/models: production routes/repositories, reviewed hosted RPCs, package/version/certificate and the approved delivery target.
- Acceptance/check: full workflow covers student/class/enrollment/session/draft/finalize/reload/progress and convert handoff with global/scoped/denied identities. Run flutter analyze --no-pub, flutter test --concurrency=1 integration_test/unified_journey_test.dart, affected python scripts/test_database.py scenarios and the inspected scripts/verify_unified.ps1 gate. Build only with public configuration and approved release signing, using --dart-define-from-file=[private-public-defines.json]; verify APK hash/package/version/certificate and install/update on an available target. Expected local, hosted and device evidence are reported separately; no category passes by inference.

## Dispatch blockers after C1 review

- I1 is committed. The C1 draft has been reviewed with zero critical or important findings. Canonical identity, Team email/edit and contact/access atomicity choices, plus legacy manual-start precedence, remain user decisions; no dependent code slice is ready for dispatch.
- Hosted project identity, migration ledger, hosted function definitions, authenticated scope and backup/recovery evidence are unavailable because there is no Supabase CLI, linked project ref or open authenticated app session.
- No Firebase export or source-project session is available; production data existence/counts and any Firebase import command remain unknown.
- No Android device/session was surfaced or exercised. Device availability, install/update and persisted-data behavior remain unverified.
