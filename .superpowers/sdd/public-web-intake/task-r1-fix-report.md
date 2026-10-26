# R1 fix round 1 — current configuration evidence

Date: 2026-10-26
Base: `9e27686a3e488f879a6ede2531d0c75db2c1997c`
Result: addressed reviewer P2; hosted acceptance remains BLOCKED/INCOMPLETE.

## Finding and correction

Reviewer finding: “Current configuration evidence is stale. `.superpowers/sdd/public-web-intake/task-r1-report.md:33` and `.superpowers/sdd/public-web-intake/progress.md:360` state that presence checks found no `SUPABASE_URL`. My independent presence-only check confirms it is present and its parsed hostname matches the inventoried project. `PUBLIC_INTAKE_DATABASE_URL` and `PUBLIC_INTAKE_TRUSTED_PROJECT_REF` remain absent. Preserve the earlier observation as historical and add the current result; this does not unblock hosted acceptance.”

Updated the R1 report, progress ledger, and acceptance evidence. The earlier no-`SUPABASE_URL` observation remains explicitly historical. The current `SUPABASE_URL` result is recorded without printing or storing its value. Hosted readiness remains BLOCKED/INCOMPLETE: the presence result is not backup evidence, a TLS database runner connection, or a hosted SQL PASS.

## Verification

Exact presence-only verification command:

```powershell
python -c "import os, urllib.parse; u=os.environ.get('SUPABASE_URL',''); host=urllib.parse.urlparse(u).hostname or ''; print('SUPABASE_URL_PRESENT='+str(bool(u))); print('SUPABASE_URL_HOST_MATCHES_INVENTORIED_PROJECT='+str(host == 'voqmtnqjrbugpazcimvh.supabase.co')); print('PUBLIC_INTAKE_DATABASE_URL_PRESENT='+str(bool(os.environ.get('PUBLIC_INTAKE_DATABASE_URL')))); print('PUBLIC_INTAKE_TRUSTED_PROJECT_REF_PRESENT='+str(bool(os.environ.get('PUBLIC_INTAKE_TRUSTED_PROJECT_REF'))))"
```

Output:

```text
SUPABASE_URL_PRESENT=True
SUPABASE_URL_HOST_MATCHES_INVENTORIED_PROJECT=True
PUBLIC_INTAKE_DATABASE_URL_PRESENT=False
PUBLIC_INTAKE_TRUSTED_PROJECT_REF_PRESENT=False
```

`git diff --check` and focused documentation assertions are run for this fix before commit. No Supabase CLI or analyzer was run.

## Deferred minor

Reviewer P3 minor deferred to R7 evidence close: explicitly label the pre-existing acceptance PASS table as T8 historical so it cannot be confused with the refreshed R1 date/candidate. This fix round records the deferral in the progress ledger and does not change that historical table label.
