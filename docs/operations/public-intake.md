# Public Web intake operations and release handoff

> Hosted routing correction: exact application-route proxies must target `/` with status 200, not `/index.html`. The first deployment reproduced HTTP 308 from `/auth/callback` to `/`, losing the callback path through Pages HTML canonicalization. Keep exact source paths (no broad wildcard), preserve query strings, and verify HTTP 200 with no Location header using requests that do not follow redirects. Earlier `/index.html` proxy advice is superseded. Static assets must retain bytes/MIME.

> Deployment update (2026-10-26): the user explicitly authorized the first public validation deployment. The existing Pages project is now deployed at `https://discipulado-ieadpe.pages.dev` (immutable deployment `https://9b00cc50.discipulado-ieadpe.pages.dev`, reviewed source `e768261`). Older undeployed/not-authorized statements below are historical for this first deployment. HTTPS routes/assets and anonymous form/catalog rendering passed; fresh Google login reached account selection but callback completion, public-origin submission/approval and real mobile photo checks remain open. Free usage was explicitly deferred by the user; no paid plan was enabled. Do not infer final production acceptance from a successful deployment. See the latest acceptance report.

> Superseding user decision (2026-10-26): the hosted project is pre-production. The Spec's latest decision and plan P1–P6 override this runbook's older per-row-only cleanup/no-data-restore restrictions. Verified recoverable backup first, authorized application-data changes and online tests next, then restore/reconcile intended launch data into the final migrated schema. Operator access/configuration failures remain technical blockers. Public publication is separate; stricter production controls begin at the transition to real use.

Date: 2026-10-25

Source: approved [public Web intake Spec](../superpowers/specs/2026-10-25-public-web-intake-design.md) and [implementation plan](../superpowers/plans/2026-10-25-public-web-intake-plan.md). These govern this increment; this runbook records the current candidate and operator steps. Historical release documents do not establish that any hosting account or production setting exists.

## Current publication status (2026-10-27)

The user authorized pushing the integrated work and publishing it. Wrangler 4.153.0 deployed the merged `build/web` (source `602d583`, which merges the approved convert-registration simplification into `feat/public-web-intake`) to project `discipulado-ieadpe`, branch `main`. Immutable deployment: `https://2164db51.discipulado-ieadpe.pages.dev`; canonical: `https://discipulado-ieadpe.pages.dev`. Canonical and immutable `/`, `/register` and `/auth/callback?next=%2Fhome` returned HTTP 200 with zero redirects, `/main.dart.js` returned HTTP 200 with `application/javascript`, and its SHA-256 matched the local artifact. No database or Supabase setting changed during this deployment.

Statements below that say publication is unauthorized or that the project has no deployment are historical for the 2026-10-26 state. Still open: Free-tier usage snapshot (deferred by the user), provider invocation-body retention decision, managed Edge client-address trust and per-network limits, a fresh OAuth round trip, and browser/mobile acceptance of this merged build. See the [acceptance evidence](../verification/public-intake-acceptance.md).

## Current pre-production status (2026-10-26)

This status supersedes the historical `BLOCKED` inventory and candidate statements below where they conflict. The user authorized controlled testing on pre-production project `voqmtnqjrbugpazcimvh`; public publication remains separate and has not occurred.

- Applied migrations `202610250002`–`004` once and deployed the reviewed `public-intake` Edge Function. The anonymous path was exercised with the real Turnstile site configuration; the configured Pages-origin preflight passes. The managed Edge client-address source remains unverified, so only Turnstile plus the global pending-capacity limit are active; per-network hourly/daily protection remains incomplete.
- Cloudflare account access and the `Public Intake Preproduction` Turnstile widget are verified. Its only allowed hostname is restored to `discipulado-ieadpe.pages.dev`. The Supabase Edge origin/hostname secrets are restored to the protected production-only allowlist after localhost testing.
- The authenticated local Flutter Web session completed anonymous submission, authorized review/approval, canonical convert listing, and authorized gallery photo crop/save. Anonymous Storage upload/download were denied; anonymous listing revealed no protected fixture. The synthetic rows, receipts, weekly guard and JPEG object were cleaned exactly.
- Post-cleanup Management API reconciliation matches every application-table row count and link-integrity value in the preserved P1 manifest. Counts include 51 converts, 51 ministry people, 15 convert events, 8 mutation receipts, 1 Auth user, no photo assets or Storage objects, 24 active congregations, and empty public-intake tables. The only intended count delta is the migration ledger (+3). The restored application data therefore needs no wholesale reimport; existing application rows were preserved.
- The protected PostgreSQL 17.11 Session Pooler URI is verified with TLS. A fresh post-acceptance custom-format dump and encrypted copy passed archive/readability and decrypt-and-hash checks; the external P5 receipt records exact hashes. A configured Flutter release build and 42-file asset manifest are also complete.
- Publication remains **NOT AUTHORIZED**. Cloudflare Pages project `discipulado-ieadpe` exists but has no deployment. Remaining release gates are current Free usage, provider invocation-body visibility/retention decision, managed Edge client-address trust, fresh OAuth redirect, mobile camera/gallery device smoke, and HTTPS browser acceptance after separate deployment approval. No Pages deployment/publication occurred.

The protected external evidence directory contains run receipts, baseline comparisons, and exact cleanup records. No secret or synthetic record identifiers belong in this runbook. Device-native camera testing, fresh OAuth redirect flow, hosted HTTPS Pages checks, and authoritative managed Edge address verification remain incomplete.

## Historical R1–R3 readiness decision (superseded by P1–P6 evidence)

The following was the point-in-time R1–R3 status and is preserved as historical evidence. It is superseded by the current pre-production status and P1–P6 closeout above/below.

**Historical status: BLOCKED for hosted activation and publication.** At that point, local implementation and T8 acceptance evidence did not prove hosted behavior. No hosted write, migration/function deployment, Turnstile configuration, account change, publication, or paid-service action had been performed for that handoff.

At the R1–R3 checkpoint, the read-only snapshot showed migrations `202610250002` through `202610250004` pending and no hosted function. R2 verified a fresh external full-backup archive/manifest, checksum, local restore rehearsal, and TLS identity probe. R3's external runner receipt was BLOCKED because the CLI-generated database login could not read the application baseline schema; no hosted scenario or write ran at that checkpoint. Turnstile's production hostname/configuration and managed Edge client-address source were then unverified, and temporary synthetic reviewer identities/grants were absent. Those are historical facts only; later authorized P1–P6 work is recorded above and in [acceptance evidence](../verification/public-intake-acceptance.md).

### Service and deployment inventory

| Service | Candidate use | Inventory and ownership |
|---|---|---|
| Static web host | Flutter Web files, exact route fallback, HTTPS | Cloudflare Pages project `discipulado-ieadpe` exists. The selected pre-production hostname is `discipulado-ieadpe.pages.dev`; the Pages project has no deployment, so no public HTTPS journey has been run. |
| Supabase | Postgres, Auth, private Storage, `public-intake` Edge Function | Exact pre-production project is `voqmtnqjrbugpazcimvh`. Migrations `202610250002`–`004` and the `public-intake` function are applied/deployed there; no production change is claimed. |
| Cloudflare Turnstile | Browser challenge and server-side Siteverify | The pre-production widget and server Siteverify secret are configured for `discipulado-ieadpe.pages.dev`; real synthetic browser verification passed. The widget is restored to that hostname only. |
| VM / custom infrastructure | None | No VM, load balancer, custom API server, scheduler, R2, or IaC platform is part of this design. No billing should be enabled automatically. |

The static web host serves public files only. Supabase owns database/Auth/private object service and Edge runtime. Turnstile verifies browser challenges; it does not replace server-side authorization or network abuse controls. Public intake persists no photo. Approved photos continue through the existing authenticated private Storage path.

### Shared responsibilities and limits

Providers operate and patch their infrastructure and platform services, and provide platform HTTPS/at-rest protections under their current plan terms. The developer/operator owns application and dependency patching, grants and RLS, precise origins/callbacks, server secrets, private-bucket policy, least-privilege account access, account recovery, reviewed migration/function/static releases, quota monitoring, off-site backups, restore readiness and incident response. Require HTTPS for the public site and Supabase URL; use private Storage and provider at-rest encryption. Do not put service credentials in Flutter defines, `build/web`, source control, CI output or public issue/report attachments.

Supabase Free is a constrained tier, not an SLA: the reviewed pricing page lists 500 MB database, 1 GB Storage, 50,000 MAU, 5 GB uncached egress, separate 5 GB cached egress and two active projects. Free projects can pause after seven days without activity; the cited policy permits manual restoration up to one year after pause. Neither pause retention nor a successful manual resume is a backup or restore guarantee. Check current dashboard usage and current provider limits before release and at least weekly after launch. Function invocation quota is consumed before in-function rate limiting, so the network/global queue limits do not prevent function-quota exhaustion. Do not enable billing, PITR, paid transformations, or fake keepalive traffic. Exhaustion or pause may interrupt service; preserve retryable form data and use the provider dashboard's supported resume/recovery process. See [Supabase Free backup and pause procedures](supabase-free.md) and official [pricing](https://supabase.com/pricing), [billing limits](https://supabase.com/docs/guides/platform/billing-on-supabase), [pause policy](https://supabase.com/docs/guides/platform/free-project-pausing), [database backups](https://supabase.com/docs/guides/platform/backups), [production guidance](https://supabase.com/docs/guides/deployment/going-into-prod), [Storage pricing](https://supabase.com/docs/guides/storage/pricing), [Storage bandwidth](https://supabase.com/docs/guides/storage/serving/bandwidth), and [Turnstile plans](https://developers.cloudflare.com/turnstile/plans/). Recheck official limits at the time of any release.

Do not promise a free SLA, geographic disaster recovery, automatic failover, or a verified point-in-time restore. A database dump excludes Storage object bytes; see the separate Storage backup/reconciliation procedure below and in [Supabase Free operations](supabase-free.md).

## Versioned candidate and public configuration

### Candidate inventory

The current source checkout is `e768261cfdf3bea538a6b9272190c9158bb24ad2` (`feat/public-web-intake`). Its implementation/configuration match approved code candidate `588397c9c0bb7b1976c3c82694c43f7438d258d9`; the intervening commit changes acceptance documentation only. Supabase configuration commit `6e09ae6` was reviewed. A configured Flutter 3.47.2 release build and 42-file external asset manifest are complete. Migrations `202610250002_public_registration_authority.sql`, `202610250003_public_intake.sql`, and `202610250004_pending_review.sql`, plus `supabase/functions/public-intake/`, are deployed to pre-production project `voqmtnqjrbugpazcimvh` and hosted synthetic behavior passed. This does not represent production deployment or Pages publication.

`verify_jwt = false` applies only to the intentionally public `public-intake` function. All other function/API defaults stay protected. The function checks exact HTTPS origin/hostname, Turnstile server-side response/action, strict payload shape and size, then uses a service-role RPC. If no trusted address resolves, it sends explicit `network_hash: null`, never derives an address from caller headers, and skips HMAC. The RPC skips per-network hourly/daily checks for null hashes but always takes the global-capacity lock and enforces the pending cap. Thus the per-network limiter is incomplete until provider trust is proven. Do not substitute arbitrary `X-Forwarded-For`, `CF-Connecting-IP`, or `X-Real-IP`. Server-side RPC grants remain narrow; no anonymous access to official records, private queue tables, private Storage, or the receive RPC is allowed.

### Exact origin and callback inputs

The selected pre-production hostname is `discipulado-ieadpe.pages.dev`; the Cloudflare Pages project exists without a deployment. Use this exact origin for the prepared candidate. A public HTTPS browser journey remains open until separately approved deployment:

- Static origin and Turnstile hostname: `https://discipulado-ieadpe.pages.dev` and `discipulado-ieadpe.pages.dev`.
- Supabase Auth Site URL: configured as `https://discipulado-ieadpe.pages.dev`.
- Supabase Auth redirect allowlist: configured with `https://discipulado-ieadpe.pages.dev/auth/callback` and the exact callback query variants for `/register`, `/home`, `/converts`, and `/admin`. No wildcard is used. The fresh OAuth round trip remains untested.
- Edge Function origin/hostname allowlists: configured for the exact Pages origin/hostname. Temporary localhost test allowances were removed and the production-origin CORS preflight now returns 204 while localhost returns 400.

The application reads these **public** Flutter build defines:

| Define | Value |
|---|---|
| `SUPABASE_URL` | `https://voqmtnqjrbugpazcimvh.supabase.co` for the pre-production project. |
| `SUPABASE_PUBLISHABLE_KEY` | That project's publishable/anon client key; public by design, still subject to server grants/RLS. |
| `AUTH_CALLBACK_URL` | `https://discipulado-ieadpe.pages.dev/auth/callback`. |
| `TURNSTILE_SITE_KEY` | Public site key registered for `discipulado-ieadpe.pages.dev`. |

Build input must be an operator-owned JSON file outside the repository, terminal history, and artifact directory, containing only those four public values. For example, after filling a protected local file:

```powershell
flutter build web --release --dart-define-from-file=<operator-public-defines.json>
python scripts/web_preflight.py build/web
python -m unittest discover -s scripts -p test_release_operations.py -v
```

Inspect the actual artifact for credentials, test adapters, dumps, and private fixtures before any authorized upload. `web/_redirects` contains exact route proxies; preserve it and never replace it with a wildcard. The static preflight and HTTP route fixture are local checks, not proof of a hosted URL or provider behavior.

The following **private function environment values** belong only in Supabase Edge Function secrets for the confirmed project; use the dashboard or an approved secret-management channel and never print their values:

| Name | Purpose / rule |
|---|---|
| `SUPABASE_URL` | HTTPS URL of the confirmed backend. Function configuration accepts HTTP only for explicit loopback development hosts. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only service credential; never a Dart define or public artifact value. |
| `TURNSTILE_SECRET_KEY` | Server-only Siteverify secret paired with the public key. |
| `INTAKE_NETWORK_HASH_SECRET` | Server-only HMAC key; rotate only with an explicit limiter-window decision. |
| `INTAKE_ALLOWED_ORIGINS` | Comma-separated exact canonical origins. |
| `INTAKE_ALLOWED_HOSTNAMES` | Comma-separated exact hostnames, lower-case, no wildcards. |

The public site key is not read by the function. The Edge invocation view may retain request/response bodies: Supabase's logging guide documents body visibility. Because these bodies contain personal data and a one-time token, obtain and document a provider/operator retention and access decision before any real anonymous submission; application code emits no such payload logs, but that alone does not settle platform log retention. T3 left this **unverified and release-blocking**.

### Controlled activation record and remaining release sequence

The following controlled activation steps are complete for the authorized pre-production project only. Do not replay migrations, change account settings, or deploy/publish Pages as part of this record.

1. **Identity/access — PASS:** the pre-production Supabase project/ref and Cloudflare account/project were verified; CLI, Management API, browser session and protected TLS Session Pooler access worked. No login/MFA is currently needed.
2. **Candidate/build — PASS, unpublished:** the coordinated app/config source is recorded above; the configured Flutter release build and external asset manifest passed. Pages publication remains separately authorized.
3. **Turnstile — PASS for synthetic checks:** the widget and server Siteverify secret are configured for the exact pre-production hostname. The provider invocation logging/body visibility and retention decision remains open before real personal data is accepted.
4. **Migrations/function — PASS, pre-production:** migrations `202610250002`–`004` were applied once and only `public-intake` was deployed. Do not replay them. The verified fallback relies on Turnstile and the global pending cap while per-network limits remain incomplete.
5. **Secrets/grants/denials — PASS for checked behavior:** expected function secrets exist without exposing values; narrow grants and anonymous direct-call/photo-upload denials were checked. No caller-supplied header is trusted as a client address.
6. **Auth/origins/build — PASS for configuration and local artifact:** exact pre-production Auth URLs and allowlists are configured; temporary localhost allowances were removed; release build and static preflight passed. A fresh OAuth round trip and deployed HTTPS route remain open.
7. **Synthetic checks/reconciliation — PASS:** browser journey, exact cleanup, P1 row/link reconciliation and fresh P5 backup are complete. Capture current free-tier usage and close the listed runtime/security gates before any release decision.

## Quotas, pause, limits, and bounded retention

Retention follows fixed policy: pending drafts expire after exactly 30 days, digest-only receipts are retained for exactly 30 days, and minimal decision metadata is retained for exactly 90 days. Operators cannot extend or shorten these periods; only abuse and capacity limits are operator-configurable. The initial settings are 20 accepted submissions per trusted network hash per rolling hour, 200 per rolling day and 1,000 active pending globally, not measured traffic needs. Church Wi-Fi may group legitimate users; tune these limits only from reviewed operational evidence. There is no browser fingerprinting. When the trusted address is unavailable, only the global pending cap and Turnstile protect intake; per-network hourly/daily limits are **incomplete** until provider trust is proven.

Pause public intake by setting the one private settings row's `enabled` value false using an audited, authorized operator SQL session. This rejects new submissions and preserves safe same-key replay behavior. To resume, first resolve the incident and verify Turnstile, queue headroom and service health. A trusted address source is required before enabling the per-network limiter; without it, document that only global capacity and Turnstile are active. Then explicitly set `enabled` true and confirm. Example SQL (execute only against the independently confirmed project, with an approved database-owner credential; do not commit credentials):

```sql
BEGIN;
UPDATE private.public_intake_settings
SET enabled = false, updated_at = now()
WHERE singleton = true;
SELECT enabled, hourly_network_limit, daily_network_limit,
       global_pending_limit, pending_ttl, receipt_retention, decision_retention
FROM private.public_intake_settings WHERE singleton = true;
COMMIT;
```

For intentional resumption, use the same transaction with `enabled = true` only after the checks above. Do not grant browser roles access to settings or to this operational control.

Retention cleanup runs opportunistically on intake/review and is also bounded for manual maintenance: `private.public_intake_cleanup()` expires at most 100 pending submissions and deletes at most 100 eligible rows from each expired receipt, old event, and retained-decision batch per call. The function is revoked from `PUBLIC`, `anon`, `authenticated`, and `service_role`; do not expose it via an RPC grant. A database owner/operator can run one call and inspect returned expiry count plus row deltas privately:

```sql
BEGIN;
SELECT private.public_intake_cleanup();
COMMIT;
```

Repeat only after reviewing the previous bounded result, until the approved retention backlog is clear. It erases expired pending drafts, deletes expired receipts only when the submission is no longer pending, removes old accepted-event counters after two days, and removes decision metadata at `retained_until`. It does not delete approved official records or photos. Verify queue, digest receipt, event counter and decision behavior against synthetic expired, rejected and approved fixtures before relying on retention. For an approved fixture, confirm that the submission payload is erased while its canonical official record remains; rejection/expiry must leave no official record. No scheduler exists or should be added for this release.

## Backup, restore, and migration rollback

Reuse [Supabase Free manual database and Storage backup](supabase-free.md#manual-database-and-storage-backup). P1 verified the pre-test archive and isolated PostgreSQL 17.11 restore rehearsal. P5 created a fresh post-acceptance full database archive over verified TLS; `pg_restore --list`, encrypted-copy decrypt/hash, and the protected external receipt all passed. Neither database archive contains Storage object bytes. Before a future hosted write, reconfirm exact project/ref and backup freshness; use the protected TLS URL and create a separate external run-owned manifest with before/after baselines, fixtures, reconciliation results and exact cleanup. Keep archives, object bytes, manifests with private IDs, credentials and personal data outside Git, `build/web`, logs and ordinary reports. The app's XLSX export is not a backend backup.

Never restore a database dump over the existing hosted database as a release rehearsal. Use an already available isolated native PostgreSQL target if available and document limitations if not; do not install Docker or start local Supabase for this handoff. Follow provider-specific restore guidance for managed Auth/Storage schema and roles; restore Storage bytes using Storage APIs, not direct `storage.objects` writes. Reconcile IDs/counts/checksums, policies/grants, auth, attachments, object metadata, and a real retrieval. Specifically reconcile submission, receipt, accepted-event and decision state with canonical official records: preserve legitimate pending drafts, ensure expired/rejected/approved payloads are erased as intended, and confirm an approved official record survives queue/decision retention cleanup. A verified archive is recovery preparation, not proof of successful restoration.

The hosted migration state is now `202610250001`–`004` applied in pre-production; the reviewed Edge function is deployed and synthetic browser checks plus exact cleanup/reconciliation passed. The prior R2/R3 blocked receipts are historical and superseded by the P1–P6 closeout. Recheck project, schema, migration/function state and a fresh protected backup before any future hosted write. The managed Edge client-address source and provider invocation-body retention remain unverified; do not claim per-network rate limiting or platform-body retention until those gates have evidence.

Rollback is an application/configuration response, not destructive schema reversal:

1. Pause new intake (`enabled = false`) and confirm the public function fails closed; preserve pending submissions and official records.
2. Keep all migrations and data. Do not drop tables, erase approved data, blindly reverse additive migrations, reset schemas, or restore the full backup over live writes.
3. If needed, restore the last compatible reviewed Flutter artifact and matching safe public config. Keep exact Auth/origin settings consistent with the restored app; turn off or restrict only the reviewed public function after confirming the effect on the live API.
4. Reconcile queue/decision/receipt state, official records and photo references; investigate partial failures from synthetic IDs only. Re-enable intake only after security and regression checks pass.

## Publication proposal and gates

| Item | Candidate / status |
|---|---|
| Source candidate | `e768261cfdf3bea538a6b9272190c9158bb24ad2` on `feat/public-web-intake`. The implementation/configuration match approved code candidate `588397c9c0bb7b1976c3c82694c43f7438d258d9`; the intervening commit changes acceptance evidence only. Supabase config was reviewed in `6e09ae6`. |
| Configured build and asset manifest | **PASS, not published**: Flutter 3.47.2 release build and `scripts/web_preflight.py build/web` passed with the protected public-defines file. External manifest `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\public-intake-release-candidate-20261026.json` records 42 asset hashes and the source commit. |
| Free static host / URL | Cloudflare Pages project `discipulado-ieadpe` exists, and Turnstile permits `discipulado-ieadpe.pages.dev`; **no Pages deployment exists**. No working public HTTPS URL or hosted browser smoke is claimed. |
| Pre-production migrations / Edge Function | **PASS, pre-production only**: migrations `202610250002`–`004` and the `public-intake` Edge Function were applied/deployed to project `voqmtnqjrbugpazcimvh`; service and policy behavior were exercised. This does not authorize production changes. |
| Pre-production browser journey, cleanup and reconciliation | **PASS**: synthetic anonymous submission passed Turnstile, entered the private queue, and was approved by an authorized reviewer; the official record and authorized photo path were verified. Exact synthetic rows/object were removed. Every application table count and recorded link-integrity check matches the P1 launch baseline; migration ledger is +3. |
| Fresh backup and recovery evidence | **PASS, database only**: protected PostgreSQL 17.11 Session Pooler TLS URI verified; new 801,059-byte custom archive passed `pg_restore --list` (817 output lines; header reports 808 TOC entries), SHA-256 `34b92f22c4bd5a75f6a5c572e507d681ecb3b777bf34cb8cf4a9ebc61a2abdc4`. AES-256-GCM copy decrypted and hash-matched using a DPAPI CurrentUser-wrapped key. Storage object bytes are not in the database archive. |
| Temporary local allowances | **Restored and verified**: only `discipulado-ieadpe.pages.dev` remains on the Turnstile widget; Edge origin/hostname secrets returned to their production-only values. Production-origin CORS preflight is HTTP 204 and localhost is HTTP 400. |
| Free-tier utilization | **OPEN**: capture current Supabase and Cloudflare usage privately before launch; no usage snapshot is claimed. |
| Remaining runtime/security gates | **OPEN**: no Pages HTTPS journey, fresh OAuth redirect, or mobile camera/gallery device smoke. Provider invocation-body visibility/retention remains unverified. Managed Edge client-address trust is unverified, so per-network hourly/daily limits are not claimed; the global cap and Turnstile fallback were checked. |
| Public release | **NOT AUTHORIZED / NOT PUBLISHED**: the configured candidate, hosted evidence, reconciliation and backup are prepared. Complete the open gates and present the release checklist for separate publication approval. |

Before any publication approval, deploy only after that approval, then run HTTPS direct-route/reload/assets/OAuth/Turnstile/anonymous submission/reviewer approval/security-denial/photo lifecycle checks against the exact host. Use exact synthetic cleanup and retain source-bound evidence. Test mobile Chrome and iOS Safari camera/gallery, cancel/denial/orientation/large-photo/enlargement where devices exist; unavailable devices stay INCOMPLETE. No Android APK/signing is required. Record observed Free usage and remaining limits. Keep the current Pages project undeployed until the separate publication decision.

## Remaining operator decisions and release work

Supabase and Cloudflare access, project/hostname, Turnstile configuration, pre-production migrations/function, synthetic tests, cleanup, reconciliation, TLS database access, fresh database archive, release build and static asset manifest are verified. No login/MFA or credential entry is currently needed. Before launch, still capture Supabase/Cloudflare Free usage, resolve managed Edge client-address trust or revise the per-network rate-limit claim, obtain a provider invocation-body visibility/retention decision, exercise a fresh OAuth redirect and available mobile-device flows, and complete HTTPS browser acceptance after separately approved deployment. The exact production site remains undeployed; do not publish, change production, add paid services, or alter account configuration under this checklist. Keep incomplete gates explicit until dated evidence exists.
