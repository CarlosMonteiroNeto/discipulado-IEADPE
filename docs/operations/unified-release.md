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
