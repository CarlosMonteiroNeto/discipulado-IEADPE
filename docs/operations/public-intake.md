# Public Web intake operations and release handoff

> Superseding user decision (2026-10-26): the hosted project is pre-production. The Spec's latest decision and plan P1–P6 override this runbook's older per-row-only cleanup/no-data-restore restrictions. Verified recoverable backup first, authorized application-data changes and online tests next, then restore/reconcile intended launch data into the final migrated schema. Operator access/configuration failures remain technical blockers. Public publication is separate; stricter production controls begin at the transition to real use.

Date: 2026-10-25

Source: approved [public Web intake Spec](../superpowers/specs/2026-10-25-public-web-intake-design.md) and [implementation plan](../superpowers/plans/2026-10-25-public-web-intake-plan.md). These govern this increment; this runbook records the current candidate and operator steps. Historical release documents do not establish that any hosting account or production setting exists.

## Current pre-production status (2026-10-26)

This status supersedes the historical `BLOCKED` inventory and candidate statements below where they conflict. The user authorized controlled testing on pre-production project `voqmtnqjrbugpazcimvh`; public publication remains separate and has not occurred.

- Applied migrations `202610250002`–`004` once and deployed the reviewed `public-intake` Edge Function. The anonymous path was exercised with the real Turnstile site configuration; production origin preflight passes. The managed Edge client-address source remains unverified, so only Turnstile plus the global pending-capacity limit are active; per-network hourly/daily protection remains incomplete.
- Cloudflare account access and the `Public Intake Preproduction` Turnstile widget are verified. Its only allowed hostname is restored to `discipulado-ieadpe.pages.dev`. The Supabase Edge origin/hostname secrets are restored to the protected production-only allowlist after localhost testing.
- The authenticated local Flutter Web session completed anonymous submission, authorized review/approval, canonical convert listing, and authorized gallery photo crop/save. Anonymous Storage upload/download were denied; anonymous listing revealed no protected fixture. The synthetic rows, receipts, weekly guard and JPEG object were cleaned exactly.
- Post-cleanup Management API reconciliation matches every application-table row count and link-integrity value in the preserved P1 manifest. Counts include 51 converts, 51 ministry people, 15 convert events, 8 mutation receipts, 1 Auth user, no photo assets or Storage objects, 24 active congregations, and empty public-intake tables. The only intended count delta is the migration ledger (+3). The restored application data therefore needs no wholesale reimport; existing application rows were preserved.
- The pre-test external full backup remains the verified recovery point. A fresh post-acceptance full dump is still required for P5/P6; `operator-db-url.txt` currently does not contain a valid PostgreSQL URI. Supabase CLI Management API authentication is effective for queries and hosted test operations. Request the full TLS Direct or Session Pooler URI through the protected file only; do not place it in logs or Git.
- Publication remains **NOT AUTHORIZED**. The Cloudflare Pages project `discipulado-ieadpe` exists but has no deployment. Before asking for publication approval, prepare a source-matched release build/manifest, final independent review, fresh backup, current free-tier usage, rollback checklist, and remaining runtime limitations. No Pages deployment/publication occurred.

The protected external evidence directory contains run receipts, baseline comparisons, and exact cleanup records. No secret or synthetic record identifiers belong in this runbook. Device-native camera testing, fresh OAuth redirect flow, hosted HTTPS Pages checks, and authoritative managed Edge address verification remain incomplete.

## Readiness decision

**Status: BLOCKED for hosted activation and publication.** Local implementation and T8 acceptance evidence do not prove hosted behavior. No hosted write, migration/function deployment, Turnstile configuration, account change, publication, or paid-service action was performed for this handoff.

The current read-only evidence says migrations `202610250002` through `202610250004` are pending and the hosted functions list is empty. R2 verified a fresh external full-backup archive/manifest, checksum, local restore rehearsal, and TLS identity probe. R3's external runner receipt is BLOCKED because the CLI-generated database login cannot read the application baseline schema; no hosted scenario or write ran. A database URL/role with the required read and scenario privileges is not configured persistently. Turnstile's production hostname/configuration is unverified, and no authoritative managed Edge client-address source is proven. The current local candidate uses the approved global-only fallback: Turnstile and global pending capacity remain enforced, while the per-network hourly/daily limiter is incomplete. No temporary synthetic reviewer identities/grants exist. Hosted acceptance remains **BLOCKED/INCOMPLETE**; do not describe intake as live or ready to publish. See [acceptance evidence](../verification/public-intake-acceptance.md), which contains current and historical receipts.

### Service and deployment inventory

| Service | Candidate use | Inventory and ownership |
|---|---|---|
| Static web host | Flutter Web files, exact route fallback, HTTPS | Repository contains `web/_redirects`; older release guidance proposes Cloudflare Pages Free. No provider account, project/site name, verified domain, production URL, or deployment evidence was found. **Host identity and hostname are unverified; host identity is unverified.** Inspect existing provider accounts before creating anything. |
| Supabase | Postgres, Auth, private Storage, `public-intake` Edge Function | Local config identifies project slug `ieadpe-converts`; this does not prove the hosted project/ref or its current state. Hosted evidence records the new migrations pending and no functions deployed. |
| Cloudflare Turnstile | Browser challenge and server-side Siteverify | New Free configuration is required. No production site key/secret, allowed hostname, or successful hosted verification is evidenced. |
| VM / custom infrastructure | None | No VM, load balancer, custom API server, scheduler, R2, or IaC platform is part of this design. No billing should be enabled automatically. |

The static web host serves public files only. Supabase owns database/Auth/private object service and Edge runtime. Turnstile verifies browser challenges; it does not replace server-side authorization or network abuse controls. Public intake persists no photo. Approved photos continue through the existing authenticated private Storage path.

### Shared responsibilities and limits

Providers operate and patch their infrastructure and platform services, and provide platform HTTPS/at-rest protections under their current plan terms. The developer/operator owns application and dependency patching, grants and RLS, precise origins/callbacks, server secrets, private-bucket policy, least-privilege account access, account recovery, reviewed migration/function/static releases, quota monitoring, off-site backups, restore readiness and incident response. Require HTTPS for the public site and Supabase URL; use private Storage and provider at-rest encryption. Do not put service credentials in Flutter defines, `build/web`, source control, CI output or public issue/report attachments.

Supabase Free is a constrained tier, not an SLA: the reviewed pricing page lists 500 MB database, 1 GB Storage, 50,000 MAU, 5 GB uncached egress, separate 5 GB cached egress and two active projects. Free projects can pause after seven days without activity; the cited policy permits manual restoration up to one year after pause. Neither pause retention nor a successful manual resume is a backup or restore guarantee. Check current dashboard usage and current provider limits before release and at least weekly after launch. Function invocation quota is consumed before in-function rate limiting, so the network/global queue limits do not prevent function-quota exhaustion. Do not enable billing, PITR, paid transformations, or fake keepalive traffic. Exhaustion or pause may interrupt service; preserve retryable form data and use the provider dashboard's supported resume/recovery process. See [Supabase Free backup and pause procedures](supabase-free.md) and official [pricing](https://supabase.com/pricing), [billing limits](https://supabase.com/docs/guides/platform/billing-on-supabase), [pause policy](https://supabase.com/docs/guides/platform/free-project-pausing), [database backups](https://supabase.com/docs/guides/platform/backups), [production guidance](https://supabase.com/docs/guides/deployment/going-into-prod), [Storage pricing](https://supabase.com/docs/guides/storage/pricing), [Storage bandwidth](https://supabase.com/docs/guides/storage/serving/bandwidth), and [Turnstile plans](https://developers.cloudflare.com/turnstile/plans/). Recheck official limits at the time of any release.

Do not promise a free SLA, geographic disaster recovery, automatic failover, or a verified point-in-time restore. A database dump excludes Storage object bytes; see the separate Storage backup/reconciliation procedure below and in [Supabase Free operations](supabase-free.md).

## Versioned candidate and public configuration

### Candidate inventory

T8's local code/test candidate is commit `023b28acf1bdb86c87cdabb6f688ae16aa9f17f3` (`test: verify public intake and approval boundaries`). T9 starts from `c4330f464f1184919359f1599d7d6ff3b1158941`, which adds later T8 readiness/hosted-blocker evidence. The versioned application changes include additive migrations `202610250002_public_registration_authority.sql`, `202610250003_public_intake.sql`, `202610250004_pending_review.sql`, the `supabase/functions/public-intake/` source, and the single local `supabase/config.toml` override `[functions.public-intake] verify_jwt = false`. These have local evidence only. They have **not** been applied/deployed to the hosted project and are not a hosted-tested candidate. `202610250001_storage_content_length_policy.sql` is reported as already applied in the read-only snapshot.

`verify_jwt = false` applies only to the intentionally public `public-intake` function. All other function/API defaults stay protected. The function checks exact HTTPS origin/hostname, Turnstile server-side response/action, strict payload shape and size, then uses a service-role RPC. If no trusted address resolves, it sends explicit `network_hash: null`, never derives an address from caller headers, and skips HMAC. The RPC skips per-network hourly/daily checks for null hashes but always takes the global-capacity lock and enforces the pending cap. Thus the per-network limiter is incomplete until provider trust is proven. Do not substitute arbitrary `X-Forwarded-For`, `CF-Connecting-IP`, or `X-Real-IP`. Server-side RPC grants remain narrow; no anonymous access to official records, private queue tables, private Storage, or the receive RPC is allowed.

### Exact origin and callback inputs

There is no evidenced production hostname. Treat `<verified-hostname>` below as a placeholder, not a permitted or tested value. After inspecting the existing host and securing its DNS/account, choose one exact HTTPS origin and use that same value consistently:

- Static origin and Turnstile hostname: `https://<verified-hostname>` and `<verified-hostname>`.
- Supabase Auth Site URL: `https://<verified-hostname>`.
- Supabase Auth redirect allowlist: `https://<verified-hostname>/auth/callback` plus the exact callback query variants for `/register`, `/home`, `/converts`, and `/admin`: `?next=%2Fregister`, `?next=%2Fhome`, `?next=%2Fconverts`, `?next=%2Fadmin`. Do not add a wildcard. Keep local-only callback examples confined to local development.
- Edge Function `INTAKE_ALLOWED_ORIGINS`: the exact canonical origin `https://<verified-hostname>`; `INTAKE_ALLOWED_HOSTNAMES`: the exact hostname without scheme/port. No wildcard or caller-derived origin. Add localhost origins only in a separately configured local development environment.

The application reads these **public** Flutter build defines:

| Define | Value |
|---|---|
| `SUPABASE_URL` | Verified HTTPS URL for the intended Supabase project. |
| `SUPABASE_PUBLISHABLE_KEY` | That project's publishable/anon client key; public by design, still subject to server grants/RLS. |
| `AUTH_CALLBACK_URL` | `https://<verified-hostname>/auth/callback` using the exact chosen origin. |
| `TURNSTILE_SITE_KEY` | Public site key registered for the exact chosen hostname. |

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

### Controlled activation sequence

1. Independently identify the existing static host, Supabase project/ref and operator accounts. Confirm account recovery/MFA and least-privilege access; no evidence in this checkout establishes a production hostname or exact project ref. Stop if either identity is ambiguous.
2. Complete hosted write prerequisites below and review the exact coordinated application/migration/function candidate. Public publication still requires a separate explicit authorization after the candidate is reviewed.
3. Create the Turnstile site configuration for the verified exact hostname and server secret. Record key IDs and config revision, never key/secret values. Verify the provider invocation logging/body retention decision.
4. Prepare and coordinate the additive migrations in dependency order (`202610250002`, `202610250003`, `202610250004`) and function config/source. Hosted checks remain blocked until a reviewed operator candidate is ready. Do not replay all migrations or deploy an intermediate authorization that breaks existing registration. The approved fallback permits controlled testing with global capacity and Turnstile while per-network limits remain incomplete.
5. Configure the private function values through the provider's secret interface. Deploy the reviewed function/config as part of the coordinated controlled candidate. Confirm only `public-intake` has `verify_jwt = false`; verify server grants and unauthorized direct-call/photo-upload denials. Do not configure any caller-supplied header as a trusted client address. If the managed Edge source remains unverified, record per-network hourly/daily protection as incomplete.
6. Configure exact Auth Site URL/redirect values and allowed function origin/hostname. Rebuild Web with the four public defines and run the named local artifact route/preflight checks. Inspect the artifact before any separately authorized upload.
7. Observe hosted free-tier usage, migration ledger, function health and retention behavior during controlled synthetic checks. Reconcile the external run manifest and exact cleanup before concluding; keep every unavailable gate BLOCKED/INCOMPLETE.

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

Reuse [Supabase Free manual database and Storage backup](supabase-free.md#manual-database-and-storage-backup). R2 verified a fresh external full database backup and manifest, checksum/readability, TLS identity probe, and an isolated PostgreSQL 17.11 restore rehearsal; this is not a hosted restore or write. Before any future hosted scenario or migration application, reconfirm the exact project/ref and backup freshness, use a TLS database URL for a role with baseline/scenario privileges, and create a separate external run-owned evidence manifest with before/after baselines, every synthetic fixture/identity/receipt ID, reconciliation results and exact guarded cleanup. Keep archives, object bytes, manifests with private IDs, credentials and personal data outside Git, `build/web`, logs and ordinary reports. The app's XLSX export is not a backend backup. Database dumps exclude Storage object bytes; separately inventory and back up objects a test might touch.

Never restore a database dump over the existing hosted database as a release rehearsal. Use an already available isolated native PostgreSQL target if available and document limitations if not; do not install Docker or start local Supabase for this handoff. Follow provider-specific restore guidance for managed Auth/Storage schema and roles; restore Storage bytes using Storage APIs, not direct `storage.objects` writes. Reconcile IDs/counts/checksums, policies/grants, auth, attachments, object metadata, and a real retrieval. Specifically reconcile submission, receipt, accepted-event and decision state with canonical official records: preserve legitimate pending drafts, ensure expired/rejected/approved payloads are erased as intended, and confirm an approved official record survives queue/decision retention cleanup. A verified archive is recovery preparation, not proof of successful restoration.

Test versioned migrations and cleanup with the approved backed-up synthetic hosted runner and rollback-only or exact run-owned cleanup as specified in the plan. Current hosted migration state (`202610250001` applied; `202610250002`–`004` pending) is read-only evidence, not approval or a request to apply them. R2's backup/manifest and TLS identity probe are complete; R3 stopped before scenario SQL because the CLI-generated login lacks baseline schema access. Configure a protected TLS `PUBLIC_INTAKE_DATABASE_URL` for a role with the needed app-schema reads and reviewed scenario privileges before hosted testing. T2 shared-table capacity/concurrency cases also remain incomplete because the existing helper is unsafe for hosted shared state. Do not claim hosted retention verification.

Rollback is an application/configuration response, not destructive schema reversal:

1. Pause new intake (`enabled = false`) and confirm the public function fails closed; preserve pending submissions and official records.
2. Keep all migrations and data. Do not drop tables, erase approved data, blindly reverse additive migrations, reset schemas, or restore the full backup over live writes.
3. If needed, restore the last compatible reviewed Flutter artifact and matching safe public config. Keep exact Auth/origin settings consistent with the restored app; turn off or restrict only the reviewed public function after confirming the effect on the live API.
4. Reconcile queue/decision/receipt state, official records and photo references; investigate partial failures from synthetic IDs only. Re-enable intake only after security and regression checks pass.

## Publication proposal and gates

| Item | Candidate / status |
|---|---|
| Source candidate | Current implementation candidate `f0c960d87b75662ccbb3581311815290a6a160a2` on `feat/public-web-intake`; R7 reconciles evidence only. The T8 review/fix-round is recorded complete for its historical candidate; the current source still has no whole-branch release review or source-matched public artifact. |
| Reviewed build/asset manifest | **BLOCKED**: no source-matched public-intake artifact manifest exists. `docs/verification/2026-10-25-web-completion-candidate.json` names the separate `codex/ministry-production-completion` worktree/commit and does not describe this branch's public-intake source. Do not reuse it as this candidate's manifest. A configured release build/hash and final whole-branch review must be produced after hosted prerequisites are met. |
| Free static host / URL | **BLOCKED**: repository describes Cloudflare Pages as a proposal/convention only. Existing host, account/site, exact hostname and HTTPS URL are unverified; do not create or publish a site from this proposal. |
| Migrations / Edge Function | **BLOCKED**: locally versioned migrations and function/config are not hosted-applied/deployed or hosted-tested. Migrations `202610250002`–`004` are pending in the read-only evidence; no hosted functions are deployed. |
| Local implementation evidence | **PASS, scoped:** R1 freshly ran the public-intake, pending-review and registration-authority SQL scenarios on local PostgreSQL 17.11 at candidate `bed4cbe2887b38db98d13e109b8cd033707ee3ae`; R3 changed only the hosted runner after that SQL candidate. T8's 645/645 Flutter suite, 18/18 Deno tests and route/artifact checks remain historical results for their recorded revision. No hosted migration/function behavior is inferred from local checks. |
| Turnstile / callback / origins | **BLOCKED**: production hostname, Siteverify secret, allowed origin/callback and invocation-body retention decision are unverified. |
| Hosted synthetic journey / rollback | **BLOCKED/INCOMPLETE**: R2 backup/manifest and TLS identity probe are verified, but the current CLI role cannot read the required baseline schema. Trusted address remains unverified; temporary synthetic reviewers/grants are absent; T2 limit/concurrency hosted checks are incomplete. No hosted rollback or scenario ran. |
| Synthetic cleanup | **Not exercised on hosted data**: the reviewed hosted runner is designed for run-namespaced rollback fixtures and external before/after reconciliation; no hosted fixture IDs exist for this candidate. T2 shared-table limit/concurrency helpers remain excluded. |
| Free-tier utilization | **UNVERIFIED**: no current dashboard utilization snapshot was captured for this handoff. Record current database, Storage, egress, MAU, project and function usage privately before launch. |
| Public release | **NOT AUTHORIZED by this runbook**: after blockers close, present reviewed build hash/URL, completed hosted evidence, cleanup/reconciliation, quota observation and rollback plan for separate publication authorization. |

Before any publication authorization, run actual HTTPS direct-route/reload/assets/OAuth/Turnstile/anonymous submission/reviewer approval/security-denial/photo lifecycle checks against the verified host. Use exact synthetic cleanup and retain source-bound evidence. Test mobile Chrome and iOS Safari camera/gallery, cancel/denial/orientation/large-photo/enlargement where devices exist; unavailable devices stay INCOMPLETE. No Android APK/signing is required. Record observed Free usage and remaining limits; no successful URL or hosted end-to-end check is claimed here.

## Operator dependencies before resumption

An operator must supply, through protected configuration rather than this repository: a confirmed Supabase project/ref; a TLS database URL/role with required baseline and scenario privileges; verified static host account/site and chosen HTTPS hostname; recovered provider account access/MFA; Turnstile site/secret for that hostname; exact Auth redirect configuration; trusted managed-function client-address evidence or supported verified gateway configuration if per-network protection is to be enabled; provider log retention/redaction/access decision; temporary synthetic reviewer identities/grants and exact cleanup authorization; and a reviewed coordinated migration/function/app candidate. Applying additive migrations or deploying a function requires the separately authorized coordinated activation decision; site publication also remains separately authorized. Until then keep each affected gate **BLOCKED** or **INCOMPLETE**, not PASS.
