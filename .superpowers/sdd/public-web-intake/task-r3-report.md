# Task R3 — hosted runner target and migration evidence

Date: 2026-10-26
Branch: `feat/public-web-intake`
Baseline: `c91c44c54e5acef21e4593f65f9435d7f001a0e6`

## Findings and changes

The hosted runner accepted only the direct `db.<project-ref>.supabase.co` database hostname. Its target check rejected the verified shared Session Pooler form before account confirmation or psql, even though the HTTPS Supabase API URL and trusted project ref already matched. `_confirm_target` now accepts either that direct endpoint or a strictly shaped shared Session endpoint: `aws-<n>-<region>.pooler.supabase.com:5432/postgres`, with username `postgres.<ref>` or `cli_login_postgres.<ref>` and exactly `sslmode=require`. The project HTTPS URL remains exact; Transaction Pooler, unrelated host, wrong project/role, wrong database, and missing/other TLS mode remain rejected.

The runner also rejected a missing required migration before writing its external evidence receipt. It now captures the read-only baseline and writes STARTED only after backup, URL/project/account checks, typed confirmation, and connected identity proof. The baseline's migration-version list drives the prerequisite check. Missing versions update the receipt to BLOCKED with the exact versions, safe reason, timestamps, `hosted_write_attempted=false`, and `scenario_dispatched=false`; no fixture is dispatched. The migration prerequisite still blocks all scenario SQL. Scenario dispatch state is recorded explicitly. Legacy truncating and concurrency paths remain blocked before hosted subprocesses; the short T2 smoke remains rollback-only. `scripts/test_database.py` and its loopback safeguards were not changed.

## Test-first and verification

- RED: the focused pooler acceptance regression raised `SafetyError` on the valid Session Pooler shape.
- RED: the fake-process missing-migration regression found no external evidence file because the old runner exited before STARTED.
- GREEN: focused tests cover the accepted pooler roles and direct endpoint, rejected unsafe DSN variants, and an end-to-end fake process that records BLOCKED baseline evidence without scenario dispatch.
- `python -m unittest discover -s scripts -p 'test_public_intake_hosted*.py' -v` — 23 tests passed.
- `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py` — passed.
- `git diff --check` — passed.

All end-to-end runner tests used fake CLI/psql processes. No real database, Supabase CLI, secret, hosted scenario, migration, function, or site was accessed or changed. T2 limits/rate/concurrency and hosted journey acceptance remain incomplete and BLOCKED pending controller coordination and safe synthetic race fixtures.

## Independent review fix round 1

Review confirmed two gaps. First, libpq URI query options could override host, user, address, database, or port while the authority portion still passed validation. `_confirm_target` now permits only the single `sslmode=require` query entry; regression cases reject each override and duplicate TLS keys while retaining valid direct and Session Pooler URLs.

Second, the runner attempted the full scenario baseline before checking migration state, which referenced queue tables absent when migrations `202610250002`/`003` are pending. It now queries the migration ledger independently, uses a core-only baseline that avoids intake tables/settings/grants when a required migration is missing, writes STARTED with available baseline and migration evidence, then BLOCKED with exact missing versions. No run ownership is recorded and no scenario SQL is dispatched in this path.

RED: the new override cases accepted host/user/hostaddr/dbname/port parameters; the fake T2 missing-schema process failed before creating its evidence receipt. GREEN: `python -m unittest discover -s scripts -p 'test_public_intake_hosted*.py' -v` — 25 tests passed; `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py` and `git diff --check` passed. Fake processes only; no remote target was called.

## Independent review fix round 2

Re-review found that the explicit `include_intake_schema` flag could re-enable feature-table baseline reads for the authority scenario whenever its only required migration (002) was applied. Baseline scope now excludes intake feature tables for that scenario unconditionally. A fake psql regression supplies migration 002 while making any intake-table reference fail, then verifies the authority scenario continues with a core-only baseline and reaches its rollback-only scenario path.

RED: `python -m unittest scripts.test_public_intake_hosted_runner.HostedRunnerSafetyTests.test_authority_scenario_baseline_ignores_absent_intake_schema -v` failed because the old baseline queried missing feature tables. GREEN: `python -m unittest discover -s scripts -p 'test_public_intake_hosted*.py' -v` — 25 tests passed; `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py` and `git diff --check` passed.

## Hosted transport fix

The controller found that the runner's use of the full connection URI as `PGDATABASE` did not connect with the short-lived CLI credential, while the same fields worked through standard libpq environment variables. The runner now parses the already validated URL into separate `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE=postgres`, and `PGSSLMODE=require` values. It removes inherited `PG*` overrides and the original database URL from the psql environment; the credential stays out of argv and logs.

RED: the fake psql regression using the accepted shared Session Pooler URL captured the prior `PGDATABASE` URI and inherited hostile `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGSSLMODE`, `PGHOSTADDR`, `PGSERVICE`, and `PGOPTIONS` values. GREEN: `python -m unittest discover -s scripts -p 'test_public_intake_hosted*.py' -v` — 25 tests passed; `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py` and `git diff --check` passed. No credential or real database connection was used in this fix round.
