# Codex Cloud Environment Setup Request

Prepare the existing GitHub-connected Discipulado IADP repository for Flutter Android development with hosted Supabase and the user's agent workflow. Inspect the selected repository first. Detect versions and install only what its manifests, lockfiles, scripts, CI, and plans require. Do not change application code or push commits as part of environment setup.

## Candidate tools

- **Flutter SDK**. Use the repository's pinned channel/version when present. Dart is bundled with Flutter; do not install a second Dart SDK unless the repository requires it.
- **Android build tools**: compatible JDK and Android SDK/command-line tools only if the repository or requested tasks build/test Android. Follow Gradle wrapper and Flutter requirements.
- **Node.js 20+** only if needed by repository tooling or for the Supabase CLI via npm.
- **Supabase CLI**. Prefer a repository-pinned CLI if a package manifest supports it; otherwise use an official Linux install method. Hosted Supabase access does not itself require Docker. Install a Docker-compatible runtime only if local Supabase services are required and Cloud supports it.
- **OpenCode CLI**. Use the official Linux installer or npm package (`npm install -g opencode-ai`); verify with `opencode --version`. If supported, use `opencode/deepseek-v4.1-flash-free`. Never copy local OpenCode credentials into the environment.
- **RTK CLI** only if the active two-model pipeline's `scripts/cmd` uses it. Inspect the skill scripts for any additional runtime requirements (such as Python or Node) before installing them.

## Skills and workflow

Check which skills/plugins are already available to Cloud. Make these available if supported; avoid duplicating or copying unrelated personal skills:

- **Superpowers**: brainstorming, writing-plans, subagent-driven-development, executing-plans, test-driven-development, systematic-debugging, receiving-code-review, verification-before-completion, requesting-code-review, using-git-worktrees, and finishing-a-development-branch.
- **Flutter app pipeline** and its **two-model SDD pipeline** dependency, if the repository uses their scripts and workflow.
- **OpenCode CLI delegation**, including the standalone-mode fallback if another OpenCode process occupies the managed port.

The skill files and pipeline scripts are separate from CLI packages. Check account/plugin availability and the selected repository's `AGENTS.md`, `.agents/skills/`, `.codex/skills/`, and `scripts/` before setup. Do not recreate a partial skill bundle. Report any skill or script source that Cloud cannot access.

Preserve the project model workflow when Cloud supports it: GPT-6.1 Sol, low effort, authors/reviews specs and plans and reviews implementation; GPT-6 Luna, medium effort, implements. Do not silently substitute models.

## Secrets and safety

- Never place credentials in this file, source control, setup logs, or prompts.
- Do not copy local `.env` files, local Codex/OpenCode auth, or workstation state.
- Do not run `supabase link`, migrations, database push/pull, or production changes during environment setup.
- If a future task needs hosted access, identify the required secret names and let the user add values through Cloud's secret manager. Use least privilege.

## Setup verification

Install repository dependencies from its lockfiles, then report tool versions and setup results. Run `flutter --version`, `dart --version`, and only the relevant checks among `flutter doctor -v`, `supabase --version` (or the repository-pinned equivalent), `opencode --version`, and project-specific dependency checks. Clearly list anything unavailable in Cloud and why.

## Context

The local checkout used to prepare this request contains project documentation but no Flutter/package manifests or configured Git remote. Treat the GitHub repository selected by the Cloud environment as the source of truth for runtime dependencies and versions.

## Official references

- Codex Cloud environments: https://developers.openai.com/codex/environments/cloud-environments
- Flutter installation: https://docs.flutter.dev/install
- Supabase CLI: https://supabase.com/docs/guides/local-development/cli/getting-started
- OpenCode CLI: https://opencode.ai/docs/cli/

