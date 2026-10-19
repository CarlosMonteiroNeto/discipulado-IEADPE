# A1 implementation report

## Investigation before implementation

- Worktree: `C:\Users\Carlos_Neto\.codex\worktrees\ministry-production-completion`, branch `codex/ministry-production-completion`, base `101fce21b0d9f5958d04d91d4cc8d0e8fc7ec4df`.
- No repository `AGENTS.md` was found; the supplied global instructions require investigation first, then RED/GREEN tests. Four pre-existing user-owned untracked docs were present and are left untouched.
- A1 brief and full Task 3 plan agree that A1 owns class management only. Enrollment actions remain A2. The reviewed class interfaces are `ieadpe_ministry_list_classes(request)`, `ieadpe_ministry_save_class(operation_id,payload)`, and `ieadpe_ministry_set_class_status(operation_id,payload)`; models are `ClassGroup`, `ClassStatus`, and `MinistryContact`.
- `ClassesPage` currently takes `MinistryBrowserRepository`; `app.dart` constructs both repositories but passes the browser repository to the page. That repository owns the current list projection and returns only `{id,name,status,start_date,end_date,revision}`. The typed `MinistryRepository` already owns `listDirectory` and `getTeacherContact`, but it has no class save/status wrapper. The page's current tap opens attendance directly.
- Existing SQL migration 016 scopes/paginates class-list reads. Migration 014 implements class save/status receipts and revision checks; class save verifies an active contact in the same congregation but does not enforce `role_code='teacher'`; status changes accept any enum status without source-lifecycle guards. `docs/integration/ministry-completion-contracts.md` labels both as forward-migration gaps. The parent approved a narrowly scoped forward migration and a list-projection extension, so A1 uses those existing typed RPCs and does not add enrollment behavior.
- The existing list projection omits `teacher_contact_id`, and no current class-detail RPC exists. The approved extension adds only the nullable teacher UUID to the bounded class summary, allowing edit to retain assignment while excluding contact personal/access data. Scope authorization, filters, ordering, cursor binding, and page bounds remain unchanged.

## Implementation extension point

The parent authorized two scope rulings from the reviewed C1 gaps. First, A1 adds a forward migration and SQL regression coverage for server-side teacher-role and class-lifecycle rules. Second, the existing bounded class-list projection gains only `teacher_contact_id` so edits can preserve the teacher; authorization, filters, ordering, cursor behavior, and exclusion of contact personal/access fields stay unchanged. The review will include the updated C1 completion contract.

Keep `ClassesPage`'s `MinistryBrowserRepository` list/pagination path. Add strict class mutation wrappers and bounded eligible-teacher reads to `MinistryRepository`, then route the new detail/form UI through it. The task remains class-only; no enrollment UI/actions are added.

RED evidence: `flutter test --concurrency=1 test/features/ministry/ui/class_management_test.dart` exited 1 at compile time because `class_detail_page.dart`, `class_form.dart`, `saveClass`, and `setClassStatus` do not exist yet. Since that was not a behavior-level RED, I then ran `python scripts/test_database.py ministry_academic_test.sql` before migration 006. It exited 1 on the new runtime assertion `class list returns the assigned teacher UUID in its bounded summary only`: the old SQL projection omitted `teacher_contact_id`. This identifies the intended missing behavior; subsequent lifecycle/teacher guard assertions are not reached until the projection is implemented.

A temporary widget-only RED also ran: `flutter test --concurrency=1 test/features/ministry/ui/class_management_red_test.dart` exited 1 at `expect(find.text('Nova turma'), findsOneWidget)`. `ClassesPage` rendered zero matching widgets, confirming the missing create action at runtime. This temporary test will be consolidated into the permanent A1 test before it is removed.

## Verification and commit

- `flutter test --concurrency=1 test/features/ministry/ui/class_management_test.dart` — exit 0, 8 tests.
- `flutter test --concurrency=1 test/features/ministry/ui/ministry_browser_repository_test.dart` — exit 0, 9 tests.
- `flutter test --concurrency=1 test/features/ministry/ui/ministry_journey_test.dart` — exit 0, 18 tests.
- `python scripts/test_database.py ministry_academic_test.sql` — exit 0 (`PASS: ministry_academic_test.sql`); ran against the disposable local database.
- `dart format --output=none --set-exit-if-changed lib/features/ministry/data/ministry_browser_repository.dart lib/features/ministry/data/ministry_repository.dart lib/features/ministry/ui/classes_page.dart lib/features/ministry/ui/class_form.dart lib/features/ministry/ui/class_detail_page.dart test/features/ministry/ui/class_management_test.dart test/features/ministry/ui/ministry_browser_repository_test.dart test/features/ministry/ui/ministry_journey_test.dart` — exit 0, 8 files unchanged.
- `git diff --check` — exit 0. The first check found extra blank lines at EOF in the two updated contract/manifest documents; those were removed and the check passed.
- A focused phone-width helper assertion first failed because the professor helper did not specify the two-line layout (`RenderParagraph.maxLines` was null); adding `helperMaxLines: 2` made the assertion pass in the 8-test class-management run.
- Visual capture command: `flutter test --no-pub --concurrency=1 --timeout=30s test/features/ministry/ui/a1_visual_capture_test.dart` — exit 0, 3 capture tests. Its first `pumpAndSettle()` attempt stalled on the class-list capture; replacing that harness wait with explicit pumps (including a 500 ms simulated frame) rendered every screen successfully. The temporary capture test and web preview were removed afterward.
- Inspected and retained six synthetic widget-rendered captures at 360×900 and 1440×900 under `.superpowers/sdd/2026-10-18-ministry-production-completion-plan/a1-visual-evidence/`: `class-list-{360x900,1440x900}.png`, `class-detail-{360x900,1440x900}.png`, and `class-form-{360x900,1440x900}.png`. The harness loaded Flutter SDK `roboto-regular.ttf` and `materialicons-regular.otf` through `FontLoader`. Text and icons are readable; the populated form shows the assigned teacher and its eligibility note wraps fully at phone width. No visible overflow or clipped actions. These are widget captures, not browser or device verification.
- Temporary preview servers on ports 8977 and 8978 were stopped, temporary browser profiles and font-check files were removed, and only the six inspected PNGs remain in the evidence directory.
- No hosted service, Android build, physical device, or screen reader was used. Hosted state and device behavior remain unverified.
- Initial implementation used the originally requested `gpt-6-luna` / `max`; the review-fix round used the updated `gpt-6-luna` / `medium` setting. Runtime metadata is unavailable. Fresh Sol/low final review remains pending.
- Commit: `85eb13e88e7c34677ab7a948960792c95eb75a11` (`Implement Ministry class management`).
