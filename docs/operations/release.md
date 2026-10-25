# Free release preparation

<!-- canonical-document-authority -->
> **Supporting technical reference.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. Reuse procedures/contracts only through the corresponding current task and its reviewed interface, prerequisites and authorization. Counts, completed operations and old environment statements retain their original observation date.

This prepares local artifacts only. Production provisioning, deployment, grants, private migration, Google console changes and signing keys are separate operator actions. Task 19 still owns application composition and real platform checks. No billing or paid add-on is authorized.

## Static web artifact

Supabase does not host the Flutter website. Proposed host: Cloudflare Pages Free static hosting only, without Workers, Functions or R2. Official [Pages limits](https://developers.cloudflare.com/pages/platform/limits/) checked **2026-10-16**: 25 MiB per file, 20,000 files/site, 500 builds/month, one concurrent build and 20-minute build timeout. Recheck at release.

After Task 19 root wiring, build with **public** values from a private local build-settings file outside the repository:

```powershell
flutter build web --release --dart-define-from-file=<private-public-settings.json>
python scripts/web_preflight.py build/web
```

The file contains only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Flutter embeds these values publicly; never include service-role credentials, DB passwords, Google secrets or signing passwords. Missing app configuration has no backend fallback. Check actual built artifacts, not source estimates. The preflight reads every file's actual byte size and file count, rejects missing entry/rewrite and symlinks, reports oversized relative paths and exits nonzero. If a renderer/WASM or asset exceeds 26,214,400 bytes, remove unused assets or select a smaller supported Flutter build/renderer configuration and rebuild/recheck. If that cannot fit Free static limits, stop release and evaluate another Free static host with explicit comparable limits; do not silently introduce R2 or billing.

`web/_redirects` must be copied into `build/web/_redirects` by the Flutter build. It contains exact application-route proxies to `/index.html` with status 200 for the session router paths (`/login`, `/register`, `/home`, `/converts`, `/admin`, `/auth/callback`, `/ministry`, `/ministry/team`, `/ministry/students`, `/ministry/students/register`, `/ministry/classes`, `/ministry/attendance`, `/ministry/handoff`). `/` uses the normal static index. Keep this list aligned with `lib/routing/router.dart`. The [Pages redirect documentation, Per file and Proxying](https://developers.cloudflare.com/pages/configuration/redirects/) checked **2026-10-16** states that matching rules apply even when an asset exists. Therefore never use `/* /index.html 200`: that broad proxy also replaces Flutter JavaScript/WASM/images with HTML. The preflight requires the exact route list and rejects broader or unexpected proxies. Existing static assets must return their own bytes/MIME. The local fixture applies the first matching rule before file lookup, requests every application route plus a callback query, and verifies actual JavaScript/WASM bytes and MIME over loopback. It is **simulated Pages routing**, not an actual deployed Pages refresh or working OAuth callback.

Before an authorized upload, inspect `build/web` for secrets, dumps and private fixtures and record hashes/preflight output. On the operator-approved host, upload only that directory, keep HTTPS and configure the exact trusted callback origin in [Google OAuth](google-oauth.md). Verify cold direct navigation and reload for each guarded route, callback query handling, JS/WASM MIME/loading and no stale protected data after logout/scope loss. Capture actual hosted URL/browser evidence; hosted QA is unrun here.

## Android signing and installation

Current `android/app/build.gradle.kts` release configuration uses the **debug signing key**. It is not distribution-ready. Task 19 must first resolve the known uncached `app_links 7.2.2` dependency on AGP `9.2.1` and complete real APK resolution/build. A narrow Kotlin/source compile does not establish a successful APK build.

An authorized operator must decide package ownership for `br.org.ieadpe.ieadpe_converts`, generate/hold a release upload keystore in a secure location outside the repository, back it up securely, and configure Gradle release signing via private environment/properties. Do not commit `key.properties`, keystores, passwords or certificate private keys. Follow [Flutter Android signing](https://docs.flutter.dev/deployment/android#sign-the-app); no key was generated and no signing configuration was changed here. Replace the debug signing selection before distribution, build the signed APK/AAB using the same public build defines, then inspect its certificate with Android SDK `apksigner verify --print-certs <apk>` and compare with the independently held release certificate. Keep install/update certificate continuity and version-code increments. A debug-signed release must fail operator release review.

Install on actual supported Android devices and test cold/warm `ieadpe://login/auth/callback`, first login/cancel/logout, grant revocation and keyboard/200% text/reduced-motion behavior. Real-device checks are unrun. Check web counterparts on approved browsers and screen widths. UI remains pt-BR.

## File export and backup release evidence

The real web exporter requires secure-context Chromium `showSaveFilePicker`; unsupported browsers (including Firefox/Safari without that API) fail visibly. Android uses SAF choose then guarded write/flush/close. Test actual chooser permissions, cancellation, provider errors, retrieve/open an accented XLSX and exercise logout/account switching during selection/write. Progress persistence is identifiers only; actual browser reload/reselection and Android SharedPreferences persistence need device checks. Protocol/JS fixtures do not prove OS saves or persistence. See [gateway handoffs](data-gateway.md) and [full DB plus Storage backup](supabase-free.md); application XLSX alone cannot recover the backend.

Release evidence must separately record full local tests/analyzer, web artifact preflight, actual hosted refresh, live Google/Auth/Storage enforcement, signed APK build/install and real export/persistence checks. Unrun categories remain explicit release blockers.
