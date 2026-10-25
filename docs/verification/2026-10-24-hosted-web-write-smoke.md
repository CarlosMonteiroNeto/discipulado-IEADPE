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

## Continued hosted Web lifecycle validation — 2026-10-25

This continuation ran on `codex/ministry-production-completion`, starting at local HEAD `2b682a087ed033e0cc5238e87697a908d8fe2d15`. It reused the verified encrypted full backup above; Docker was neither installed nor used. Synthetic writes were authorized by the user for this hosted Supabase test, with exact cleanup afterward.

### Web defect fixed during the journey

The `Cadastrar aluno` entry was exposed as a context-free generic menu route. Selecting it navigated to `/ministry/students/register` without the required `MinistryRouteContext`; the route guard redirected to `/register`, which is the unrelated new-convert form. The registration screen is reachable through `Alunos`, where `_openStudentRegistration()` supplies the required context. `AppShell.hiddenFromMenu` now hides only the direct menu shortcut while preserving that supported route. The focused widget test first failed on the expected menu assertion (RED), then `flutter test --no-pub --concurrency=1 --timeout=30s test/widgets/app_shell_test.dart` passed **8/8** (GREEN). The rebuilt Web bundle also showed `Equipe`, `Alunos`, `Turmas`, and `Frequência` with no context-free `Cadastrar aluno` entry.

### Hosted synthetic workflow

On authorized congregation Chafariz, the browser created `WEB JORNADA INTEGRADA 20261024` with synthetic education data, edited the linked canonical identity name, and restored that name. It created class `WEB JORNADA 20261024`, enrolled the synthetic student, created a session dated 2026-10-24, marked the student present, and saved the open attendance. After a full Web reload and normal congregation reselection, reopening the session showed the saved presence, confirming persistence across reload.

The original session was finalized and displayed its marks read-only. The UI then canceled that synthetic session while retaining its history, created the fixed-date linked replacement, and finalized its attendance. The refreshed session list showed both sides of the replacement link. Enrollment progress showed 1 evaluated session, 1 presence, 0 absences, 0 excused marks, and 100% utilization; the canceled session was excluded from the aggregate.

### Targeted cleanup and restored state

The cleanup used the hosted Supabase CLI Management API as PostgreSQL `postgres`, with pre-delete guards on the exact Chafariz class, student, canonical person, sole test enrollment, the two linked sessions, their two roster/attendance rows, absence of convert references, and the 12 operation receipts created during this test. The transaction deleted only those rows and receipts. Follow-up SQL returned **24 congregations, 51 converts, 0 test people, 0 test students, 0 test classes, 0 classes in Chafariz, 0 test sessions, 0 test receipts, and 8 total mutation receipts**, matching the pre-run baseline. Refreshed Web pages showed `Nenhuma turma encontrada.` and `Nenhum aluno cadastrado nesta congregação.`

Ignored local screenshots are in `build/verification/hosted-web-write-smoke-2026-10-24/`:

- `web-progress-cancel-replacement.png` — SHA-256 `152a233b80348c1ae12504d299c632a36aebfd97ec9e49b0e3054130f8efd61b`
- `web-class-list-after-cleanup-20261025.png` — SHA-256 `3ccf40513ac2e023c1b988ac53341459c7b18f2a4e952cd7ff4d1c1540deb27f`
- `web-student-list-after-cleanup-20261025.png` — SHA-256 `9129109bed3b0b461c38c4918263dcf104d6259d23b575066af79853b0c4152d`

This is observed authenticated hosted Web CRUD/lifecycle evidence. It does not exercise cross-congregation denial or existing-token revocation. Under the user's 2026-10-25 plan amendment, the hosted lifecycle is the intended Web acceptance environment; that leg passes, and overall T11 is PARTIAL pending those hosted authorization-boundary cases. Docker/local Supabase is explicitly not required. Fresh OAuth/provider remains O1/G2; Android Storage/photo remains D2.

### Static Web deep-link routing and final verification — 2026-10-25

The first fresh-build inspection found that `build/web/_redirects` had only the six older application routes. A previously running local Pages fixture still held a broader rewrite in memory, which made one initial browser check misleading. A clean fixture request reproduced the actual issue: direct ministry URLs returned 404. The source rewrite list and Web preflight now require all 13 exact router paths, including the seven `/ministry...` routes; no wildcard proxy was added, so JS/WASM and other assets keep their own responses.

The release-operation regression test failed on the newly covered ministry URL before the route list was extended; afterward `python -m unittest discover -s scripts -p test_release_operations.py` passed **5/5**. `python scripts/web_preflight.py build/web` passed. A restarted local Pages server served all **13/13** direct application routes from the rebuilt artifact and retained the expected MIME for **4/4** sampled assets. A real browser direct navigation to `/ministry/classes` loaded the Flutter app instead of returning 404; after congregation reselection, the empty-state Students page remained available and its registration flow opened from Alunos.

Final review after all changes: `flutter test --no-pub --concurrency=1` passed **566/566**. `flutter analyze --no-pub` had passed with **No issues found** for the same Dart source state; the subsequent static-routing changes touched no Dart files. `flutter build web` passed after adding the exact redirects, and the generated artifact passed the Web preflight. Build emitted only the optional WASM-renderer suggestion and the existing unused CupertinoIcons-font notice; no build errors.

## Limits and next gate

- This confirms authenticated hosted Web creation, editing, enrollment, attendance, finalization, cancellation/replacement, aggregate progress, and targeted cleanup for synthetic records in one authorized congregation.
- It does not cover cross-congregation denial, existing-token revocation, or a fresh OAuth/provider handshake.
- Under the 2026-10-25 amendment, T11's hosted Web lifecycle leg passes; overall T11 is PARTIAL only for the unrun authorization-boundary cases. Docker/local Supabase is not required. This evidence does not close O1/G2, D2, or release gates.
- No Android/Wi-Fi debugging was run. Docker remained unused throughout.
