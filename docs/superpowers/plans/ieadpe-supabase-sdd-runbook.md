# IEADPE Supabase Free — Codex SDD Runbook

## Execution contract

Plan: `docs/superpowers/plans/2026-10-14-ieadpe-flutter-supabase-free-sdd.md`.
Spec: `docs/superpowers/specs/2026-10-14-ieadpe-flutter-supabase-free-design.md`.
Source: `reference/base44/manifest.json` and the task-specific captured files.

Use standard `superpowers:subagent-driven-development`. The optional custom `two-model-sdd-pipeline` / `flutter-app-pipeline` workflow has not been selected; do not install or mix it into this run. The user has already selected SDD and the model/effort. Do not ask them to choose native execution or different tiers again.

Every reasoning role uses **`gpt-6.1-sol` with `low` effort**: coordinator, implementer, task reviewer, fixer, research helper if needed, and final reviewer. The current planning session does not change its own active model by writing a document; start the execution session with these settings. Never inherit an unspecified model, increase effort on hard tasks, or escalate on fix rounds. The user's explicit selection overrides skill model-escalation/final-review recommendations. If unavailable, report that fact without substituting a model.

The root configuration example is provided in `ieadpe-sdd-config.toml.example`. It is documentation, not an activated project/global configuration. During execution, merge the listed keys into project settings without replacing unrelated user configuration. Review custom agent definitions: their own model/effort values can override defaults. Any participating custom role must pin the same pair.

When using the current Codex collaboration tools, dispatch explicitly:

```text
spawn_agent(
  task_name = "task_08_implementer",
  model = "gpt-6.1-sol",
  reasoning_effort = "low",
  fork_turns = "none",
  message = "Read the task brief first; implement only its owned files; write the report at its named path. Do not spawn agents."
)
```

This is a dispatch contract, not a shell command. Use the same settings for the independent reviewer and any fixer. A fresh context reads its brief and referenced files; it does not inherit the full conversation. Do not spawn anything during this planning-only delivery.

## State and context budget

1. Resolve the installed SDD skill's plan-owned workspace with its helper. Keep ledger, task briefs, reports and review packages there, not in a shared flat directory. On Windows, use the installed compatible shell; if the helper is unavailable, preserve equivalent plan identity and artifact semantics in a PowerShell implementation before dispatch.
2. Ledger header must contain the exact plan path and source manifest SHA-256. Record task status, base/head commits, model/effort, checks, reviews, fix rounds and coordinator rulings.
3. On resume, inspect Git state plus this ledger. Never redo a completed task or reread all 101 source files. Resume the first incomplete task or its active fix round.
4. Only one implementation/fix writer is active. Finish or interrupt it before handing the same files to another agent. The reviewer does not edit files or spawn helpers. The coordinator owns routing and synthesis, not unreviewed product-code patches.
5. Briefs contain the single task block, Global Constraints, relevant spec excerpts, exact source/owned paths, interfaces from predecessors, test expectations and report path. Target <=1,500 words; justify larger briefs. Do not paste source code or cumulative conversation summaries into every dispatch.
6. Terminal results carry only status, commit IDs, check summary and concerns. Put complete logs and review evidence in files. Target worker terminal reports <=200 words and review summaries <=300 words; findings still need concrete paths/reproductions.

## Per-task protocol

1. Investigate the task's owning source, data flow, contracts and related tests before editing. Confirm checkout/branch and source-manifest integrity. Complete Task 1's repository preflight before Git-dependent SDD helpers.
2. Capture `BASE` before dispatch. Send one fresh implementer its brief and report paths with explicit model/effort. Worker writes meaningful tests for behavior, captures a genuine assertion RED, implements, runs narrow checks, self-reviews and commits.
3. Read the report. Missing checks, skipped assertions, unclassified failures or out-of-scope edits require correction before review. Investigate failures rather than labeling them baseline defects.
4. Build the full review package for `BASE..HEAD`, not merely the last commit. Include tests and the relevant unchanged interfaces, report and constraints. Dispatch one fresh reviewer for spec compliance, correctness, authorization, concurrency and test quality.
5. Important findings return to the implementer. Reuse its task context for rounds 1–3 when supported; use a fresh **same-model, same-effort** fixer for rounds 4–5. Verify covering checks, then perform a scoped re-review of the fix delta and open findings.
6. At five unsuccessful rounds, the coordinator investigates the underlying contract/task split. Resolve a plan ambiguity or decompose the task within scope; record the ruling. Do not silently park a real security/data-integrity defect or raise the model/effort. Report a genuine external blocker if it prevents safe continuation.
7. Mark complete only after meaningful checks pass and important findings are resolved. Record deferred minor findings for the final review. Proceed automatically to the next authorized task; no routine permission checkpoint is needed.

Use the installed skill's brief/review-package helpers where available. Their exact extraction format must be checked against this plan before the first dispatch. An artifact path is not evidence unless its contents match the intended task and commit range.

## Final review and release boundary

Task 19 performs one fresh whole-branch review at `gpt-6.1-sol` / `low`, including deferred findings and all coordinator rulings. Batch any final fixes into one coherent fix wave, then scoped re-review. Do not rerun unchanged broad suites after every reviewer message.

Finish with a local verified branch and English handoff describing implemented behavior, actual checks, deviations and release dependencies. Keep source-manifest hashes intact. Do not delete the user's original checkout or reference folder. Archive only agent-created managed worktrees through the normal worktree workflow after preserving deliverables.

Implementation authorization covers local work and disposable emulator fixtures. It does not activate billing, publish a production app, grant live users access, import private Base44 records, or install signing credentials. Prepare concrete release artifacts before asking for any release-only information/action.

## Copyable execution prompt

```text
Execute docs/superpowers/plans/2026-10-14-ieadpe-flutter-supabase-free-sdd.md using standard Codex Subagent-Driven Development. Read its Supabase Free spec and ieadpe-supabase-sdd-runbook.md first. Stay within Supabase Free with Google OAuth, PostgreSQL RLS/transactional RPCs and private photo Storage. Do not add paid services, mandatory Edge Functions or a Firebase backend. Prepare a separately hosted static Flutter web build. Use gpt-6.1-sol with low reasoning effort for every agent, including coordinator, implementers, fixers, task reviewers and final reviewer; explicitly pin both settings, use fresh task contexts, and do not escalate models or effort. All communication, code comments and artifacts must be English; app UI remains pt-BR. Investigate before editing, preserve reference/base44, use synthetic local Supabase data, and maintain a plan-owned progress ledger. Implement tasks sequentially with independent review and meaningful checks, proving SQL/RLS enforce atomic transitions before building dependent UI. Continue through all authorized local tasks without repeated approval questions. Prepare web/Android builds and an honest verification report. Do not deploy, enable billing, migrate private records or grant production access as part of this local implementation.
```

## Configuration reference

[Official Codex subagent configuration](https://learn.chatgpt.com/docs/agent-configuration/subagents) documents global defaults, explicit spawn settings and custom-role precedence. The model/effort pair here is the user's instruction, not a recommendation to choose a different model for reviews.
