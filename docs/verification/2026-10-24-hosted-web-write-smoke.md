# Hosted Web write smoke — 2026-10-24

## Scope

Authenticated browser validation on the `codex/ministry-production-completion` branch, commit `c97b5cffde2cf3ef6905d85f1b0ee620879a7dd2`. The user authorized a fresh backup and synthetic production writes, followed by restoration of the original state after each test. The authenticated user selected the authorized congregation **Chafariz**.

This documents two narrow Web CRUD smoke tests. It is not the local Auth/PostgREST/Storage/Chromium journey required by plan gate T11.

## Backup and restore evidence

Before writes, a fresh full custom-format `pg_dump` was created outside the repository in the user's protected local backup directory. The 856,732-byte dump has SHA-256 `870436eb6fd904701f4b8294db7be27cd532e803d5551d8b1bd7ddc9cacae2de`. An AES-GCM encrypted copy (856,768 bytes; SHA-256 `d234e1541818e15473ad59933130a365d4b8ee47f51d210fe831b300cba9d9d0`) was verified by decrypting it with the DPAPI-protected CurrentUser key and comparing its digest to the original. The plaintext dump and key remain outside Git.

The archive TOC contains 66 table-data entries, 10 schemas, 18 `public` tables, 4 extensions, 268 ACL entries and 24 default-ACL entries. A restore was verified in an isolated local PostgreSQL 17.11 database before testing. The portable local instance does not provide Supabase's managed Vault extension, so only the `vault` schema and `supabase_vault` extension were excluded from that local restore; the backup itself is complete.

## Web write/restore checks

The pre-test state in Chafariz was 0 active classes and 0 students. The UI identified Chafariz as the selected authorized congregation. The test used synthetic values only.

| Area | Actions | Cleanup and observed result |
|---|---|---|
| Classes | Created `TESTE WEB CODEX 20261024`; edited its name to `TESTE WEB CODEX EDITADA 20261024`; restored the synthetic name; archived it in the app. | Because app archival retains a history row, a narrowly scoped SQL cleanup removed only the synthetic class and its matching mutation receipts. The predicate required the exact test name and Chafariz and required no sessions or enrollments. Follow-up counts were 0 test-class rows, 0 matching receipts and 0 remaining Chafariz classes. The class page returned to `Nenhuma turma encontrada.` |
| Students | Created `TESTE WEB CODEX ALUNO 20261024` with synthetic education `Escolaridade sintética`; changed it to `Escolaridade editada`; then restored and saved `Escolaridade sintética`. | A narrowly scoped cleanup removed only this synthetic student, its synthetic canonical person and matching `register_student`, `save_student` and `save_person` receipts. The predicate required the test name and Chafariz, active state, and no convert, enrollment, attendance or roster links. Follow-up counts were 51 people, 0 students, 8 mutation receipts, 0 Chafariz classes, and no synthetic student or matching receipts. The student page returned to `Nenhum aluno cadastrado nesta congregação.` |

The final counts match the pre-test baseline captured with the backup/restore check: 51 people, 0 students, 8 mutation receipts and 0 classes in Chafariz. The existing 24 congregations and 51 converts were not test targets. The cleanup was verified against exact synthetic identifiers and relationship guards; no bulk restore or migration was performed on production.

Screenshots were saved locally under the ignored `build/verification/hosted-web-write-smoke-2026-10-24/` directory:

- `class-list-after-cleanup.png` — SHA-256 `eb92198f2a8cc1c9f512834a9e8234ba2f94bf4c34ef945fe1649da061ca82f5`
- `student-list-after-cleanup.png` — SHA-256 `393fac4e14f1702369c683ba9582c19bda295492e631a4d3ce69cc8878f1e381`

## Limits and next gate

- This confirms authenticated hosted Web creation, editing, and targeted cleanup for classes and students in one authorized congregation.
- It does not cover class sessions, attendance, enrollment lifecycle, cross-congregation access, revocation, or behavior in a fresh login session.
- Docker was not installed or used. Plan gate T11 remains blocked pending the owned local Auth/PostgREST/Storage/Chromium journey and its required sentinel cleanup. This smoke does not close T11 or release gates.
- No Android/Wi-Fi debugging and no full Flutter suite were run in this validation step.
