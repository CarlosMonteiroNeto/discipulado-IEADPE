# Public Intake Acceptance Evidence

## Mobile photo source and crop preview — 2026-10-26

The user confirmed camera capture and gallery selection both work on the phone. The first crop screen showed the preview as a small square in the upper-left. Investigation found that `StackFit.expand` constrained the `Image` to the square viewport while `PhotoCropPage` computed its transform from the preview's decoded dimensions. The regression test reproduced the mismatch (400×200 source laid out as 480×480). `OverflowBox` now preserves the preview's decoded aspect/dimensions under the existing clipped viewport and transform; original source bytes, crop coordinates, and post-confirm 512×512 JPEG processing are unchanged.

Verification on the feature checkout: photo suite 36/36; full Flutter suite 646/646; targeted Dart analysis of both changed files reports no issues; `flutter build web --release` succeeded with the existing public build-defines file; `scripts/web_preflight.py build/web` passed. Full-project `flutter analyze --no-pub` completed with three informational `unnecessary_underscores` notices in `test/features/intake/pending_submission_repository_test.dart` (lines 134, 165 and 190), outside this change. The release build emitted a Cupertino icon font notice; no Cupertino icon references exist in application/test source. The user confirmed on a physical phone that the corrected preview now opens with the source photo ready for framing and that camera capture, gallery selection, and crop confirmation work.

The user authorized updating the existing public pre-production site for another phone check. Wrangler 4.153.0 deployed source `23e81afba858feba2cf58c4ade12b26c4781cab3` to Pages branch `main` as immutable deployment `https://83b9a149.discipulado-ieadpe.pages.dev`; canonical URL remains `https://discipulado-ieadpe.pages.dev`. The immutable `/auth/callback?next=%2Fhome`, `/register`, and `/main.dart.js` all returned HTTP 200 with zero redirects; JavaScript MIME was correct. Downloaded `main.dart.js` SHA-256 matched the local built artifact at both the immutable deployment and canonical URL. The 42-file release manifest is stored outside Git at `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\public-intake-photo-crop-fix-release-20261026.json`. No database or Supabase setting changed during deployment. The user later confirmed the corrected crop and photo sources on a physical phone.


## Mobile camera/gallery acceptance and synthetic-data cleanup — 2026-10-26

The user confirmed the camera, gallery, and crop flow work on a physical phone after the public photo-crop fix was deployed. This completes the mobile photo interaction check for the anonymous intake page.

The temporary synthetic signup and its approval, photo assets, and related operation receipts were removed after an encrypted database and photo backup was created. The original data totals were restored: 51 converts, 51 ministry people, 15 convert events, 8 mutation receipts, 40 congregation week guards, 10 weekly reports, and zero photo assets, Storage objects, or public-intake submissions/receipts/events/decisions. Integrity checks found no convert-to-congregation, convert-to-person, or photo-asset/Storage orphans. The encrypted pre-cleanup archive and operation evidence are stored outside the repository under `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\phone-photo-cleanup-20261026T204116Z`.
## Public-origin mobile submission and approval — 2026-10-26

The user submitted the agreed fictitious `TESTE CELULAR` from a physical phone using the public registration URL. The authenticated browser queue showed exactly one pending submission for Matriz. The operator approved that item through the published review UI; the queue then showed no pending requests. Official name search showed exactly one matching Matriz record, and the same one-result search succeeded after a full browser reload. This verifies the public-origin mobile-submission -> pending -> approval -> persisted official-record journey; the report does not store the submitted phone/address/birth-date values.

The synthetic record was retained temporarily for the authorized camera/gallery test described below. Its initial submission and approval path passed. Cleanup and reconciliation have since returned the official data to the pre-test baseline; see “Mobile camera/gallery acceptance and synthetic-data cleanup”. No other business record was edited.

## Public OAuth routing fix and successful sign-in — 2026-10-26

The first live Google attempt exposed a Pages routing defect: direct GET/HEAD `/auth/callback?next=%2Fhome` returned HTTP 308 with Location `/?next=%2Fhome`. `/register` also redirected to `/`. Earlier route checks followed redirects, so their HTTP 200 results did not prove path preservation. Root cause: exact proxies targeted `/index.html`, invoking Pages HTML canonicalization. Commit `45535fc` changes only static route targets to `/` with status 200, aligns preflight and adds the regression assertion. Initial RED failed at the expected callback target; final release-operation suite passed 10/10. Stale documentation assertions were updated to the actual configured host/artifact state.

Redeployed as `https://8010813b.discipulado-ieadpe.pages.dev`, retaining the original 41 non-routing assets byte-for-byte. Curl GETs with redirect following disabled returned HTTP 200 and zero redirects for the canonical `/auth/callback?next=%2Fhome` and `/register`; HEAD showed no Location header on canonical and immutable callback endpoints. A Python urllib probe returned 403 while curl/browser requests succeeded, so that client-specific result is not counted as passing route evidence. No app bundle rebuild or database mutation was required.

The user then completed a fresh Google sign-in. The browser returned through `/auth/callback`, established an authenticated session and rendered the protected shell with sign-out and authorized Convertidos/Pendentes/Admin/Discipulado navigation. Início navigated to canonical `/home`. This supersedes the prior fresh-login/account-selection-only limitation; it does not establish the remaining mobile-device or public-origin anonymous submission/approval checks. No authorization codes/tokens are stored in this report.

## First authorized Pages deployment — 2026-10-26

The user explicitly approved first publication to `https://discipulado-ieadpe.pages.dev` and validation there. Wrangler 4.153.0 deployed the reviewed `build/web` to the existing Pages project's production branch `main`, tagged with source `e768261cfdf3bea538a6b9272190c9158bb24ad2`; immutable deployment URL: `https://9b00cc50.discipulado-ieadpe.pages.dev`. This supersedes older NOT AUTHORIZED / NOT PUBLISHED statements for this first deployment only. No paid services or plan changes were enabled.

Fresh HTTPS checks passed for `/`, `/register`, `/login`, `/pending`, `/auth/callback` and `/ministry/students`: HTTP 200 with Flutter bootstrap HTML. Both `/flutter_bootstrap.js` and `/main.dart.js` returned HTTP 200 and JavaScript MIME. This verifies static routing, not authorization for those routes.

Browser check on the canonical public origin rendered anonymous registration and the names-only congregation selector without sign-in; photo controls were absent. Selecting Início showed Google-login requirements. Clicking Google login reached the real Google account chooser with the Supabase callback and canonical Pages redirect. Account selection and successful callback/session establishment are not yet verified; the user must select the intended account. No synthetic registration was submitted in this check and no business data was altered. Public-origin Turnstile submission/approval and actual mobile camera/gallery remain open.

## Launch follow-up — 2026-10-26

The user explicitly deferred the Free-tier usage snapshot, accepting possible Free-limit interruption and no automatic paid activation. This gate is deferred by the user, not measured or passed.

Read-only dashboard inspection of the successful `public-intake` POST/202 invocation at 2026-10-26 13:20:34 America/Sao_Paulo checked both Details and Raw. That invocation showed request/response metadata (including IP/network-derived location and browser information), not the submitted draft/person fields or Turnstile token. No provider configuration was changed. This is evidence for the inspected invocation only, not proof of universal non-retention or a provider-wide guarantee. Earlier blanket body-visibility uncertainty should be read with this bounded observation; actual metadata access/retention still follows provider controls.

Before the first Pages deployment, the existing configured release passed `python scripts/web_preflight.py build/web`; all 42 asset SHA-256 hashes matched the external reviewed manifest for source `e768261`. No `lib`, `web`, or dependency source changes exist between that candidate and the current documentation-only head. Public HTTPS/OAuth/mobile acceptance still requires the first deployment and actual checks. No publication occurred during this preparation.

Date: 2026-10-26 (R7 evidence close)
Implementation baseline: `origin/main` at `846a320619d3d8240df391a8b218c713bcceedc3`
T8 checkout baseline: T7 reviewed commit `d75ee355a5b197fd09485771608ed7864dac04b9`
Execution checkout: `feat/public-web-intake` in the isolated `public-web-intake` worktree
Current source candidate: `e768261cfdf3bea538a6b9272190c9158bb24ad2` on `feat/public-web-intake`; implementation/configuration match approved code candidate `588397c9c0bb7b1976c3c82694c43f7438d258d9`, and Supabase pre-production settings are committed at `6e09ae6`. The configured release build, preflight and external asset manifest are complete. An independent Sol 6.1 low review found and prompted correction of stale status summaries and the archive TOC count.

T9 release handoff and current operator prerequisites: [Public Web intake operations](../operations/public-intake.md). Sections below record historical R1–R7 evidence; the later “P1–P6 pre-production closeout” section is the current evidence summary.

## T8 historical candidate checks

The following T8 PASS/INCOMPLETE results describe the earlier T8 source candidate and remain historical receipts. R1 refreshed only the three named local SQL scenarios; R3 changed only the hosted verification runner. The new current-candidate checks are recorded below and do not convert any hosted gate to PASS.

## Acceptance status

| Gate | Status | Evidence |
|---|---|---|
| Full Flutter suite | PASS | `flutter test --no-pub --concurrency=1 --reporter expanded`: 645/645 passed, 17:38. Full output: `.superpowers/sdd/public-web-intake/t8-full-flutter-test.log`. |
| Changed Dart analysis | PASS | Direct SDK `dart analyze` on the six changed Dart sources/tests: `No issues found!` |
| Full Flutter analyzer | INCOMPLETE | `flutter analyze --no-pub` remained alive for over four minutes with no output and a zero-byte log. Process inspection showed about 7 MiB working set and under 0.02 CPU seconds. Only that analyzer command was interrupted; the scoped direct analyzer completed. |
| Dart format and whitespace | PASS | `dart format --output=none --set-exit-if-changed` on six changed Dart files reported 0 files changed; `git diff --check` passed. |
| Web release build and preflight | PASS | `flutter build web --release --no-pub` built `build/web` in 246.5 seconds; `python scripts/web_preflight.py build/web` passed. Flutter's Wasm dry run succeeded. The build emitted the existing CupertinoIcons font-manifest warning. |
| Python runner/gate contracts | PASS | `python -m unittest discover -s scripts -p 'test_unified_*.py' -v`: 48/48 passed in 290.1 seconds. |
| Verification manifest | PASS | `python scripts/verification_cases.py --validate`: 33 SQL scenarios and 10 concurrency cases validated. |
| Public intake SQL and concurrency | PASS | `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency`: scenario passed, followed by capacity, same-network, receipt, review, registration, and revocation race checks. |
| Pending review SQL and concurrency | PASS | `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency`: scenario passed, followed by the same nine shared intake/review race checks. |
| Catalog archive concurrency | PASS | `python scripts/test_database.py catalog_test.sql --catalog-concurrency`: archive/create and archive/grant wait and revalidate in both commit orders. |
| Deno test handler | PASS | `deno check scripts/public_intake_test_server.ts` passed; `deno test supabase/functions/public-intake` passed 18/18. Deno 2.9.8. |
| Original local browser journey | BLOCKED (historical) | The original T8 run of `python scripts/run_unified_journey.py` reported local Supabase unavailable. This was the pre-amendment local path; Docker is not a prerequisite in the amended hosted plan. No journey was run during this offline-only follow-up. |

## R1 current-candidate SQL reconciliation (2026-10-26)

The previous local SQL `INCOMPLETE` assessment described an earlier environment without an available `psql`/server path. For current candidate `bed4cbe2887b38db98d13e109b8cd033707ee3ae`, the three focused database commands below were freshly executed and exited 0 with their reported PASS lines. The runner selected the existing PostgreSQL 17.11 loopback bundle at `~/.codex/tools/ieadpe-postgresql/pgsql/bin`; it constrains targets to loopback and did not start Docker. `psql` is absent from PATH, but this did not prevent the runner from using the bundle. This is local SQL evidence only; hosted SQL remains unverified.

| Local SQL gate | Status | Current-candidate command and outcome |
|---|---|---|
| Public intake scenario and concurrency | PASS (local) | `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency` — exit 0; `PASS: public_intake_test.sql` and `PASS: public intake serializes the last global capacity slot`. |
| Pending review scenario and concurrency | PASS (local) | `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency` — exit 0; `PASS: pending_review_test.sql` and `PASS: public intake serializes the last global capacity slot`. |
| Registration authority scenario | PASS (local) | `python scripts/test_database.py public_registration_authority_test.sql` — exit 0; focused authority scenario passed. |

These results supersede the earlier local SQL `INCOMPLETE` statements only for the named scenarios and current local candidate. They do not amend historical receipts, establish complete manifest coverage, or establish hosted runtime behavior. The earlier `INCOMPLETE` statements remain historical records of their then-current environment.

### R1 hosted configuration presence update (2026-10-26)

The earlier environment-presence observation that `SUPABASE_URL` was absent is historical. A later presence-only check found `SUPABASE_URL` present and its parsed hostname matched the inventoried project. `PUBLIC_INTAKE_DATABASE_URL` and `PUBLIC_INTAKE_TRUSTED_PROJECT_REF` remain absent. This configuration evidence does not establish backup/TLS runner readiness or hosted SQL acceptance; hosted gates remain BLOCKED/INCOMPLETE. No variable values are included here. Exact safe check and result: `.superpowers/sdd/public-web-intake/task-r1-fix-report.md`.

### R2 hosted verification prerequisites (2026-10-26)

Controller-verified evidence establishes the exact target as the unique active Supabase project `Discipulado IEADPE` (`voqmtnqjrbugpazcimvh`); the process `SUPABASE_URL` host parsed to that same project. Migrations `202610250002`–`004` remain pending and the functions list was empty in the R1 read-only inventory. No hosted write was attempted for R2.

A fresh external full custom-format backup was verified against that project by the external manifest validator. The archive is 857,367 bytes with SHA-256 `56bbe069fb9568d07a193f4197d300bb0f85dd8eccc358f234ca04de3bd4f33b`; the external manifest records its exact UTC backup time. The backup directory/files are owner-only. An AES-256-GCM encrypted copy and DPAPI CurrentUser-wrapped key are also external; decrypt-and-hash matched the plaintext archive. The referenced archive header records 1,018 TOC entries; `pg_restore --list` emitted 1,026 lines. An isolated PostgreSQL 17.11 recovery rehearsal restored application data, verified 9 application schemas, 37 migration rows, 24 congregations and 51 converts, and dropped its exact local database. This is a successful local restore rehearsal, not a hosted restore. The restore excluded only 10 `vault`/`supabase_vault` TOC entries unavailable in that local target. Database/Storage dump evidence does not include Storage object bytes; no existing Storage object is targeted by the planned rollback-only SQL smoke.

TLS readiness was verified with client-only PostgreSQL 17.11 tools and `PGSSLMODE=require`: authenticated `SELECT 1 AS safe_probe` returned `1`, and `pg_dump` completed. The database URL was held only in process environment; `PUBLIC_INTAKE_DATABASE_URL` remains absent from persistent process environment and no credential value is recorded here. No Docker was started.

The runner evidence path is external at `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\run-5655bd75-b699-47da-b3db-24d3e046e78a-evidence.json`; R3 later wrote a redacted BLOCKED receipt there after target confirmation and a TLS identity probe. No synthetic fixture or hosted scenario was dispatched. The exact external backup manifest and validation receipt remain outside Git. Project and backup details are recorded in `.superpowers/sdd/public-web-intake/task-r2-report.md` without secrets or dump contents.

These checks satisfy the backup, archive/recovery-path, TLS identity-probe, and external evidence-path prerequisites only. They do not authorize or claim hosted SQL acceptance, migration/deployment, function deployment, or browser verification. The general hosted write gate and service-specific prerequisites remain blocked.

Local versions were Flutter 3.47.2 / Dart 3.13.2, Python 3.12.10, and Deno 2.9.8, versus the repository CI pin Flutter 3.47.7 / Dart 3.13.5. No shared SDK or CI pin was changed.

## Amended hosted acceptance status

### R3 hosted runner evidence (2026-10-26)

The current hosted-runner offline suite passed 27/27. Target validation now accepts only the verified direct endpoint or the project-scoped shared Session Pooler shape, rejects libpq query overrides and inherited `PG*` routing values, and keeps the password out of argv/output. Missing migrations are inventoried through the authenticated CLI; psql does not query the protected `supabase_migrations` schema.

The external run receipt records `status=BLOCKED`, `target_confirmed=true`, `baseline_scope=unavailable`, `blocker_code=baseline_unavailable`, `scenario_dispatched=false`, and `hosted_write_attempted=false`. The authenticated CLI login passed the TLS database identity probe but was denied access to a required application schema during baseline collection. Therefore the runner stopped before migration inventory or scenario dispatch. The separate read-only CLI migration inventory at 2026-10-26 04:00 UTC showed 37 remote migrations: `202610250001` applied and `202610250002`–`004` pending; the function list was empty. No fixture, grant, record, object, migration, or function was changed.

The amended plan makes Docker unnecessary for acceptance and requires backup-first hosted checks. None of the following hosted gates has passed; T8 hosted acceptance remains **INCOMPLETE**.

General hosted write readiness is BLOCKED. R2 established the exact project/ref, fresh external full-backup archive and manifest, checksum/readability/recovery-path evidence, and TLS identity-probe readiness. R3 confirmed the exact target and wrote an external receipt, but the CLI-generated PostgreSQL login could not read the application baseline schema; the receipt is BLOCKED with `baseline_scope=unavailable`. No scenario SQL, fixture, hosted write, migration, or deployment occurred. Before resuming a hosted write, provide a protected TLS database URL/role with required baseline and scenario privileges and create a separate external run-owned evidence manifest containing before/after baseline, fixture/identity/receipt IDs, reconciliation result, and exact guarded cleanup plan. Additive migrations/function activation still need the separately authorized coordinated candidate; publication remains separate.

| Hosted gate | Status | Evidence and resumption prerequisites |
|---|---|---|
| Hosted migration/schema readiness | BLOCKED | Read-only migration list shows `202610250001` applied and `202610250002`–`202610250004` pending. No migration was applied. Resume only after a fresh external full backup and manifest are verified, then review and coordinate the exact migration candidate and deployment. |
| Hosted functions readiness | BLOCKED | Read-only functions list is empty. No function was deployed. The reviewed local fallback can proceed without authoritative address trust using Turnstile plus global pending capacity; its hourly/daily per-network limiter remains incomplete. Resume after reviewed function candidate and coordinated deployment readiness. |
| Hosted runner / database journey | BLOCKED | Current hosted-runner offline suite passed 27/27. The real runner confirmed target and TLS identity, then wrote an external BLOCKED receipt because its CLI login lacks the baseline schema privileges. No scenario was dispatched. Provide a protected TLS URL/role with required baseline and scenario privileges before resuming; the reviewed scenario/function candidate and service-specific gates must also be ready. |
| Hosted T2 limits and concurrency | BLOCKED / INCOMPLETE | T2 hosted smoke explicitly refuses the legacy shared-table `TRUNCATE` scenario and `--concurrency`; rate-window/capacity limits, cleanup and concurrency are not hosted-verified. Keep those gates incomplete until a reviewed, non-interfering run-owned fixture/race design supports exact cleanup and reconciliation. |
| Hosted bot verification | BLOCKED | Hosted Turnstile hostname and server configuration were not verified or changed. Resume after confirming the real hostname and matching server-side Turnstile configuration. |
| Hosted reviewer access | BLOCKED | No temporary synthetic reviewer identities or grants were created. Resume only with temporary synthetic reviewer identities/grants, a bounded run-owned fixture, and exact cleanup authorization. |
| Hosted anonymous browser journey | BLOCKED | No hosted browser journey ran, and no hosted PASS or user completion observation is claimed. This is blocked by the insufficient database role, pending schema and absent function, unverified hostname/Turnstile configuration, and absent reviewer identities/grants. If run before trusted address evidence exists, the global-only fallback applies and per-network hourly/daily protection remains incomplete. Resume only after the remaining prerequisites are independently reviewed and available. |

## P4 address-unavailable fallback (2026-10-26)

The current local candidate explicitly represents an unavailable trusted address as `network_hash: null`. It never reads or hashes caller-supplied `X-Forwarded-For`, `CF-Connecting-IP`, or `X-Real-IP`. The receive RPC accepts a present null hash, skips only the network advisory lock and hourly/daily checks for that request, and always enforces global pending capacity. Same-key replay remains digest-bound and idempotent; valid HMAC hashes retain the existing per-network checks. Turnstile hostname/action checks remain mandatory. **The per-network limiter is incomplete** until an authoritative managed Edge address source is proven; global capacity and Turnstile are the only available guards in this fallback.

Local verification for this candidate: `deno check supabase/functions/public-intake/index.ts` passed; `deno test supabase/functions/public-intake` passed 20/20; `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency` passed in the disposable loopback PostgreSQL harness, including null-hash acceptance/replay, global capacity rejection, and the existing intake concurrency checks. These results do not establish hosted migration, function, address-source, Turnstile, or browser acceptance. No hosted service was contacted or changed.

Read-only hosted evidence and constraints are recorded in `.superpowers/sdd/public-web-intake/progress.md`, `.superpowers/sdd/public-web-intake/task-r1-report.md`, `.superpowers/sdd/public-web-intake/task-r2-report.md`, and `.superpowers/sdd/public-web-intake/task-r3-report.md`. Offline PASS results establish runner contracts only, not hosted behavior. No hosted migration, function deployment, Auth user, grant, record, or Turnstile setting was changed.

## Journey and security design

The added browser journey uses the existing unified runner and the actual Flutter app, repositories, and pending/review contracts. It covers anonymous submission to an active congregation, generic acceptance and same-ID retry after a lost response, exclusion of pending data from official reads/reports, wrong-scope denial, scoped supervisor correction and approval, one canonical official result, payload erasure, rejection of anonymous official RPC/photo-upload bypasses, and sign-out cleanup. The original local journey could not execute because local Supabase was unavailable; this historical result is not amended hosted-journey evidence, and those behaviors are not represented as browser PASS evidence.

`scripts/public_intake_test_server.ts` is a host-side local test adapter. Its bot token and address are deterministic and keyed to the generated journey run. It binds only to loopback, accepts only the configured public-intake path, and talks only to the configured local Supabase API. The runner's endpoint rewrite requires an exact loopback endpoint and exact function path. The service-role credential remains in the Deno host process environment and is never written into Flutter settings or the browser bundle. The adapter is outside `supabase/functions` and is not referenced by deployment configuration. T3's production resolver and trust boundary were not modified.

Runner cleanup uses generated run IDs and the browser-reported submission UUID. It removes only the run-owned pending submission, decision, receipt/event, canonical convert/person dependencies, and exact run-owned unsigned photo object if an unauthorized upload unexpectedly succeeds. The runner remains guarded against remote Supabase URLs and hosted database targets; its Python tests cover cleanup after partial setup and browser failure.

## Test partitions and boundaries

- The public HTTP/Deno checks cover valid acceptance and invalid bot, origin, schema, unknown-key/photo, size, provider/database timeout, and unsafe error/log cases. The handler suite passed 18 tests. Request-size validation retains the 16 KiB boundary and rejects before draft decode.
- SQL scenarios cover active/archived names-only catalog behavior; private queue access; idempotent and conflicting submission retries; exact hourly, daily, and global-pending settings; decision retention; payload erasure; scope checks; and official-record absence/presence across review.
- Concurrency cases exercise the last global slot, 20 same-network acceptances versus the 21st, same-key retry, identical and conflicting review decisions, reject/approve races, normal registration versus approval, and grant revocation versus review. The direct T8 commands passed every reported race.
- Photo usability checks cover 360, 768, and 1440 pixel viewports at 200% text, high-contrast rendering, keyboard alternatives, reduced-motion transitions, cancellation and authority loss. A selected crop combined with EXIF orientation 6 remains 512×512 and keeps the selected region. No native camera hardware was available for a device smoke check.
- The complete unit/widget suite passed 645 tests. The first full run completed with 638 passes and seven failures. Investigation found three distinct test-harness issues: the catalog concurrency fixture lacked scoped authority for its synthetic registrar; the shell gate harness lacked an isolated Deno executable; and four older protected-photo workflow fixtures tried opening the picker before selecting a congregation (the current UI correctly hides it until a scope is selected). The workflow scope-change fixture now transitions from global admin to a scoped registrar for the same synthetic congregation. All repairs are test-only and the full rerun passed.
- The public-intake SQL scenario exposed two older cleanup-seed decision rows missing T5's required `corrected_draft_digest`. They now use the documented SHA-256 digest of the JSON null sentinel for rejection. The SQL scenario and concurrency rerun passed.

## Observations and remaining evidence

No public visitor or reviewer browser completion observation was collected: no hosted journey ran, and the prior local journey result is historical only. No impression, completion time, or error observation is claimed. No disability-user study or native camera/device smoke was performed. Flutter 3.47.2 exposes a high-contrast accessibility flag but no reduced-transparency signal; the crop guide responds to high contrast with opaque shading and a thicker, high-contrast selection ring. Platform-specific reduced-transparency behavior still needs device review.

The production intake remains release-blocked until the complete hosted prerequisites above are satisfied. Docker is not required by the amended plan. No hosted migration, hosted fixture, production change, publication, paid service, or account configuration was performed during this follow-up.

## P1–P6 pre-production closeout (2026-10-26)

This section supersedes earlier hosted `BLOCKED` statements above where newer receipts exist. It records pre-production acceptance only; no Pages site was published.

| Gate | Current status | Evidence |
|---|---|---|
| P1 backup and launch baseline | PASS before hosted writes | Reused the verified external full custom-format pre-production archive and protected copy. Project/ref and inventory are recorded in the external manifest. No existing Storage object bytes were present at baseline. |
| P2 operator access | PASS for authorized scope | Authenticated Supabase CLI Management API queries and exact pre-production SQL mutations succeeded against `voqmtnqjrbugpazcimvh`; the deployed Edge Function and Storage APIs were reachable. A protected PostgreSQL 17.11 Session Pooler URI passed authenticated TLS identity verification and `pg_dump`. |
| P3 runner safety | PASS | Runner review at `f7ba726` passed 38/38; subsequent hosted-fixture compatibility changes passed 42/42 at `7231ee7`, independently reviewed at the time. The current hosted runner uses explicit pre-production confirmation, verified backup manifest, exact target identity, rollback, and reconciliation. Individual external run receipts are in the protected backup directory. |
| P4 hosted activation | PASS, pre-production only | Applied migrations `202610250002`–`004` once and deployed only `public-intake`. Verified migration ledger, grants, Edge secrets by name, exact production CORS, Turnstile Siteverify rejection for an invalid token, and the reviewed global-capacity/Turnstile fallback. No Pages deployment/publication occurred. |
| P5 synthetic journey, cleanup and data reconciliation | PASS | Anonymous browser submission to active `Água Fria` passed Turnstile and entered the private pending queue; an already-authenticated authorized reviewer corrected and approved it; the official record appeared in the authenticated converts list. The authorized gallery flow selected the synthetic four-color fixture, exercised square crop/zoom/pan, saved it, and the resulting profile photo appeared. Anonymous Storage upload/download were denied and anonymous listing did not expose the protected fixture. Exact cleanup removed the synthetic Storage object, photo asset, official convert/person, weekly guard, intake submission/receipt/event/decision, and four operation receipts. Final count/link comparison matches the preserved launch manifest exactly for every application table; only the migration ledger is +3. Final state: 51 converts, 51 ministry people, 15 convert events, 8 mutation receipts, 1 Auth user, 0 photo assets, 0 Storage objects, 24 active congregations, 0 queued intake rows, and no application FK/link mismatch. A fresh PostgreSQL 17.11 custom-format dump was made over verified TLS; `pg_restore --list` exited 0 with 817 output lines, and the archive header records 808 TOC entries. Its AES-256-GCM encrypted copy decrypted and hash-matched using a DPAPI CurrentUser-wrapped key. |
| P6 publication proposal | CANDIDATE PREPARED / NOT AUTHORIZED / NOT PUBLISHED | Cloudflare Pages project `discipulado-ieadpe` exists, but has no deployment. Release build and static preflight passed for source checkout `e768261` (code/config unchanged from approved candidate `588397c`; the intervening commit only pins acceptance evidence). The external asset manifest covers 42 files. The fresh post-acceptance backup and encrypted copy are verified. Pages HTTPS smoke, fresh OAuth redirect, mobile camera/device smoke, free-tier usage snapshot, provider request-body retention decision, and verified managed Edge client-IP handling remain open. Publication remains separately authorized and has not occurred. |

### Prepared candidate and release checklist

The candidate checkout is `e768261cfdf3bea538a6b9272190c9158bb24ad2`; implementation/configuration remain byte-for-byte unchanged from approved code candidate `588397c9c0bb7b1976c3c82694c43f7438d258d9` (the intervening commit changes acceptance documentation only). `flutter build web --release --no-pub` completed successfully with the protected public-defines file, and `python scripts/web_preflight.py build/web` passed. The external 42-file asset manifest is `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\public-intake-release-candidate-20261026.json` (SHA-256 `bae1d632ef6fdfe30a88a4e2ad5444b98aaccf3fe56920f3a8b820c5e154cbf8`). It contains no secrets.

The fresh post-acceptance archive is `public-intake-post-acceptance-20261026T182108Z.dump` in the protected external backup directory: 801,059 bytes, SHA-256 `34b92f22c4bd5a75f6a5c572e507d681ecb3b777bf34cb8cf4a9ebc61a2abdc4`; `pg_restore --list` exited 0 and emitted 817 lines; the archive header records 808 TOC entries. An AES-256-GCM copy and DPAPI CurrentUser-wrapped key were verified by decrypt-and-hash. The detailed protected receipt is `p5-browser-acceptance-20261026.json`. The archive contains database state, not Storage object bytes.

| Release gate | Status before any publication request |
|---|---|
| Approved source, configured release build, static preflight and asset manifest | PASS; externally hash-pinned |
| Pre-production hosted journey, exact cleanup and launch-data reconciliation | PASS; P1 application counts and link checks match, migration ledger is +3 |
| Fresh post-acceptance database backup, TLS, archive readability and encrypted copy | PASS; Storage object bytes are outside this archive |
| Temporary test allowances | PASS; production-only origin/hostname settings restored and verified |
| Pages deployment and real HTTPS browser journey | OPEN; the Pages project exists without a deployment; publication authorization is intentionally outstanding |
| OAuth redirect round trip and mobile camera/gallery device smoke | OPEN; authenticated session existed, but a fresh redirect/device run was not performed |
| Free-tier usage snapshot | OPEN; record current Supabase and Cloudflare usage before launch |
| Provider invocation-body visibility/retention decision | OPEN; no provider retention behavior is claimed |
| Managed Edge client-address trust and per-network rate limits | OPEN; global cap/Turnstile fallback passed, per-network limits are not claimed |
| Final publication approval | NOT REQUESTED; prepare and review the complete candidate first, then obtain separate approval |

Temporary local test allowances were restored after the browser journey: the Turnstile widget again permits only `discipulado-ieadpe.pages.dev`; Supabase Edge allowlist secrets were reset to the protected production-only file. Post-restore preflight returned HTTP 204 with the production origin and HTTP 400 for `http://localhost:3000`. The authenticated browser session remains available, so no user login/MFA was requested again.

Known limitations remain explicit: no trusted client-address source is established for managed Edge Functions, so the per-network hourly/daily limit is incomplete; no hosted Pages deployment or HTTPS end-to-end check occurred; OAuth callback configuration is present but a fresh OAuth redirect was not exercised; no native mobile camera/device smoke was done. A test request with a deliberately unsupported `x-turnstile-token` CORS header returned 400; code inspection confirmed the token is sent in the JSON body, and the actual Supabase function client's allowed headers pass preflight. This rejected probe did not alter configuration.

The exact synthetic IDs, storage path, SQL cleanup receipt and table-by-table count comparison are retained only in the protected external evidence directory. The first guarded SQL cleanup attempt aborted and rolled back because it referenced a nonexistent `payload` column; schema inspection corrected the guard to `draft IS NULL`. Reconciliation then found one newly created weekly guard for the synthetic convert, which was deleted by exact congregation/week/count predicate. A subsequent full row-count and link-integrity comparison matched the P1 manifest.
