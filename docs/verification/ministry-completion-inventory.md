# Ministry Completion Inventory

Status: I1 evidence draft, 2026-10-18. This records local source and repository metadata only. Hosted state and production record counts are unknown, not passed. No credentials or personal records were read.

## Checkout and evidence boundary

- Worktree: C:/Users/Carlos_Neto/.codex/worktrees/ministry-production-completion
- Branch and HEAD: codex/ministry-production-completion at 2ecba875591e2567cf353d7045b85da44b0a085b (the requested baseline).
- The caller-supplied AGENTS.md workflow applies. No repository AGENTS.md was found in this worktree or its ancestors.
- At inventory start, docs/integration/ministry-contracts.md was modified and docs/integration/unified-design-system.md, docs/integration/unified-input-inventory.md, the completion plan and design spec were untracked. Those pre-existing edits were left untouched.
- Read-only source evidence was inspected at Git revision 4acb563. Paths prefixed by that revision below refer to the original Firebase app.
- The existing contract at docs/integration/ministry-contracts.md:3-5 is explicitly a historical baseline; its independent grant assumptions are superseded. The new completion contract required by the plan does not exist yet.

## APK provenance lead

The repository's documented APK build is tied to source revision 642047f2acbd826b6c25cedb4e0c28e1ed17497e on implementation/supabase-free. That commit is titled “feat: integrate complete application and verify workflows”; its committed docs/verification/final-report.md:3,15 records the branch and a successful debug APK build. The later docs/operations/base44-visual-restoration.md:27 says a subsequent build stalled and left the pre-existing 16 October artifact in place. No APK file is present in this checkout, so its hash, package metadata and certificate cannot be independently checked here. Treat 642047f as the source revision lead, not binary verification.

## Current workflow mapping

The original callable API is exported in 4acb563:functions/src/index.ts:349-377. Original page actions below are direct source evidence; the current UI and repository calls are separate evidence.

| Original workflow | Current local path and data flow | I1 status |
| --- | --- | --- |
| Team contacts, role assignment/replacement, archive/restore and phone actions. Source: 4acb563:lib/features/team/team_page.dart:156; contact_form.dart:150; contact_page.dart:178,297-311; role_replacement_dialog.dart:51,116; phone_actions.dart:57-76. Firebase callables: saveContact, replaceRoleHolder, setContactArchived. | Route is registered in lib/app.dart:671-677. Current TeamPage loads only the directory via MinistryRepository.listDirectory at lib/features/ministry/ui/team_page.dart:46. Local SQL has save_contact, replace_role_holder and set_contact_archived wrappers in supabase/migrations/202610140013_ministry_registry_commands.sql:226-230. The current page does not call these commands or expose a contact form/detail/access editor. | Partial: directory browsing is present; contact and role lifecycle UI is absent. Unified contact-to-login access is also a separate C1/E1/E2 contract gap. |
| Student create, edit, detail/history and archive/restore. Source: 4acb563:lib/features/students/students_page.dart:169; student_form_page.dart:269; student_detail_page.dart:134,281,288-295; student_repository.dart:269. Firebase callables: saveStudent, setStudentArchived. | StudentsPage loads the bounded student list at lib/features/ministry/ui/students_page.dart:46 and opens the handoff at :91. Local SQL defines save_student and set_student_archived in supabase/migrations/202610140013_ministry_registry_commands.sql:232-234; current list is ieadpe_ministry_list_students from supabase/migrations/202610140016_ministry_ui_reads.sql:1. | Partial: list and handoff exist; student create/edit/detail/history/archive UI is absent. |
| Class create/edit/detail/status and teacher selection. Source: 4acb563:lib/features/classes/classes_page.dart:162; class_form.dart:180; class_detail_page.dart:170,322,374-388. Firebase callables: saveClass, setClassStatus. | ClassesPage lists classes at lib/features/ministry/ui/classes_page.dart:40 and opens attendance at :163. Local SQL defines save_class and set_class_status in supabase/migrations/202610140014_ministry_academic_commands.sql:132-133. | Partial: list/filter/navigation exist; class form/detail/status/teacher-management UI is absent. |
| Enrollment add and close/withdraw, selected from a class's eligible students. Source: 4acb563:lib/features/classes/enrollment_editor.dart:94,139. Firebase callables: enrollStudent, closeEnrollment. | The only current enrollment flow is convert/student handoff: lib/features/ministry/ui/convert_handoff_page.dart:229-286 promotes/selects a candidate and calls enroll_student. Local read and commands are ieadpe_ministry_list_class_students, ieadpe_ministry_enroll_student and ieadpe_ministry_close_enrollment. | Partial: handoff enrollment exists; general class enrollment and close/withdraw UI are absent. |
| Lesson/session create, attendance draft/finalize, cancellation and progress. Source: 4acb563:lib/features/classes/class_detail_page.dart:322; attendance/session_editor.dart:72; attendance_page.dart:245-264; attendance_controller.dart:300,418-431. Firebase callables include createSession, saveAttendance, cancelSession, getSessionAttendance, getEnrollmentProgress. | AttendancePage lists pending sessions, opens the roster and calls save_attendance at lib/features/ministry/ui/attendance_page.dart:49,83,117-129; draft/finalize actions are at :314-319. Local SQL defines create_session, cancel_session and save_attendance in supabase/migrations/202610140014_ministry_academic_commands.sql:136-138, plus roster/progress reads in supabase/migrations/202610140012_ministry_access.sql:264-337. | Partial: existing-session roster, draft and finalize are present; class-bound lesson creation, cancellation and persisted class/session history/progress UI are absent. |

Route and access evidence: lib/routing/router.dart:32-42 and lib/app.dart:603-705 register Ministry routes and gate scoped actions from the server-provided access scope. lib/features/auth/auth_repository.dart:100-116 calls ieadpe_get_scope and decodes the ministry booleans/IDs. docs/superpowers/specs/2026-10-18-ministry-production-completion-design.md:27-33 independently records the same visible gaps.

## Current convert follow-up behavior

This is the current convert pathway, distinct from F1's planned attendance/enrollment-derived shared follow-up projection. ConvertRepository.list pages the public `converts` table through Gateway.read (lib/data/convert_repository.dart:17-40). SupabaseGateway performs a Supabase PostgREST table select, with optional congregation equality and name search, undeleted filtering, ID cursor/order and a 100-row page limit (lib/data/supabase_gateway.dart:139-176). This read path uses Gateway.read, not a dedicated convert-list RPC. Authenticated row scope is enforced by converts_scope RLS, which permits only undeleted rows for congregations private.can_access_congregation accepts (supabase/migrations/202610140003_access.sql:43-44); the converts table and stored visit/discipleship fields are defined in supabase/migrations/202610140002_schema.sql:16-33.

HomeRepository fetches ConvertRepository.list pages until the cursor is exhausted, then computes urgentVisits client-side with visitState and counts the stored isInDiscipleship value (lib/features/home/home_repository.dart:22-52). Current convert_policy thresholds are: first visit after 1 day, subsequent visits after 7 days or after 30 days while in discipleship, completion after 90 days, and deviation after at least 3 visits (lib/domain/convert_policy.dart:11-39). The transition UI sends transition_convert (lib/features/converts/convert_actions.dart:104-117), which SupabaseGateway maps to the ieadpe_transition_convert RPC (lib/data/supabase_gateway.dart:605-634). The SQL function updates visit/discipleship fields and inserts convert_events for transitions (supabase/migrations/202610140005_lifecycle.sql:1-62). This describes current stored convert behavior; it does not establish the planned shared attendance-derived projection.

## Local RPC surface

Local client call sites are allow-listed in lib/data/supabase_gateway.dart:183-223 and :251-439; typed ministry adapters are in lib/features/ministry/data/ministry_repository.dart:28-180, ministry_browser_repository.dart:48-132 and ministry_handoff_repository.dart:61-145. The historical contract records request/return envelopes in docs/integration/ministry-contracts.md:52-84. These are local migration/client facts, not confirmation of hosted definitions.

- Scope: ieadpe_get_scope() returns jsonb.
- Read RPCs, each request jsonb to jsonb: ieadpe_ministry_list_congregations, ieadpe_ministry_list_directory, ieadpe_ministry_list_class_students, ieadpe_ministry_get_session_attendance, ieadpe_ministry_get_enrollment_progress, ieadpe_ministry_get_overview, ieadpe_ministry_list_pending_sessions, ieadpe_ministry_list_convert_referrals, ieadpe_ministry_list_convert_student_candidates, ieadpe_ministry_list_students and ieadpe_ministry_list_classes.
- Mutation RPCs, each operation_id uuid plus payload jsonb to jsonb: ieadpe_ministry_save_contact, ieadpe_ministry_replace_role_holder, ieadpe_ministry_set_contact_archived, ieadpe_ministry_save_student, ieadpe_ministry_set_student_archived, ieadpe_ministry_save_class, ieadpe_ministry_set_class_status, ieadpe_ministry_enroll_student, ieadpe_ministry_close_enrollment, ieadpe_ministry_create_session, ieadpe_ministry_cancel_session and ieadpe_ministry_save_attendance.
- Convert handoff: ieadpe_promote_convert_to_student(operation_id uuid, payload jsonb) returns jsonb.
- Relevant local domain models are MinistryContact, Student, ClassGroup, Enrollment, Session, AttendanceMark and EnrollmentProgress in lib/features/ministry/domain/ministry_models.dart:114-554. Handoff DTOs are ConvertReferral, HandoffStudentCandidate and ConvertPromotionResult in lib/features/ministry/data/ministry_handoff_repository.dart:4-50.

## Local migration and test state

There are 21 tracked SQL migrations under supabase/migrations; the latest local migration is 202610180003_base44_unified_access.sql. The baseline contains the ministry schema, access, registry and academic commands, convert/student link, UI reads, unified scope and Base44 follow-up/access migrations. There are 18 SQL scenarios under supabase/tests/database; relevant existing files include ministry_registry_test.sql, ministry_academic_test.sql, ministry_ui_reads_test.sql, convert_student_link_test.sql, unified_scope_test.sql, base44_history_test.sql and base44_unified_access_test.sql. The disposable local runner is scripts/test_database.py.

Recent local history already contains the unified-access implementation and regression hardening; this inventory does not restart that work:

- 8d60ee98d701fe83d6a42c8d97494b876d7f3dc3 adds 202610180003_base44_unified_access.sql and base44_unified_access_test.sql and updates unified_scope_test.sql.
- fbbcf13119cb25a49e8eddbafe6804e652f9a4d8 hardens convert_student_link_test.sql, ministry_academic_test.sql, ministry_access_test.sql, ministry_congregations_test.sql, ministry_registry_test.sql and ministry_ui_reads_test.sql, including concurrency checks.
- d9f79389cefb2186e65e3ab4e8fe1244d26fdfff hardens auth scope/navigation tests in test/features/auth/auth_repository_test.dart and test/widgets/unified_navigation_test.dart.
- The later local verification commits are visible in history through b9daebc and 2ecba87. No test was run for I1.

Static local evidence does not identify a missing local CRUD RPC for the listed contact/student/class/enrollment/session commands. The observed delivery gaps are primarily the incomplete UI paths above, the not-yet-written completion contract, and open hosted state. Which migrations are missing remotely cannot be determined without the hosted ledger.

## Hosted project, ledger and authenticated scope

Observed local project identifier: supabase/config.toml sets project_id to ieadpe-converts. This is a local config value only; no remote project identity was verified. Supabase CLI is not installed, supabase/.temp/project-ref is absent, and no SUPABASE-named environment variable was present (only variable names were inspected). CUA inventory returned no open apps or browsers, so there is no existing authenticated app session from which to request scope.

Blocker: no existing authorized Supabase CLI/database or app session is available in this worktree. Therefore the remote project identity, hosted migration versions, hosted function definitions, recovery/backup state, authenticated role booleans and scoped ID counts remain unknown. No hosted read or write was made. Do not infer “missing schema,” “empty records,” or “hidden route” from this local-only evidence.

## Legacy Firebase export availability

Git revision 4acb563 provides the original Firebase application source and callable definitions, not a production data export. The repository contains no Firebase/Firestore export directory or apparent export package. Filename/metadata inspection found 23 synthetic backup-parser fixtures under test/features/backup/fixtures; these are tests, not ministry records. No fixture or data row was opened. Local record counts are therefore unavailable and no “no legacy records” claim is supported.

Blocker: no local legacy export and no existing authenticated Firebase/source-project session were available for a metadata-only count. Production Firebase record existence and counts remain unknown until an authorized export or verified absence is supplied.

## Exact gaps and next gates

1. C1 must replace the historical contract assumptions with docs/integration/ministry-completion-contracts.md, resolve canonical person/academic identity and the role/lifecycle matrix, and review all current RPC envelopes before code work. Plan evidence: docs/superpowers/plans/2026-10-18-ministry-production-completion-plan.md:28-36.
2. Local backend commands exist for contact, student, class, enrollment, session and attendance operations, but the management screens listed above are incomplete. Implement only after the reviewed C1 contract.
3. Remote migration status/capabilities, role scope and backup/recovery are unknown until an authorized hosted read-only session is available.
4. Firebase export/data status is unknown until source-project metadata or a private export is available. Existing Base44 import tooling is not evidence of a Firebase export or mapping.
5. No Android target was surfaced through the available app/browser inventory; no Android device check, APK build, install or smoke test was performed. Device availability remains unverified.

## I1 checks performed

- git status --short --branch; git rev-parse HEAD; git branch --show-current: confirmed requested worktree, branch and baseline; captured pre-existing integration-doc edits.
- git ls-tree -r --name-only 4acb563; git grep -n on original functions/features: confirmed source workflow files and callable exports without contacting Firebase.
- rg searches across lib, supabase/migrations, supabase/tests/database and docs: mapped current call sites, migration declarations, test files and contracts.
- git log / git show metadata for 642047f, 8d60ee9, fbbcf13, d9f7938 and the current branch: recorded APK provenance lead and pre-existing unified-access work.
- Get-Command supabase, local config/ref-file checks, environment-variable-name check, repository filename/metadata scan and CUA getState: confirmed the local-only blockers above.
- No tests, analyzer, build, hosted query/write, Firebase export, APK read/build, or device interaction occurred.
