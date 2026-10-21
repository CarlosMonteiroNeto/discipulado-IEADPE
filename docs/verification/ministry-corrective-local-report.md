# Ministry corrective release — local acceptance and evidence index

**Date:** 2026-10-21
**Disposition:** PARTIAL / BLOCKED — not a local-release, branch, hosted, or delivery approval.
**Evidence unit:** L0-E; pending independent Sol review.

## Source identity and candidate boundary

At the pre-report evidence snapshot the branch was `codex/ministry-production-completion`, HEAD `f2fffca489fd36f55957bba49736cb35dd31d5a6`, with 135 modified/untracked file entries. The current dirty-file hashes are recorded in `build/verification/corrective-release/L0-evidence/current-candidate-hashes.json` and `.sha256`; the current hash list digest is recorded in the L0-E coder report. The dirty-file manifest SHA-256 is `2fa2e05e0148eb93c5ea24a522c1e608eaebdd6d13f958ddd0c64f5d4ee787db`. This full dirty candidate is not the historical 96-file checkpoint candidate.

Comparison with `CHECKPOINT-T04-T07/candidate-hashes.json` found 89 matching paths, 7 paths with changed hashes, no checkpoint paths missing/clean, and 39 additional current dirty files. The 7 changed paths are `docs/integration/ministry-completion-contracts.md`, the corrective plan, corrective design spec, `lib/app.dart`, `lib/features/ministry/ui/attendance_page.dart`, `test/features/ministry/ui/attendance_history_test.dart`, and `test/workflows_test.dart`. Hashes are in the comparison manifest. The current L0 report/evidence outputs are excluded from that source snapshot; the snapshot is not represented as the final review candidate. Historical approvals are scoped to their recorded candidates and are not silently carried to this assembled dirty candidate.

## Approval and task artifact index

The source for requirement definitions is the current plan completion map (`docs/superpowers/plans/2026-10-20-ministry-corrective-release-plan.md`, “Task-by-task completion assessment”, “Addendum L0”, and R01–R11 crosswalk) plus design S11/S15/S16. `build/verification/corrective-release/L0-evidence/approval-index.json` links each B/T unit's coder report, recorded review/approval source, candidate/hash artifacts, exact recorded test commands/exits/evidence paths, and limits.

- **B1–B3:** durable Sol review files say APPROVED for scoped local work: `B1/review.md`, `B2/review.md`, `B3/review.md`, with review/candidate hash files. Full current local closing gates remain separate.
- **T01–T02:** durable scoped Sol records: `T01/review.md` and `T02/review.md`/`review.json`, with candidate/review hashes. Their local task approvals do not prove current hosted RPC behavior or final assembled branch acceptance.
- **T03–T10 and T12:** the plan completion map records director-supplied Sol scoped approvals. Individual worker reports remain historical records, and several still carry pending wording; those worker fields are not treated as new denials or new approval records. Where no durable independent final review file exists, that remains a documentation/attachment gap. T12 is local preparation only.
- **T11:** worker evidence reports `blocked` / `partial_unverified`; local integration source is not a live browser result. Sol identified a second-replacement preview assertion gap, which was corrected in the current source candidate. Re-review is pending; no approval is claimed.
- **T04-P / S16:** the T04-P handoff and SQL blocker evidence are in `T04-first-save/`. Latest Sol review message confirms the prior two SQL fixture/set_config P1s are fixed and finds no new static defect, but acceptance approval remains blocked: retained RED is a post-implementation mutation check, SQL remains `BLOCKED_NOT_RUN`, and this is not approval of T04-P or T11. No durable final review artifact was found in that directory. Migration `202610200006` is still not proven by SQL execution.

The task reports and their local raw logs are not repeated here; the JSON artifact index gives exact paths and recorded commands/exits. A read-only pass checked 173 referenced executed-evidence paths and found none missing. A reviewer can verify each referenced artifact hash in `approval-index.json` and the source snapshot manifests. The T04-P 30-entry and T11 33-entry local manifests were each checked with `sha256sum -c` (exit 0); these checks only validate their recorded hashes. The older T12 eight-file candidate comparison has six current hash mismatches, so its local approval is not silently transferred.

## Local requirement matrix

| Requirement | Owned tasks | Last proven local evidence and current disposition | Next dependency |
|---|---|---|---|
| R01 — import compatibility, replay, duplicates/tombstones/counters | B1, T12, H3 | B1 scoped local approval and SQL/replay/concurrency evidence; T12 rehearsal is synthetic/local. **Approved scoped; current candidate changed.** No supported legacy-source reconciliation. | Rebind current source hashes; inspect/verify original source or owner-attested absence; authorized import package. |
| R02 — canonical operational identity and unchanged history | T01, T11 | T01 scoped SQL/Dart evidence approved; T11 has RPC-bound source assertions only. **Approved scoped / current candidate changed; production journey unverified.** | T11 real loopback journey; hosted RPC parity remains separate. |
| R03 — immutable finalization, cancellation, linked replacement | T02, T04, T04-P, T11 | T02 local scope approved; T04 UI tests pass; T04-P preview SQL is not run; T11 browser journey blocked. **Scoped parts approved; first-save SQL/live acceptance blocked.** | Disposable local PostgreSQL T04-P gates, then T11 stack/browser. |
| R04 — exact ambiguous retry and protected context | T03, T04, T11 | T03 scoped controller approval recorded, but the assembled 528/529 full checkpoint fails the old-target lock test; earlier isolated T03 pass is not hash-bound to that checkpoint. **Branch gate FAIL/unresolved.** | Deterministic current-candidate investigation and, if warranted, Sol-authored corrective brief. |
| R05 — persisted history and progress | T05, T06, T11 | T05/T06 scoped local SQL/UI approvals recorded; T11 fresh-read/progress assertions are source-only. **Approved scoped; current candidate changed, browser persistence blocked.** | Real local journey and fresh-session persisted reads. |
| R06 — authority and compatibility | T07, T12, H1/H2 | T07/T12 local scoped work approved by director record; hosted exact-state/real-role parity not demonstrated. **Local scoped pass; hosted compatibility blocked.** | Authorized current schema/ledger fingerprint, restore and reviewed activation package. |
| R07 — safe greeting and Team access presentation | T08, H2, D1 | T08 scoped UI approval recorded; no real Google session or live scope/revocation evidence. **Approved scoped; real-session acceptance blocked.** | Correct hosted authority and authorized real-account/device checks. |
| R08 — verification quality and fail-closed gates | B0–B3, T09–T11, L0 | B1–B3 scoped approvals, B0 partial prerequisites, T09/T10 scoped approvals, and L0 credential-free contract tests. Current assembled full suite is **FAIL 528/529**; analyzer passes; browser stack blocked. | Investigate retained race; complete T04-P SQL and T11 actual loopback/browser; rerun required final gates on one stable candidate. |
| R09 — recovery and exact activation preparation | T12, H1/H2 | T12 synthetic local rehearsal approved as preparation; no encrypted backup/isolated restore/current hosted parity proof. **Preparation approved; activation BLOCKED.** | Authorized protected backup + isolated restore, refreshed target inventory, exact reviewed migration package and explicit G1/G2 approval. |
| R10 — legacy source reconciliation | H3 | Plan records H3 **BLOCKED**; no Firebase export or independently verified source absence. | Obtain authorized export or documented/verified source absence; stable-ID reconciliation and repeat-import rehearsal. |
| R11 — exact signed deliverable and installed journey | D0–D2 | Plan records D1 **BLOCKED**; no release certificate decision, attached target, candidate APK, installed journey, or verified download. | G3 signing/custody approval, Android targets, approved build, actual install/update and matching download-byte proof after all prior gates. |
| T04-P / S16 first-save preview | T04-P, T11 dependency | Widget evidence passes, SQL test authored but not run; Sol review says SQL acceptance remains blocked. T11 now expects preview in both replacement paths, source-only. **BLOCKED_NOT_RUN for SQL; T11 partial.** | Owned disposable PostgreSQL for migration 006 SQL/no-DML/real first-save/reopen/finalize tests; then T11 complete owned loopback stack. |

## Retained checkpoint

The exact assembled local checkpoint is preserved as FAIL: `flutter test --no-pub --concurrency=1` exit 1, 528 passed and 1 failed; analyzer exit 0/no issues. The failed assertion is a 15-second synchronization assertion in the old-target access-lock concurrency scenario, not a captured SQLSTATE. An earlier isolated task_3 pass exists but belongs to an earlier T03 candidate without a hash binding to the later 96-file checkpoint. A separate diagnostic snapshot supports a wait-graph observation but does not establish product or infrastructure root cause. See `build/verification/corrective-release/L0-evidence/failure-analysis.md` for paths, digests, supported hypotheses and evidence limits.

## Credential-free evidence executed for L0-E

| Command | Exit/result | Raw evidence |
|---|---:|---|
| `python3 -m unittest discover -s scripts -p 'test_verification_cases.py'` in an empty inherited environment with only PATH | 0; 8 tests passed | `build/verification/corrective-release/L0-evidence/test_verification_cases.log` / `.exit` |
| `python3 -m unittest discover -s scripts -p 'test_unified_gate.py'` in an empty inherited environment with only PATH | 0; 15 tests run, 1 skipped | `build/verification/corrective-release/L0-evidence/test_unified_gate.log` / `.exit` |

The source inspection shows these suites use temporary fixtures/stub executables and do not call a real Supabase/PostgreSQL service. They validate runner/manifest contracts only; they are not evidence of migration correctness, full platform gates, browser acceptance or hosted access. No database command, runner, full suite, hosted access, browser service, Docker operation, build/APK or commit was performed for L0-E.

## Remaining blockers and disposition

- Current full-suite checkpoint remains FAIL 528/529; do not use the isolated historical pass to waive it.
- T04-P SQL preview/no-DML/actual first-save remains BLOCKED_NOT_RUN. `psql` is unavailable and the only observed listener (`127.0.0.1:54329`) was not identified as task-owned; it was not contacted.
- T11 full journey requires the actual owned loopback Supabase Auth/PostgREST/Storage stack and Chromium/ChromeDriver. Prior evidence says Docker VFS exhaustion prevented image extraction; this task did not start a stack.
- The current full suite, final analyzer, local browser journey, FK cleanup/sentinel checks, actual hosted restore/upgrade/role checks, legacy-source resolution, signing/device/install and download gates remain separate and open as mapped above.
- T04-P and current T11 independent review status do not confer L0 or release approval. H1/H2/H3/D1 remain separate gates.

This index is a partial local evidence reconciliation only. It does not close L0, approve the dirty branch, authorize hosted mutation, or claim completed release/delivery.

## 2026-10-21 approval-attachment reconciliation

The plan's 2026-10-20 completion map records director-attributed scoped Sol approvals for T03–T10 and T12. No durable individual final Sol review artifact for T03–T10 was located in the task directories. The worker reports remain historical and preserve their own approval wording; several reviewed file sets no longer match the current candidate, and T05 has no report-bound file hashes. These records are therefore indexed as `director-recorded scoped approval; final artifact not attached`, with per-task candidate identity limits in [the reconciliation index](../../build/verification/corrective-release/L0/approval-reconciliation/approval-index.json). The plan's original attachment checkbox remains open.

Two later scoped approvals are durable: T04-P is `APPROVED_LOCAL` in `T04-first-save/sol-final-review.md`, including the actual migration-006 SQL fixture PASS (exit 0); T12-006 is `APPROVED_LOCAL` in `T12/continuation-006/sol-final-review.md`, covering the exact 16-migration chain and 17 actual local checkpoints. These do not substitute for missing T03–T10 records or close L0. The T04-P legacy 30-file candidate manifest has one stale hash; the final Sol review lists and matches the final seven authorized file hashes. T12 correction-6 remains historical; the approved local result is the 006 continuation. T03's lock investigation is separately `ACCEPTED_BLOCKED`; the assembled checkpoint remains FAIL 528/529. T11's live browser journey, owned-stack cleanup and sentinel proof remain blocked/unverified.

The credential-free `test_verification_cases.py` check passed 8/8 (exit 0; raw log and exit are indexed). That validates the local manifest/fixture contract only and does not satisfy the missing final approval attachments. L0, full stable-candidate gates, hosted/recovery, legacy, device and APK gates remain open. This dated reconciliation supersedes stale approval-status descriptions above only where the durable review and exact evidence are cited; earlier snapshots are retained as history.
