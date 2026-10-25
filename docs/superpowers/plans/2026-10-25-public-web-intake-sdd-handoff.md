# Public Web Intake — SDD Controller Handoff

The user approved the Spec on 2026-10-25 and requested that a smaller model implement later via SDD. Do not start from historical closed plans or from the old local `flutter-supabase` checkout.

## Copy-ready controller prompt

Implement the approved public Web intake increment using `superpowers:subagent-driven-development` and these documents:

- `docs/superpowers/specs/2026-10-25-public-web-intake-design.md`
- `docs/superpowers/plans/2026-10-25-public-web-intake-plan.md`

First confirm the human has approved the plan for execution. Then inspect instructions, live origin/main, worktree state, source owners and current evidence. Preserve unrelated work. The planning documents were committed on an older local documentation branch: import only their commits/files into an isolated checkout from the current main; never merge the old branch wholesale. Verify the documents have arrived before dispatching workers. Record any main drift relative to `846a320` and adapt paths only with evidence.

Use the currently selected smaller model for implementation; do not switch to a larger implementer or invent model names. Use available supported model identifiers deliberately. If a stronger independent reviewer is already configured, preserve that separation. Each task gets a fresh implementer context with the approved Spec, plan Global Constraints/Shared Contracts and complete selected task section; this is the task brief. Include completed dependency receipts, current commit and file ownership. Independent reviewers check requirements and implementation before the next dependent task. Investigate failures rather than dismissing baseline failures. Keep evidence concise and never expose credentials/PII.

Execute T1 through T9 in plan order for the simplest low-cost workflow. T5 can follow T2 independently of T3/T4, and T7 can follow T1, but parallelism is optional and must avoid shared migrations/form/router ownership. Do not split tasks into token-sized fragments that cannot be reviewed independently. Ask the human only for genuine product/external blockers. Unresolved hosted network-address trust blocks the limiter/release; it does not block photo work or local review tests.

After T8, perform a whole-increment review, then finish T9's local runbook/artifact proposal. Publication, live SQL changes, credentials/account setup and hosted synthetic mutations require their separate authorization. Prepare the concrete candidate first; never infer publication authorization from Spec approval. No APK/signing/release or paid services. Report PASS/FAIL/BLOCKED with source and command evidence.

## Compact task dispatch template

Task: [T1–T9 title]. Baseline: [commit/workspace]. Read: approved Spec, plan global/shared sections and this task's full section. Dependencies: [commit + interface/test receipts]. Ownership: [task file list]. Investigate current implementation/history and reproduce narrowly before editing. Deliver only this task; no unrelated refactor or public deployment. Write and confirm meaningful expected RED, implement minimal GREEN, run named checks, commit owned files. Return: files/commit, cause/extension point, exact checks/results, remaining blockers and any contract deviations. Do not message other app threads; report to the controller through the agent tools.

## Progress receipt

Store current progress at `.superpowers/sdd/public-web-intake/progress.md` in the execution workspace. Track task ID, baseline/result commit, implementer review receipt, verification commands/results and blockers. A resumed controller reads that file before dispatching; completed tasks are not restarted. The authoritative briefs remain the plan task sections; no duplicate JSON plan is required.
