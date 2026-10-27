# Final whole-branch review fix report

Date: 2026-10-25

Status: **DONE WITH CONCERNS** — four findings are addressed, focused non-database checks pass, and SQL runtime verification is incomplete because no allowed native PostgreSQL target is available.

Reviewed baseline: `6e2754b3330c9f51820a4e33b4b5a1833d5925d6`

Branch: `feat/public-web-intake`

## Investigation and scope

Read the fix brief, approved Spec, approved plan, project instructions and RTK, T8/T9 reports, SDD ledger, public-intake runbook, and the exact Edge Function, SQL migration, SQL scenario, integration contract and static-gate owners before editing. The hosted ledger/T8/T9 reports state that migrations `202610250002`–`004` are pending and `202610250001` is applied. That read-only evidence permits the retention adjustment to the pending T2/T5 migrations; no applied migration was rewritten.

The environment has no `psql`, `pg_isready`, `pg_ctl` or PostgreSQL service/native target. No Docker or local Supabase was started, no SQL was sent to a hosted database, and no deployment, account, publication or other hosted write was performed. No secrets were printed.

## Changes

1. Extracted Supabase URL validation to `supabase/functions/public-intake/config.ts`. HTTPS remains valid for hosted endpoints; HTTP is valid only for `localhost`, IPv6 loopback `::1`, or IPv4 loopback `127.0.0.0/8`. Added focused tests for HTTPS, explicit loopback, remote HTTP, credentials and paths. The function does not become configured for a remote HTTP endpoint, so its service credential cannot be sent to that endpoint.
2. In the not-yet-hosted `202610250003_public_intake.sql`, fixed pending expiry and digest receipt retention at exactly 30 days and decision metadata retention at exactly 90 days. In the pending `202610250004_pending_review.sql`, added a defensive exact-90-day check before writing decision metadata. Updated the T2/T5 SQL scenarios with below/above-boundary assertions and exact 90-day retention expectations.
3. Changed the archived-congregation denial in `public_registration_authority_test.sql` to use the global manager fixture. This manager is otherwise authorized across congregation scope, so the assertion isolates the archived guard.
4. Updated `docs/integration/ministry-contracts.md` to label no-grant/unassigned creation as historical and superseded by current scoped official creation and pending intake. Updated `docs/operations/public-intake.md` to distinguish fixed retention policy from configurable abuse/capacity limits, describe the function URL transport rule, and label the earlier T8 database results as historical relative to this change.
5. While running relevant static checks, found the existing `public_intake_hosted_smoke_test.sql` was omitted from the loopback verification manifest, causing its validator suite to fail. Added it to `scripts/verification_cases.json` and added a focused manifest regression. The runner continues to use the existing loopback-only guarded `test_database.py` path.

## RED/GREEN evidence

- Configuration RED: `deno test supabase/functions/public-intake/config_test.ts` failed on `http://project.supabase.co` with `expected rejected Supabase URL` before the transport restriction. It passed after the fix.
- Documentation RED: the two new release-contract assertions failed first on the absent fixed-retention wording and the stale no-grant contract. Both passed after the documentation changes.
- Manifest RED: `python -m unittest discover -s scripts -p test_verification_cases.py -v` initially failed 5/10, including the new focused test, with `SQL scenario coverage mismatch; missing=['public_intake_hosted_smoke_test.sql']`. After adding the scenario, all 10 tests passed and the validator passed.
- SQL fixture assertions were added before the migration edits, but could not be run: the required PostgreSQL executable/service/target is unavailable. They have not been represented as a runtime RED or GREEN.

## Verification commands and output

Commands run after implementation:

```text
deno test supabase/functions/public-intake
ok | 19 passed | 0 failed

deno check supabase/functions/public-intake/index.ts
Check supabase/functions/public-intake/index.ts

deno fmt --check supabase/functions/public-intake
Checked 6 files

python -m unittest discover -s scripts -p test_release_operations.py -v
Ran 9 tests
OK

python -m unittest discover -s scripts -p test_verification_cases.py -v
Ran 10 tests
OK

python scripts/verification_cases.py --validate
PASS: 34 SQL scenarios and 10 concurrency cases validated

python -m py_compile scripts/test_release_operations.py scripts/test_verification_cases.py
exit 0

git diff --check
exit 0
```

No database scenario, database concurrency hook, hosted runner, migration apply, browser journey, Docker, local Supabase, or deployment command was run.

## Remaining concern

SQL runtime verification is **INCOMPLETE**. The migration and scenario changes are source-reviewed and the fixture assertions are present, but the SQL cannot be claimed runtime-verified without an existing approved non-hosted native PostgreSQL target. The guarded unified manifest will select the hosted smoke fixture only through the existing loopback harness; that harness was not executed here.

## Commits

- `a627dfb43354e77402a27e738c07e0db9f5b153b` — `fix: close public intake review findings`
- SDD progress/report receipt is committed separately after this report is written.
