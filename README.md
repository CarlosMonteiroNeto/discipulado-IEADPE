# IEADPE Converts

Flutter web and Android application with pt-BR UI, Supabase Free and Google OAuth. The immutable source capture is under `reference/base44`; personal records have not been migrated.

## Bootstrap status

The app starts in Brazilian Portuguese. Missing or invalid build configuration displays a recoverable unavailable screen. Valid public configuration displays an honest preparation state until authentication and routing are implemented in subsequent tasks. Bootstrap does not initialize a network client or contact a fallback backend.

## Local development

Use the committed dependency lock with `flutter pub get`. Configure a local backend through build-time Dart defines:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_LOCAL_PUBLIC_KEY
```

`Configuration.fromEnvironment()` reads only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Use an HTTPS backend URL or HTTP on loopback (`localhost`, `127.0.0.1`, `::1`); Android emulator access to the host uses `10.0.2.2`. Use the public publishable key (`sb_publishable_…`), never secret/service-role credentials. Public build values are visible to app users. Correct missing configuration and restart/rebuild the app; retry rechecks the current build configuration.

The checked-in `supabase/config.toml` describes local CLI ports and disables email/SMS signup. Starting the full local stack requires Supabase CLI and Docker (`supabase start`). Neither is installed on the current host. Google provider configuration and real Auth/Storage verification remain separate integration work; no production credentials or services are used as a fallback. The native PostgreSQL verification profile is described in `docs/superpowers/specs/2026-10-14-ieadpe-flutter-supabase-free-design.md` and verifies SQL contracts only.

## Checks

```powershell
./scripts/check.ps1
```

This runs `flutter analyze` and `flutter test`, stopping on failure. Widget checks cover pt-BR locale, recovery keyboard interaction, narrow layouts, large text and reduced motion. They do not certify live Supabase, Google OAuth, Storage HTTP or real Android device behavior.

## Workflow

Use standard Superpowers SDD with direct project tools, TDD and independent task review. The 19-task plan and accepted design are under `docs/superpowers`. Custom pipeline runtime experiments are suspended. Production deployment, live access grants and private-record migration require separate release actions. No billing, publishing or signing credentials are configured.

## Current ministry delivery work

The active branch `codex/ministry-production-completion` carries the approved L1 class-session management plan. Tasks 1–4 are reviewed; Task 5 implementation and its scoped review are complete, while broad verification and final L1 review remain open. See the [cross-device handoff](docs/verification/l1-cross-device-handoff.md), [L1 plan](docs/superpowers/plans/2026-10-19-ministry-l1-session-management-plan.md), and [L1 design](docs/superpowers/specs/2026-10-19-ministry-l1-session-management-design.md) before continuing. The handoff records remaining failures and required model roles; it does not mark the work release-ready.
