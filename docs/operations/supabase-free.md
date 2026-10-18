# Supabase Free operations

Verified against official documentation on **2026-10-16**. Recheck before release; quotas can change. Preparation makes no remote resources, grants, private exports, billing changes or scheduled keepalive requests.

## Capacity and interruptions

[Supabase pricing](https://supabase.com/pricing) lists Free limits of 500 MB database, 1 GB Storage, 50,000 monthly active users, 5 GB uncached egress and a separate 5 GB cached egress allowance, with two active projects. Check dashboard usage weekly and before imports/releases. Budget photos, report downloads and backups as traffic; private downloads should not be assumed cached. Use existing 100-row traversal and bounded photos. Reduce retained unused assets and workload before limits; stop/reassess release if it cannot fit Free. Do not activate billing, image transformations, PITR, paid add-ons or mandatory Edge Functions.

Free projects may pause after one week of inactivity. The app must show a recoverable unavailable/retry state. An operator opens Dashboard, selects the paused project, chooses Resume project and waits for healthy status before retrying login/reads. The current [pausing policy](https://supabase.com/docs/guides/platform/free-project-pausing) allows manual restoration for up to **one year after pause**. Do not rely on pause retention as a backup or install fake traffic/cron to avoid it. Beyond the restore window, use separately retained exports and operator-approved recovery; successful recovery is not guaranteed without a tested backup.

## Manual database and Storage backup

The application's XLSX is a portable business export: it omits binary photos, authentication, policies, grants, functions and other backend state. It is **not** a full backend backup. Free has no included managed daily backup/PITR. Official [database backup guidance](https://supabase.com/docs/guides/platform/backups) recommends regular off-site CLI dumps and explicitly says database backups do not contain Storage bytes.

For a separately authorized operator backup:

1. Choose an access-controlled encrypted destination outside this repository and web build. Set a maintenance window to stop writes/photo cleanup so DB metadata and downloaded bytes share a consistent point. Record time, migration revision, project identity and tool versions in a private inventory. Never put private rows, paths, credentials or dumps in CI/report logs.
2. Use the current Supabase CLI dump/restore procedure, with connection/password supplied via the operator's secret manager or a protected PostgreSQL service/password file rather than shell history. For a linked, independently confirmed target: `supabase db dump --linked --role-only -f <private-directory>/roles.sql`, `supabase db dump --linked -f <private-directory>/schema.sql`, and `supabase db dump --linked --data-only --use-copy -f <private-directory>/data.sql`. Placeholders must be replaced privately. The CLI can require Docker; this host has no Docker, so those commands were not run. Use a compatible operator host or reviewed native pg_dump procedure. Check exit statuses and nonempty dumps; inspect the dump schema selection privately, including required application, auth and Storage metadata. A default dump is not evidence that managed schemas or all roles were captured.
3. Separately inventory every bucket (including private `convert-photos`), paginate object listings, and download each object through authenticated Storage API/operator dashboard access, preserving bucket/path, content type and checksum in the private inventory. Use no public/signed URLs in logs. Preserve private bucket configuration and policies. Count and hash every downloaded object; retry failures without calling a partial archive complete. Database `storage.objects` rows contain metadata, not file bytes.
4. Encrypt the combined DB/config/inventory/Storage archive, retain at least two independent copies under least access, and record retention/deletion dates. Keep Google secrets/signing keys in a separate managed recovery store. A dump can contain sensitive records and auth material even if role passwords are omitted.
5. Rehearse recovery on an isolated, operator-approved nonproduction target before depending on it: follow current Supabase restore guidance for roles/schema/data and managed auth/storage schemas, apply matching migrations, restore object bytes using Storage API (never direct SQL insertion/deletion of `storage.objects`), reconcile metadata/paths and verify counts/checksums, RLS, identities, attachments, login and a real photo retrieval. Do not blindly restore managed ownership/roles or duplicate Storage metadata. Reconfigure provider secrets/redirects separately. Record failures and elapsed recovery time privately. Existing synthetic SQL/HTTP fixtures do not establish that a real backup restores.

## Explicit photo maintenance

Supply `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` only in the operator process environment from a secret store; confirm the intended project independently before running. Never use the service key in Flutter, public CI artifacts or checked-in files. Empty/missing settings fail before network activity; there is no default production URL.

```powershell
pwsh -NoProfile -File scripts/maintenance_photos.ps1          # dry-run IDs/count
pwsh -NoProfile -File scripts/maintenance_photos.ps1 -Apply   # explicit mutation
```

The thin wrapper calls the existing Python cleanup policy (Python 3 required). It selects at most 100 detached or expired pending assets in ID order, excludes attached assets via server filters, prints eligible IDs/count without paths/keys, then on Apply removes each object through Storage HTTP before the restricted metadata purge RPC. SQL independently rejects live attachments, active assets and remaining objects. Never clean Storage by deleting `storage.objects` rows. Storage failure stops before that asset's metadata purge; earlier completed assets remain removed. A metadata error also stops the batch. Rerun dry-run after investigating, then repeat Apply until the next dry-run is empty. A failed run's initial count is not a completed deletion count. No scheduler is installed. These are synthetic HTTP contract checks, not actual Storage service verification; race/authorization enforcement must also be checked on approved services before use.

See [Google setup](google-oauth.md) and [release preparation](release.md).
