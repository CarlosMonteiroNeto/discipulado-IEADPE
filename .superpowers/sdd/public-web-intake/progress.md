# SDD ledger — plan: docs/superpowers/plans/2026-10-25-public-web-intake-plan.md

Controller: OpenCode session `ses_e8c5f3a62ffd5xYY8M3d6Dy0dn`
Approved Spec: `docs/superpowers/specs/2026-10-25-public-web-intake-design.md`
Handoff: `docs/superpowers/plans/2026-10-25-public-web-intake-sdd-handoff.md`

## Baseline and workspace

- Fetched origin: `https://github.com/CarlosMonteiroNeto/discipulado-IEADPE.git`
- Authoritative `origin/main`: `846a320619d3d8240df391a8b218c713bcceedc3` (docs: close web completion plan).
- No commits after the planning baseline `846a320`; main drift for this plan: none.
- Execution worktree: `C:\Users\Carlos_Neto\.local\share\opencode\worktree\efb495\public-web-intake`
- Branch: `feat/public-web-intake`
- Docs import commit: `2598ef6` (only the three approved planning documents copied from local `flutter-supabase`; old branch not merged).
- Local workspace preserved untouched at `C:\Users\Carlos_Neto\FlutterProjects\App discipulado`.
- Toolchain observed: Flutter 3.47.2 / Dart 3.13.2, Python 3.12.10, Docker 29.8.2, PostgreSQL loopback on 127.0.0.1:54329, psql available. Deno is not installed (T3 prerequisite).
- CI pins Flutter 3.47.7 / Chrome 139.0.7258.154 (`.github/workflows/verify-unified.yml`). Local Flutter is one patch lower.

## Preflight scan (before Task 1)

| Pair / task | Produces versus consumes | Finding / ruling |
|---|---|---|
| T1 → T2 | T1 migration `202610250002`; T2 migration `202610250003` and T1 authority constraints | Ordered, distinct files. Consistent. |
| T2 → T3 | T2 `ieadpe_receive_public_intake` + catalog; T3 calls them | Contract signatures match the Shared Contracts. Consistent. |
| T2 → T5 | T2 pending/receipt state; T5 reads/locks it and extends T2 concurrency script | Planned sequential edit to the same script. No overlap conflict. |
| T3 → T4 | Wire endpoint/error map; Dart repository consumes it | HTTP codes/statuses match. Consistent. |
| T4 → T5 | No direct shared file; review consumes T2, not T4 | Dependency map lists T6 depends on T4+T5; T5 only depends on T2. Consistent. |
| T4 → T6 | T4 creates feature models/page and changes app/router/shell; T6 changes app/router/shell again | Sequential; no parallel dispatch. T6 reuses T4 models/form policy. Consistent. |
| T4 → T7 | T4 preserves picker APIs until T7; T7 changes picker injection/form integration | Sequential. T7 owns the final form/photo wiring. Consistent. |
| T1 → T7 | T1 enforces photo draft/upload authority; T7 UI relies on it | Sequential and stated. Consistent. |
| T6/T7 → T8 | T6 review UI, T7 photo pipeline; T8 integration journey | T8 depends on both. Consistent. |
| T8 → T9 | Verification receipts; operations runbook | T9 consumes evidence. Consistent. |
| T1 self-check | Test `official_create_requires_matching_grant`; migration and stale fixture updates | Test, migration and verification command agree. |
| T2 self-check | `public_intake_test.sql` plus `--public-intake-concurrency`; `test_database.py` extension named | Files and command agree. |
| T3 self-check | Deno handler tests/`deno check`, config change | Command prerequisite (Deno) absent; see ruling. |
| T4 self-check | Named tests and touched app/router/shell/form | Agree; test paths match `test/features/intake/`. |
| T5 self-check | Review SQL scenario and concurrency extension | Agree; reuses T2 hook as stated. |
| T6 self-check | Review tests + `_redirects`/preflight route fixtures | Agree, subject to inspecting actual route files at execution. |
| T7 self-check | Crop/processor tests and form integration | Agree; old 192px tests must remain green where legacy compatibility is required. |
| T8 self-check | Journey test, acceptance doc, gate scripts | Agree; runner command must be inspected, not invented. |
| T9 self-check | Runbook, preflight, candidate proposal | Agree; hosted mutation explicitly out of scope until authorized. |

Rulings:
- Ruling: use local Flutter 3.47.2 for implementation and record the CI 3.47.7 pin; do not upgrade the shared global SDK during this increment — avoids breaking unrelated projects, and the repo SDK constraint `^3.13.2` is satisfied. If CI-only analyzer/format drift appears, report it as an environment gap rather than silently editing CI pins.
- Ruling: install a local Deno binary before T3 if still absent; this is free development tooling, not a product/runtime dependency. If installation cannot be verified, T3 is BLOCKED, not silently skipped.
- Ruling: the task-brief extraction script matches `Task N` headings, while this plan uses `T1`-style headings; controller will create each brief file manually from the exact plan section, preserving all task text.
- Ruling: T1's old “registrar without grant may create” assertions are intentionally stale under the approved policy; update them only with failure evidence and record the policy change in the test.
- No task contradicts a Global Constraint or mandates a review-rubric defect known at planning time.

## Progress

- Setup: complete. `origin/main` fetched at `846a320`; worktree created and docs imported at `2598ef6`.
- Task 1: complete (commits `2598ef6..f0c4f1d`, review clean). Review receipt: spec ✅, quality Approved, 0 Critical, 0 Important. Evidence: new `public_registration_authority_test.sql` RED from no-grant create, GREEN after additive migration; 7 affected SQL suites, convert concurrency and manifest validation pass. Review minors parked: anonymous assertions prove lack of EXECUTE rather than the new guard; authorized archived creation branch not directly pinned; any-active-scope helper can finish a draft after losing the original scope (attachment is still scope-checked); historical contract doc still describes old registrar behavior (follow-up outside T1 ownership); fixed test date `2026-10-01` is already past as of 2026-10-25. Behavior-removal check was performed locally and reported but not committed.

## Recovery and Task 2 resumption (2026-10-25)

- Recovered OpenCode controller session `ses_e8c5f3a62ffd5xYY8M3d6Dy0dn` and failed child `ses_e8c46cd67ffeNeS1CNNjnx7n57` (`Implement T2 intake queue`). The child ended with `provider.free-limit` (HTTP 429); no completed report or T2 commit exists.
- Recovery checkout remains `C:\Users\Carlos_Neto\.local\share\opencode\worktree\efb495\public-web-intake`, isolated Git worktree branch `feat/public-web-intake`; `origin/main` remains `846a320`, T1 receipt commit is `f0c4f1d`, and the docs-only import is `2598ef6`.
- T2 files are present but uncommitted. Session history shows two intentional behavior-removal mutations: disabling rolling limits caused the expected 21st-submit assertion, and temporarily granting `anon` caused the expected private-RPC privilege assertion. Both mutations were reverted in session; current migration has active rolling-limit predicates and grants receive RPC only to `service_role`. No final full T2 verification was recorded.
- Resume T2 from `f0c4f1d`; inspect and complete current work, run the exact T2 checks, report and commit T2-owned files, then independently review before T3.

## Task 2 completion (2026-10-25)

- Task 2: complete. Commit `e313e25425c1628e836b84514a81b3b1c0d55bd3` (`feat: add private public-intake queue and limits`).
- The migration, SQL scenario, concurrency hook, combined runner path, and manifest coverage are in the T2 commit; no hosted changes were made.
- Verification: the combined T2 SQL/concurrency command passed; manifest validation passed with 32 SQL scenarios and 10 concurrency cases; `python -m unittest scripts.test_unified_gate` passed (15 tests, 179.487s).
- Existing SQL manifest sweep: 30/32 scenarios passed. Two unchanged pre-migration seed setups fail before the T2 migration: `canonical_person_link_test.sql` lacks its active congregation fixture; `ministry_session_management_test.sql` calls an RPC before its target migration. See the T2 report for root-cause evidence; no unrelated fixture changes were made.
- RED evidence: removing the rolling predicate failed at the 21st-submission assertion; granting anon execute failed at the private-RPC privilege assertion. Both mutations were restored byte-for-byte.
- Ruling: an explicitly supplied scenario is run before `--public-intake-concurrency`; an omitted scenario keeps manifest race invocations narrow. This follows the T2 required combined command and avoids running the default access scenario during a race-only invocation.
- Report: `.superpowers/sdd/public-web-intake/task-2-report.md`.
- SDD task review: spec compliant ✅; task quality Approved; 0 Critical, 0 Important, 0 Minor. Diff package: `.superpowers/sdd/public-web-intake/review-f0c4f1d..e313e25.diff`.
- Review verification caveat resolved: HTTP body size is owned by T3 and will be checked there (16 KiB streamed cap before JSON decode). Decision metadata writer is owned by T5; T2 provides `decision_retention >= 90 days`, required `retained_until`, and bounded cleanup; T5 must set `retained_until` from the configured value and test the 90-day boundary.
- Ruling: keep the two pre-T2 seed-order failures outside T2 ownership; verified their scenario/fixture/target migration paths are unchanged from `f0c4f1d`, and the runner change only selects a default scenario or runs a named scenario before the T2 concurrency hook. Carry both exact cases and root causes to the final branch review; they do not block dependent T3 work.

## Task 3 start (2026-10-25)

- Baseline: `e313e25425c1628e836b84514a81b3b1c0d55bd3` (T2 commit, review clean).
- Created complete T3 brief at `.superpowers/sdd/public-web-intake/task-3-brief.md`; no function source directory exists and `supabase/config.toml` has no function-specific entry.
- Installed Deno `v2.9.8` x86_64 into `C:\Users\Carlos_Neto\.codex\tools\deno-local\bin\deno.exe`; verified `deno --version`, SHA-256 `b0f654158ad3edaee34cf6aa8d39695f242d3b122753f6fb965261b9c7986f24`; user PATH unchanged.
- Address-trust investigation references: Supabase's Edge Function Turnstile example selects first `x-forwarded-for`; Supabase logging docs show Cloudflare gateway headers, while Cloudflare's current header docs say `CF-Connecting-IP` carries the client IP from Cloudflare edge to origin and recommend it over XFF. Implementer must evaluate trust for managed Supabase Edge Function traffic and use only a verified source; otherwise report the limiter blocked/fail-closed as specified.

## Task 3 completion (2026-10-25)

- Task 3: complete locally at commit 387ed04b5b3b35fe50ad5d9136ed3113d8abee62. Post-commit verification: Deno handler tests 18/18 passed; Deno check, Deno format check and git diff check exited 0.
- Report: .superpowers/sdd/public-web-intake/task-3-report.md.
- Address trust ruling: provider documentation did not establish a trusted address header for managed Supabase Edge Functions. Keep the runtime resolver fail-closed; the per-network limiter and hosted release are BLOCKED until the trust chain is verified. Cost if wrong: legitimate anonymous submissions remain unavailable until a verified source is established; accepting spoofable forwarding values could let callers evade the per-network limits.
- Runtime implication: successful Turnstile validation still returns unavailable before HMAC/RPC while no address source is trusted; T2 global capacity is not reached during this block. No hosted configuration or deployment changed.
- Operations concern: Supabase invocation observability documents request/response bodies; confirm body retention/redaction before releasing PII-bearing submissions.

## Task 3 completion (2026-10-25)

- Task 3: complete locally (commit `387ed04b5b3b35fe50ad5d9136ed3113d8abee62`; review clean, spec ✅, task quality Approved, 0 Critical/Important).
- Verification: 18 Deno tests passed after commit; `deno check`, `deno fmt --check`, and `git diff --check` passed.
- Release blockers: authoritative client IP source for managed Supabase Edge Functions is unverified; runtime ignores forwarded headers and returns 503 before HMAC/RPC. Hosted Supabase invocation-body retention/redaction is unverified; address it in T9 before release. Carry both to T8 acceptance and T9 release checklist.
- Reviewer minor deferred for final triage: `index.ts` permits remote `http://` SUPABASE_URL, which could send the service credential without TLS if misconfigured. Include an HTTPS/loopback check in the T9 configuration checklist; final branch review must decide whether code hardening is required.
- Review package: `.superpowers/sdd/public-web-intake/review-e313e25..387ed04.diff`.

## Task 4 preparation

- T4 complete brief: `.superpowers/sdd/public-web-intake/task-4-brief.md`; source-owner inspection confirmed bootstrap/protected boundary in `lib/app.dart`, route authorization/session cleanup in `lib/routing/router.dart`, shell navigation in `lib/widgets/app_shell.dart`, and `ConvertDraft`/gallery policy in `lib/features/converts/convert_form.dart`.
- T3 wire contract is stable for local fake-HTTP tests, but production submits remain 503 until address trust is resolved. Do not weaken T3 fail-closed behavior to make UI tests pass.

## Task 4 completion (2026-10-25)

- Baseline: `387ed04b5b3b35fe50ad5d9136ed3113d8abee62`; branch `feat/public-web-intake`.
- Added public `/` and `/register` bootstrap that avoids authenticated Gateway/protected reads, a bounded public names-only catalog and intake client, Portuguese public registration UI, and web Turnstile adapter with a fail-closed non-web stub. Existing own-scope registration stays on the official save controller. No-grant/out-of-scope registration uses T3; photo policy is secure by default, authority is revalidated before picker use, and protected photo state clears on authority changes. Unknown outcomes freeze the draft/key for same-key, fresh-token retry.
- RED evidence and detailed Entry→Process→Exit receipt: `.superpowers/sdd/public-web-intake/task-4-report.md`.
- Verification: T4 pair 12/12; auth/navigation/form regressions 42/42; conversion page tests 2/2; app smoke 5/5; scoped analyzer on T4 production/test paths completed with `No issues found!`; `flutter build web --no-pub` passed; `git diff --check` passed. Whole-repository analyzer was stopped after active Dart analysis-server indexing; see T4 report for process evidence and limits.
- Release blockers carried forward unchanged: T3 address trust resolver fails closed with 503 before RPC until a trusted address source is verified; hosted PII-bearing invocation-body retention/redaction remains unresolved. No hosted changes were made.
- Local implementation commit: `8d025aa9867457970721d1ad67523c4c013cac4d` (`feat: open public registration with protected navigation`).

## Task 4 review follow-up (2026-10-25)

- Baseline: `8d025aa9867457970721d1ad67523c4c013cac4d`.
- Review fixes: apply existing `orderCongregations`/`sortPortugueseNames` to the authenticated no-grant public catalog; Bootstrap listens to browser popstate and returns to public registration on Back; unauthenticated SessionRouter leaves public paths for Bootstrap. Public-page Turnstile challenge is recreated on return and disposed on route exit.
- RED/reverse-patch receipts: catalog test failed on unsorted order, and passed again after restoring ordering; Back test found no public page after history back, and failed again when the listener was temporarily removed; SessionRouter test showed pre-fix public pop rewrote history to `/login`.
- Verification: T4 repository/page pair 13/13; auth flow 17/17; auth/navigation/form/page regressions 45/45; app smoke 5/5; targeted analyzer clean; web build exit 0; `git diff --check` passed.
- Follow-up commit: `d9c7219d050d724583cd852b2486a4c6b3838cb7` (`fix: preserve public registration ordering and history`).
- Independent T4 review: initial assessment Approved; two Minor findings were addressed in follow-up commit `d9c7219d050d724583cd852b2486a4c6b3838cb7`. Independent re-review confirms both addressed with no new Critical/Important breakage. Final T4 gate clean.

## Task 5 investigation (2026-10-25)
- Source investigation: T2 migration `202610250003_public_intake.sql` owns `private.public_intake_submissions` (status/revision/payload/digest/expiry) and `private.public_intake_decisions` (outcome/reviewer/official ID/decided_at/required retained_until), but provides no authenticated list/get/review RPC or decision writer. Setting `decision_retention` is constrained to >=90 days; cleanup deletes bounded decisions by `retained_until`.
- T1 canonical `public.ieadpe_create_convert(uuid,jsonb)` delegates to `private.convert_registration_command`, which locks `private.lock_access(ARRAY[auth.uid()])` before current authority checks, then runs canonical official person/convert/weekly-counter logic and actor-scoped receipts. T5 must recheck the active congregation/current reviewer scope under the access lock and call this RPC with the authenticated reviewer identity, fixed operation UUID, and null photo; direct official inserts or broader grants are out of scope.
- The shared T5 contract requires exact JSON allowlists, oldest-first `(submitted_at,id)` paging with scope-bound opaque cursor, current scope checks on list/detail/replay, revision checks, no PII in decision metadata, and atomic rejection/approval. Existing `public_intake_test.sql` seeds the real T2 tables; `database_public_intake_concurrency.py` is the sole race harness and will be extended.
- Cause/extension classification: T2 intentionally stopped at an isolated pending queue; the missing behavior is the T5 transactional review boundary. The appropriate extension is a new migration/test scenario plus the existing T2 concurrency hook, leaving T1 authority and T2 schemas intact. Pre-migration SQL manifest failures are documented separately and remain outside this task.

## Task 5 completion (2026-10-25)

- T5 local implementation is complete at `13a23d8723a94813c3216ec3238cce6afc682585` (`feat: approve anonymous submissions within congregation scope`). New migration: `202610250004_pending_review.sql`; SQL scenario: `pending_review_test.sql`; existing T2 concurrency hook extended in place.
- RED evidence: before the migration, the SQL scenario reached the new list-RPC assertion and failed there as expected. A later focused assertion exposed that JSONB `null` and SQL NULL compared differently in global cursor binding; the guard was corrected, and the global all-scope page-2 test now passes.
- Approval uses `auth.uid()` through T1's canonical create RPC, a fixed derived operation UUID and explicit null photo. The review transaction locks actor access before the queue row, rechecks active scope, stores digest-only decision metadata, erases the draft, and uses configured decision retention. Same-operation replay, identical-draft replay, conflicting corrections and canonical rollback are covered.
- Concurrency hook now covers same/conflicting reviewer approvals, approve/reject, review versus normal registration, and revoke-first/review-first races. Both reviewers in the identical-approval race must retain receipts for the same official ID.
- Verification: combined pending SQL and `--public-intake-concurrency` passed all ten PASS checks; canonical authority/create/student-registration/follow-up SQL scenarios all passed; 24 verification-manifest/unified-gate unit tests passed; manifest validates 33 SQL scenarios and 10 race flags; Python compilation and `git diff --check` passed.
- The T5 addition to the verification manifest exposed stale unit expectations for the T2 tenth race. T2 history confirmed the source/manifest flag was already correct; only the expected race list/count was updated.
- Previously recorded full-suite seed-order blockers remain unchanged: `canonical_person_link_test.sql` fails before its target migration due a missing active congregation; `ministry_session_management_test.sql` calls its RPC before migration. Direct T5 scenarios and named canonical regressions are green.
- No hosted migration or production/account/publication changes were made. Full Entry→Process→Exit receipt: `.superpowers/sdd/public-web-intake/task-5-report.md`.
- Commit: `13a23d8723a94813c3216ec3238cce6afc682585`.
- Independent T5 review: spec compliant ✅; task quality Approved; 0 Critical, 0 Important, 0 Minor. Review package `.superpowers/sdd/public-web-intake/review-d9c7219..13a23d8.diff`; no follow-up fixes required.

## Task 6 investigation (2026-10-25)
- Source investigation: `AccessScope` and `routesFor` separate campaign reviewer grants from ministry-only access; `SessionRouter` is the route authority, while `AppShell` is presentation only. `_ProtectedFeatures` owns authenticated data/revalidation. `/pending` must be added consistently to exact `web/_redirects`, preflight route set and release-operation fixture.
- T5 reviewed contract receipts: exact list/detail/review RPC schema, caller/scope-bound cursor, current scope checks, stable actor receipts and revision conflict semantics are documented in `task-5-report.md`; use existing `ConvertForm` with photos and congregation reassignment disabled.
- T6 source-owner classification: the feature is absent; extend the existing protected route/shell and current form contracts. Do not access private tables or create alternate authorization/data paths. T5/T4 provide local fakes for verification; unresolved T3 deployment blockers do not block this UI task.
- Complete T6 brief prepared at `.superpowers/sdd/public-web-intake/task-6-brief.md` with spec/plan pointers, contract receipts, source owners and complete task brief.

## Task 6 completion (2026-10-25)
- Baseline: T5 commit `13a23d8723a94813c3216ec3238cce6afc682585`; both T4 and T5 independent review gates were clean.
- Added typed T5 RPC repository, authenticated `/pending` review UI, scoped queue filtering, editable `ConvertForm` without photo/reassignment, stable review operation retry, route/deep-link integration and exact release/preflight coverage. Unknown outcomes freeze the operation/draft and disable refresh, filter and decision changes until retry resolves.
- Initial test-first RED was at intended route assertions: `routesFor` lacked `/pending`, `safeRoute('/pending')` returned `/register`, and the protected direct route was unavailable. Reverse-patching away the SessionRouter scope guard failed the no-grant direct-route test (`Expected: '/register'; Actual: '/pending'`); reverse-patching the allowed route failed the authorized `Pendentes` navigation assertion. Restored both changes; see `task-6-report.md`.
- Verification: T6 scoped repository/page tests 22/22; broader auth/navigation/form regressions 58/58; `python scripts/test_release_operations.py` 5/5; scoped Dart analyzer `No issues found!`; changed-Dart format and `git diff --check` passed. Web build and static preflight passed locally; build emitted the existing CupertinoIcons font warning. Report: `.superpowers/sdd/public-web-intake/task-6-report.md`.
- Added `unittest.main()` to the release operations script so the specified direct command executes the existing five cases instead of silently reporting zero tests.
- No hosted migration, production change, deployment, publication, paid service or account configuration was performed. Commit `93f7e0a` (`feat: add protected pending-registration review`); `git status --short` is clean after commit.

## T6 independent-review follow-up (2026-10-25)
- Fixed page-local operation loss on navigation: a tokenized `SessionRouter` lock now blocks `go`, restores `/pending` after browser Back, and is exposed to `AppShell` so route selectors and feedback overlays disable while an approval/rejection is in flight or unresolved. Sign-out remains available; auth/scope invalidation clears all locks, and stale lock tokens cannot release a newer lease.
- Test-first RED: before the fix, in-flight `router.go('/home')` and unknown-outcome browser Back both changed the route to `/home` instead of retaining `/pending`. Reverse patches of route guard, popstate guard, and shell route control each reproduced their expected failures; all were restored.
- Verification: T6 pair 24/24; auth/navigation/form regressions 50/50; release operations 5/5; scoped analyzer clean; changed-Dart format and `git diff --check` clean. `flutter build web --no-pub` exited 0; local web preflight passed. Build reported the Wasm dry-run advisory and missing CupertinoIcons font warning.
- Follow-up report: `.superpowers/sdd/public-web-intake/task-6-report.md`. Commit `6cc33931181d5df39295971cdfdac3b5cb78e223` (`fix: preserve pending review across navigation`); `git status --short` clean. No hosted or production actions were performed.
- Independent T6 review: initial Important navigation-loss finding was addressed in `6cc33931181d5df39295971cdfdac3b5cb78e223`; independent fix-round Approved with no new findings. The operation lock now survives AppShell/go/popstate attempts and unknown retries; revocation/dispose clears it. Sign-out remains available and clears protected state.

## Task 7 investigation (2026-10-25)

## Task 6 final gate (2026-10-25)

- T6 complete at `6cc33931181d5df39295971cdfdac3b5cb78e223`; independent follow-up review Approved with no new findings. The original Important finding (unknown outcome could lose frozen operation on shell/Back navigation) was corrected by a tokenized SessionRouter lock. The lock spans request through unknown retry, AppShell and browser Back are blocked while it is held, session invalidation clears it, and sign-out remains available and clears protected state.
- Final evidence: pending repository/page pair 24/24; auth/navigation/form 50/50; release operations 5/5; scoped analyzer clean; web build and local preflight pass. Reverse patches to router, popstate, and AppShell reproduce the regression.
- T6 implementation and review report: `.superpowers/sdd/public-web-intake/task-6-report.md`.

## Task 7 investigation (2026-10-25)

- Baseline: T6 reviewed HEAD `6cc33931181d5df39295971cdfdac3b5cb78e223`.
- Cause/extension point: `photo_processor.dart` currently orients, center-crops to 192×192, composites transparency on white and emits metadata-free JPEG; `photo_repository.dart` invokes its positional processor injection during upload and enforces a 1 MiB storage cap. Existing `ConvertForm` injects a gallery-only raw-byte picker and rechecks photo authority around asynchronous acquisition. `ConvertSaveController` sends draft bytes to `PhotoRepository.upload` before canonical create/update. Keep this private upload and legacy-download contract intact while adding confirmed crop + 512×512 processing.
- Critical integration constraint: form must retain original bytes until crop confirmation, then pass selected normalized crop through a processor closure that still honors `PhotoRepository.processor`'s positional injection. Avoid applying the crop twice or sending a 512 image through the old 192 default path. Only processed JPEG reaches upload. Existing old 192px JPEG downloads remain valid.
- T7 brief prepared at `.superpowers/sdd/public-web-intake/task-7-brief.md`; implementer receives source ownership, shared contract, dependency receipts and RED/GREEN gates before editing.
- T7 source reconfirmation: baseline photo + repository tests passed 10/10 and demonstrated current 192×192 output. Integration point confirmed: `ConvertSaveController` passes draft bytes to `PhotoRepository.upload`, which calls the existing positional processor once at upload time. The intended crop-metadata/processor closure must preserve that single processing point and injection signature.
- Crop-bound ruling: because `left/top` are normalized by oriented width/height while `size` is normalized by the source minimum dimension, normalized checks `left + size <= 1` and `top + size <= 1` are incorrect for non-square sources. Validate rounded pixel origin and square side against actual oriented width and height: `x + side <= width` and `y + side <= height` after deterministic rounding.

## Task 7 implementation and verification (2026-10-25)

- Implemented explicit camera/gallery/cancel choice, bounded original-byte acquisition, guarded Android lost-picker recovery, orientation-aware crop UI, normalized oriented crop coordinates and one-shot 512×512 metadata-free JPEG processing. No new camera framework or hosted service was introduced.
- `ConvertForm` retains the original candidate until confirmation; crop cancellation preserves the existing photo; scope/session checks prevent stale selection. `RegisterPage._submit` revalidates the selected congregation before invoking the save controller. The existing positional `PhotoRepository.processor` injection remains compatible via a single closure; crop is not applied twice. Legacy 192×192 download compatibility and the existing private upload cap remain intact.
- TDD RED: `flutter test test/features/photos/photo_test.dart` failed on `confirmed_crop_is_applied_once`: expected output dimensions `[512, 512]`, actual legacy output `[192, 192]`. The focused processor subset then passed 8/8; after the tiny 1×1 input case was added, final `flutter test test/features/photos/photo_crop_test.dart test/features/photos/photo_test.dart` passed 13/13. An old center-pixel sample `(96,96)` was moved to `(256,256)` because the expected image center changed from 192px to 512px output.
- Final focused gates: `flutter test test/features/photos test/features/converts/photo_save_test.dart test/features/converts/stale_save_test.dart` 37/37; `flutter test test/features/converts/form_test.dart` 15/15; crop-page interactions 5/5. Coverage includes source camera/gallery/cancel/denial, original bytes plus selected crop, stale authority/session during crop, 360px/200% text, keyboard alternatives, 20MiB/24MP edges, transparency, orientation, crop bounds and legacy JPEG downloads.
- Scoped `dart analyze` on the 18 changed production/test Dart paths: `No issues found!`. The scoped `flutter analyze --no-pub` process produced no output for ~90 seconds and was interrupted; the equivalent direct analyzer completed and, after fixing its first-pass warnings/infos, passed cleanly.
- `flutter build web --release` exited 0 and built `build/web` in 238.6s. The CupertinoIcons font-manifest notice is pre-existing and documented by successful repository Web builds; current source and dependency manifest have no CupertinoIcons reference/direct dependency. `python scripts/web_preflight.py build/web` passed (static artifact size/routing, local only).
- Hardware camera/native picker smoke was unavailable. Channel-backed picker tests are not device evidence; keep real camera, platform permission and native lifecycle checks for T8/T9 device verification. No hosted migration, production config, publication, paid service or account configuration was touched.
- T7 implementation report: `.superpowers/sdd/public-web-intake/task-7-report.md`. Task-owned commit: `69f8a01e77274d2d1a96b4e85807ccda607ec599` (`feat: capture and frame standardized profile photos`); staged `git diff --cached --check` passed, and working tree was clean immediately after commit.

## T7 independent-review follow-up (2026-10-25)

- Addressed all four Important findings in T7-owned files: authority revalidation now runs after chooser and before acquisition; corrupt/unsupported sources render a recoverable crop error page instead of throwing through route construction; all arrow keys and semantic direction buttons move the visible image in their named directions; and reduced-motion route push/pop transitions have zero duration.
- Test-first RED evidence: the authority regression observed `acquisitions == 1` instead of zero after the second check; corrupt bytes raised `DataFailure(invalid)` during `PhotoCropPage.initState`; the former left direction control yielded crop.left 0.030303 (< center 0.04545); disabled-motion route duration remained 450ms. Regression tests now assert the protected ordering, recoverable invalid image, all eight directional inputs, and reduced-motion plus normal route durations.
- Follow-up GREEN: crop page + form 24/24; broad T7 gate 40/40; form 16/16; crop page + picker 14/14; scoped analyzer clean; format and `git diff --check` clean. No Web-only code or platform dependency changed, so the previously verified local Web build/preflight were not repeated.
- Report: `.superpowers/sdd/public-web-intake/task-7-report.md`. Follow-up commit: `d75ee355a5b197fd09485771608ed7864dac04b9` (`fix: address reviewed photo crop behavior`); staging included four T7 form/crop/test files only, `git diff --cached --check` passed and tracked worktree was clean after commit.

- T7 final SDD review gate (2026-10-25): original commit `69f8a01e77274d2d1a96b4e85807ccda607ec599` received four Important findings and was not approved. Fix commit `d75ee355a5b197fd09485771608ed7864dac04b9` addressed all four with regressions: authority revalidation after chooser before acquisition; corrupt-image recoverable crop error; correct directional semantics for buttons/arrows; reduced-motion zero-duration push/pop while normal mode retains transition. Independent re-review approved with 0 Critical / 0 Important. Minor follow-ups for T8: high-contrast/reduced-transparency overlay adaptation, direct 768/1440 viewport tests, and selected crop combined with EXIF orientation 6.

## Task 8 investigation (2026-10-25)

- Baseline: T7 approved HEAD `d75ee355a5b197fd09485771608ed7864dac04b9` (T7 implementation `69f8a01` plus reviewed fix round). Working tree was clean before T8 brief/ledger preparation.
- Existing journey owner is `integration_test/unified_journey_test.dart`, launched only by the existing runner `python scripts/run_unified_journey.py` (the runner accepts no feature flags beyond `-h`). Python runner validates Supabase targets as loopback, seeds synthetic users/records, controls grant revocation, runs Flutter Drive/Chrome at `http://127.0.0.1:7357`, parses exact owned IDs and cleans the fixture. Extend this runner/manifest and its existing guard tests; don't create a competing gate.
- Current journey covers authenticated registrar → convert → supervisor visit plus ministry authorization/revocation. It does not cover anonymous pending intake or T5 reviewer UI. Existing T2/T5 SQL scenarios already cover private queue, review authority, concurrency, global/rate limits and idempotency. T3 local handler uses injectable Turnstile/RPC/address dependencies, but production address resolver deliberately fails closed until managed Supabase's trusted address source is verified. Any local stub must be deterministic, loopback-only and impossible to enable in production; never change the release-blocking production resolver to make the test pass.
- Exact focused invocation inspected and run: `python scripts/run_unified_journey.py` → `UNIFIED_JOURNEY=BLOCKED`, `Local Supabase stack is not running`. Attempted local-only `supabase start --exclude studio,edge-runtime,logflare,vector,imgproxy,supavisor` → `DockerLifecycleInspectError`, cannot connect to `npipe:////./pipe/dockerDesktopLinuxEngine`; Docker Desktop Service is stopped and this session cannot open the service. No hosted service was contacted and no fixture mutations occurred. Treat full browser journey as BLOCKED if this local Docker condition persists, not as a code RED or PASS.
- CI pins Flutter 3.47.7 / Dart 3.13.5; the approved execution environment earlier recorded local Flutter 3.47.2 / Dart 3.13.2. Verify current versions and use available local SDK without changing shared global toolchain; report the pin drift.
- T7 independent re-review approved the fix round (0 Critical/Important). Three Minor follow-ups are accepted into T8 audit: high-contrast/reduced-transparency crop overlay, direct 768/1440 viewport coverage, and selected crop combined with EXIF orientation 6.
- Complete task brief: `.superpowers/sdd/public-web-intake/task-8-brief.md`.

## Task 8 implementation and verification (2026-10-25)

- Added a loopback-only host Deno test adapter with deterministic bot/address inputs; the real production handler remains fail-closed and unchanged. Extended the existing browser journey runner, exact run-owned cleanup, browser acceptance assertions, portable PowerShell/Bash gates, and route/security contract tests. The Flutter journey covers anonymous intake, lost-response retry, official-versus-pending isolation, scoped review, correction/approval, payload erasure, anonymous bypass denial, and protected sign-out cleanup.
- Completed T7's accepted minor follow-ups: high-contrast crop guide, 768/1440 viewports at 200% text, and selected crop combined with EXIF orientation 6. The crop guide uses opaque high-contrast shading and an outlined selection; Flutter 3.47.2 exposes no reduced-transparency accessibility flag.
- Initial full Flutter run: 638 passed, 7 failed. The catalog concurrency test lacked the exact synthetic registrar scope now required by T1; the isolated unified-gate harness did not stub the new Deno executable; four older workflow tests attempted photo selection without first selecting a congregation (the current UI correctly hides it until a scope is selected). All four categories were corrected in fixtures, with the photo-authority behavior preserved. The rerun passed all 645 tests.
- Direct SQL verification found two stale rejection-decision rows missing T5's required `corrected_draft_digest`; both now use the SHA-256 JSON-null rejection sentinel. Public-intake and pending-review SQL plus their concurrency gates pass. Manifest, 48 Python runner/gate tests, Deno check/18 handler tests, and catalog archive concurrency pass.
- `flutter analyze --no-pub` showed no output for more than four minutes with an idle 7 MiB Dart process; after interrupting only that command, direct `dart analyze` on all six changed Dart paths returned `No issues found!`. Dart format and staged whitespace checks passed.
- `flutter build web --release --no-pub` built `build/web` successfully in 246.5 seconds; `python scripts/web_preflight.py build/web` passed. Existing CupertinoIcons manifest warning and Wasm dry-run advisory were non-fatal.
- Exact browser runner recheck returned `UNIFIED_JOURNEY=BLOCKED`, `Local Supabase status is unavailable`; the Docker Desktop service is stopped. The user confirmed a computer restart is needed and unavailable now. No start attempt, hosted request, hosted fixture, or production mutation was made during this verification.
- Acceptance evidence: `docs/verification/public-intake-acceptance.md`. Full Flutter output: `.superpowers/sdd/public-web-intake/t8-full-flutter-test.log`.
- Task-owned commit: `023b28acf1bdb86c87cdabb6f688ae16aa9f17f3` (`test: verify public intake and approval boundaries`). Working tree was clean after commit. Independent T8 review is pending; do not begin T9 until the gate is resolved.

## User testing-method amendment (2026-10-25; received after T8 local gate)

- User updated the Spec, plan and SDD handoff in the primary workspace to remove Docker as a prerequisite and authorize backup-first controlled hosted synthetic database/function tests. Only the three named documents were copied into this execution checkout and committed as `9095fee` (`docs: switch public intake tests to hosted backend`). The primary workspace's unrelated dirty/untracked files remain untouched.
- New amendment explicitly requires a fresh full database backup outside Git, checksum, archive readability/restore-path evidence, external run manifest, baseline/after reconciliation, run-owned synthetic IDs, exact cleanup and no use of `scripts/test_database.py` against hosted. Site publication, destructive operations, paid service and unrelated production changes remain unauthorized.
- Read the referenced hosted Web smoke evidence from the separate current clone at `C:\Users\Carlos_Neto\FlutterProjects\discipulado-IEADPE\docs\verification\2026-10-24-hosted-web-write-smoke.md`; it documents prior backups and exact synthetic cleanup, but it is historic and cannot substitute for a fresh backup.
- Read-only target check: configured Supabase URL host matched the sole project returned by `supabase projects list`. `supabase migration list --project-ref <configured>` shows baseline through `202610250001` applied; `202610250002`–`004` are pending. Read-only `supabase db query --linked --project-ref <configured> 'SELECT 1 AS safe_probe'` succeeded. No hosted writes or migration changes were made.
- Current hosted-runner gap: updated T1 requires `scripts/test_public_intake_hosted.py` and its unit tests, but neither exists yet. The T8 implementation `023b28a` was authored under the prior Docker-local runner workflow and is not yet compliant with revised T8's hosted journey requirement. T8 review is paused pending plan reconciliation.
- Backup readiness: local native `pg_dump.exe`/`pg_restore.exe` exist; no PGSERVICE/PGPASS/database-URL environment names or standard libpq service/password files were found. Supabase CLI `db dump` runs pg_dump in a container and excludes managed auth/storage/extension schemas, so it is not a compliant full backup and cannot be used without Docker. No fresh backup exists yet. Do not write to the hosted project until a compliant full backup and external evidence manifest are verified.
- New T1 hosted-runner brief: `.superpowers/sdd/public-web-intake/task-1-hosted-runner-brief.md`.

## T1 hosted-runner follow-up (2026-10-25)

- Baseline: `9095fee` on `feat/public-web-intake`; no hosted writes or reads were performed by this follow-up. Existing `test_database.py` and loopback guards are unchanged.
- Added `scripts/test_public_intake_hosted.py` and `scripts/test_public_intake_hosted_runner.py`. The runner requires explicit project/run/scenario, external fresh full-backup manifest and new external evidence path; checks trusted project configuration plus authenticated Supabase CLI access, asks for typed target confirmation, verifies migration ledger and TLS psql target, namespaces UUID/email fixtures, executes only rollback-only static-safe SQL, and reconciles before/after counts.
- Test-first RED: missing runner contracts failed as expected. Post-commit GREEN: requested unittest discovery command passed 10/10 with fake Supabase and psql executables; `python -m py_compile` and `git diff --check` passed; no network calls. `ruff` is unavailable (`No module named ruff`). Commit `1d5e0e8c1b170da90e1a609c1a4a6965b8fcdd5e` (`test: add guarded hosted public intake runner`).
- Safety finding: T2's `public_intake_test.sql` directly truncates shared queue tables; `database_public_intake_concurrency.py` also truncates shared tables and commits fixed-ID fixtures. These are incompatible with the no-truncate/run-owned cleanup amendment. The runner rejects T2 and refuses `--concurrency`; do not try hosted execution until T2-owned fixtures/helper are rewritten and independently reviewed.
- T1/T5 scenario static classification: both are explicit rollback transactions. All fixed UUIDs and test emails are run-namespaced. T5's canonical-function replacement is transaction-local; before/after aggregate counts are recorded and must match.
- Plan invocation and safety note updated in `docs/superpowers/plans/2026-10-25-public-web-intake-plan.md`; full T1 addendum report: `.superpowers/sdd/public-web-intake/task-1-hosted-runner-report.md`.

- Task 1 fix round 1/5: both Important findings addressed in `69fcb29`; scoped independent re-review approved both and found no new breakage. Focused suite 11/11, `py_compile`, and `git diff --check` passed; no hosted calls.

- T2 hosted-safety follow-up implemented at `0b66092` with T2 fix round `91e4f71`; independent review and re-review approved after adding all four private-table SELECT denials and the intake receipt ID to evidence. Final focused runner suite 15/15, `py_compile`, `git diff --check`, and source-hash/pin equality passed. T2's full boundary suite and concurrency helper remain local-only/BLOCKED for hosted due long global transaction locks/shared live queue and unsafe legacy fixture helper. No hosted calls.
- T2 task-quality gate: initial review raised those two Important omissions; fix-round 1 (`91e4f71`) closed both, and scoped re-review approved with no new Critical/Important breakage.

## T8 amended-acceptance follow-up investigation (2026-10-25)

- Fresh `git fetch origin` confirms `origin/main` remains `846a320619d3d8240df391a8b218c713bcceedc3`; no upstream drift changes the current branch.
- Read-only hosted state: migrations `202610250002`–`004` remain pending after `202610250001`, functions list is empty. No DB URL/password env key or backup manifest/archive is available in this execution environment. No hosted writes have occurred.
- T3's `resolveSupabaseEdgeClientAddress` remains fail-closed and its report says no authoritative managed gateway address source has been verified. The updated T8 hosted browser journey therefore cannot reach a successful intake even after local build; also no fresh backup, function deployment, Turnstile hostname/config or temporary reviewer identities are present.
- T8's existing `integration_test/public_intake_journey_test.dart` and `scripts/run_unified_journey.py` are loopback-only and must stay so. The old acceptance report names Docker outage as the browser blocker; updated T8 report will distinguish no-Docker local PASS evidence from hosted external prerequisites.
- CI source investigation: `.github/workflows/verify-unified.yml` invokes the Deno gates but has no Deno setup step. The current official Ubuntu 24.04 runner image inventory does not list Deno (source: `https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md`), so T8 follow-up adds explicit pinned setup Deno action/runtime and a static contract regression test.
- T8 follow-up brief: `.superpowers/sdd/public-web-intake/task-8-amended-acceptance-brief.md`; no hosted action is authorized/performed in this follow-up.

## T8 independent-review ruling (2026-10-25)

- Review of `91e4f71..f1ede5a` confirmed the Deno setup/test and found no hosted PASS claims, but identified a general-readiness documentation gap: external hosted-write prerequisites did not explicitly state exact confirmed project/ref plus run-owned cleanup and before/after reconciliation. Those are required by the approved amendment, so add them to the general hosted readiness and resumption contract.
- The ignored local SDD ledger has the T8 investigation but lacks a completion entry naming `f1ede5a` and final scoped test output. Add that entry; the existing ledger itself is present, but the review package could not see the ignored file.

## T2 hosted-safety follow-up investigation (2026-10-25)

- Source review confirmed the T2 SQL's `pg_temp.reset_intake` calls `TRUNCATE ... CASCADE`; the current concurrency helper truncates all shared pending/receipt/decision/event tables, resets singleton settings, and commits static-ID fixtures. This violates the updated no-truncation/run-ownership contract even though the old tests pass in disposable local DBs.
- The T1 runner now supplies a reviewed source digest pin, project/migration preflight, backup and external evidence requirements, rollback-only scenario gate, and T2 fail-closed refusal. T2 must update its own test scenario/helper and runner safety tests before the exact scenario hash can be approved. Brief: `.superpowers/sdd/public-web-intake/task-2-hosted-safety-brief.md`.
- Ruling: adapt only the hosted fixture/race path; preserve reviewed production migrations. Transaction-local SQL fixtures can be retained with run-namespaced values. Any global capacity/race case that cannot be made non-interfering and exactly cleanable remains explicitly BLOCKED/incomplete under the plan; do not force a hosted PASS.

## T2 independent-review ruling (2026-10-25)

- Independent review of `69fcb29..0b66092` found two Important, plan-conflicting gaps: the hosted smoke checks SELECT denial on `private.public_intake_submissions` but omits the receipts, accepted-events and decisions tables; the run evidence/test omit the intake receipt ID even though receive/replay creates a receipt.
- Ruling: both findings are real and should be fixed before accepting the hosted path. Assert the private privilege boundary across all queue tables per the migration contract, and record the run-owned intake receipt identifier (distinguish it from unrelated operation receipts if needed). Add focused offline coverage. No hosted calls.

## T1 independent review and ruling (2026-10-25)

- Independent review of `9095fee..1d5e0e8` found two Important, plan-conflicting gaps: the SQL validator permits unapproved SQL/functions and does not bind an allowlisted filename to reviewed content; the evidence manifest omits baseline settings/grants/revisions and the run-owned fixture IDs/operation receipts required for recovery/reconciliation.
- Ruling: both findings are real and load-bearing because the runner is the hosted write boundary and downstream T2/T5 hosted checks depend on it. Fix with fail-closed reviewed-content binding plus rejection tests for a dangerous function call, and complete redacted baseline/run-ownership evidence. A hash pin alone is insufficient if the pinned source itself contains an unsafe command; keep explicit SQL safety checks. Re-run focused offline tests only; no hosted calls. Cost if wrong: an unreviewed or destructive script could mutate production data or leave no recoverable fixture map.

## T1 independent-review fix round 1 (2026-10-25)

- Baseline commit: `1d5e0e8c1b170da90e1a609c1a4a6965b8fcdd5e`.
- Added immutable SHA-256 pins for the three reviewed SQL scenario files and an explicit function/expression allowlist plus privileged-function rejection. A modified T1 scenario containing `pg_terminate_backend` reaches neither fake Supabase nor psql; the pre-fix RED showed the Supabase fake was invoked.
- Expanded external evidence to persist STARTED before executing SQL, with PASS/FAIL + rollback reconciliation, counts/revisions/settings/grants/migrations before and after, all run-owned fixture/Auth IDs, and operation receipt IDs/dispositions. No personal data or raw query output is recorded.
- Post-commit verification: focused hosted-runner unittest command 11/11 with fake subprocesses; `python -m py_compile` and `git diff --check` passed; tracked worktree clean. No network/hosted calls. Commit `69fcb29a37b8daf02f670aa7cebcf9f05a8c6845` (`fix: pin hosted intake scenarios and evidence`).
- Report: `.superpowers/sdd/public-web-intake/task-1-hosted-runner-report.md`.

## T2 hosted-safety follow-up implementation (2026-10-25)

- Baseline: `69fcb29a37b8daf02f670aa7cebcf9f05a8c6845`. The product migration and disposable local T2 SQL/concurrency harness are unchanged. `scripts/test_database.py` and its loopback guards are unchanged.
- Cause: T2 receive calls hold transaction-level submission/network/global-capacity locks; the full rolling-window/capacity SQL run would hold the global lock for the long test and query the live pending total. The concurrency helper still truncates shared tables and commits fixed Auth/access/official fixtures. These hosted assertions remain BLOCKED/incomplete.
- Added pinned `public_intake_hosted_smoke_test.sql`: names-only catalog and privacy checks plus one run-namespaced receive/replay in a bounded rollback transaction (5s statement/idle timeouts, 2s lock timeout). Read-only preflight requires two free pending slots, enabled intake, unused run UUID/network hash, an active congregation, and no eligible cleanup candidates. Runtime lock/capacity/pause/rate/idempotency conflicts write BLOCKED evidence after rollback reconciliation.
- Runner writes external BLOCKED evidence for the legacy full T2 scenario and `--concurrency` without invoking Supabase CLI or psql. Safe smoke uses the same backup/project/account/TLS/migration preflight and STARTED/before/after evidence contract as T1. Only the new smoke SQL digest was added; existing T1/T5 pins are unchanged.
- Test-first RED reproduced the missing smoke allowlist and missing BLOCKED evidence. Final review caught and corrected a SQL validator token false positive on the temp scope table, then added a role-boundary assertion to keep the service-role helper from depending on unverified EXECUTE access to `private.business_today()`. T2 smoke SHA-256: `dc62f035075d61a146a6d19d595e1a38b2d9d3db362feca1f0b0caa615d23479`. Final fake-process suite: `python -m unittest discover -s scripts -p test_public_intake_hosted_runner.py -v` — 14/14; `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py` and `git diff --check` pass. No Supabase, PostgreSQL, Docker, hosted SQL, migration replay or real-target runner was invoked. The local database harness was not run under the offline-only constraint.

## T2 independent-review fix round 1 (2026-10-25)

- Baseline commit: `0b66092bd6c78beafcd3dae21e82d86d73b5016b`.
- Review finding 1: hosted smoke privacy checks omitted `public_intake_receipts`, `public_intake_accepted_events`, and `public_intake_decisions`; now checks SELECT denial for all four private queue tables and all three API roles.
- Review finding 2: T2 receive/replay creates a private intake receipt keyed by its run-owned submission UUID, while manifest/test recorded only generic operation receipts. Added distinct `intake_receipt_ids` and `intake_receipts` evidence; generic `operation_receipt_ids` remains separate. The fake end-to-end test asserts the exact run-derived ID and receipt table.
- Test-first RED: privacy coverage failed for nine missing table/role checks; the smoke manifest test raised `KeyError: intake_receipt_ids`. Focused GREEN: both targeted tests passed after implementation. T2 source digest updated to `d925b46d128cac8c20a2884c6335da22bfeb0235f211ecae31df30dd0f13a95b`.
- Final fix-round verification: focused hosted-runner suite 15/15, `py_compile`, `git diff --check`, and source SHA-256/pin comparison passed. No hosted calls, Docker, production migration, local disposable harness or loopback guard changes. Commit `91e4f71d0203a8acbdc88102a6266029f9f35ebe` (`test: record T2 intake smoke receipt evidence`); tracked worktree clean. Full detail: `.superpowers/sdd/public-web-intake/task-2-hosted-safety-report.md`.
- Updated plan invocation to use the T2 smoke and list incomplete hosted boundary/race checks. Report: `.superpowers/sdd/public-web-intake/task-2-hosted-safety-report.md`. Independent SDD review and any hosted execution remain pending; fresh external backup requirements still apply.

## T8 amended-acceptance follow-up implementation (2026-10-25)

- Baseline: `91e4f71` (`test: record T2 intake smoke receipt evidence`). Offline-only scope; no hosted call, Docker/service attempt, browser journey, migration/function deployment, account change, publication, or secret output.
- CI source review found `.github/workflows/verify-unified.yml` ran the unified gate without setting up Deno, although the gate executes Deno checks and existing local evidence used Deno 2.9.8. Test-first RED: new `test_workflow_pins_deno_before_running_unified_gate` failed because `denoland/setup-deno@v2` was absent. Added that action with `deno-version: v2.9.8` immediately before the unified-gate step.
- Acceptance amendment: Docker is no longer described as required. Prior T8 local PASS results remain source-bound historical evidence. The old local journey result is labeled historical BLOCKED; no journey was run in this follow-up. Hosted acceptance remains INCOMPLETE: read-only migration list has `202610250001` applied and `202610250002`–`004` pending; functions list empty; no fresh external full backup/manifest or `PUBLIC_INTAKE_DATABASE_URL`; T2 limits/concurrency intentionally BLOCKED; T3 address resolution remains fail-closed; hosted Turnstile config and temporary synthetic reviewer identities/grants are absent. No hosted PASS or user/disability/device observation is claimed.
- General hosted write resumption prerequisites: explicit exact project/ref selection and typed target confirmation; fresh external full-backup archive/manifest with checksum, readability and restore-path verification; secure TLS database connection; new external run-owned evidence manifest recording baseline/after-state, fixture/identity/receipt IDs and reconciliation; exact run-owned cleanup plan and authorization; and a coordinated reviewed migration/function candidate. Service-specific prerequisites remain authoritative address trust, real Turnstile hostname/server config, and temporary synthetic reviewer identities/grants. T2 limits/concurrency additionally require a reviewed non-interfering fixture/race design with exact cleanup and reconciliation. These conditions do not authorize execution; hosted acceptance remains blocked.
- Acceptance detail: `docs/verification/public-intake-acceptance.md`; report: `.superpowers/sdd/public-web-intake/task-8-amended-acceptance-report.md`. Existing loopback-only guards are unchanged.
- Implementation commit `f1ede5acd363b6e13ca0b68d50a2533e219107f6` (`ci: pin Deno for unified verification`). Focused output: `python -m unittest scripts.test_unified_gate.UnifiedGateContractTests.test_workflow_pins_deno_before_running_unified_gate -v` — `Ran 1 test`, `OK`; `python -m py_compile scripts/test_unified_gate.py` — passed; `git diff --check` — passed. No hosted calls or Docker/browser activity.

## T8 amended-acceptance independent-review fix round 1 (2026-10-25)

- Review finding 1: general hosted write readiness omitted explicit project/ref confirmation and run-owned external evidence with baseline/after reconciliation and exact cleanup. Added these requirements to the general hosted resumption criteria in both `docs/verification/public-intake-acceptance.md` and the T8 report; the hosted database journey remains BLOCKED.
- Review finding 2: the reviewed package did not include the requested ledger update. This completion entry records the T8 implementation, `f1ede5a`, and its focused 1/1 workflow contract, py_compile, and diff-check results.
- Focused verification: Python source assertion confirmed both reports explicitly contain project/ref, typed confirmation, external run-owned evidence manifest, baseline, reconciliation, cleanup, and BLOCKED/INCOMPLETE status; passed. `git diff --check` passed. No hosted action was run.

## T9 operations and release handoff (2026-10-25)

- Baseline: `c4330f464f1184919359f1599d7d6ff3b1158941`; branch `feat/public-web-intake`.
- Investigation confirmed no source evidence of a provisioned static host/account/hostname, no source-matched public-intake artifact manifest, pending hosted migrations `202610250002`–`004`, no deployed functions, unavailable fresh external backup/manifest and TLS DB URL, unresolved T3 trusted address, unverified Turnstile config/log retention, no synthetic reviewers/grants, and incomplete T2 hosted limit/concurrency checks. The existing candidate JSON belongs to `codex/ministry-production-completion`, not this branch. T8 review/fix-round is recorded complete at `c4330f4`; final whole-branch review remains for the controller.
- Added `docs/operations/public-intake.md` with service/ownership map, exact public/private config contract, origin/callback placeholders, secret boundaries, free quota/pause guidance, operator SQL for pause/unpause and bounded cleanup, backup/restore/rollback procedure, candidate proposal and BLOCKED/INCOMPLETE dependencies. Linked it from release, OAuth, unified responsibility, and acceptance evidence; corrected the old no-Edge-function statement for this new approved exception while preserving Cloudflare Pages as a proposal only.
- TDD RED: `python -m unittest discover -s scripts -p test_release_operations.py -v` with only the new runbook temporarily moved aside; the two new contract tests failed at missing required migration/config/blocker assertions (18 expected subtest failures); five existing release tests passed. The runbook was restored in `finally`.
- GREEN/post-commit: `python -m unittest discover -s scripts -p test_release_operations.py -v` — 7/7 passed (including local route/artifact fixture and the two new doc contracts); `python -m py_compile scripts/test_release_operations.py` passed; `git diff --check` and staged diff check passed. Did not run `flutter build web`, `python scripts/web_preflight.py build/web`, hosted checks, Docker, or local Supabase because no operator public defines/verified host exist and those hosted prerequisites remain blocked.
- Commit: `340c9cf` (`docs: record public web intake release readiness`), six T9-owned tracked files only. Full report: `.superpowers/sdd/public-web-intake/task-9-report.md`. Hosted activation/publication remains BLOCKED; no remote state changed.

- Task 9: complete (commits `c4330f4..6e2754b`, review clean). T9 independent review: spec compliant, task quality Approved, 0 Critical/Important/Minor; public release remains blocked by external prerequisites.

## Final whole-branch review fix wave (2026-10-25)

- Baseline: `6e2754b3330c9f51820a4e33b4b5a1833d5925d6`; branch `feat/public-web-intake`. Read the approved Spec, plan, T8/T9 reports, runbook and all exact source/test owners before editing. The existing read-only hosted ledger/report says `202610250002`–`004` are pending; no applied migration was rewritten and no hosted write/deploy/account/publication action occurred.
- Commit `a627dfb43354e77402a27e738c07e0db9f5b153b` (`fix: close public intake review findings`) covers the 4 findings and the validator regression found during relevant static checks. Remote HTTP `SUPABASE_URL` is rejected; HTTPS and explicit `localhost`, `127.0.0.0/8`, and `::1` development URLs remain accepted. T2 fixes pending, digest receipt and decision-metadata retentions at 30/30/90 days; T5 refuses any decision retention other than exactly 90 days. SQL fixture assertions cover below/above boundaries and the writer's recorded 90-day expiry. Archived congregation denial now runs as a global manager. Historical integration authority wording is marked superseded. T9 runbook distinguishes fixed periods from configurable abuse/capacity limits and labels earlier T8 SQL evidence as historical relative to these edits.
- RED/GREEN: `deno test supabase/functions/public-intake/config_test.ts` failed as intended on `http://project.supabase.co` before the scheme fix (`expected rejected Supabase URL`). Two new `test_release_operations.py` contracts initially failed on missing fixed-retention and superseded-authority wording; both pass after the docs updates. Existing manifest suite initially failed because `public_intake_hosted_smoke_test.sql` was absent from `scripts/verification_cases.json`; a focused regression failed on that coverage gap, then passed after listing the self-contained scenario in the guarded loopback manifest.
- Verification after implementation: `deno test supabase/functions/public-intake` — 19/19 passed; `deno check supabase/functions/public-intake/index.ts` — passed; `deno fmt --check supabase/functions/public-intake` — passed. `python -m unittest discover -s scripts -p test_release_operations.py -v` — 9/9 passed. `python -m unittest discover -s scripts -p test_verification_cases.py -v` — 10/10 passed. `python scripts/verification_cases.py --validate` — `PASS: 34 SQL scenarios and 10 concurrency cases validated`. `python -m py_compile scripts/test_release_operations.py scripts/test_verification_cases.py` and `git diff --check` — passed.
- SQL runtime verification: **INCOMPLETE**. No `psql`, `pg_isready`, `pg_ctl`, or native PostgreSQL service/target is available. No Docker/local Supabase was started and no hosted SQL was run. The two changed SQL fixtures contain assertions, and the hosted smoke fixture is now included in the guarded loopback manifest, but migration/application runtime behavior is not claimed verified.
- Full report: `.superpowers/sdd/public-web-intake/final-review-fix-report.md`.

- Final whole-branch fix round 1: 3 original findings addressed; retention finding remains open after scoped re-review (6e2754b..790c095); the additional manifest-gate regression was fixed and reviewed. Remaining issue: interval aliases can exceed the fixed 30/90-day policy. The final-review SDD skill allows one fix wave and directs residual load-bearing findings to the user. Evidence: .superpowers/sdd/public-web-intake/final-review-rereview.md. Cost if ignored: pending PII/decision metadata could remain longer than the approved retention policy.

## Final Sol 6.1 review follow-up fixes (2026-10-25)

- Baseline: `790c095b7d7d84a78f38fab3ac6e802669532bcc`; branch `feat/public-web-intake`. Confirmed the tracked hosted readiness record still lists migrations `202610250002`–`004` as pending; modified only those pending source files. Preserved earlier progress notes.
- TDD RED/GREEN: adapter-level RPC test first failed because the body keys were flat; passed after sending `{request: ...}`. Static SQL contract tests first failed on missing interval-component checks; passed after constraints and the T5 writer check rejected year/month components while retaining exact 30-/90-day comparisons. The smoke privilege test first failed on authenticated congregations denial; passed after preserving authenticated SELECT and continuing anon denial. Digest-pin test failed on the three changed source files before pin refresh; now all four allowlisted scenario sources match their pins. A safe source edit is rejected by the reviewed-digest guard.
- SQL scenarios now reject `interval '1 month'` for pending expiry and `interval '3 months'` for decision retention; T5 records an explicit exact 90-day timestamp. Receipt-retention policy was left unchanged. Runbook wording needed no change.
- Verification: Deno intake suite 19/19; `deno check` and `deno fmt --check` passed. Hosted-runner tests 19/19, verification-manifest tests 10/10, release-operation tests 9/9. Manifest validator passed (34 scenarios, 10 concurrency cases); relevant `py_compile`, source digest comparison and `git diff --check` passed.
- SQL runtime verification remains **INCOMPLETE**: no native PostgreSQL/psql target is installed. No Docker, local Supabase, hosted SQL, migration apply, deploy, account change, or publication was performed.
- Full report: `.superpowers/sdd/public-web-intake/follow-up-fix-report.md`.
- Implementation commit: `9924817e075d4770f7d8aaa88a1ef4c470827cb5` (`fix: honor public intake RPC and retention contracts`). The receipt and report were committed separately afterward.

## Final Sol 6.1 review follow-up: time-component retention aliases (2026-10-25)

- Baseline: `c3c0daf7785bedea02d1d5e7ceb29594cd404509`, clean branch `feat/public-web-intake`. Investigation confirmed PostgreSQL's interval fields are stored separately as months, days, and microseconds; hour/minute/second representations can compare as exact 30-/90-day lengths while containing time components.
- TDD RED/GREEN: extended the offline migration-contract test to require hour, minute, and second checks alongside year/month in both settings constraints and T5 writer guard. It failed first on missing `extract(hour from pending_ttl)=0`; it passes after adding all required component checks. SQL fixtures add 720/43,200/2,592,000-unit pending aliases and 2,160/129,600/7,776,000-unit decision aliases. Reviewed scenario pins recomputed after fixture edits.
- Verification: hosted-runner tests 19/19; verification-manifest tests 10/10; release-operation tests 9/9. `python scripts/verification_cases.py --validate` passed (34 SQL scenarios, 10 concurrency cases); relevant `py_compile`, all scenario-pin comparisons and `git diff --check` passed.
- SQL runtime verification remains **INCOMPLETE**; native PostgreSQL is unavailable. No Docker, local Supabase, hosted SQL, migration apply, deploy, account change, or publication was performed.
- Full report: `.superpowers/sdd/public-web-intake/follow-up-fix-report.md`.
- Implementation commit: `ea73412a231342ff454212ab2b170ed586cfba25` (`fix: reject time-based retention aliases`); report and progress receipt committed separately afterward.

## R1 — evidence reconciliation (2026-10-26)

- Scope: documentation and ledger only; T1–T9 were not restarted. Required baseline candidate `bed4cbe2887b38db98d13e109b8cd033707ee3ae`, branch `feat/public-web-intake`, origin/main `846a320619d3d8240df391a8b218c713bcceedc3`; worktree was clean before this R1 change.
- Local runtime: the source in `scripts/test_database.py` confirms the fallback to `~/.codex/tools/ieadpe-postgresql/pgsql/bin`, rejects non-loopback targets and uses the default `postgresql://postgres@127.0.0.1:54329/postgres` when `IEADPE_DATABASE_URL` is unset. Fresh commands on 2026-10-26 each exited 0: `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency` (`PASS: public_intake_test.sql`; last global capacity slot PASS), `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency` (`PASS: pending_review_test.sql`; last global capacity slot PASS), and `python scripts/test_database.py public_registration_authority_test.sql` (exit 0). This is local PostgreSQL 17.11 loopback evidence; Docker was not started. `psql` being absent from PATH did not prevent runner execution.
- Current-candidate ruling: the above three focused scenarios now PASS locally. Earlier local SQL INCOMPLETE receipts remain preserved as historical; they describe prior runtime availability and are not rewritten. Scope is limited to these exact scenarios, not the full SQL manifest.
- Hosted evidence remains separate: the already-captured authenticated CLI inventory identifies one `Discipulado IEADPE` project (`voqmtnqjrbugpazcimvh`); migration listing showed `202610250001` applied and `202610250002`–`004` pending; functions listing was empty; linked safe `SELECT 1 AS safe_probe` succeeded. One query attempt without `--linked` failed due to `DbQueryMutuallyExclusiveFlagsError` and the corrected linked read succeeded (CLI invocation issue, not database failure). No hosted SQL acceptance PASS is claimed. Backup/TLS runner prerequisites were not established. Historical environment-presence check had no `SUPABASE_URL`, `PUBLIC_INTAKE_TRUSTED_PROJECT_REF`, or `PUBLIC_INTAKE_DATABASE_URL`; current fix-round presence-only check below supersedes that `SUPABASE_URL` result while confirming the two other variables remain absent. No new CLI call or remote query was needed for this reconciliation.
- Full Flutter analyzer remains INCOMPLETE based on `.superpowers/sdd/public-web-intake/t8-full-flutter-analyze.log` (zero bytes) and the prior report of an over-four-minute invocation with an idle ~7 MiB process and <0.02 CPU seconds. The equivalent scoped direct Dart analyzer had completed cleanly on changed paths in the recorded T8 evidence. Cause is classified as a full analyzer process/tooling stall with no diagnostic output; evidence does not identify a source defect. The unchanged hanging Flutter invocation was not repeated.
- Full R1 details: `.superpowers/sdd/public-web-intake/task-r1-report.md`; acceptance table reconciliation: `docs/verification/public-intake-acceptance.md`.

## R1 fix round 1 — configuration evidence (2026-10-26)

- Base: `9e27686a3e488f879a6ede2531d0c75db2c1997c`. Reviewer P2 finding: current configuration evidence was stale. The earlier observation that `SUPABASE_URL` was absent is preserved as historical; current presence-only check returned `SUPABASE_URL_PRESENT=True`, `SUPABASE_URL_HOST_MATCHES_INVENTORIED_PROJECT=True`, `PUBLIC_INTAKE_DATABASE_URL_PRESENT=False`, and `PUBLIC_INTAKE_TRUSTED_PROJECT_REF_PRESENT=False`. This does not unblock hosted acceptance.
- Exact command and result are recorded in `.superpowers/sdd/public-web-intake/task-r1-fix-report.md`. Values are not displayed or stored; no Supabase CLI or analyzer was run.
- Reviewer P3 minor deferred to R7 evidence close: explicitly label the pre-existing PASS table in `docs/verification/public-intake-acceptance.md` as T8 historical, to distinguish it from the refreshed R1 date/candidate.

Task R1: complete (commits bed4cbe..f2daaec, review clean)

## R2 — hosted verification prerequisites (2026-10-26)

- Scope: documentation only, on `feat/public-web-intake`; no T1–T9 restart. The unique active `Discipulado IEADPE` project ref `voqmtnqjrbugpazcimvh` matches the parsed process `SUPABASE_URL` host. R1 read-only evidence still shows migrations `202610250002`–`004` pending and an empty function list.
- Controller-verified backup evidence: fresh external full custom-format archive, 857,367 bytes, SHA-256 `56bbe069fb9568d07a193f4197d300bb0f85dd8eccc358f234ca04de3bd4f33b`; external manifest validator passed for the exact project. External AES-256-GCM copy/decrypt-and-hash round trip matched the archive; key is DPAPI CurrentUser-wrapped. Archive listing succeeded with 1,011 TOC entries. Isolated PostgreSQL 17.11 recovery rehearsal restored and checked 9 application schemas, 37 migration rows, 24 congregations and 51 converts, then dropped the exact local database. This is a local restore rehearsal, not hosted restore evidence. Ten vault-related TOC entries were excluded because the local target lacked those schemas; database/Storage dump does not include object bytes.
- TLS readiness: PostgreSQL 17.11 client with `PGSSLMODE=require` authenticated successfully; `SELECT 1 AS safe_probe` returned `1`, and `pg_dump` completed. Connection URL was transient process-only; `PUBLIC_INTAKE_DATABASE_URL` remains absent from persistent process environment. No secret or identity value recorded.
- Reserved external runner receipt: `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\run-5655bd75-b699-47da-b3db-24d3e046e78a-evidence.json`; intentionally absent until runner STARTED/baseline receipt. No synthetic fixtures, hosted writes, migration/function changes, Docker startup, or publication occurred. Exact backup manifest/receipt remains external.
- R2 does not authorize hosted execution or change the hosted acceptance status. Exact target typed confirmation, STARTED/baseline receipt, exact cleanup authorization, reviewed candidate and remaining service-specific prerequisites are still required. T3 authoritative address trust, Turnstile configuration, reviewer access and hosted browser journey remain blocked.
- Report: `.superpowers/sdd/public-web-intake/task-r2-report.md`; acceptance update: `docs/verification/public-intake-acceptance.md`.

Task R2: minor (deferred): restore full external manifest baseline/fixture/identity/receipt reconciliation wording in the main acceptance checklist and add the backup-manifest locator to the R2 report at R7 evidence close.
Task R2: complete (commits 5f3b0f3..9e2b94e, review clean)

Task R2: complete (commits 5f3b0f3..9e2b94e, review approved with P3 nits deferred to R7)

## Runtime acceptance continuation — R3–R7 (2026-10-26)

- Execution checkout: `C:\Users\Carlos_Neto\.local\share\opencode\worktree\efb495\public-web-intake`, branch `feat/public-web-intake`. R1/R2 remain closed; implementation tasks T1–T9 were not restarted. Current R3 code candidate is `f0c960d87b75662ccbb3581311815290a6a160a2`.
- R3: hosted-runner implementation and offline tests are complete through `f0c960d`. The independent Sol 6.1 low review of that implementation reported no actionable findings. Offline runner suite passed 27/27; `py_compile` and `git diff --check` passed. The actual hosted invocation confirmed target/TLS identity, then failed closed at the psql role's application-schema baseline read and wrote the external redacted BLOCKED receipt at `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\run-5655bd75-b699-47da-b3db-24d3e046e78a-evidence.json`. It records `baseline_scope=unavailable`, `blocker_code=baseline_unavailable`, `scenario_dispatched=false`, and `hosted_write_attempted=false`; no credential, SQL output, baseline values or fixture ownership are included. No scenario SQL was dispatched.
- R4 read-only inventory: project `voqmtnqjrbugpazcimvh` was confirmed; 37 remote migrations were listed, with `202610250001` applied and `202610250002`–`004` pending; the hosted function list was empty. No migration, function, grant or account setting was changed. Candidate coordination/activation remains blocked pending a privileged protected connection and separately authorized live activation.
- R5: source and tests confirm `resolveSupabaseEdgeClientAddress` fails closed; forged `X-Forwarded-For` and `CF-Connecting-IP` do not produce a trusted address, hash or RPC call. Deno intake tests passed 19/19, `deno check` and `deno fmt --check` passed. Provider evidence did not establish trusted client-address provenance through managed Edge ingress. Turnstile hostname/server configuration and real deployment hostname remain unverified; preserve the limiter and release gate as incomplete.
- R6: hosted authority/intake/review/browser journey is BLOCKED. The available CLI DB role cannot read the required baseline schema; migrations are pending, no function is deployed, temporary synthetic reviewer identities/grants and exact cleanup scope are absent, and address-trust/Turnstile prerequisites remain unresolved. The runner dispatched no scenarios and attempted no hosted writes. The backup archive, manifest, local restore rehearsal and TLS identity probe are documented in R2 evidence; no hosted restore is claimed.
- R7 evidence reconciliation: updated `docs/verification/public-intake-acceptance.md` to label historical T8 results and record current R3 receipt, migration/function inventory and blocked gates; updated `docs/operations/public-intake.md` with protected-role and separate activation/publication prerequisites; updated `task-r2-report.md` with external backup/evidence locators and current receipt result. These changes do not claim hosted PASS or authorize production action.
- Focused verification: `python -m unittest discover -s scripts -p 'test_release_operations.py' -v` — 9/9 passed; `python -m unittest discover -s scripts -p 'test_verification_cases.py' -v` — 10/10 passed; `git diff --check` — passed. The runbook test initially exposed a stale expectation for the historical T8 completion sentence after candidate reconciliation; the runbook now keeps that history explicitly while pinning the current R3 candidate, and the focused suite passes.
- Independent Sol 6.1 low review found P2 (stale backup/SQL status in runbook) and P3 (manifest checklist omitted reconciliation/cleanup details). Updated the runbook with R1/R2/R3 evidence and restored the full external manifest requirements in acceptance. The reviewer re-read the corrected diff and reported no actionable findings; clean for commit. No hosted query or write was needed for this evidence close.
