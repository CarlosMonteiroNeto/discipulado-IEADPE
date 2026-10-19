# L1 fixture repair batch report

## Scope and environment

- Worktree: `C:\Users\Carlos_Neto\.codex\worktrees\ministry-production-completion`
- Branch: `codex/ministry-production-completion`
- Scope: validate the interrupted linked-person, lifecycle, and workflow fixture repairs; repair the catalog, academic concurrency, and photo test fixtures where current contracts were confirmed; record remaining SQL fixture failures.
- No product migrations or Task 16 import code were changed.
- Four pre-existing untracked documents were left untouched: `docs/integration/unified-design-system.md`, `docs/integration/unified-input-inventory.md`, `docs/superpowers/plans/2026-10-18-ministry-production-completion-plan.md`, and `docs/superpowers/specs/2026-10-18-ministry-production-completion-design.md`.

## Evidence and verified changes

- `scripts/database_ministry_academic_concurrency.py`: current `ieadpe_ministry_enroll_student` requires `person_id`, and linked student rows must point to a matching congregation scoped person. The fixture now creates and links synthetic people, uses distinct IDs outside its capacity seed range, and sends `person_id` in enrollment payloads.
- `supabase/tests/database/lifecycle_test.sql`: the policy for never-visited records uses `conversion_date` when `last_visit_date` is null. The boundary fixture now sets a null visit date and advances `conversion_date` for never-visited cases.
- `test/workflows_test.dart`: `PersonFields` uses `ValueKey('person-name')`; the Admin flow uses RPCs and no longer calls `/rest/v1/user_access`. The test now uses the current name key and checks the actual current congregation route.
- `scripts/database_catalog_concurrency.py`: the active registration RPC requires `{congregation_id, person, convert}`. Its create race fixture now sends that shape.
- `supabase/tests/database/photos_test.sql`: the active create and edit RPCs require the typed registration shape and linked-person revisions. The fixture now creates in a synthetic active congregation and uses a test-only helper to submit complete revisioned edit payloads for photo replacement checks.

## Focused verification

- `python scripts/test_database.py --ministry-academic-concurrency` — pass: `class cap race and both enrollment/roster-freeze serialization orders`.
- `python scripts/test_database.py lifecycle_test.sql` — pass.
- `python scripts/test_database.py --catalog-concurrency` — pass: archive/create and archive/grant serialize and revalidate in both commit orders. Before the harness edit, it timed out waiting for the flat-payload create selection to acquire the catalog lock.
- `python scripts/test_database.py photos_test.sql` — pass.
- `flutter test --no-pub --concurrency=1 --reporter=expanded test/workflows_test.dart` — pass, 7 tests. The initial no-output interval was first-time Dart test compilation; the test process then ran to completion.

## Remaining focused failures and full-suite status

- `python scripts/test_database.py convert_commands_test.sql` — fails at line 14 with `invalid_payload` from `private.convert_registration_command`, because the fixture still sends the predecessor flat create object. This scenario also exercises the predecessor flat edit contract; only changing the create payload would not preserve its existing test intent. No partial edit was retained.
- `python scripts/test_database.py weekly_test.sql` — fails at line 50 with the same `invalid_payload` from the current typed registration contract. Its subsequent edit calls also use the predecessor flat contract. No partial edit was retained.
- The 2026-10-19 full Flutter suite was not rerun during this batch. The latest recorded full-suite result remains the Task 5 report: 432 passes, 9 failures, and 8 errors (449 outcomes). It lists the unrelated Task 16 import integration defect, convert/student concurrency fixture, Task 5/8/11/19 stale flat payloads, Task 6 lifecycle threshold fixture, backup fake using the old table path, four stale workflow assertions, and two tests that timed out only under the sequential full run. The academic concurrency, lifecycle, workflow, catalog, and photo fixture issues addressed here now have focused passing evidence. The Task 16 migration defect and backup fake were not changed.
- `flutter analyze --no-pub` remains unresolved per the latest recorded attempt, which emitted only its initial status line and was interrupted after about 90 seconds.

## Exclusions and handoff

- The flat create payload in `convert_commands_test.sql` and the flat create/edit calls in `weekly_test.sql` are confirmed incompatible with the current typed contract, but a safe fixture-only repair must update their complete transaction flows while preserving the existing assertions. These remain open.
- Task 16 remains a product migration integration defect and was explicitly excluded from this repair batch.
- `git diff --check` — pass. The reviewed changes are limited to the five verified fixture files above and this report. The full L1 acceptance review remains open.
