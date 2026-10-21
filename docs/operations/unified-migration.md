# Unified IEADPE Data Migration

<!-- canonical-document-authority -->
> **Supporting technical reference.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. Reuse procedures/contracts only through the corresponding current task and its reviewed interface, prerequisites and authorization. Counts, completed operations and old environment statements retain their original observation date.

Status: Base44 records and 30 authorized access grants are active in hosted Supabase. Migration `202610180002_base44_archive_weekly_consistency.sql` is applied. It reconciled 39 weekly guard rows for 50 active converts; verification now reports zero missing and zero stale counters. Firebase ministry records, production cutover, and deleting either source remain separate operations.

## Base44 export contract

The source is the read-only Base44 app `IEADPE Novos Convertidos`. The complete JSON export uses format `ieadpe-converts-full-backup`, version 1, and includes the six entities `Congregation`, `Convert`, `ConvertEvent`, `WeeklyReport`, `UserAccess`, and `Feedback`. Do not commit the real export or include record values in output or logs.

The current export contains 24 congregations, 50 converts, 13 events, 10 weekly reports, 30 access records, and 0 feedback rows. Eight event references point to converts absent from the export. Import them as congregation-scoped historical events with `convert_id = NULL`, retaining the Base44 convert ID and event name; do not create a synthetic person or match by name. Import normalization trimmed outer ASCII spaces from 27 names and 21 landmarks; no internal content was changed. The generator archives full Feedback JSON in a private table if an export includes any, because the legacy field contract has not been established. The current private archive count is 0.

## Local preparation

Run `python scripts/build_base44_import_sql.py --input <private-export.json> --output <private-import.sql> --dry-run`. The builder validates the export and emits only counts and the destination filename to stdout. Keep the generated SQL next to the export in a private temporary location; it embeds personal data. It ends with `ROLLBACK` and is intended for an initial execution in the Supabase dashboard SQL Editor.

Migrations `202610180001_base44_history.sql` and `202610180002_base44_archive_weekly_consistency.sql` must be applied before a generated import. They preserve source keys, allow safely scoped orphan history, create private access review/source-metadata/Feedback archive tables, add the import digest ledger, reconcile weekly guard counts, and make weekly reads check canonical converts directly. The full Feedback record is retained only in the private archive.

## Hosted execution and reconciliation

1. Confirm the six destination table counts are zero or reconcile any rows created since the read-only baseline.
2. Apply the additive migration once through Supabase SQL Editor and inspect its result.
3. Open the generated SQL and run the dry-run version. It must finish without an error and report reconciliation success; its final statement is `ROLLBACK`.
4. Generate the same SQL without `--dry-run`, verify only the final statement differs (`COMMIT`), and run it once. The transaction is atomic, uses deterministic target UUIDs, and records a SHA-256 export digest. Rerunning the exact export is a no-op; a changed export that conflicts with imported keys fails closed.
5. Verify only counts and relationships: 24 congregations, 50 converts, 13 events (5 linked, 8 legacy orphans), 10 weekly reports, 30 rows in `private.base44_user_access_pending`, 0 archived Feedback rows for this export, and 30 active access grants matching the pending records (28 congregation-scoped direction grants and 2 global supervision grants). Hosted reconciliation returned these counts and one import receipt; Base44 source keys and foreign keys passed the transaction assertions. One grant is bound to a confirmed Auth user; the other 29 remain email-bound and will link on confirmed sign-in.
6. After access activation, the local app's Admin page displayed the imported congregations. The grants were created with the exact role and congregation mapping in the Base44 export; no broader access was added. Continue using the database RLS test when validating future policy changes.
7. The private generated SQL and local bridge directory were removed after import and count reconciliation. Keep the original downloaded export in the user's private Downloads folder until backup/restore and app-level reconciliation are complete.
8. Weekly counter review found 39 missing guard rows across 39 weeks and no stale rows, covering all 50 active converts. Migration `202610180002_base44_archive_weekly_consistency.sql` backfilled those counters and updated weekly overview to use active converts as the read-time source of truth. Post-migration verification returned 0 missing guards, 0 stale guards, 39 convert weeks, and 50 active converts. SQL regression checks passed inside a rolled-back transaction.

## Access records and rollback

The 30 exported `UserAccess` rows remain in the non-API-exposed `private.base44_user_access_pending` table as a private source record. By the user's explicit instruction, the same email/role/congregation assignments were activated in `public.user_access`; no Auth accounts were created. One row is bound to an existing confirmed Auth user. The other 29 keep `user_id = NULL` and bind automatically after that email completes confirmed sign-in through `ieadpe_get_scope`.

Base44 remains unchanged and authoritative while the new app is observed. Before commit, `ROLLBACK` removes all import effects. After commit, keep Base44 authoritative and stop new target writes if reconciliation fails. Remove only rows bearing the recorded digest's Base44 source keys, after checking dependent references; never clear whole tables or match by personal name. Preserve the original export and source app until restoration is rehearsed.

## Corrective release preparation (T12)

The inspector is not to be run during this local-only preparation. A later authorized read-only inspection must provide `--project-ref`, the exact `--endpoint db.<project-ref>.supabase.co`, managed `--service`, a reviewed `--contracts <complete-versioned-contract.json>`, and `--output <private-report.json>`. It rejects an unbound endpoint and validates all 16 ordered migration contracts before DNS or psql. The connection explicitly pins host, resolved host address, port, database, and TLS hostname verification; inherited libpq `PG*` settings are removed. Queries run in a read-only transaction and inspect catalog fingerprints and aggregate invariants only; no scope RPC or personal rows are queried. Keep output private. Unknown or partial evidence blocks any repair proposal.

Use `scripts/rehearse_hosted_upgrade.py --plan-only --output <review-package.json>` to prepare the exact sequence and digests. For a local database rehearsal, provide `--database-url` only for a loopback PostgreSQL endpoint; the tool delegates execution to `scripts/test_database.py`, which owns and drops its disposable database. It rejects remote targets before connecting. The generated ledger repair proposal is for review only. This preparation does not authorize hosted migration or ledger writes.

Historical pre-execution status: when this paragraph was first written, T12-006 SQL rehearsal and the 17-checkpoint bundle were `BLOCKED_NOT_RUN`. See the dated T12-006 local rehearsal closing addendum below for the completed local evidence. The retained correction-6 SQL/snapshot evidence remains historical and covers only the 15-migration chain through 005; it is not relabeled as covering 006.

## T12-006 local rehearsal closing addendum — 2026-10-21

**Local result: PASS / APPROVED_LOCAL; harness exit 0.** The disposable local rehearsal applied the exact ordered 16 forward migrations `202610180003`, `202610190001`–`202610190009`, and `202610200001`–`202610200006`. It captured and classified 17 real catalog checkpoints: the `202610180002` baseline plus one checkpoint for each migration prefix. The report's `semantic_snapshot_count=16` counts migration-version checkpoints only; with the separate baseline there are 17 total.

The reviewed evidence covers exact local upgrade, prefix classification, partial resume, deliberate catalog-drift stop/rollback, the Base44 equivalence proposal (proposal only, no ledger repair), and the corrected attendance-preview no-DML/first-save assertions. The snapshot-derived semantic manifest and candidate were independently reviewed. This is local rehearsal evidence, not hosted-state evidence.

Evidence: [final rehearsal report](../../build/verification/corrective-release/T12/continuation-006/final-rehearsal-report.json), [raw harness output](../../build/verification/corrective-release/T12/continuation-006/final-harness-output.log), [17-checkpoint snapshots](../../build/verification/corrective-release/T12/semantic-snapshots.json), [derived semantic manifest](../../build/verification/corrective-release/T12/semantic-manifest.json), and [Sol review](../../build/verification/corrective-release/T12/continuation-006/sol-final-review.md). The current activation package carries the SHA-256 identities for these artifacts and the migration chain.

Hosted inventory/parity/application and ledger repair were not performed or approved; no hosted migration occurred. Base44 ledger reconciliation remains a proposal only. H1 still requires an exact fresh target inventory, verified backup and isolated restore, and an approved cutover package. Original Firebase export or verified absence, source reconciliation, device/signing/installed APK/download evidence remain pending. T11's live browser/Auth/Storage/cleanup/sentinel journey and L0's assembled current stable gates remain separate and open. Overall release status is unchanged.
