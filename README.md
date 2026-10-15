> Development workflow: standard Superpowers SDD, activated 2026-10-15 by user instruction. Custom pipeline runtime experiments are suspended and are not required to build or run the app.

# IEADPE Converts — Flutter conversion

Target: Flutter web and Android, pt-BR UI, Supabase Free and Google OAuth. Source capture is immutable under reference/base44. Personal records have not been migrated.

## Current state

Flutter scaffold, dependency lock and executable pipeline plan are prepared. Product implementation is pending; do not mistake the scaffold counter screen for the converted app.

## Execution

Use docs/superpowers/plans/2026-10-14-ieadpe-flutter-supabase-free-plan.json and ieadpe-pipeline-runtime.json through the installed two-model-sdd-pipeline Codex launcher. Every role is pinned to gpt-6.1-sol / low, local publication and one active task. The runbook describes the approved unattended workflow. Full evidence is retained in the ignored pipeline workspace.

## Glossary

- Script CEO: deterministic routing, dispatch, gates and ledger.
- Operator: implementation and RED/GREEN evidence.
- Reviewer: independent semantic and test-quality review.
- Director: same-model corrections and closing assessment.
- Local database profile: real loopback PostgreSQL with synthetic Auth/Storage schema fixtures; it does not certify live Supabase services.

See docs/research/pipeline-runtime.md for the reviewed project hook adapter and local tooling decisions. No production backend, billing, publishing or signing credentials have been configured.

## Migration workspace and pipeline runtime

The immutable Base44 capture is in `reference/base44`; its manifest records 101 file checksums. Migration decisions and the executable 19-task plan are in `docs/superpowers`. This checkout currently contains the Flutter scaffold; product implementation completion is recorded only by the script-owned ledger and final verification report.

The local runtime adapter is `.codex/codex_adapter.py`. It preserves gpt-6.1-sol / low, narrows native tools to read-only, and registers `.codex/scoped_tools.py` with the attempt policy supplied explicitly. The operator receives declared-path writes and closed scoped checks; reviewer and director receive read capabilities. Scoped checks invoke the installed `scoped-run` and `scripts/cmd`. Runtime regression checks: `python -B .codex/tests/test_scoped_tools.py`, invoked through the shared command runner.

Linked Codex worktrees discover project hook declarations in the primary checkout. The reviewed hook is registered there, but live controls show that nested Code Mode edits do not invoke its denial. The native read-only sandbox and task-bound MCP capabilities are the active runtime boundary; hooks are not claimed as complete enforcement. Authoritative scope checks, RED evidence checks, full gates and independent reviews remain mandatory.
