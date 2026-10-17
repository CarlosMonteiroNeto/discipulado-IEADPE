# Synthetic Ministry Migration Rehearsal

Status: deterministic dry-run tooling only. No production export, database write, authentication cutover, or private record processing has been performed or is authorized by this runbook.

## Input and output contract

`scripts/rehearse_ministry_migration.py` accepts a JSON file containing only a `records` array. Each row contains an entity (`congregations`, `contacts`, `students`, `classes`, `enrollments`, `sessions`, `attendance`, `progress`, `converts`, or `links`), a source system (`firebase` or `base44`), the legacy source ID, its source state, candidate canonical congregation IDs, and optional reviewed existing-student candidate IDs. The tool rejects unknown fields so personal profile data cannot accidentally be copied into its report.

Stable target UUIDs are derived from a versioned namespace plus the source system, entity and legacy ID. Firebase and Base44 IDs remain distinct even if their text matches. A source key may appear only once. No name-based match is attempted. A missing or ambiguous congregation, or a missing/ambiguous explicit existing-student match, marks that row `review`; it is not eligible for cutover until a human resolves and records the decision.

The report preserves every source state, summarizes source/planned counts for all entities, lists stable student-convert link keys, and compares a second deterministic pass against the first. These are manifest reconciliation checks, not proof that rows were imported into a database. Review rows remain visible in totals and must not be silently dropped.

## Local synthetic run

Create a fixture with fake IDs and canonical UUID-like values, then run:

```powershell
python scripts/rehearse_ministry_migration.py --input synthetic-ministry.json --output rehearsal-report.json
python -m unittest discover -s test/migration -p '*_test.py'
```

Review `review_count`, each `review_reason`, `reconciliation.counts_match`, `reconciliation.states_match`, and the stable `links` list. Repeat the command and compare the JSON output. Any count/state drift, duplicate source key, or unresolved match blocks a real cutover plan.

## Future cutover and rollback gates

1. Keep Firebase and Base44 sources read-only and retained through reconciliation and an explicitly authorized observation period.
2. Freeze a versioned source export and checksums; do not include credentials, photos, or unnecessary personal fields in rehearsal artifacts.
3. Rehearse backups and restore into an isolated nonproduction target before any real import is considered.
4. Resolve every congregation and existing-student candidate through a documented human review. Never merge by name alone. Preserve terminal/archived state and conversion/attendance histories separately.
5. A separately approved importer must use the reviewed source keys and a transactionally idempotent import ledger. Re-run reconciliation against actual target database counts and link pairs, and verify scoped RLS behavior before opening access.
6. Roll back by keeping the old system authoritative, stopping target writes, restoring the isolated target from a verified backup, and reconciling before any retry. Do not delete or mutate either source during rollback.

Real export/import, live identity mapping, production credentials, deployment, and cutover require a separate release authorization and operations review. This dry-run script cannot perform those actions.
