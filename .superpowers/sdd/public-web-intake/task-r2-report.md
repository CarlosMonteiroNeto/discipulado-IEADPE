# Task R2 — hosted verification prerequisites

Date: 2026-10-26
Branch: `feat/public-web-intake`
Baseline: `5f3b0f39e61e74c5835a03a7b44b3593e034e3a6`
Origin/main: `846a320619d3d8240df391a8b218c713bcceedc3`

## Scope and outcome

R2 updated only the acceptance evidence, progress ledger, and this report. Evidence listed below was captured and verified by the controller before this documentation task. No Supabase CLI call, backup file access, hosted action, Docker startup, migration/deployment/function change, browser test, or publication was performed in R2.

## Verified prerequisites

- **Project target:** Supabase CLI inventory identified the unique active `Discipulado IEADPE` project ref `voqmtnqjrbugpazcimvh`. The process `SUPABASE_URL` host parsed to `voqmtnqjrbugpazcimvh.supabase.co`. The R1 read-only inventory showed migrations `202610250002`–`004` pending and no deployed functions.
- **External backup:** Manifest validator passed for the exact project ref. The fresh full custom-format archive is 857,367 bytes, SHA-256 `56bbe069fb9568d07a193f4197d300bb0f85dd8eccc358f234ca04de3bd4f33b`; exact UTC backup timestamp is in the external manifest. The directory/files are owner-only. An AES-256-GCM encrypted copy (857,395 bytes, SHA-256 `db1bbbb64c63820412428ea6568c2164036db901ce8b84daa72e798ace7789f4`) uses a DPAPI CurrentUser-wrapped key outside Git; decrypt-and-hash matched the plaintext archive. No dump contents, key material, credential values, or PII are included in this repository.
- **Archive and recovery path:** `pg_restore --list` exited 0 and reported 1,011 TOC entries. Isolated local PostgreSQL 17.11 restore rehearsal succeeded, excluding only 10 `vault`/`supabase_vault` TOC entries unavailable in that local target. It verified 9 application schemas, 37 migration rows, 24 congregations, and 51 converts, then dropped the exact local database. This establishes a successful local recovery rehearsal, not hosted restore verification. Database/Storage dump does not contain Storage object bytes; no existing Storage object is a target of the planned rollback-only SQL smoke.
- **TLS:** Client-only PostgreSQL 17.11 tools with `PGSSLMODE=require` authenticated; `SELECT 1 AS safe_probe` returned `1`, and `pg_dump` completed. `PUBLIC_INTAKE_DATABASE_URL` remains absent from persistent process environment; the connection URL was held only in process environment and is not recorded.
- **Runner evidence location:** Reserved external path is `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\run-5655bd75-b699-47da-b3db-24d3e046e78a-evidence.json`. It remains absent until the runner writes its STARTED/baseline receipt. No synthetic fixture or hosted write has occurred.

## Remaining boundary

R2 establishes the backup, archive/recovery-path, TLS, and external evidence-path prerequisites. It does not authorize hosted execution. Exact target typed confirmation, runner STARTED/baseline receipt, exact run-owned cleanup authorization, and reviewed migration/function candidates remain required. T3's authoritative managed gateway address source, Turnstile hostname/server configuration, temporary synthetic reviewer identities/grants, hosted T2 limits/concurrency evidence, and hosted anonymous browser journey remain blocked. No hosted PASS is claimed.

## Focused verification

Documentation assertions checked the project ref and URL host match, pending migrations, backup checksum and manifest validation statement, restore rehearsal classification and counts, TLS probe, external reserved evidence path, no-fixtures/no-hosted-write boundary, and absence of a hosted PASS claim. `git diff --check` passed. No test suite or hosted command was run.
