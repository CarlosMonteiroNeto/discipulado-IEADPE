# IEADPE Converts

Flutter Web and Android application with pt-BR UI, Supabase Free and Google OAuth integration. The immutable source capture is under `reference/base44`. Hosted compatibility, private-record reconciliation and release acceptance require their separately recorded evidence.

## Authoritative delivery documents

Continue on `codex/ministry-production-completion` in the attached worktree. The [current spec](docs/superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](docs/superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and its [JSON mirror](docs/superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern requirements, current status, work order and gates. The [document index](docs/superpowers/README.md) and [skill routing](docs/superpowers/skills-routing.md) explain their supporting references. Earlier specs/plans/handoffs are historical sources; dated reports retain candidate-specific observations. Technical contracts and runbooks are subordinate references, not independent execution queues or operational authorization.

## Bootstrap status

The app starts in Brazilian Portuguese. Missing or invalid build configuration displays a recoverable unavailable screen. Authentication, routing and the Ministry journey have implemented source; their current local, hosted and device acceptance states are in the canonical plan. A no-config bootstrap smoke is not evidence of successful login or persistence. Bootstrap never contacts a fallback backend.

## Local development

First complete the current plan's B0 toolchain/ownership checks and inherited pinned SDK environment. Use the committed dependency lock. The following Web development command illustrates public client configuration for an owned local stack; execute it only within the corresponding current task and logged command convention:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_LOCAL_PUBLIC_KEY
```

`Configuration.fromEnvironment()` reads only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Use an HTTPS backend URL or HTTP on loopback (`localhost`, `127.0.0.1`, `::1`); Android emulator access to the host uses `10.0.2.2`. Use the public publishable key (`sb_publishable_…`), never secret/service-role credentials. Public build values are visible to app users. Correct missing configuration and restart/rebuild the app; retry rechecks the current build configuration.

The checked-in `supabase/config.toml` describes local CLI ports and disables email/SMS signup. The full local stack requires operational Supabase CLI/Docker and verified run ownership; recheck actual readiness through B0/T11 rather than relying on historical installation observations. Google provider configuration and real Auth/Storage verification remain separately gated; hosted services are not a fallback for local tests. Native PostgreSQL checks prove SQL contracts only and do not replace the real T11 service/browser journey.

## Checks

```powershell
./scripts/check.ps1
```

This runs `flutter analyze` and `flutter test`, stopping on failure. Resolve the pinned SDK for the process and all children first; this helper alone does not close every current L0 gate. Widget checks cover pt-BR locale, recovery keyboard interaction, narrow layouts, large text and reduced motion. They do not certify live Supabase, Google OAuth, Storage HTTP or real Android device behavior.

## Workflow

Use the current plan's native Luna Medium implementer and independent Sol 6.1 Low reviewer, investigation before changes, meaningful regression tests for behavioral fixes and source-bound evidence. The inherited 19-task implementation and earlier L1 plans are historical baselines, not fresh queues. Production deployment, hosted mutations, private-record migration, signing/build and publication retain the canonical gates and required authorization.

## Current ministry delivery work

Read the canonical plan's consolidated state and ordered continuation first. The latest recorded pinned full suite is 546/548; two goldens, historical 528/529 disposition, a Bash timeout, real T11 and Android acceptance remain open. Windows Web/Android is the selected scope; Linux acceptance is deferred. The [L1 handoff](docs/verification/l1-cross-device-handoff.md) and [portable handoff](docs/verification/2026-10-21-portable-branch-handoff.md) preserve their dated evidence without overriding the current plan. Finalized attendance corrections require cancellation and a linked replacement.
