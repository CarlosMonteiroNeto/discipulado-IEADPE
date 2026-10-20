---
name: opencode-cli-delegation
description: Use when the user explicitly asks Codex to use OpenCode to implement, change, or code in a project, or to hand coding work to OpenCode.
---

# OpenCode CLI Delegation

When the user asks to use OpenCode for coding, delegate through the locally installed OpenCode CLI. The user's confirmed coding model is the OpenCode provider's `deepseek-v4.1-flash-free`, selected as `opencode/deepseek-v4.1-flash-free`. Do not use the Windows GUI or call a model/provider API directly from Codex; the CLI uses the user's existing OpenCode login and provider configuration.

## Workflow

1. Treat explicit requests such as “use OpenCode”, “pass the coding to OpenCode”, or “have OpenCode implement this” as authorization to run the CLI. A question about OpenCode, a mention of it, or a vague “have a look” is not automatically authorization to edit; clarify whether the user wants coding or read-only review.
2. Resolve the active project/worktree root before invoking the CLI. Check Git status first and note existing changes so they are not attributed to OpenCode or overwritten. Run OpenCode from that project root.
3. Give OpenCode a concise, scoped task with the relevant requirements and constraints. Invoke the CLI with the explicit model, for example:

   ```sh
   opencode run --model opencode/deepseek-v4.1-flash-free "Implement the requested change in this repository. Follow its project instructions. Keep the changes scoped to the request."
   ```

   Use an argument-safe process invocation or correctly quote the prompt for the active shell. Never put credentials in the prompt or command. Do not inspect or copy OpenCode credentials.
4. Wait for the CLI process to finish and check its exit status and response. If the CLI reports an authentication, model, or provider error, stop and report it. Do not silently switch to a different model, direct API, GUI, or Codex implementation.
   If the CLI cannot connect because its managed service port is already occupied by another OpenCode process, retry the same command and model with `--standalone`.
5. After a successful run, inspect `git status` and the diff, separating pre-existing changes from OpenCode's changes. Review the actual code against the request; the model's completion message is not evidence that the work is correct. Report the files changed, review findings, and any requested verification results.
6. Do not commit, push, deploy, or make other external changes unless the user separately asks. Run tests or other checks when the user explicitly asks whether the change works, is sound, or should be verified; otherwise follow their instructions and do not add or run tests without a request to test or verify.

For Codex-side planning and review, honor the user's preference for GPT-6.1 Sol with Low effort when that model and setting are available in the active Codex session. Do not claim to have changed or used that setting unless the session confirms it.
