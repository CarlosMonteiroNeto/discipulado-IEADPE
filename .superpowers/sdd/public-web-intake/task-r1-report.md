# R1 — evidence reconciliation report

Date: 2026-10-26
Result: **PASS for focused local SQL evidence; hosted acceptance remains BLOCKED/INCOMPLETE.**
Branch: `feat/public-web-intake`
Candidate inspected: `bed4cbe2887b38db98d13e109b8cd033707ee3ae`
Origin/main: `846a320619d3d8240df391a8b218c713bcceedc3`

## Scope and investigation

R1 reconciled evidence only. The worktree was clean at the requested candidate before changes. The supplied task brief, `scripts/test_database.py`, acceptance evidence, T8 amended acceptance report, T9 release report, progress ledger, and analyzer log were inspected. No application source, migrations, runner, hosted project, secret, or publication configuration was changed. T1–T9 were not restarted.

The earlier local SQL `INCOMPLETE` text was accurate for its historical environment, which lacked a usable `psql`/server path. The current runner has an existing PostgreSQL bundle fallback. Current local focused scenario evidence therefore supersedes the current-candidate status for those scenarios while leaving the older receipt untouched.

## Local database runtime and results

`scripts/test_database.py` defaults to `postgresql://postgres@127.0.0.1:54329/postgres` when `IEADPE_DATABASE_URL` is unset, and rejects targets outside `127.0.0.1`, `localhost`, or `::1`. When `psql` is absent from PATH, it looks under `~/.codex/tools/ieadpe-postgresql/pgsql/bin`. The existing loopback bundle was PostgreSQL 17.11. Docker was not started; `psql` was absent from PATH but the runner executed using its fallback.

Fresh local commands run on 2026-10-26:

| Command | Result |
|---|---|
| `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency` | Exit 0. `PASS: public_intake_test.sql` and `PASS: public intake serializes the last global capacity slot`. |
| `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency` | Exit 0. `PASS: pending_review_test.sql` and `PASS: public intake serializes the last global capacity slot`. |
| `python scripts/test_database.py public_registration_authority_test.sql` | Exit 0. The focused registration authority SQL scenario passed. |

**Classification:** current focused local SQL evidence is PASS. It covers only the named scenarios and concurrency hook; it does not establish every scenario in the SQL manifest or hosted behavior. Historical receipts are retained as historical evidence.

## Hosted state and blockers

The read-only hosted evidence supplied for R1 records an authenticated CLI inventory with a unique `Discipulado IEADPE` project (`voqmtnqjrbugpazcimvh`), migration `202610250001` applied and `202610250002`–`202610250004` pending, an empty Edge Functions list, and a successful linked safe `SELECT 1 AS safe_probe`. A first safe query omitted `--linked` and failed with `DbQueryMutuallyExclusiveFlagsError`; the corrected invocation succeeded. This is a CLI invocation/configuration error, not a database failure.

No hosted migration, function deployment, or hosted SQL scenario PASS is claimed. Hosted backup/TLS runner prerequisites remain unverified; the presence checks found no `PUBLIC_INTAKE_TRUSTED_PROJECT_REF`, `SUPABASE_URL`, or `PUBLIC_INTAKE_DATABASE_URL`. Migration readiness is blocked by pending migrations and backup-first requirements. Function readiness is blocked by no deployed function and T3's unresolved authoritative managed-gateway address source, for which production remains fail-closed. Hosted journey/readiness is also blocked by absent verified Turnstile configuration, reviewer identities/grants, external full-backup evidence and run-owned fixture/cleanup readiness. Local SQL PASS does not lift any of these hosted blockers.

R1 required no further Supabase CLI invocation or remote query. The prior `supabase db dump --dry-run` output included a CLI-generated database login credential; this report deliberately does not repeat, store, quote, or use that value. The user plans to rotate/revoke it. No credentials or PII were recorded here.

## Flutter analyzer

The full `flutter analyze --no-pub` result remains **INCOMPLETE**. The T8 evidence records it alive for over four minutes with no output and a zero-byte `.superpowers/sdd/public-web-intake/t8-full-flutter-analyze.log`; process inspection recorded about 7 MiB working set and under 0.02 CPU seconds. Existing T8 evidence says direct SDK `dart analyze` on the six changed Dart paths completed with `No issues found!`. The observed cause is classified as a full Flutter analyzer process/tooling stall without diagnostic output; the evidence does not establish a Dart source defect. The unchanged hanging invocation was not repeated. The already-recorded focused analyzer result remains the scoped analysis evidence.

## Updated evidence and verification

- Updated `docs/verification/public-intake-acceptance.md` with the current source candidate and three local SQL PASS rows. Hosted acceptance is still BLOCKED/INCOMPLETE. Existing historic PASS/INCOMPLETE receipts remain in place.
- Updated `.superpowers/sdd/public-web-intake/progress.md` with exact current-candidate commands, local runtime, hosted inventory and blockers, analyzer classification, and report link.
- `git diff --check` and focused assertions over the changed documents were run before commit. Only the acceptance evidence, progress ledger, and this R1 report are included in the R1 documentation commit.

## Concerns

1. Hosted acceptance is not ready: migrations remain pending, no Edge Function is deployed, trusted address resolution and Turnstile settings remain unresolved, and required backup/TLS/runner/reviewer prerequisites are unavailable.
2. The full Flutter analyzer remains an unresolved tooling/process stall. Existing scoped Dart analysis is clean, but it does not replace the full command.
3. The prior CLI-generated database login credential must be rotated/revoked by the user as planned; it is excluded from this report and was not used.
