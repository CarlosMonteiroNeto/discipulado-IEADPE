# Public Web Intake — SDD Controller Handoff

## Current resume instructions — 2026-10-26

The feature is implemented on `feat/public-web-intake` at `C:\Users\Carlos_Neto\.local\share\opencode\worktree\efb495\public-web-intake`. Do not follow the original new-checkout/import/T1-start instructions below when resuming this branch. Read the Spec's Runtime acceptance clarification and the plan's Resume acceptance first section; complete R1–R7 against current progress/evidence. No Docker or local PostgreSQL server is required; missing client tools and missing hosted readiness are different issues. Preserve existing testing authorization boundaries and do not infer publication authorization.

Short resume prompt:

```text
Resume feat/public-web-intake in C:\Users\Carlos_Neto\.local\share\opencode\worktree\efb495\public-web-intake. Read applicable instructions, then the 2026-10-25 public-web-intake Spec, plan and SDD handoff under docs/superpowers/. Follow their 2026-10-26 runtime-acceptance amendment and complete R1–R7. Do not restart completed tasks. Docker/local PostgreSQL server are not prerequisites: use the agreed backup-first hosted verification, with synthetic fixtures, exact cleanup and reconciliation. Investigate actual remaining blockers, continue independent work, and report source-bound results. Do not publish the site.
```

The user approved the Spec on 2026-10-25 and requested that a smaller model implement later via SDD. Do not start from historical closed plans or from the old local `flutter-supabase` checkout.

The user subsequently amended testing: Docker is unavailable. No Docker installation or local Supabase startup is required. Use local unit/widget/processor checks and the existing hosted database for integration tests, following the plan's backup-first reversible-testing protocol and the historical hosted smoke procedure. Fresh backup/integrity verification, synthetic run-owned records/identities, guarded rollback or exact cleanup, and baseline reconciliation are mandatory. Never point the disposable database runner at hosted data, remove its safety guards, reset schemas, overwrite real records or restore a whole dump over legitimate new writes. Use the separate non-destructive hosted runner defined in T1. Native PostgreSQL restore rehearsal is optional if already available; missing Docker is not a blocker.

## Copy-ready controller prompt

Implement the approved public Web intake increment using `superpowers:subagent-driven-development` and these documents:

- `docs/superpowers/specs/2026-10-25-public-web-intake-design.md`
- `docs/superpowers/plans/2026-10-25-public-web-intake-plan.md`

First confirm the human has approved the plan for execution. Then inspect instructions, live origin/main, worktree state, source owners and current evidence. Preserve unrelated work. The planning documents were committed on an older local documentation branch: import only their commits/files into an isolated checkout from the current main; never merge the old branch wholesale. Verify the documents have arrived before dispatching workers. Record any main drift relative to `846a320` and adapt paths only with evidence.

Use the currently selected smaller model for implementation; do not switch to a larger implementer or invent model names. Use available supported model identifiers deliberately. If a stronger independent reviewer is already configured, preserve that separation. Each task gets a fresh implementer context with the approved Spec, plan Global Constraints/Shared Contracts and complete selected task section; this is the task brief. Include completed dependency receipts, current commit and file ownership. Independent reviewers check requirements and implementation before the next dependent task. Investigate failures rather than dismissing baseline failures. Keep evidence concise and never expose credentials/PII.

Execute T1 through T9 in plan order for the simplest low-cost workflow. T5 can follow T2 independently of T3/T4, and T7 can follow T1, but parallelism is optional and must avoid shared migrations/form/router ownership. Do not split tasks into token-sized fragments that cannot be reviewed independently. Ask the human only for genuine product/external blockers. Unresolved hosted network-address trust blocks the limiter/release; it does not block photo work or local review tests.

After T8, perform a whole-increment review, then finish T9's runbook/artifact proposal. Controlled hosted synthetic tests and reviewed additive changes required for them follow the user's explicit testing-method amendment, not the older blanket deferral of hosted verification. Site publication, destructive operations, unrelated production changes and paid services remain outside that authorization. Prepare coordinated SQL/function/UI changes before activation; do not break the live registration path with intermediate changes. No APK/signing/release project. Report PASS/FAIL/BLOCKED with source and command evidence, including backup/cleanup outcomes.

## Compact task dispatch template

Task: [T1–T9 title]. Baseline: [commit/workspace]. Read: approved Spec, plan global/shared sections and this task's full section. Dependencies: [commit + interface/test receipts]. Ownership: [task file list]. Investigate current implementation/history and reproduce narrowly before editing. Deliver only this task; no unrelated refactor or public deployment. Write and confirm meaningful expected RED, implement minimal GREEN, run named checks, commit owned files. Return: files/commit, cause/extension point, exact checks/results, remaining blockers and any contract deviations. Do not message other app threads; report to the controller through the agent tools.

## Progress receipt

Store current progress at `.superpowers/sdd/public-web-intake/progress.md` in the execution workspace. Track task ID, baseline/result commit, implementer review receipt, verification commands/results and blockers. A resumed controller reads that file before dispatching; completed tasks are not restarted. The authoritative briefs remain the plan task sections; no duplicate JSON plan is required.
