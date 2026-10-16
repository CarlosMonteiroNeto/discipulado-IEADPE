# IEADPE Flutter + Supabase Free — Final Verification Report

Branch `implementation/supabase-free`, Task 19 completion. Plan: `docs/superpowers/plans/2026-10-14-ieadpe-flutter-supabase-free-sdd.md`. Spec: `docs/superpowers/specs/2026-10-14-ieadpe-flutter-supabase-free-design.md`. Source manifest: `reference/base44/manifest.json` (**101/101 SHA-256 unchanged**).

## Implemented behavior

Flutter Material 3 app (web + Android, pt-BR UI) backed by Supabase Free with Google OAuth (PKCE), PostgreSQL RLS plus authorized transactional RPCs (`(operation_id uuid, payload jsonb) -> jsonb` with receipts, sorted UID locks, week guards), and a private photo draft/upload/attach protocol. Covered journeys: registration/editing with photos, scoped lists with lifecycle actions (visit, discipleship start/stop/complete, deviation), Home dashboard, weekly reports with zero-confirmation, congregation/access management (five Admin tabs), event and conversion reports with guarded XLSX export, versioned backup codec with resumable import, feedback submission/management, and free-tier operations tooling. Task 19 connected every feature to the production gateway/auth/routes through `ProtectedApplication` + `SessionRouter` (explicit invalidating `refresh()` vs owner-preserving `revalidate()`), removed placeholder bootstrap behavior, applied IEADPE branding (web `lang="pt-BR"`, SVG church mark, Android label/icon), and closed all parked review minors with regressions (asterisk literal search, strict OOXML namespaces, import row diagnostics, EXIF/transparency, selected navigation semantics, photo-null reset, chooser-time scope validation, feedback pending default).

## Actual checks and results

- `flutter test` (full): **240 passed, 0 failed** — widget/unit suites plus synthetic loopback journeys (`test/workflows_test.dart`: root mount, picker/resume ownership, identity switch, resume failure/scope change, Admin tabs/feedback owners) and branding.
- Native PostgreSQL 17.11 loopback (authoritative local profile; disposable server on `127.0.0.1:54329`, synthetic data only): all 13 database scenarios pass, including independent-session races in both commit orders — create/zero-confirm, lifecycle terminals/revocation, import/zero, access, and archive-vs-create/grant (`PASS: archive/create and archive/grant wait and revalidate in both commit orders`). One genuine harness defect was found and fixed during verification (grant payload used `email` instead of `user_email`, so the race never blocked; product locking was proven correct by manual two-session reproduction).
- `flutter analyze`: **No issues found!**
- `flutter build web`: **Built build\web** (42 files, 42.22 MB); `scripts/web_preflight.py build/web` **passed**; `build/web/_redirects` carries the six exact route proxies.
- `flutter build apk --debug`: **Built app-debug.apk** (debug-signed, packaging evidence only). The earlier uncached-AGP configuration failure did not recur under online resolution.
- `test/operations/configuration_test.dart`: passes (release-artifact checks, photo-cleanup contracts, missing-config wrapper guard; `pwsh` resolved with Windows PowerShell 5.1 fallback on this host).
- `git diff --check`: clean. No production contact, billing, deployment, grants, migration of private records, or signing credentials at any point.

## Deviations and review rulings carried

- `integration_test/` on-device coverage was replaced by synthetic widget journeys: no AVD/device exists on this host, so no runtime installation, OS picker, or live OAuth/Storage behavior is claimed. Emulator images are present but no AVD was configured and no driver changes were made.
- `supabase test db` (CLI/Docker) is environmentally blocked; SQL/RLS/concurrency evidence comes from the native-PG harness running the exact migration files.
- Web manifest is SVG-icon-only; superseded PNGs remain on disk unreferenced (cosmetic).
- Prior rulings preserved: Storage HTTP verification mandatory before release (never inferred from SQL/SDK fixtures); ordinary resume preserves owners while explicit/failed/changed validation destroys them; Task 14 shared workbook writer reused by Task 15; Task 13 archive semantics unchanged.

## Release dependencies (operator actions)

Supabase Free project + publishable URL/key, apply all 10 migrations, private `convert-photos` bucket, Google provider with exact local/production/Android redirect URLs (PKCE, `openid/email/profile` only), out-of-band admin-allowlist bootstrap, Google Cloud console consent setup, static web hosting upload of `build/web` with hosted refresh/callback QA, release keystore + signed AAB/APK with `apksigner` certificate comparison, device QA (login/cancel/logout, revocation, pickers, 200% text/reduced motion), weekly usage monitoring, manual DB+Storage backups with restore rehearsal (application XLSX is not a backend backup), and screenshot/evidence capture. Full detail: `docs/operations/supabase-free.md`, `google-oauth.md`, `release.md`.
