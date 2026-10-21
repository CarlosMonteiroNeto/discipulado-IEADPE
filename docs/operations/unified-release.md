# Unified Discipulado Release Readiness

Status: preparation only. No hosted project, static site, user account, signing key, or production data has been provisioned or changed. This runbook is not a deployment authorization.

## Release gates

1. Run `scripts/verify_unified.ps1` on Windows or `scripts/verify_unified.sh` on macOS/Linux against local Supabase/PostgreSQL and retain `build/verification/unified-report.md` plus its command log. Any `FAIL`, `BLOCKED`, or `INCOMPLETE` result prevents release approval.
2. Review all migrations and function/table grants. Provision only verified Auth UIDs and least-privilege campaign/ministry grants through the trusted operator flow. Confirm campaign-only and ministry-only identities remain separate.
3. Configure Google OAuth PKCE with exact production callbacks and HTTPS. Verify login, cancel, logout, identity switch, grant revocation, and direct refresh for each allowed route. Test Storage upload/read denial and allowed photo retrieval through HTTP using synthetic accounts and objects.
4. Build the web artifact with public Supabase URL/publishable key only. Inspect the artifact for secrets and private fixtures; run `scripts/web_preflight.py build/web`. On the approved static host, verify direct-route refresh, callback query handling, JavaScript/WASM/image MIME, logout cleanup, TLS, and account/IAM restrictions.
5. For Android, use an operator-generated release keystore kept outside the repository. Build a signed APK/AAB, verify its certificate with `apksigner`, install/update on supported devices, and test OAuth callback, lifecycle resume, logout/revocation, keyboard, large text, reduced motion, and photo picker recovery.
6. Before migration or cutover, retain both legacy sources read-only, prepare checksummed exports under separate authorization, rehearse an encrypted database and Storage backup restore on an isolated target, and reconcile congregation, contacts, students, classes, enrollments, sessions, attendance, converts, links, and terminal states. Resolve every ambiguous match through a recorded human decision. Do not merge by name.
7. Recheck current Supabase and static-host limits, estimate expected Auth MAU/database/storage/egress, set monitoring and incident contacts, and document pause/outage behavior. An application XLSX export is not a database or Storage backup.

## Rollback conditions

Stop cutover if authorization denials, row/link reconciliation, historical state counts, restore verification, hosted route refresh, OAuth, Storage, or signed-device checks fail. Keep the old systems authoritative and retained. Stop new writes to the target, restore only into an isolated target from a verified backup, reconcile again, and retry only after the failed cause is understood. Never delete or rewrite source history as a rollback shortcut.

## Evidence record

Attach dated reports, tool/browser/device versions, migration hashes, host URL, callback results, backup/restore checksums, reconciliation totals, and reviewer disposition to the release record. Mark checks individually `PASS`, `FAIL`, `BLOCKED`, or `INCOMPLETE`; do not infer one check from another. The current unified matrix and generated gate report identify the local checks. Hosted OAuth/Storage enforcement, hosted deep links, Firefox/WebKit smoke, Android signing/device behavior, production backup restore, capacity headroom, and real data cutover remain release-only checks until executed by an authorized operator.

## Corrective activation package

The current review package is `docs/verification/ministry-corrective-activation-package.md`. It records target identity, source revision, ordered migration digests, backup/restore evidence needed, compatibility controls, rollback stops, and independent Firebase/APK blockers. It is preparation evidence only: the T12 tools perform no hosted inventory call by default and execute no hosted write or ledger repair. The earlier statement that the T12-006 rehearsal and checkpoints were still blocked is historical pre-execution status; see the dated local rehearsal closing addendum below. Overall hosted activation remains unapproved. Rebuild the package from the current checkout before any later authorized activation review.

## T12-006 local rehearsal closing addendum — 2026-10-21

**Local result: PASS / APPROVED_LOCAL; harness exit 0.** The exact forward sequence was 16 migrations: `202610180003`, `202610190001`–`202610190009`, then `202610200001`–`202610200006`. The rehearsal produced 17 real catalog checkpoints (the `202610180002` baseline plus all 16 prefixes); `semantic_snapshot_count=16` in the report counts prefixes and excludes the baseline. The independently reviewed snapshot-derived manifest and candidate are linked from the [activation package](../verification/ministry-corrective-activation-package.md).

The local proof includes ordered upgrade, prefix classification, partial resume, deliberate drift stop/rollback, Base44 equivalence proposal only, and corrected preview no-DML/first-save assertions. See the [final report](../../build/verification/corrective-release/T12/continuation-006/final-rehearsal-report.json), [raw harness output](../../build/verification/corrective-release/T12/continuation-006/final-harness-output.log), [snapshots](../../build/verification/corrective-release/T12/semantic-snapshots.json), [semantic manifest](../../build/verification/corrective-release/T12/semantic-manifest.json), and [Sol review](../../build/verification/corrective-release/T12/continuation-006/sol-final-review.md). These local artifacts do not prove hosted state.

Hosted inventory/parity/application and ledger repair were not performed or approved; no hosted migration occurred. Base44 ledger reconciliation remains a proposal only. H1 exact inventory, backup/isolated restore and approved cutover package remain required. Firebase source/export verification, source reconciliation, device/signing/installed APK/download, T11 live browser/Auth/Storage/cleanup/sentinel, and L0 assembled stable gates remain open. This addendum does not change the overall preparation-only status or authorize release actions.
