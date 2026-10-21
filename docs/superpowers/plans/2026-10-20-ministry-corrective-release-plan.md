# Ministry Corrective Release Implementation Plan

> **Current execution priority (2026-10-21):** The consolidated current-state section below governs continuation on Windows Web/Android. Linux is deferred. Hosted project reads are authorized; APK builds and hosted mutations retain separate gates.

> **Current review entry:** Read “Consolidated current state and continuation — 2026-10-21” first. It owns current status/evidence/authority; original task IDs, contracts, acceptance and historical checkboxes remain preserved below.

> **Execution method:** native Luna Medium implements; native Sol 6.1 low independently reviews; the director coordinates and obtains independent final assembled review.

**Goal:** Correct the identified integrity/compatibility gaps, complete operator-facing attendance/progress, and prepare a proven hosted activation and Android delivery.

**Architecture:** Preserve the existing Flutter/Supabase model and Base44 theme. Use narrowly owned forward migrations, canonical bounded projections, a composed immutable pending-attendance controller, explicit cancellation/replacement lineage, and reusable persisted-progress presentation.

**Tech Stack:** Existing Flutter/Dart dependencies, PostgreSQL/Supabase RPC/Auth/private Storage, Python SQL/runner tooling, local Chromium and the existing Android toolchain. No new application package or paid service.

**Spec:** [Corrective release design](../specs/2026-10-20-ministry-corrective-release-design.md).

**Machine plan:** [Local tasks JSON](2026-10-20-ministry-corrective-release-plan.json). It carries complete task interfaces, exact owned paths, acceptance, dependencies and verification commands; it is not an authorization to mutate the hosted project. Bootstrap and operational stages below are deliberately outside automatic local-task execution.

**Status:** Local corrective source is implemented with scoped approvals. Current assembled acceptance is FAIL/BLOCKED (pinned 546/548, real T11 and Android missing). The consolidated index below replaces former Task 3-in-progress and 459/461/465 checkpoint status; those counts remain historical evidence.

## Consolidated current state and continuation — 2026-10-21

This is the single current execution/status index, mirrored in JSON `consolidated_current_state_2026_10_21`. [Spec S17](../specs/2026-10-20-ministry-corrective-release-design.md#s17-consolidated-authority-and-acceptance-state--2026-10-21) owns current authority; S01–S16/R01–R11/A1–A9/G0–G4 preserve product contracts. Markdown owns current evidence and operational steps; JSON retains Tasks 1–12/dependencies/interfaces and mirrors this index. Reconcile discrepancies before dependent work. Historical checkboxes/assessments below are process history, not a second queue or current approval. Do not reimplement approved slices.

**Workspace/authority.** Use `C:/Users/Carlos_Neto/.codex/worktrees/ministry-supabase-config/App discipulado`, branch `codex/ministry-production-completion`, investigated clean base `0b05473`. Historical merge/documentation refs are ancestors; application `lib/`, Android and migrations are unchanged since `d0d0e0f`. Native Luna Medium implements, native Sol 6.1 low independently reviews, director coordinates and obtains independent assembled review. This consolidation is documents only; review it before continuing implementation. Local commits/merges and hosted project reads are already authorized; push is not. Supabase CLI is authenticated and discovered `Discipulado IEADPE` (`voqmtnqjrbugpazcimvh`, `linked:false`), which proves discovery only. Local project linking/client settings may proceed within existing authorization after investigation; hosted migration/ledger/grant/OAuth/import/test writes are not authorized. No APK until ALL pre-gates and explicit build/signing approvals; G3 and G4 remain separate. Windows Web+Android only; Linux DEFERRED by user. Finalized attendance remains immutable; acknowledge cancellation then create linked replacement, preserving original marks/history and exact replay.

**Requirement inheritance.** Read the [2026-10-18 design](../specs/2026-10-18-ministry-production-completion-design.md) and [parent plan](2026-10-18-ministry-production-completion-plan.md) as provenance. Their two contextual registration entries/shared fields, canonical unique identity, genuine visits, effective enrollment/attendance follow-up, 1/7/30-day reminder boundaries, manual 3-visit deviation / 90-day completion guards, Team/access separation, history, Storage/SAF and accessibility obligations remain covered by R01–R11/S15. Their former model/executor/status and older single-entry wording are superseded, not new work.

### Portable evidence and current limits

Current review inputs: [consolidation README](../../verification/consolidation/2026-10-21/README.md), [result](../../verification/consolidation/2026-10-21/result.md), [independent review](../../verification/consolidation/2026-10-21/independent-review.md), [dated local report](../../verification/ministry-corrective-local-report.md), and [portable handoff guide](../../verification/2026-10-21-portable-branch-handoff.md). These are dated evidence, not present release authority. The handoff's historical push authorization does not authorize a push in this continuation.

`build/verification` is absent in the active worktree. References below use portable archive-member locators, not working local hyperlinks. `tar:X` means member `build/verification/corrective-release/X` in [original evidence tar](../../verification/handoff/2026-10-21-corrective-evidence.tar.gz), SHA256 `a2eca52bab31566dfc2cdaa7aca2ef93e9cc8a78f598473745fd9be58dd2104e` (522 regular relative files; [manifest](../../verification/handoff/evidence-manifest.json)). `zip:X` means the same prefix in [reviewed local evidence ZIP](../../verification/consolidation/2026-10-21/reviewed-local-evidence.zip), SHA256 `034df43a08dd675e7d958a0872785e2d70e066d73c0e9a6312f980a40d6361eb` (28 entries; [hash manifest](../../verification/consolidation/2026-10-21/reviewed-local-evidence-manifest.json)). Historical tools/specs are inactive in [recovered history ZIP](../../verification/consolidation/2026-10-21/recovered-local-history.zip), SHA256 `31bcadd71ec0066088b4008b39a1538d73b21911516e3d1ffbb4dda20ff4f3c0` ([manifest](../../verification/consolidation/2026-10-21/recovered-local-history-manifest.json)). Read regular relative members without execution; verify SHA/size/member hashes before relying on extracted bytes. Do not activate old tooling.

The two L0 approval-index JSONs were deliberately excluded by credential scanning and are absent from the tar. Do not reconstruct/expose them or turn their historical links into available evidence. Missing individual final reviews remain missing. Original `build/...` links in historical sections mean archive locations where a matching member exists; otherwise evidence is unavailable. T04-P and T12-006 durable final reviews ARE in the tar. Recent pinned full-suite/analyzer/web/preflight logs and source manifest are in the ZIP. Some later device/smoke/timeout logs are only described by dated reports or external backup; do not claim portable raw evidence until indexed and sanitized. Archives preserve hashes/candidate context; scope approval never transfers automatically to changed bytes.

### Existing units: implementation versus approval

`IMPLEMENTED` means source exists without a durable complete current scoped approval. `APPROVED_LOCAL` means only the described source-bound slice/checkpoint; it does not imply L0/hosted/device/release approval. `FAIL`, `BLOCKED`, `DEFERRED` retain their ordinary meanings. Task IDs and acceptance criteria are unchanged.

| Existing unit | Current disposition | Evidence and limit | Portable/source locator |
|---|---|---|---|
| B0 | BLOCKED | Windows Docker/bootable Android prerequisites missing; pinned SDK available historically, default differs. | `consolidation README; local report dated Windows continuation` |
| B1 | APPROVED_LOCAL | Importer/replay/race scoped historical approval; no real legacy import. | `tar:B1/review.md; 2026-10-20-corrective-execution.md` |
| B2 | APPROVED_LOCAL | Historical font/visual portability slice; current golden failures remain under L0. | `tar:B2/review.md; B2/promotion-review.md` |
| B3 | APPROVED_LOCAL | 459-test bootstrap checkpoint only; not current branch green. | `tar:B3/review.md` |
| T01 | APPROVED_LOCAL | Canonical projection scoped review; hosted parity unproven. | `tar:T01/review.md` |
| T02 | APPROVED_LOCAL | Immutable finalization/replacement scoped review; live acceptance missing. | `tar:T02/review.md` |
| T03 | IMPLEMENTED | Director-attributed scoped verdict; durable individual final review absent. | `tar:T03/coder-report.json; handoff acceptance limitations` |
| T04 | IMPLEMENTED | Attendance UX source exists; director-attributed verdict; live browser/device missing. | `tar:T04/coder-report.json; integration_test/unified_journey_test.dart` |
| T04-P | APPROVED_LOCAL | Actual first-save SQL and focused UI proof; original test-first RED not reconstructed. | `tar:T04-first-save/sol-final-review.md` |
| T05 | IMPLEMENTED | Bounded history source/migration004 exists; director-attributed verdict, missing individual final review. | `tar:T05/coder-report.json` |
| T06 | IMPLEMENTED | Progress UI exists; director-attributed scoped verdict, live persistence missing. | `tar:T06/coder-report.json` |
| T07 | IMPLEMENTED | Authority compatibility migration005 exists; director-attributed verdict, hosted authority unknown. | `tar:T07/coder-report.json` |
| T08 | APPROVED_LOCAL | Later pinned workflow fixture scoped review supersedes earlier pending note; Google/OAuth still open. | `zip:T08/captured-zone-stage-report.json; consolidation independent-review` |
| T09 | APPROVED_LOCAL | Windows portability scoped partial approval; Linux DEFERRED, ordinary matrix incomplete. | `zip:T09/coder-report.json; consolidation independent-review` |
| T10 | APPROVED_LOCAL | Literal-LF argv correction scoped review; live stack gates remain missing and Linux DEFERRED. | `zip:T10/final-candidate-report.json; consolidation independent-review` |
| T11 | BLOCKED | Journey source IMPLEMENTED; actual owned-stack Auth/PostgREST/Storage/Chromium execution, cleanup and sentinel survival unverified. | `integration_test/unified_journey_test.dart; local report guarded runner exit 2` |
| T12 | APPROVED_LOCAL | 006 local preparation: 16 forward migrations / 17 real checkpoints; later Windows fixture 30/30 and wrapper 2/2 scoped. Hosted parity/recovery unproven. | `tar:T12/continuation-006/sol-final-review.md; zip:T12/windows-fixture-followup/sol-final-review.md` |
| L0 | FAIL | Pinned 546/548:two 360px goldens; larger loops unexecuted; historical 528/529 unresolved; consolidation54-test run failed on90s timeout, narrow 1/1 does not waive. | `zip:final-local-candidate-manifest.json; tar:CHECKPOINT-T04-T07/checkpoint-report.json; consolidation README` |
| H0/H1 | BLOCKED | Recovery/catalog/ledger equivalence and exact package remain missing; project read access authorized. | `activation package; S12/S15/G1` |
| H2/O1 | BLOCKED | Hosted mutations/OAuth/grants/test writes not authorized; actual roles/Google/Storage journey unproven. | `S15 A1–A8/G1/G2; existing OAuth runbook` |
| H3 | BLOCKED | Firebase export or source-inspected verified absence and stable-ID reconciliation missing. | `S13; inherited 2026-10-18 requirements` |
| D0/D1/D2 | BLOCKED | No accepted runtime device/installed journey; release uses debug signing; G3/build/G4 outstanding; no APK. | `android/app/build.gradle.kts; S15 A9/G3/G4` |
| Linux T09/T10 matrix | DEFERRED | User directed no further Linux investment; never label old cross-platform acceptance complete. | `2026-10-21 amendment` |

The broad consolidation run is FAIL: 54 tests in 348.596s, one Bash subprocess timeout at90s. Focused repetition1/1 in 27.988s does not identify the timing cause. Pinned 546/548 failures remain360px Team 2.63% and gallery 3.64%; inspected glyph/icon-edge disposition is not a suite waiver and larger loops were not reached. Default 3.47.2 results remain distinct from pinned 3.47.7. Historical 528/529 is neither silently inherited as a current reproduced bug nor waived by isolated PASS.

### Ordered continuation within existing owners

These are refinements of existing B0/B2/T09–T12/L0/H0–H3/O1/D0–D2, not new feature tasks. Commands are future reproducible entry points from the canonical root, using explicitly resolved pinned executables; inspect local parameters and ownership first. Placeholder values must be resolved privately. Environment checks need direct evidence; behavioral changes require cause-based regression tests. None of these commands was executed by this document consolidation.


**Command convention (B0 resolves before running checks).** The command lines below are inner argv, not unwrapped execution instructions. The project has no `scripts/cmd`; use the installed global runner `C:/Users/Carlos_Neto/.codex/skills/two-model-sdd-pipeline/scripts/cmd`. Resolve `$MinistryBash`, `$MinistryPython`, `$MinistryPwsh` and `$MinistryPinnedFlutter` to actual absolute executables, and verify PowerShell supports `-CommandWithArgs`. `$MinistryPinnedFlutter` must report Flutter 3.47.7/Dart 3.13.5; PATH `flutter` is known to resolve 3.47.2 on this host and cannot close final gates. Bind each log to a unique existing-unit/candidate run. Example shape, with variables resolved in B0 (not executed here):

```powershell
$MinistryCmd = 'C:/Users/Carlos_Neto/.codex/skills/two-model-sdd-pipeline/scripts/cmd'
& $MinistryBash $MinistryCmd --full-file $MinistryEvidenceLog -- $MinistryPython -m unittest scripts.test_unified_gate.UnifiedGateContractTests.test_database_child_failure_is_retained_as_its_exact_exit_code
& $MinistryBash $MinistryCmd --full-file $MinistryFlutterLog -- $MinistryPwsh -NoProfile -CommandWithArgs '& $args[0] @($args | Select-Object -Skip 1); exit $LASTEXITCODE' $MinistryPinnedFlutter --version
```

**Inherited process PATH is mandatory.** An absolute launcher alone is insufficient: `run_unified_journey.py` resolves `flutter` through `shutil.which`, and both unified shell gates invoke `flutter`/`dart` from PATH. In B0 resolve the SDK root containing the verified 3.47.7 `bin`, Git Bash binary directory, Python directory and any required session-only `python3` launcher directory. Prepend those directories to the PATH of the current execution process and its children only. Do not use `setx`, user/machine environment APIs, shell profile edits or persistent aliases. Restore the parent process PATH after the bounded run. Example setup, using actual paths resolved in B0 rather than guessed SDK locations:

```powershell
$MinistryPreviousPath = $env:Path
try {
    $env:Path = @($MinistryPinnedSdkBin, $MinistryGitBashBin, $MinistryPythonBin, $MinistrySessionLauncherBin, $MinistryPreviousPath) -join [IO.Path]::PathSeparator
    # All logged probes and subsequent gates run here and inherit this PATH.
    # Start Git Bash with --noprofile --norc; PowerShell children with -NoProfile.
    # Assert the recorded paths and version output below before any acceptance gate.
} finally {
    $env:Path = $MinistryPreviousPath
}
```

Before gates, use the global runner to capture these nonsensitive probes inside the SAME inherited environment: Python `shutil.which('flutter')`, `shutil.which('dart')`, `shutil.which('python')` and `shutil.which('python3')`, plus child `flutter --version` and `dart --version`; Git Bash `--noprofile --norc -c 'hash -r; command -v flutter dart python3; flutter --version; dart --version; python3 --version'`; PowerShell `-NoProfile` with `Get-Command flutter,dart,python` and each version. Verify Python resolves the pinned SDK `.bat` launchers and Bash resolves the equivalent launchers in the SAME SDK bin; both Flutter 3.47.7 and bundled Dart 3.13.5 must be observed in all three processes. Verify Bash `python3` and PowerShell `python` use the intended Python runtime (provide only a session-local launcher outside tracked source if required). Stop for environment diagnosis on any mismatch. Reuse that exact inherited environment for Python browser runner, Bash and PowerShell gates; fresh login shells/default PATH are not acceptable. Retain path/version proof with the candidate/toolchain evidence. These are prerequisite checks, not product tests.

Use the same argument-safe launch shape for each listed check, substituting its resolved executable/arguments; capture the raw child exit, not merely successful wrapper launch. If the installed launcher cannot execute the pinned `.bat` correctly, classify/fix launcher setup before acceptance. Raw Supabase credential status and interactive ADB pairing codes are explicit exceptions: user-private terminal/device flow, no runner or transcript/evidence capture. Log only redacted health and the minimum nonsensitive ADB target/reverse summary. Never put credentials in runner argv or full logs.

#### 1. B0 / L0 toolchain and evidence index

**Dependencies:** consolidated-plan review. **Files:** `docs/verification/ministry-corrective-local-report.md`, `docs/verification/consolidation/2026-10-21/README.md`, `docs/verification/handoff/evidence-manifest.json`, `pubspec.lock`, `test/support/sdk_fonts.dart`.

- Record absolute resolved executable paths and pin Flutter 3.47.7 / Dart 3.13.5 through the inherited process PATH convention and three-process resolution proofs above for all direct and nested final gates; record framework/engine/font provenance, JDK/Gradle/browser/driver versions and lockfile digest. Default 3.47.2 is separate evidence. Do not alter dependencies to erase a renderer mismatch.
- Validate tracked archive SHA/member path/type/size/hash against existing manifests without running archived tooling; index each task review/log as archive+member+hash and source candidate. Bind new evidence to current HEAD+dirty/new-file hashes. Missing member remains missing; do not invent a final review.

```text
git status --short
git rev-parse HEAD
git branch --show-current
Get-Command flutter,python,java,adb,supabase -ErrorAction SilentlyContinue
flutter --version
python --version
java -version
supabase --version
```

**Review:** Sol checks exact toolchain/source identity and portable evidence coverage; direct inventory, no artificial RED.

**Expected result:** Reproducible candidate/toolchain index with every required evidence locator resolved or explicitly absent; no product acceptance inferred.

#### 2. T09/T10 / L0 Bash timeout diagnosis

**Dependencies:** B0 source/toolchain capture. **Files:** `scripts/test_unified_gate.py`, `scripts/verify_unified.sh`, `scripts/verification_cases.py`, `docs/verification/ministry-corrective-local-report.md`.

- Retain broad 348.596s / 54 tests / one 90s timeout and focused 27.988s / 1 pass as separate runs; reproduce the existing exact target method before grouped discovery.
- Reproduce boundedly with resolved Python/Bash identity; capture subprocess argv, child lifecycle, elapsed stages and inherited nonsecret environment/runner load. Compare narrow and discovery ordering and the working child-exit tests. Classify fixture/runner/environment/product cause before correction; increasing timeout alone is not a diagnosis.
- For evidenced behavior defect add a failing regression at the cause, fix within owner files, then narrow and appropriate grouped check. Environment-only remediation uses direct evidence. Stop repeated broad runs once new evidence no longer changes diagnosis.

```text
python -m unittest scripts.test_unified_gate.UnifiedGateContractTests.test_database_child_failure_is_retained_as_its_exact_exit_code
python -m unittest scripts.test_verification_cases scripts.test_unified_gate scripts.test_hosted_upgrade
```

**Review:** Sol verifies exact exit-code assertion is preserved, no skip/relaxation, and reasoned cause or named blocker.

**Expected result:** Root-cause disposition and stable bounded child-exit behavior; until then broad run remains FAIL.

#### 3. B2 / L0 visuals and historical race

**Dependencies:** B0 pinned identity, T09/T10 diagnostic disposition. **Files:** `test/features/ministry/ui/team_lifecycle_test.dart`, `test/widgets/ministry_component_gallery_test.dart`, `test/database/task_3_test.dart`, `scripts/database_access_concurrency.py`, `docs/verification/ministry-corrective-local-report.md`.

- Inspect retained expected/actual/diff images under pinned SDK/fonts. Investigate glyph/icon differences; source-bound 360px disposition does not pass failing tests. Execute 360/768/1440 and 200% text even when first golden assertion stops its loop, using a bounded test-structure correction if needed; preserve all assertions and review each capture. No blind update-goldens/tolerance change.
- Inspect original 528/529 lock failure and isolated-pass logs; bind a fresh reproduction to an owned disposable PostgreSQL target. Trace lock ordering and compare working race paths before changing code/test; missing owned DB is BLOCKED. Do not reopen approved unrelated features.

```text
flutter test --no-pub --concurrency=1 test/features/ministry/ui/team_lifecycle_test.dart test/widgets/ministry_component_gallery_test.dart
flutter test --no-pub --concurrency=1 test/database/task_3_test.dart
```

**Review:** Sol inspects visual artifacts at all required sizes and semantic race assertions; any baseline promotion needs actual comparison and explicit disposition.

**Expected result:** Failing golden/race causes resolved with evidence; unchanged historical failures retain explicit disposition, no waiver.

#### 4. B0 / T11 local backend and client setup

**Dependencies:** B0 identity, owned local service capacity. **Files:** `supabase/config.toml`, `scripts/run_unified_journey.py`, `scripts/verification_cases.json`, `scripts/verify_unified.ps1`, `scripts/verify_unified.sh`, `integration_test/unified_journey_test.dart`, `lib/configuration.dart`, `docs/verification/ministry-corrective-local-report.md`.

- Diagnose Docker WSL Virtual Machine Platform blocker with bounded probes and logs. Admin Windows-feature/reboot action needs user action; keep dependent T11 blocked while progressing other local units. Provision only identified coordinator-owned disposable loopback Auth/PostgREST/Storage/PostgreSQL and matching Chrome/driver; capture health/ownership and sufficient disk.
- Do not run raw credential-bearing Supabase status through a command/evidence logger. Let the guarded runner consume status internally; retain only its redacted health/ownership summary. Use guarded runner to create run-owned synthetic identities and matching public client URL/publishable key through private temporary settings; service role/PAT/DB password/Google secret never enter Flutter defines. Read existing actual config file location before any change. A no-config fail-closed page proves bootstrap only.
- Run existing T11 source, inspect all real assertions: canonical registration/edit/enroll/preview/draft/finalize/read-only/progress/cancel-linked-replacement/fresh session, cross-scope and revocation. Verify FK/lineage cleanup after success and partial failure plus unrelated sentinel survival. No privileged seeded-roster shortcut or hosted fallback.

```text
docker info
python scripts/run_unified_journey.py
bash scripts/verify_unified.sh
pwsh -NoProfile -File scripts/verify_unified.ps1
```

**Review:** Sol reads actual run logs, owned setup/cleanup proof and current source hashes; stubs/static build do not close browser acceptance.

**Expected result:** Actual local journey and both local gates exit 0 on same candidate, or exact BLOCKED/FAIL prerequisite without fabricated runtime PASS.

#### 5. D0 Android target and safe loopback connectivity

**Dependencies:** B0 Android toolchain inventory, T11 owned backend for connectivity. **Files:** inspect `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `docs/operations/unified-release.md`; **create future evidence document** `docs/verification/ministry-corrective-delivery-report.md` (currently absent).

- Prepare bootable authorized Google-capable emulator and physical device; investigate existing API 31/34 ADB offline and package-install stalls. Setup/connectivity only before APK gate: do not build/install/run app. Record actual API/browser/device identity and boot completion.
- For physical wireless ADB use Android Wireless debugging pairing UI and trusted private same-network transport; user enters short-lived pairing code directly into private local terminal/device flow. Never request/store code in chat, screen capture or logs; do not expose adb tcpip 5555 or public firewall rules. Select explicit authorized serial; disconnect/remove pairing after use.
- Keep backend host bind loopback. Once connection exists, adb reverse the actual owned local API port (54321 example must match Supabase local status), verify reverse listing/device route before later app execution and remove mapping afterwards. Use 127.0.0.1 on device with matching public client config; do not replace with hosted URL to bypass unavailable local stack. Only public URL/key in private client settings; no client service credentials.

```text
adb devices -l
adb -s <authorized-serial> reverse tcp:54321 tcp:54321
adb -s <authorized-serial> reverse --list
adb -s <authorized-serial> reverse --remove tcp:54321
```

**Review:** Sol checks target ownership, private pairing handling and loopback mapping evidence; physical observations identified separately from emulator/fixtures.

**Expected result:** Authorized online target and documented secure backend reachability, still no APK or Android product acceptance until all build gates pass.

#### 6. T12 / H0/H1 read-only package refresh

**Dependencies:** T12-006 local preparation preserved. **Files:** `scripts/inspect_hosted_contracts.py`, `scripts/rehearse_hosted_upgrade.py`, `docs/verification/ministry-corrective-activation-package.md`, `docs/operations/unified-migration.md`, `docs/operations/unified-release.md`.

- CLI authentication/project discovery already done: Discipulado IEADPE/voqmtnqjrbugpazcimvh/linked:false. Reuse authorized reads; no repeated login or migration command. Investigate local linking/settings separately within existing authorization, recording only nonsensitive config identity. Inspector needs explicit project-ref, endpoint, managed libpq service, local semantic contract and output; --help is safe, actual inventory needs authorized managed DB channel and read-only catalog queries. PAT is not a DB password.
- Refresh exact schema/ledger/function/policy/grant fingerprints without binding scope RPC or personal rows. Retain local 006 chain 16 migrations / 17 checkpoints; prepare exact hashes/order and classify complete/partial/conflicting effects including 180001/002 data guards.
- H1 backup/Auth/Storage recovery proof and isolated restore, H3 authorized source export/absence and stable-ID reconciliation remain separate prerequisites. Prepare reviewable package before requesting mutations; do not run hosted migrations/ledger repair/grants/import/OAuth/test writes.

```text
supabase projects list
python scripts/inspect_hosted_contracts.py --help
```

**Review:** Sol checks target identity, full semantic comparison, exact006 chain and protected evidence handling; stale healthy/404 observations remain historical.

**Expected result:** Updated read-only compatibility evidence and concrete G1/G2 package, or exact access/source/recovery blockers; no hosted activation claim.

#### 7. L0 final Web assembly

**Dependencies:** T09/T10 timeout disposition, B2 visuals/race, T11 actual journey/gates. **Files:** `docs/verification/ministry-corrective-local-report.md`, `docs/verification/unified-final-report.md`.

- Use pinned explicit SDK paths and same stable source/config/stack. Retain focused and full command exits/raw hashes plus live/fixture distinctions; run required SQL/concurrency/local gates and complete existing accessibility/routing checks.
- Recover missing individual review records if available; otherwise keep director attribution and request current bounded source/evidence review, never relabel absent historical artifacts. Independent assembled review resolves all Critical/Important findings and records remaining minor/operational blockers.

```text
flutter test --no-pub --concurrency=1
flutter analyze --no-pub
flutter build web --no-pub
python scripts/web_preflight.py build/web
```

**Review:** Independent Sol plus director evaluate R01–R11 / A1–A8 and current Web evidence; Linux explicitly DEFERRED, not blanket original-plan completion.

**Expected result:** Current Windows local/Web acceptance approved only if every required current gate passes; Android/hosted/legacy/release categories remain separately open.

#### 8. O1 / H2 / H3 / D1-D2 gated delivery

**Dependencies:** L0, H1 recovery/parity package, H3 source disposition, O1 real OAuth, D0 target and G3 signing, explicit build authorization. **Files:** `docs/operations/google-oauth.md`, `docs/operations/unified-release.md`, `android/app/build.gradle.kts`, `pubspec.yaml`; **create future evidence document** `docs/verification/ministry-corrective-delivery-report.md` (currently absent).

- Prepare exact setting/account/import/signing diffs and recoverability/custody evidence through existing G1/G2/G3; current release debug signing blocks delivery. These tasks remain gated, not instructions to mutate now. No APK build until ALL pre-gates+approvals, including reviewed package/version/certificate continuity and explicit build authorization.
- Only after approval build exact candidate with public-only configuration; inspect hash/size/package/version/certificate/toolchain, install/update approved bytes and observe A1-A8 on emulator/physical device. Hosted live checks/test writes require their separate authorization. Verify Storage/SAF, callbacks and durable fresh-session journey.
- Independent final review and G4 exact destination/audience/retention/download-byte policy precede publication. Local commits/merges authorized; push and artifact publication remain unauthorized.

```text
apksigner verify --verbose --print-certs <approved-apk>
aapt dump badging <approved-apk>
```

**Review:** Independent assembled review verifies S15 A9 plus real-role/legacy/device evidence and separate G1-G4 dispositions.

**Expected result:** Eventually exact signed installed/downloaded artifact evidence; currently BLOCKED, no speculative release/build PASS.

**Consolidation review:** outcome is recorded in the [separate consolidation review record](../../verification/2026-10-21-spec-plan-consolidation-review.md). Prior amendment/consolidation approvals apply only to their recorded hashes and scopes. JSON/link/diff validation is documentation evidence only.

## Parallel-document incorporation and quality coverage — 2026-10-21

This refinement applies [S18](../specs/2026-10-20-ministry-corrective-release-design.md#s18-documentation-authority-inherited-coverage-and-engineering-assurance--2026-10-21) and the [actual skill routing](../skills-routing.md) to the approved current plan. It retains all task IDs/statuses/acceptance and does not create a second implementation queue. Investigation base for this broader documentation audit: `36c53e9f6f233868abdac44fdf0569c513dc9463`. The preceding source-bound product evidence still belongs to its original hashes/runs; documentation changes do not trigger broad application checks or erase failures.

### Document roles and former queues

| Document group | Current role and authority |
|---|---|
| This spec + Markdown + JSON | Sole requirement/interface, current-status/continuation and mirrored-task authority respectively. |
| All other `docs/superpowers/specs` / `plans` including older JSONs/templates | Historical requirements/design/execution provenance; preserved bodies and IDs, current owners mapped in S18. Read source-specific details without executing old tasks/executor/build/push instructions. |
| `docs/integration` contracts/design/input/sequence references | Technical field/envelope/theme details under canonical decisions. Runtime handoff contract is an API reference; it is not a session-resume handoff. Old authority/snapshot clauses yield to current typed completion contracts and S05/S09. Investigate discrepancies, no silent codec relaxation. |
| `docs/operations` runbooks | Technical operator procedures and dated evidence under existing H/O/D tasks and G1–G4. They provide no separate mutation/build/publication approval; refresh drift/quotas/settings before using a command. |
| Root README / superpowers README / skills routing | Entry points and actual applicability map; no independent task/status queue. |
| Handoffs/ledgers/manifests/report entry points | Dated source/candidate/scope/evidence snapshots; current owners consume useful proof and missing obligations, not old next-task instructions. |
| `docs/research` package/source/quality artifacts | Dated research provenance, no independent executor, queue or runtime approval. |
| Raw reviews/logs/archive manifests/ZIP/TAR/screenshots | Immutable evidence. Preserve bytes/hashes/exclusions; Git history retains bodies before banners. No reconstructed historical RED/approval and no automatic current PASS. |

S18 maps each source family’s retained obligations to existing owners and resolves supersession. Existing task file ownership remains authoritative; a confirmed defect outside it requires a bounded owner amendment before editing. The partition table below is a review/coverage checklist for already-required behavior, not a demand to duplicate tests or repeat completed features. Reuse candidate-matching valid evidence; run new/affected checks during later implementation. Environment/inventory/document work uses direct evidence. Commands and process-inherited pinned PATH in the consolidated section remain mandatory.

### Case partitions, boundaries and evidence ownership

| Coverage key | Requirements / existing owners | Partitions | Boundaries | Evidence / review |
|---|---|---|---|---|
| `authority_identity` | R02/R06/R07; S05/S09/S15A2-A5; T01, T07, T08, T11, H2, O1 | Registrar create-without-read; own active/foreign/archived scope; global selection; revoked existing token; organizational job title versus verified login grant; same-scope explicit identity versus nonexistent/foreign/already-linked/ambiguous ID. | Empty/one/multiple direction grants; exact 12 organizational role codes remain directory data; no name-only merge. | Current SQL/RPC/HTTP allow+deny and no-partial-state assertions; typed codec/permission review. Old independent ministry-grants contract is historical, not new runtime authority. |
| `paging_capacity` | R02/R05/R06/R08; T01, T05, T07, T10, T11, L0 | Valid scoped prefix/page versus tampered/foreign/filter-changed cursor and unsupported filter; complete result versus genuine empty/search-empty/error. | Page0/1/100/101; signed cursor tail ordering/no duplicates; enrollment99/100/101 historical total and duplicate active enrollment, both race orders. | Bounded query/page traversal and invariants with actual argv/scenarios; retain measured page/payload/read cost if captured, never invent latency/budget numbers or use Firestore read assumptions. |
| `attendance_history` | R03/R05; S06/S08/S16; T02, T04, T04-P, T05, T06, T11, L0 | Open-unfrozen read-only preview; frozen stored roster including empty; finalized/canceled; legacy/canonical names; canceled predecessor versus mismatch/duplicate replacement; active versus completed/archived class. | Enrollment start/end date−1/on/+1; zero/one/many eligible, closed-but-date-eligible; rename before/after freeze; future finalization; save/cancel and duplicate replacement both commit orders. | No-DML preview, first-save exact roster, persisted reopen, rollback on mismatch, new-operation immutable denial and exact authorized replay; progress present/(present+absent), null denominator 0, exclude excused/unmarked/canceled. No copied marks/history rewrite. |
| `retry_generation` | R04/R06/R08; S07; T03, T04, T11, L0 | Acknowledged/ambiguous/definite rejection; same versus changed ID/payload/action/revision; late response after logout/scope/user/session/route change; success on old target must not refresh/save new target. | No retry/one/repeated exact retry; overlapping save/open/refresh and both relevant completion orders. | Controller/production-boundary regression proving immutable pending command and rejected late generations; actual T11 where available. Revert/mutation probe labelled by actual timing, never reconstructed historical RED. |
| `campaign_baseline` | R01/R02/R05/R08/R10; inherited campaign contracts; B1, T01, T07, T11, L0, H3 | Register new convert versus non-convert student; real visit versus qualifying finalized presence; manual historical state versus active/closed enrollment; exact import/reimport/tombstone/ambiguous source. | 1/7/30-day follow-up; deviation 2/3 actual visits; completion 89/90 days with known start+active state; Sunday 19:59/20:00 America/Sao_Paulo weekly boundary versus academic America/Recife date policy. | Existing lifecycle/weekly/import/report/feedback/registration suites are preserved, not reimplemented. Check affected coupled projections/counts and history/source parity; native SQL fixtures do not prove real source completeness. |
| `oauth_session` | R06/R07/R11; S15A1/A2/A8; T08, T11, O1, H2, D2 | First/existing Google login; denial/cancel/back; cold/warm Android return; expired/replayed/missing verifier; duplicate/unknown query or unsafe destination; offline/online logout/user switch/revocation. | Exact trusted origin/path/query and local/hosted/client identity, no wildcard/fragment bypass; no email fallback/metadata authority. | Authorized actual PKCE/provider/session evidence separately from synthetic SDK/loopback tests; current exact callback/config setting diff for any G2 mutation. |
| `photo_file_privacy` | R06/R08/R11; inherited private photo/export contracts; T11, L0, H1, H2, O1, D2 | Own pending/attached versus foreign/expired/revoked; picker cancellation/corrupt/oversize/EXIF/transparency; upload/attach/remove failure retains prior image; user/scope loss while choosing/uploading/downloading/writing. | Existing 192×192JPEG processing,1 MiB object and1 hour pending expiry contracts; actual capability limitations and supported file-provider errors. | Real Storage allow/deny + picker/resume + protected-cache evidence; cleanup uses Storage HTTP then restricted metadata RPC, no direct storage.objects deletion. Only authorized operator cleanup. No religious prefill/PII routes/logs/persistent private-image URLs. |
| `xlsx_feedback` | R01/R08/R11; inherited backup/report/feedback; B1, T11, L0, H3, D2 | Supported XLSX roundtrip/accents/age0/null versus .xls/formula/malformed ZIP/oversize; chooser unsupported/cancel/error/saved; feedback submitter versus manager; scope loss during chooser/write. | Existing 10 MiB compressed / 50 MiB expanded / 10,000 rows and 10,001 rejection; feedback 5000/5001 chars; report inclusive endpoints/filter/sort/export exact displayed rows and >1000 rows. | Reuse valid baseline codec/writer evidence if hashes match; affected regressions and real secure-context browser chooser/Android SAF flush-close-reopen/persistence proof remain separate. No new exporter feature inferred for unsupported browsers. |
| `ui_accessibility` | R07/R08/R11; S03/S15A8; B2, T04, T06, T08, T11, L0, D2 | Loading/empty/search-empty/error/retry/forbidden/not-found/stale-revision/success; keyboard/dialog cancel and restored focus; labeled attendance and screen-reader outcome; reduced motion versus normal. | 360/768/1440 and 200% text; 48 logical px targets;4.5:1 ordinary text/3:1 meaningful boundaries; long accented text; all viewport cases execute despite earlier golden fail. | Source-bound visual comparisons + measured contrast and actual keyboard/assistive-tech/human observations with unexecuted markers. Dark-mode obligation/support disposition unresolved from old source; no automatic palette/theme change. |
| `browser_host` | R08/R11; inherited unified-quality/release; T09, T10, T11, L0, D2 | Configured real local journey versus no-config bootstrap; route cold/reload/back/forward/callback; real asset bytes versus HTML wildcard replacement; Chromium versus Firefox/WebKit smoke capability. | Exact route fallback/MIME/HTTPS/public configuration; current host file-size/count limits revalidated from actual artifacts before destination approval. | Chromium Auth/PostgREST/Storage/cleanup/sentinel proof; Firefox/WebKit executed or explicitly incomplete plus support disposition, no silent waiver/new automatic blocker from this audit. Hosted QA requires separate authorized destination/action. |
| `recovery_operations` | R09/R10/R11; S12/S13/S15G1-G4; T12, H0, H1, H2, H3, O1, D0, D2 | Recorded+present/equivalent-unrecorded/absent/partial-conflicting catalog; exact recognized prefix versus drift; stable source IDs versus ambiguous/unavailable source; full versus partial DB+Storage recovery. | 16 forward migrations / 17 real checkpoints through 006; restore metadata+bytes/count/hash/RLS/Auth/photo; old/new writers and approved write-pause; same-certificate update/version continuity; exact downloaded artifact bytes. | Fresh authorized catalog fingerprints; protected encrypted independent backup copies and isolated measured restore; quotas/MAU/database/storage/egress and outage/incident owner; concrete G1-G4 package. No paid availability/geo/LB promise or XLSX-as-backup. |
| `environment_evidence` | R08; S17/S18; B0, T09, T10, T11, L0, D0 | Pinned versus default SDK; narrow versus grouped Bash timeout; real owned loopback target versus unknown/hosted; valid member versus absent/excluded historical evidence. | Flutter 3.47.7 / Dart 3.13.5 inherited Python/Bash/PowerShell PATH; 90s timeout 54-test failure versus 27.988s narrow PASS; device online versus offline; interactive ADB secret never logged. | Direct path/version/ownership/child-exit/hash/portable-index checks, no artificial TDD. Diagnose cause before timeout change; no broad PASS from isolated PASS, no fixture PASS for actual stack/device. |

The mirrored JSON adds `existing_evidence_references` per coverage key (current SQL/UI/controller/OAuth/photo/file tests and runbooks); these are review entry points, not new ownership. Run commands from the existing owner’s ordered continuation, preserving its dependencies/review/expected results and approved file scope. T04-P’s wrapper belongs in `verification.new_test_files` and its explicit verification command, while the SQL scenario is task-owned; duplicate placement of that wrapper in `touches` was a planning-metadata incompatibility found by the actual installed validator, not a product defect.

### Remaining refinements within the current ordered continuation

- **B0/T09/T10/L0:** retain exact toolchain/PATH proof and root-cause diagnosis of the grouped Python/Bash timeout. Skill/source hash and documentary validity are static SQA inputs; real child exits/environment/ownership and application checks are dynamic evidence. Raw status/ADB pairing remain private, not full-file logs.
- **B2/T11/L0:** ensure larger golden-loop cases execute and inspect every requested viewport; recover actual keyboard/focus/screen-reader/contrast findings. Preserve old-target save/late-generation and actual cleanup/sentinel coverage. Record dark-mode source/approved support disposition and Firefox/WebKit smoke/support evidence explicitly as unresolved/incomplete where absent; this audit adds neither a theme/browser feature nor a silent waiver/new automatic build blocker.
- **T12/H0/H1/H3:** preserve exact 006 rehearsal proof and refresh hosted catalog via existing read authorization. Include source counts/links/weekly guards/orphan history, independent encrypted recovery copies, DB/Auth/config plus actual Storage bytes/policies, isolated restore/reconciliation and measured duration, current quota/cost/outage/incident ownership. No backup/import/cleanup/cutover mutation is authorized here.
- **O1/H2/D0/D2:** preserve PKCE edge/session transitions, photo picker/resume/cache and actual Storage enforcement, secure-context file capability/SAF flush-close-reopen, signing/update/artifact/download proof, actual hosted direct-route/MIME/callback validation and destination policy. Keep prerequisite diagnosis separate from APK build and G1–G4 operations.
- **Every bounded brief/review:** apply S18 DoR/DoD, actor/value, exact scope/contracts, top-down change sketch and risk partitions; record SQA process assurance versus SQC product observations, static/dynamic and fixture/live/device distinctions, Critical/Important closure and minor disposition. No standards certification, new external skill installation or invented numerical quality target follows from this matrix.

These refinements only make existing obligations/evidence gaps findable in one plan. User approval of the consolidated direction persists; this documentary audit introduces no new generic permission checkpoint. Product execution continues later through the existing native pipeline and authorization boundaries.

## Global constraints

- Preserve the application baseline `f2fffca489fd36f55957bba49736cb35dd31d5a6` and read parent requirements at `origin/main@c71534d`; rebase/integrate deliberately if HEAD changes, preserving existing work.
- Technical artifacts in English, product UI in Portuguese, existing Base44 theme, existing dependency lock and Supabase Free. No unrelated refactor or replacement backend.
- Finalized attendance is immutable for new operations, with exact receipt replay retained. Correct by acknowledged cancellation and a linked new session, preserving original history.
- Canonical operational identity comes from `ministry_people`; legacy fallback applies only to unlinked rows. Never merge by name, rewrite frozen snapshots, fabricate conversion dates or convert attendance into home visits.
- Retry an ambiguous command with the exact same operation ID, payload, revision and action; authorization loss clears protected state and discards late replies.
- Forward migrations only. Preserve strict public payload/result types, RLS/grants, lock ordering, idempotency, current one-active-enrollment and historical capacity invariants.
- New test files belong to each JSON task's `verification.new_test_files`; SQL/Python scenario files are explicitly owned in `touches` and executed through contained Dart wrappers/authoritative commands. This keeps the installed Flutter RED adapter meaningful without pretending SQL is a Dart test file.
- Bootstrap failures are disclosed and repaired; no hidden waiver or red full-suite approval. Local, hosted, legacy and device evidence have separate states.
- Read-only Sol stage reviewers do not implement. Only director arbitration may change task acceptance; fixes return to the same native Luna task implementer; record actual model availability and do not substitute silently.
- Local commits/merges are authorized by the user; push, hosted mutations and Android publication are not authorized by this consolidation. Preserve the user's existing changes and do not expose credentials/private records.

## Execution protocol for this environment

The current method is native Luna Medium implementation and fresh native Sol 6.1 low read-only review, with director coordination and independent final assembled review. Investigate repository, behavior, contracts and failures before design/fixes. Bind each bounded brief to existing task files/interfaces/dependencies and exact candidate hashes; record actual model, commands/exits, findings and re-review. Return findings to the same task implementer. One writer owns shared contracts. Direct evidence suffices for environment/inventory/document checks; no artificial TDD RED. Behavioral corrections require meaningful assertion RED/GREEN and appropriate final gates.

Local commits and merges have user authorization; push does not. Hosted project reads have authorization, mutations do not. No APK build until every existing pre-gate and separate build/signing approval passes. The original OpenCode invocation/session protocol is historical provenance in `0b05473`, not executable policy. The consolidated current-state section governs stop points, source identity, status and continuation.

## B0 — Environment and baseline entry

Historical bootstrap checklist: retain old observations/process boxes; use consolidated B0 continuation for current readiness, not the former import/36-diagnostic baseline.

**Owners:** director prepares/validates; any bounded environment repair is explicit. No product change during this document-authoring stage.

- [ ] Verify requested native implementer/reviewer availability and record actual identity; template declarations are not runtime proof.
- [ ] Verify trusted portable hooks. Existing project hooks point to Windows paths; do not execute them as if valid on Linux, silently discard inherited restrictions, or activate packaged Terra/Sol example defaults. Confirm the adapted protocol instead of starting a second automatic executor.
- [ ] Verify Flutter/Dart, Java/Android, PostgreSQL, PowerShell, Chromium/driver and loopback Supabase prerequisites as needed. Repair local executable modes via the supported installation/workspace process; `bash scripts/cmd` is valid for its currently non-executable copy.
- [ ] Pin SDK and test font provenance; retain the current lockfile. Capture an exact fresh baseline (commands, tool versions, file hashes, raw failures) before fixing it.
- [ ] Record the known expected baseline: import failures, two golden suites and 36 analyzer diagnostics. Any additional failure is investigated, not assumed inherited.
- [ ] Resolve test commands from the existing Flutter project; new Dart database/operations wrappers invoke the specific SQL/Python tests and retain child exit codes. Do not feed `.sql` files to the Flutter test runner or install an unrelated Python toolchain just to satisfy a name.

## B1 — Restore importer/schema compatibility

**Own files:** create `supabase/migrations/202610200001_import_revision_compatibility.sql` and `supabase/tests/database/import_revision_compatibility_test.sql`; extend `supabase/tests/database/import_test.sql`, `scripts/database_import_concurrency.py` and `test/database/task_16_test.dart`; add `test/database/import_revision_compatibility_test.dart` using the existing contained database harness. Recheck unused migration number.

**Contract:** existing `ieadpe_import_convert(operation_id uuid,payload jsonb)->jsonb`; no accepted client revision/person field is added. Existing result/replay/duplicate/tombstone contracts stay intact. New legacy rows have revision 1/person_id null; canonical reconciliation remains a separately audited stable-ID operation.

- [x] Add/reproduce a valid accepted import after all migrations with the mandatory revision column; observe SQLSTATE 23502 in the current code. Add duplicate, tombstone, lost-response replay, concurrent same legacy ID and counter/zero-confirmation transaction-order assertions.
- [x] Have the native Luna implementer replace the importer in a forward migration, explicitly initializing the inserted composite record's revision, retaining every prior validation/lock/result/receipt rule.
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

Start with one writer at a time. `depends_on` is authoritative; exact `touches` and registered new test paths define scope. Shared model/codec/server contract producers land before consumers. The current native director/implementer/reviewer protocol owns dispatch; installed deterministic validation/command helpers remain useful without invoking Script CEO.

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
- [x] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [x] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

**Focused verification** (expected PASS, except the initial meaningful RED). Existing T04-P/S16 commands are included for the already-owned preview regression; retain all original UI targets:

```text
flutter test --no-pub --concurrency=1 test/features/ministry/ui/attendance_history_test.dart test/features/ministry/ui/lesson_session_test.dart test/features/ministry/ui/session_navigation_test.dart test/features/ministry/ui/session_visual_test.dart
python3 scripts/test_database.py attendance_roster_preview_test.sql
flutter test --no-pub --concurrency=1 test/database/attendance_roster_preview_test.dart
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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- Exact ordered local upgrade includes 202610180003, all nine October 19 migrations and all six corrective October 20 migrations through 006; test partial resume and stop on deliberate catalog drift.
- Upgrade preserves counts, stable IDs, manual states, snapshots, scope/replay rules and current RPC envelopes; expected hashes and roles are recorded without private records.
- Activation package names target/source/migration digests, backup/restore checks, old-client compatibility/write-pause plan, monitoring and rollback/stop conditions; no hosted writes or ledger repair is executed.
- Unknown Firebase source and unavailable APK/device evidence remain explicit blockers; do not infer source absence from empty Ministry tables or invent supported import shapes.

**Work steps:**

- [ ] Read cited spec sections and predecessor interfaces; check the task-owned paths and current migration numbering.
- [ ] Author the named behavioral assertions, execute focused tests and retain an assertion/runtime RED with at least one test executed; never count compile/load failure as RED.
- [ ] Implement only the owned behavior and exact contracts; preserve security, lock/replay ordering and existing historical data.
- [ ] Run the listed focused verification; inspect expected results and repeat only for changed code or unresolved failures.
- [ ] Director runs and inspects the authoritative configured full Flutter suite and analyzer through the pinned command runner; no ordinary task approval while gates are red.
- [ ] Director captures HEAD plus full candidate/new-file digest, dispatches a read-only native gpt-6.1-sol reviewer with low effort, returns Critical/Important corrections to the same native Luna implementer and records re-review. Local commits/merges are authorized; push remains unauthorized.

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
- [ ] Rehearse the ordered pending sequence: `202610180003`, October 19 `001` through `009`, then October 20 `001` through `006` (T12-006: 16 forward migrations). Preserve old/new client compatibility or define an explicit write pause/update boundary; new nested create/edit envelopes must not break an active old APK silently.
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

Author: native Sol 6.1 low. Assessment only; no tests/builds/remote writes were performed for this document. Existing plan/spec remain the owners; no new plan is necessary. Read [S15 acceptance and approval boundaries](../specs/2026-10-20-ministry-corrective-release-design.md#s15-completion-assessment-and-bounded-delivery-clarification--2026-10-20). Historical assessment of the then-dirty candidate; current authorization is recorded in the consolidated section.

### Historical task-by-task completion assessment (superseded status index below)

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
| T11 coupled Chromium journey | Incomplete / blocked | No T11 executed acceptance report found. `integration_test/unified_journey_test.dart` contains the current journey assertions; actual local Auth/Storage/Chromium execution, cleanup and sentinel-survival proof remain missing. Full stack capacity is a blocker. |
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

Native Luna Medium implements one bounded task at a time; a fresh native Sol 6.1 low reviewer checks each task read-only. An independent final reviewer checks the assembled product/evidence and unresolved findings. Do not use OpenCode or historical CLI session-resume instructions. Reviewer findings return to that task's native implementer. The director owns approval arbitration and evidence indexing; no automatic commits/pushes. Read applicable engineering skills for execution. The former planning-review stop point is superseded for the bounded local work authorized in the 2026-10-21 Web/Android amendment; release gates remain separate.

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
- [ ] Prove every 180001/180002 DDL/data/guard effect, propose exact ledger commands only for fully equivalent versions, pin 16 forward migrations/checksums through 006 and resume/drift criteria. Unknown state stops; no blind ledger repair/push.
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

Self-review checked all units B0–B3/T01–T12/local closing/H1–H3/D1, source-versus-hosted evidence, stale report wording, no secret values and no duplicate implementation queue. The consolidated Markdown and JSON now share current status/continuation; this dated assessment remains historical evidence. No existing checkbox was falsely marked complete.

**Historical review prompt:** This completion-map review preceded the current consolidation; it is not an unanswered execution-method approval checkpoint.


## T04-P: bounded first-save roster preview correction — 2026-10-21

**Owner:** Sol 6.1 low authors brief/spec/plan and independently reviews; native Luna Medium implements. **Spec:** S16 above and existing S06/S07/S11. This is corrective work within T04's promised open draft/finalize/replacement interface; SQL ownership below is the explicit bounded extension to the original T04 file list. It does not reopen completed tasks wholesale or authorize hosted migrations. Do not use OpenCode or build APKs before all pre-gates/approvals. Local commits/merges are authorized; push is not. This task’s historical focused-gate sequence is preserved below.

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

**Machine-plan reconciliation:** JSON Task 4 now explicitly carries S16/T04-P ownership, approved scoped status and evidence limits; Task 12 includes 006. Original task IDs/interfaces remain stable. No separate executor or replacement task queue is introduced.

### T04-P local closing record — 2026-10-21

**APPROVED_LOCAL**, per [durable Sol review](../../../build/verification/corrective-release/T04-first-save/sol-final-review.md). This dated record supersedes earlier SQL-blocked status for the reviewed local candidate while preserving the original checklists/history. Real SQL `revocation-fixture/real-sql-green.log` exited 0 (SHA-256 `04ee04a3d1d5046dbd5136c1717fb4cc2d55e026ba59c5d16119776346922daf`); attendance integrity SQL passed, contained focused Flutter tests 43/43, session visual 6/6, manifest tests 8/8 and scoped analyzer clean, as linked in that review. Migration 006 digest: `a422ca796a1ec3fade9cdc6cce82d8dd06cbfce890801e274fcb40f9080bdaeb`; corrected fixture digest: `ac89601fe02a4ee3287d270be956c78c0eb9b431f7e17ef0d028a647e4b48ed0`.

The original test-first SQL RED and UI RED/GREEN checkboxes remain unchecked as historical process evidence: the retained UI negative control is a **post-implementation mutation probe**, not reconstructed historical TDD RED. Later temporal/revocation fixture REDs and real SQL GREEN are valid specific correction evidence, not proof of the original missing-preview RED. The initial-preflight checkbox is likewise retained pending a complete contemporaneous capture rather than inferred from final candidate hashes. Functional local approval does not rewrite those history limitations.

T12's dependent 006 integration now has separate [APPROVED_LOCAL review](../../../build/verification/corrective-release/T12/continuation-006/sol-final-review.md), with 17 real checkpoints and derived manifest SHA-256 `2e05cbb0a747d4b34321c6a60f5838e13f043c3d733ec314a299bddc99742fc9`. No hosted migration, parity/ledger repair, restore or release approval follows. T11 browser/cleanup/sentinel, current L0 assembled acceptance, H1/H2/H3, device/signing/APK/download gates remain pending.

## 2026-10-21 Web and Android functional-acceptance amendment

**Authority and scope:** The user selected functional acceptance on Web and Android and directed that no further work be invested in Linux. Continue the existing T11/L0/O1/D0/D2 requirements on Windows; no replacement implementation plan or duplicate feature queue is created. Linux 23/25 acceptance remains **NOT EXECUTED / DEFERRED BY USER**, so T09/T10 ordinary acceptance and original-plan completion must not be claimed from this platform recut. This amendment does not waive failing checks or confer branch/release approval.

**Director ruling — 2026-10-21:** The user's selection authorizes the bounded local investigation, prerequisite diagnosis, existing tests and necessary scoped corrections in the checklist below, with the native implementation/review pipeline. It supersedes earlier planning-only statements such as “does not authorize execution ... now” and “planning review is the current stop point” only for that local Web/Android work. The earlier amendment did not authorize APK/build publication, hosted access/mutation, keys or Git integration. Later user authority now permits project reads and local commits/merges; push, APK builds, hosted mutations and secret exposure remain unauthorized; all existing pre-build, signing and release gates remain binding.

**Current evidence:** At `codex/ministry-production-completion@d0d0e0fbedd4a671f2e09180de94dcac0343ef63` plus the reviewed dirty delta, the pinned Flutter 3.47.7/Dart 3.13.5 full suite is 546 passed/2 failed (360px Team/gallery goldens); analyzer, web build and static web preflight pass. The current manifest and dated local report bind the evidence. An independent Sol 6.1 low visual review approves disposition of the inspected 360px diffs as glyph/icon rendering differences with no visible layout defect; it does not waive the two suite failures and calls out that neither responsive golden loop reaches its larger viewports. Additional local Chrome smoke confirms Flutter startup and the fail-closed bootstrap screen at exact 360/768/1440 CSS viewports, but no backend is configured and no login/persistence acceptance is claimed; the Flutter app smoke suite passed 5/5 on the available Windows SDK. Docker's WSL Virtual Machine Platform is unavailable; Android HAXM is usable and the CPU reports VT-x/SLAT support. API 31 and 34 system images are present, but the clean API 31 no-Vulkan retry and the API 34 attempt both remain ADB `offline`; no Android boot or app run completed. The SDK Manager emulator update also stalled with no package progress and was stopped (exit 1). Enabling Windows Hypervisor Platform and Virtual Machine Platform with administrator access and rebooting remains an unperformed next setup option; DISM returned elevation-required error 740. Historical 528/529 requires root-cause disposition; real T11 and Android application acceptance remain blocked. No approval is transferred to changed bytes. **2026-10-21 update:** the bootable/attached Android prerequisite is now resolved for connectivity only — a physical Xiaomi `2109119DG` (`lisa_eea`, Android 14/API 34, `arm64-v8a`, 1080×2400 at 440 dpi) paired over the user's tailnet, `adb devices -l` reports `device`, and pinned Flutter 3.47.7 lists it as `android-arm64`. No APK was built, installed or launched, so Android app/device/accessibility acceptance and the build/signing gates remain open. Exact endpoint and pairing code are intentionally not tracked.

### Ordered execution within existing units

- [ ] **L0 visual and failure disposition:** inspect the two remaining golden differences against intended 360px behavior; fix an evidenced product defect or obtain reviewed visual baseline disposition. Investigate/dispose the retained 528/529 failure with exact historical/current identity and evidence limits. Preserve all negative/security assertions. Rerun affected checks, then the authoritative pinned full suite/analyzer after source settles; record results against one candidate.
- [ ] **B0/D0 readiness, without an APK:** inspect current Flutter/Android SDK/JDK/Gradle, licenses, `adb devices -l`, available emulator/physical target, browser and callback connectivity, package/version and certificate continuity. Use existing Android configuration and S15/D0 gates; SDK paths alone are not operational proof. Release currently uses debug signing. Prepare a concrete G3 signing/custody/update-policy diff for separate approval; no key generation or signing-policy change follows from this amendment.
- [ ] **B0/T11 local services:** diagnose the observed Windows Docker engine failure before changing configuration. Provision only an explicitly owned disposable loopback Supabase Auth/PostgREST/Storage stack and matching Chromium/ChromeDriver; verify ownership and health through the existing guarded runner. Preserve SQL, concurrency and unified local gate coverage. Missing prerequisites remain BLOCKED; no fake status, fixture substitution or hosted fallback.
- [ ] **T11/L0 Web acceptance:** run the existing exact registration/canonical-edit/enroll/draft/finalize/read-only/progress/cancel/linked-replacement/fresh-session journey, scope-loss denial and FK-ordered cleanup with unrelated sentinel survival. Retain actual browser evidence. Complete L0's 360/768/1440, 200% text, keyboard, reduced-motion and error/empty/loading dispositions, web routing and existing web build/preflight. Bind command/exits/logs and approval to the same candidate. Real Google/OAuth evidence remains O1/G2 and may stay blocked under the hosted boundary below.
- [ ] **D0/D2 Android acceptance, only after predecessor gates and separate build/signing approval:** use the exact candidate and S15 A1–A8/D2 checks: install/update, cold/warm login return, cancellation/denial/back, proper greeting/Team authority, persisted complete academic journey after reopening, revocation/user switch, 200% text/back/resume, Storage/photo and SAF XLSX choose/cancel/write/reopen with accents. Emulator and physical-device observations, certificate/package/version/hash and update continuity remain the existing requirements; widget tests or a launch smoke do not replace them. Do not build an APK until all previously required pre-build gates and approvals have been satisfied. If real provider/backend or target prerequisites are unavailable, record the corresponding acceptance as BLOCKED rather than claim both platforms work.
- [ ] **Independent assembled review:** preserve Luna Medium implementation and Sol 6.1 low stage review. Director reviews the complete candidate, test meaning, exact Web/Android evidence and remaining categories before any integration/publication. Update the existing local report and eventual delivery report independently; the current work is functional acceptance, not completed production activation/delivery.

**Unchanged boundaries and dependencies:** Finalized attendance is immutable for new commands; correction requires acknowledged cancellation and a linked replacement, preserving history and exact receipt replay. Hosted Supabase mutations, migrations, ledger repair, grants, OAuth console changes, recovery/activation, legacy import and deployment remain outside this authorization; obtain separate explicit authorization for a concrete hosted operation. H1/H2/H3 and G1/G2/G3/G4 are neither removed nor satisfied by this amendment. In particular, no claim of intended hosted compatibility, real Google login, release signing or production delivery is possible without their evidence. Later user authority permits local commits/merges and project reads. Push, APK builds, hosted mutations and publication remain gated.

**Machine-plan relationship:** `execution_amendment_2026_10_21` in the JSON mirrors this scope and references existing units; Tasks 1–12 retain IDs/interfaces; consolidated status/continuation and T04-P/006 ownership are now mirrored in JSON. Markdown S15/S16/T04-P and this amendment govern current native dispatch; historical OpenCode metadata is not dispatch authority. The amendment's scope and preserved boundaries were independently **APPROVED — no findings** by Sol 6.1 low against the hashes recorded in the local report. This is plan review only; JSON parse and diff checks are documentary validation, not execution-gate evidence.
