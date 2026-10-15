# Codex headless runtime verification

## Scope and model

The product is still the generated Flutter scaffold. No product implementation task has completed. These checks repair and verify the local script-pipeline transport. All reasoning calls use OpenAI Codex with gpt-6.1-sol / low and normal ChatGPT authentication; Anthropic is not involved. The official CLI 0.162.1 is isolated under .pipeline-preflight.

## Investigated causes

1. Codex linked worktrees replace worktree-local hook declarations with the matching primary-checkout .codex layer. Registering the reviewed declaration in the primary checkout fixes discovery; its exact declaration hash is trusted.
2. Live nested Code Mode edits still do not invoke the hook denial. Hooks are not claimed as the active enforcement boundary.
3. CLI config overrides split before/after exec replaced one another. The adapter now validates and consolidates every override before exec.
4. Quoting a simple MCP server ID in a CLI dotted key created a new, invalid transport entry. The adapter uses valid simple keys and rejects unsupported names.

## Active transport

The tracked .codex/codex_adapter.py preserves model/effort, forces native tools to read-only, rejects bypass/profile/permission shortcuts and overrides of enforcement settings, disables unrelated MCP providers and app/plugin tools per invocation, and registers the attempt-bound .codex/scoped_tools.py server. User settings are not globally disabled. The MCP policy is supplied explicitly because its process environment is filtered.

The operator can write/delete only explicitly declared task files or valid attempt-bound grants. Source capture, runtime files, pipeline control files and dependency manifests remain protected. Read capabilities cover project code/documentation and declared context, with secret-shaped files excluded. Reviewer/director advertise only context/read_file and reject writes/checks. Workers have red/test/analyze checks; Script CEO owns formatting. Check subprocesses receive the exact policy attempt identity.

Checks invoke the installed scoped-run and scripts/cmd, preserving full evidence and authoritative pipeline gates. Executed tests are not an OS sandbox against arbitrary authored test code; this documented pipeline limit remains. Root does not implement business tasks or edit the production ledger.

## Verified evidence

- 29 Python regression tests pass. Argument coverage includes omitted, equals, repeated and attached sandbox/profile/approval cases; capability overrides and unrelated provider isolation are checked.
- Actual adapter + exact model: native forbidden write denied; MCP undeclared write denied; declared write and read succeed. The filesystem was checked and the disposable probe removed.
- Actual adapter -> MCP context -> MCP run_check -> installed runner: generated Flutter scaffold smoke test passes (one test, exit 0). This is not product verification.
- Separate synthetic Flutter fixture: RED fails at Expected 1 / Actual 0; structured evidence records task 1 and attempt runtime-modes-verification. After changing only the fixture implementation, the same test passes. Analyzer exits 0.
- Worker formatting is rejected and the unformatted undeclared fixture file remains byte-identical.
- Reviewer/director server fixtures start, advertise exactly context/read_file, read successfully, and reject mutation/check calls.

Evidence is retained in ignored .pipeline-preflight files: runtime-final-regressions.txt, adapter-control-verification.json, adapter-control-probe.events, adapter-check-probe.events, runtime-modes-verification.json and runtime-mode-fixture/workspace/*-protocol.jsonl. Independent runtime reviews and corrections are retained in runtime-review*.events. Final independent review is pending.

## Source preservation

All 101 captured source files were reverified on 2026-10-15: 312,692 bytes, zero missing or changed files. See source-integrity-2026-10-15.md. The capture, specification, plan and Git history do not depend on conversation context. No production database records were exported.
