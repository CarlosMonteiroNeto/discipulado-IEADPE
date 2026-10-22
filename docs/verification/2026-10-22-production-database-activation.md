# Hosted production database activation — 2026-10-22

**Status:** `PRODUCTION_DATABASE_APPLIED / STRUCTURAL_VERIFICATION_PASS / HOSTED_API_SMOKE_PASS / RELEASE_GATES_OPEN`

**Project:** Discipulado IEADPE, `voqmtnqjrbugpazcimvh`, PostgreSQL `17.11.0.003`
**Candidate:** branch `codex/ministry-production-completion`, HEAD `a2bf2c234c51d8e6893de92f51e92a3b8f76f88b`
**Authorization:** the user authorized production database changes on 2026-10-22 with the explicit constraint that existing information must not be lost. Local commits are authorized; no push was performed.

## Outcome

The corrective forward chain is active on production. The hosted migration ledger now has **36 rows** through `202610200006_attendance_roster_preview.sql`; the 16 forward migrations applied without an SQL error. The two missing baseline ledger rows were repaired first, without a blind `db push`.

Pre-existing rows were preserved. Every pre-migration table count rechecked equal after activation, including 51 converts, 24 congregations, 30 access assignments, 40 week guards, 10 weekly reports, 15 convert events, 127 Base44 source-metadata rows, 30 pending access rows, 6 mutation receipts, and 1 profile. The new `public.ministry_people` table was backfilled to 51 rows, and all 51 converts have `person_id` populated.

| Check | Result |
|---|---|
| Ledger | 36 rows; last version `202610200006` |
| Forward migrations | 16 applied; 16 progress records; 0 SQL errors |
| Preserved data | All pre/post counts equal; no row deletion observed |
| New identity table | `public.ministry_people` = 51; `converts.person_id` = 51/51 |
| Final columns / constraints / indexes / policies / RLS | 244 / 187 / 78 / 18 / 27, exact against the T12 final contract |
| RLS | 0 tables without row-level security |
| Anonymous access | `anon` has no `SELECT` on `public.converts`; REST probes return HTTP 401 |
| Auth / PostgREST | Auth health HTTP 200; PostgREST schema cache reloaded; new tables visible and fail-closed |
| Backup / restore | Encrypted backup verified by decrypt-to-identical archive; isolated restore passed |

## Backup and isolated restore

The backup was taken before any forward migration:

- `app.dump` — 265,472 bytes, SHA-256 `6A5916F26AD6DDAAB83FE3611F19BFEA8983EF45B9C4E8CD50611FB0720629E3`
- `auth-storage-meta-data.dump` — 46,023 bytes, SHA-256 `1D4BADCD2531D10019564F7921CEB6233FF403926E7E15F1D517763FCA36233A`
- `full.dump` — 586,278 bytes, SHA-256 `B917B12810244ECA3C19ACA26A89BFBCBE8DCB1F4BCE42010F31DD5370870489`

The three dumps were archived, encrypted with AES-256-CBC/PBKDF2, and decrypted again. The decrypted archive SHA-256 equals the original archive SHA-256 (`BED4AD3F3216F197D5B6B8BE3D57F39BA7DE8310BFDBA542BAE9F65AE991D29A`); the encrypted archive SHA-256 is `D5CDA777E44A13D109052FFE846A2D50B36E08521C46FD33BE6AA0A3110513F8` (223,056 bytes). The passphrase is retained separately under an owner-only ACL and is not recorded in the repository. The plaintext backup directory also has owner-only ACL.

An isolated restore of `app.dump` into disposable loopback PostgreSQL exited 0 with 26 tables and 171 constraints. After `SET timezone='UTC'`, the `converts`, `congregations`, and `user_access` content hashes matched the source. Auth contained 1 user; Storage contained 1 bucket and 0 objects, so there were no Storage object bytes to restore.

## Baseline and ledger repair

The hosted ledger contained only the 18 baseline versions `202610140001`–`202610140018`. The baseline objects nevertheless existed; the missing ledger rows were `202610180001` and `202610180002`. A blind `db push` was not used.

Baseline catalog comparison matched **227/227 columns, 171/171 constraints, 71/71 indexes, 17/17 policies, and 26/26 RLS tables**. The two missing ledger rows were inserted with their exact versions and names, taking the ledger from 18 to 20 rows. The 16 forward migrations then ran one transaction at a time through the Supabase Management API as the existing `postgres` session. No temporary superuser was created; the failed attempt to create one changed nothing.

## Real-data clone rehearsal

Before production, the verified `app.dump` was restored into `ministry_prodclone_20261021` and all 16 forward migrations were applied. The clone had one local-only limitation: its minimal Auth stub lacked `auth.users.email_confirmed_at`, which was added only to the clone. The production Auth schema already has it, and production applied without that workaround.

The clone final contract matched the `202610200006` T12 contract for columns, constraints, indexes, policies, and RLS. This rehearsal used real production data, not only the synthetic T12 fixture.

## Residual findings

All **10** function-definition fingerprint differences from the synthetic final contract were already present before activation and were unchanged by the 16 migrations. They are pre-existing production function drift, not a regression introduced by this activation. They remain recorded rather than being silently rewritten.

The **18 table-grant** and **55 function-grant** differences are only extra `service_role` privileges, which are normal Supabase defaults. There are no missing expected grants and no unexpected `anon` grants. The applied migration therefore did not weaken the expected grant model.

## Open gates and risks

The following are still open and are not implied by this database activation:

- T11 live loopback Auth/PostgREST/Storage/Chromium journey is still blocked by the unavailable Windows Docker engine. The hosted API smoke is useful but does not replace that journey.
- Full Android authenticated acceptance, OAuth, persistence, and Storage/SAF checks are not complete. The 2026-10-21 debug APK login smoke used synthetic configuration and is not production acceptance.
- Release signing/custody, release APK publication, and production device acceptance remain gated; no release artifact exists.
- H3 legacy Firebase export/verified absence and stable-ID reconciliation remain open.
- Independent review of the current package, migration bytes, and this production activation remains pending.
- Earlier tooling displayed a legacy service-role credential and a temporary database password. Values are not repeated here. The temporary application/backup roles are gone and no `ministry_*` role remains; rotation of the exposed service-role credential is still pending and should be completed before release.

## Rollback

The verified encrypted backup and plaintext copies are retained. Rollback or recovery must restore to an isolated destination first, reconcile counts, constraints, links, RLS, and object access, and only then consider a production restore with explicit authorization. No production restore was performed.

## Evidence index

- Tracked activation evidence: `docs/verification/evidence/2026-10-22-production-activation-evidence.json`, SHA-256 `864FA13C88A8E0870253FF5717376088AB0DA5DB1F080272779DF03A80996A31`, 5,866 bytes.
- Machine activation package: `docs/verification/ministry-corrective-activation-package.md`.
- Local-only apply logs: `build/verification/corrective-release/hosted-db-2026-10-21/production-apply-logs/` (16 files); progress ledger: `production-apply-progress.txt` (16 lines).
- Local-only comparisons: `production-final-catalog-raw.txt`, `production-final-equivalence.json`, `production-final-contract.json`, `baseline-equivalence.json`, `clone-final-equivalence.json`, `summary.json`, `parity-key-objects.json`.
- Local backup directory: `C:/Users/Carlos_Neto/.codex/backups/ministry-prod-20261021`; encryption passphrase file is in a separate owner-only directory.
- Historical T12 rehearsal and package evidence remain under `build/verification/corrective-release/T12/`.

The tracked evidence file contains counts, schema identifiers, hashes, and gate status only. It contains no credentials and no user records.
