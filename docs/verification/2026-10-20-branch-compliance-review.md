# Ministry branch compliance review — 2026-10-20

**Historical initial review:** the missing parent documents were subsequently recovered from `origin/main@c71534d`, and hosted access now works. See the [expanded review](2026-10-20-expanded-compliance-review.md) for the current disposition, confirmed hosted schema/authorization mismatch, and additional reproduced behavior gaps. The former missing-document and invalid-credential blockers below describe the initial run only.

**Disposition: incomplete; do not treat this branch as ready for integration/release.** The implemented Ministry slices have substantial local coverage, including passing class-session and concurrency scenarios, but import is broken, several regression gates fail, browser acceptance is incompatible with the new contracts, and hosted/device acceptance remains unverified.

## Source and recovered planning

- Repository: `CarlosMonteiroNeto/discipulado-IEADPE`.
- Reviewed branch: `codex/ministry-production-completion`, HEAD `f2fffca489fd36f55957bba49736cb35dd31d5a6`.
- Remote main observed after fetch: `0a0f4db74da7cbbfe20214f1bcd17d366344e6b4`. This is the only other remote branch. The initial `work` checkout at `2ecba87` was stale and was not used as the final review target.
- Recoverable parent requirements and execution evidence: [completion contracts](../integration/ministry-completion-contracts.md), [task manifest](ministry-task-manifest.md), [execution ledger](ministry-execution-ledger.md), and [cross-device handoff](l1-cross-device-handoff.md).
- Exact L1 documents: [design](../superpowers/specs/2026-10-19-ministry-l1-session-management-design.md) and [implementation plan](../superpowers/plans/2026-10-19-ministry-l1-session-management-plan.md).
- Separate pending draft: [APK identity/access recovery design](../superpowers/specs/2026-10-20-apk-identity-access-recovery-design.md) and [plan](../superpowers/plans/2026-10-20-apk-identity-access-recovery-plan.md). Their proposed fixes are not implemented and must not be counted as completed branch behavior.
- The original `2026-10-18-ministry-production-completion-design.md`, `2026-10-18-ministry-production-completion-plan.md`, and `docs/integration/unified-design-system.md` are referenced but absent from this checkout and the fetched history for these paths. The handoff explicitly records four source-device documents intentionally left untracked. The surviving contracts/manifest/ledger recover much of their intent; they do not recover the missing original text verbatim.

## Requirement disposition

| Slice | Current evidence | Disposition |
|---|---|---|
| C1 — canonical identity, scope, field ownership and replay contracts | Surviving exact contracts; migration and scoped scenarios | Recoverable, with stale historical/current wording in documents |
| V1 — shared visual foundation | Functional/accessibility coverage; two visual suites still differ from committed goldens | Partial acceptance |
| P1 — canonical person and explicit legacy links | Seeded `canonical_person_link_test.sql` passes | Local SQL acceptance passes |
| P2 — shared registration | `ministry_student_registration_test.sql` passes; current typed client coverage runs | Local acceptance evidence; import compatibility fails separately |
| P3 — student academic detail/linking | `student_academic_link_test.sql` passes; teacher detail scenario fails on obsolete contact payload | Partial regression acceptance |
| E1/E2 — contact/access lifecycle | `ministry_contact_access_link_test.sql` and registry concurrency pass | Local evidence; old registry fixture remains incompatible |
| A1/A2 — classes and enrollment | Academic SQL/concurrency and class-management retest pass | Local acceptance evidence |
| F1 — derived follow-up | `ministry_follow_up_test.sql` and follow-up concurrency pass | Local SQL acceptance passes |
| L1 — class-bound lesson read/create/cancel/navigation | Seeded session-management SQL passes; lesson/navigation tests pass in broad run; all three session visual tests pass after SDK font preparation | Local behavior supported; broad closure still fails |
| L2 — attendance history/progress completion | Manifest still assigns this as a later slice; no `attendance_history_test.dart`; no progress read in the current attendance/class-detail UI | Not delivered as the full planned slice; existing attendance backend is not equivalent to L2 completion |
| H1 — hosted activation | Management API rejects configured credential; no hosted schema/function inventory | Blocked/unknown |
| H2 — legacy reconciliation | Synthetic rehearsal passes; no authorized legacy export/production reconciliation | Not verified |
| D1 — full workflow and Android delivery | Web build passes; browser, hosted, signed-device and full gate acceptance remain open | Incomplete |

## Findings

### 1. High — new schema breaks the existing convert import

`202610190001_ministry_people_identity.sql:32` adds `converts.revision NOT NULL DEFAULT 1`. The existing `ieadpe_import_convert` constructs a composite record with `jsonb_populate_record` (`202610140009_import.sql:43`) and inserts every field using `INSERT ... SELECT row_data.*` (`:72`). The record's new `revision` field is null; explicitly inserting null does not use its default. No later migration replaces this importer.

Reproduced in `import_test.sql` and import concurrency: SQLSTATE 23502, null `revision`. Both Task 16 Flutter database tests fail for this cause. Valid new backup/import rows cannot be restored. Fix through a reviewed forward migration and rerun import, duplicate/tombstone/replay, weekly guard and both transaction-order tests; changing a fixture to accept failure would not fix the product.

### 2. High — browser acceptance no longer exercises a valid product journey

`integration_test/unified_journey_test.dart:98–157` fills the old form, registers without selecting a congregation, and later changes congregation in edit. Current `ConvertSaveController.save` (`lib/features/converts/convert_save_controller.dart:38–43`) requires a congregation, rejects unlinked legacy edits, and prohibits congregation changes. The form also has a required congregation field. This is a confirmed static contract incompatibility, not a claimed live browser failure: the actual runner returned `UNIFIED_JOURNEY=BLOCKED`, exit 2, without a local Supabase HTTP stack.

The runner cleanup is also stale. `scripts/run_unified_journey.py:217–271` deletes Auth users and congregations without removing canonical people introduced by this branch. A disposable PostgreSQL reproduction using the real fixture setup, one synthetic canonical person, and the exact cleanup SQL fails on `ministry_people_updated_by_fkey` when deleting the Auth user. The database is dropped afterward. Current registration creates precisely this new dependency. Update the journey and bounded cleanup to the accepted identity model before claiming end-to-end acceptance.

### 3. Medium — four additional SQL regressions remain unresolved

Besides import, these checked-in scenarios fail against all 30 migrations:

- `base44_unified_access_test.sql:279`: archived direction scope assertion fails. New scope code (`202610190003_ministry_team_access.sql:68–76`) removes archived congregations from campaign `congregation_ids`, while the older accepted Base44 contract/test explicitly retained that campaign field and removed only Ministry scope. Decide and document the intended compatibility rule; the test is evidence of contract drift, not proof of unauthorized access.
- `convert_student_link_test.sql:143`: snapshot/provenance assertion fails after canonical address storage. The fixture expects a partial address object while the current canonical fixture carries the full structured address. Reconcile the assertion with approved field ownership, preserving provenance checks.
- `ministry_registry_test.sql:82` and `teacher_contact_detail_test.sql:118`: old contact writes omit `email`. Migration 003 now requires that key, including an explicit JSON null for directory-only contacts (`:251–260`). These failures are stale scenario envelopes, rather than evidence that current typed contact UI writes fail.

### 4. Medium — verification entry points omit this branch's new server acceptance

`scripts/verify_unified.sh:76–80` still enumerates the old 16 SQL scenarios and eight races. It omits canonical identity seeded migration acceptance, student registration, contact/access, student academic linking, teacher detail, session management seeded acceptance, and the F1 race. Existing Flutter database wrappers do not include these new standalone scenarios. The PowerShell SQL list likewise does not name the new acceptance files. A future green old gate could miss new-slice regressions. Extend both gates with the required seeded migration ordering and new scenarios.

### 5. Medium — broad analysis and visual gates are not green

Fresh `flutter analyze --no-pub` reports 36 diagnostics. Prepared retesting leaves pixel mismatches in the Ministry gallery (3.64%, 11,797 pixels) and Team lifecycle (2.63%, 8,506 pixels) using Flutter 3.47.7. These reproduce the previous handoff; do not regenerate baselines without visual disposition. Font lookup initially failed because tests request lower-case SDK filenames on a case-sensitive filesystem; temporary SDK aliases allow the tests to execute without changing repository code.

Runner contract tests also fail on Linux: 23/25 pass, with two Windows fallback tests setting `LOCALAPPDATA` but not selecting/mocking the Windows OS branch. Production resolver behavior correctly branches on `os.name`; the test setup is not portable.

## Fresh execution evidence

Environment: Flutter 3.47.7 / Dart 3.13.5, Linux, PostgreSQL 17 binaries already installed in the workspace. A new loopback-only cluster on port 54329 was created for this review. Every SQL/race run creates and drops its own database with synthetic Auth/Storage fixtures; this does not certify real Supabase Auth/Storage HTTP behavior.

| Check | Result | Evidence under `build/verification/` |
|---|---|---|
| All 25 standalone SQL scenarios, including both required pre-migration legacy seeds | 20 pass / 5 fail | `review-sql-results.json`, `review-sql-*.log` |
| All nine independent-session races | 8 pass / import fails | `review-race-results.json`, `review-race-*.log` |
| Synthetic migration rehearsal | 4 pass | `review-migration-tests.log` |
| Analysis | 36 diagnostics, nonzero exit | `review-analyze.log` |
| Web release build | PASS | `review-web-build.log` |
| Static web artifact/routing preflight | PASS | `review-web-preflight.log` |
| Runner/gate contract unit tests | 23 pass / 2 fail on Windows-specific assumptions | `review-runner-tests.log` |
| Real Chromium/local Supabase journey | BLOCKED, exit 2 | `review-journey.log` |
| Cleanup compatibility probe | FAIL on canonical-person/Auth FK | `review-cleanup.log` |
| Prepared retest: database wrappers + gallery + Team + session visuals + class management | 45 pass / 4 fail (two import, two visual) | `review-retest.log` |
| Final prepared full Flutter suite, sequential | 450 pass / 4 fail, exit 1 (two import, two visual) | `review-tests-prepared.log` |

The initial broad run returned 417 passes / 22 error outcomes, including missing local PostgreSQL and case-sensitive font prerequisites. Those infrastructure failures were investigated and the affected tests rerun after preparation; they are not counted as product defects. The final prepared full run confirms 450 passing tests and four remaining failures. The PowerShell configuration check passes with the installed host on PATH. L1's lesson, selected-session navigation and three visual-layout tests pass in this final run.

## Hosted boundary and next actions

Only `SUPABASE_ACCESS_TOKEN` is configured. A management API project-list request returned HTTP 401. The user clarified that the stored value came from the project's Secret Keys page, rather than account Personal Access Tokens. This is the wrong credential class for the management API/CLI. Replace it through environment secret configuration with an account PAT; do not paste credentials into documents or messages. The runtime readiness tool also reported credential state unknown. No hosted schema, migration, personal row, access grant, or storage object was read or changed.

Recommended order: restore/preserve the missing original planning documents; fix import with a forward migration; resolve the four SQL contract regressions; update browser journey/cleanup and both gates; disposition analyzer/visual/platform-test failures; rerun full acceptance; then inventory hosted migrations/functions read-only with the correct credential. Hosted migrations, legacy import, deployment and device delivery require their own concrete reviewed actions and are not performed by this review.

No application code or migration was modified, and no commit, push or merge was made. This report is the review deliverable; generated logs and screenshots are verification artifacts.
