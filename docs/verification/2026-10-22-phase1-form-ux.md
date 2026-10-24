# Phase 1 form and ministry navigation verification

Date: 2026-10-22
Branch: `codex/ministry-production-completion`
Commit under test: `757d0c9`

## Scope

Phase 1 corrective UI release for Web and Android:

- Shared calendar-only date fields and Brazilian phone fields.
- `dd/MM/yyyy` display, calendar-only entry, and blur/submit validation.
- 11-digit national phone mask with E.164 normalization on save and legacy
  preservation when the value was not edited.
- Redundant sidebar handoff entry hidden while its authorized deep link remains.
- `Cadastrar aluno` navigation icon restored.
- Convertidos screen and handoff heading renamed to remove the duplicate
  "Novos convertidos" wording.

Linux release work and the Phase 2 `new_convert` student filter remain deferred.

## Verification evidence

| Check | Result |
|---|---|
| `dart format` on changed Dart files | clean |
| `flutter analyze --no-pub` | `No issues found!` (73.0s) |
| `flutter test --no-pub` | `560/560` passed (6:40) |
| Shared input tests | `test/ui/br_input_test.dart` and `test/widgets/form_fields_test.dart` passed |
| Golden update | only the intentional team-contact visual baseline changed, regenerated with `--update-goldens` |

### Debug APK

- Path: `build/app/outputs/flutter-apk/app-debug.apk`
- Target: `android-arm64`
- Bytes: `136,304,948`
- SHA-256: `D07AB76CB83EDE4BD6185C6AC37147719872B2AD59F70E73D2505FCFC1FC0735`
- Built: `2026-10-22T23:53:30-03:00`
- Configuration: `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` supplied at build
  time through `--dart-define-from-file`, from a defines file kept outside the
  repository and deleted after the build.

The APK is a debug build. Release signing, publication, and production-device
acceptance remain gated.

### Android device pass

- Device: `2109119DG`, Android 14 (`API 34`), `arm64-v8a`. The adb serial is
  recorded in `evidence.json` rather than repeated here.
- Install: `adb install -r build\app\outputs\flutter-apk\app-debug.apk` printed
  `Performing Streamed Install` / `Success` and exited `0`; app data was
  preserved.
- Launch: launcher `br.org.ieadpe.ieadpe_converts/.MainActivity` started `COLD`
  with status `ok` in `2,590 ms`, and the focused window was that activity.
- Init log: `supabase.supabase_flutter: INFO: ***** Supabase init completed *****`.
  No fatal exception and no ANR in the 141 captured logcat lines.
- Visible shell labels: `IEADPE`, `Novos Convertidos`, `Abrir menu`,
  `Seção do Discipulado`, `Discipulado`, `Cadastrar Novo Convertido`,
  `Sem foto do convertido`, `Escolher foto`, `Congregação *`,
  `11 dígitos com DDD`, `Abrir calendário`, `Selecione no calendário`,
  `Enviar sugestão`, and the `Início`, `Cadastrar`, `Convertidos`,
  `Discipulado`, and `Menu` tab labels.
- Configuration error screen absent: `Serviço indisponível`,
  `Preparando acesso`, `Tentar novamente`, and
  `Não foi possível disponibilizar o acesso` were each searched for and not
  found.
- Persisted session present: the device already held a Supabase session, so the
  router published an access scope and the authenticated ministry shell rendered
  on the `Cadastrar` tab. **The login screen was therefore not rendered and login
  was not exercised.** Clearing app data or signing out was out of scope and was
  not performed.

Evidence: `build/verification/phase1-config-apk-2026-10-22/evidence.json` and
`ui-text.txt`. Those two artifacts and the APK itself were **not** transferred to the
continuation host, so the values above are the record made on the previous host and
could not be re-read here. This pass installed, cold-started, and read the screen
only: no write or mutation, no Storage access, and no screenshot.

### Read-only ministry navigation audit (2026-10-23)

Provenance: performed on the previous host during the 2026-10-23 session. The
git-ignored artifacts (`build/verification/phase1-device-2026-10-23/navigation.json`
and `ui/*.xml`) were **not** transferred to the continuation host, so **no row below
has a retrievable artifact on this host**. Every verdict is second-hand from the
previous session's capture; the table is not an independent re-run, and the review of
Task 2's artifact is still open. The pass was navigation only: no submit, login,
logout, data clearing, screenshot, or write.

| Check | Verdict | Observed |
|---|---|---|
| Cold start on the authenticated shell | PASS | opened on `Cadastrar`, not `Início` |
| `Início` | PASS | dashboard rendered with live readings |
| `Convertidos` | PASS | list rendered 51 records |
| `Discipulado` | FAIL | `Falha ao carregar congregações` plus `Nenhuma congregação autorizada está disponível para esta sessão.` |
| `Alunos` | FAIL | `Selecione uma congregação autorizada antes de continuar.` |
| `Cadastrar aluno` entry on `Alunos` | BLOCKED | the congregation gate prevented the screen from rendering; the drawer route exists and was not tapped |
| Redundant handoff entry in the drawer | PASS | drawer dump without the handoff entry; the deep link was not opened |

Two observations remain unclassified rather than accepted as product defects:
`adb shell input keyevent 4` ended the Activity instead of returning to the
previous tab, so the audit navigated by tabs and the drawer; and cold start
repeatedly landed on `Cadastrar`.

### Discipulado authorized-congregation diagnosis (2026-10-23)

Classification: `client_filter` is the best-supported hypothesis, meaning client-side
identifier validation rather than a session-scope or server-contract failure. Local
evidence: `build/verification/phase1-device-2026-10-23/discipulado.json` (git-ignored).
Because no fresh device log or server response could be captured here, a mapped
backend error is **not** positively excluded; the ranking is given under limits below.

- The 24 hosted congregations were imported through
  `private.base44_stable_uuid` (`supabase/migrations/202610180001_base44_history.sql`),
  which assembles a UUID from raw md5 hex and never normalizes the RFC 4122
  version and variant nibbles. The import record is
  `docs/operations/unified-migration.md`.
- `MinistryBrowserRepository._isUuid`
  (`lib/features/ministry/data/ministry_browser_repository.dart`) requires version
  `1`-`8` and variant `89ab`. An md5-shaped id satisfies that pattern with
  probability `(8/16)*(4/16) = 1/8`; all 24 satisfying it has probability `2^-72`.
- The scope loader (`lib/features/auth/auth_repository.dart`) accepts the same ids
  with a lax `8-4-4-4-12` shape, so the app reports ministry access, requests the
  catalog, and then the parser throws on the first imported id. `lib/app.dart`
  converts that throw into `Não foi possível carregar as congregações autorizadas.`;
  the empty catalog also renders `Nenhuma congregação autorizada está disponível
  para esta sessão.`; and `Alunos` then falls into the congregation gate.
- `Convertidos` passes because `Congregation.fromJson` performs no UUID validation
  and `SupabaseGateway.validateUuid` uses the same lax shape. The split between a
  working `Convertidos` and a failing `Discipulado` is therefore explained by the
  validation difference, not by the session.
- Reproduced on the continuation host with a git-ignored probe,
  `build/diag/ministry_uuid_probe_test.dart`: 4/4 passed. A v4 id parses; ids with
  a version nibble of `0` or a variant nibble of `0` are rejected as
  `invalid_response`; the scope loader's lax regex accepts the same values.
- This host has no `adb`, Android SDK, or attached device, so the diagnosis is not
  confirmed by a fresh device log. The ranking among causes is therefore:
  `client_filter` best supported (reproducible parser rejection plus the import
  provenance of the ids); `rpc_error` not excluded; `session_scope_empty` and
  `stale_cache` unsupported by the code paths. The only record of a direct scoped
  RPC returning HTTP 200 with non-empty results is the 2026-10-22 report itself —
  no captured status/body artifact exists in this repository, so that record cannot
  carry independent evidential weight.
- The simultaneous `Nenhuma congregação autorizada está disponível para esta sessão.`
  panel is an empty state rendered while `_ministryCatalogError` is set. Spec A3
  forbids presenting a failure as a genuine empty state, so the double panel is a
  disclosed follow-up defect, not intended behaviour.

`follow-up required` (not implemented here, because this plan forbids product edits
inside a verification task): replace the strict RFC 4122 pattern with one shared
shape validator that mirrors PostgreSQL's textual `uuid` form, use it in every
ministry id check — `ministry_browser_repository.dart`, `ministry_codec.dart`,
`ministry_repository.dart`, `ministry_handoff_repository.dart`,
`ministry_models.dart`, `session_navigation_context.dart`, and
`MinistryRouteContext` in `lib/domain/models.dart` — and add a regression test that
feeds an md5-shaped congregation id through the repository and the ministry route
guard.

### What this pass does and does not establish

Established: the configured debug APK installs, cold-starts, initializes Supabase,
and renders the authenticated shell; `Início` and `Convertidos` render real scoped
readings on the device; the redundant sidebar handoff entry is hidden; and the
`Discipulado`/`Alunos` failure is a client-side identifier-validation defect with a
reproducible local probe.

Not established: login, OAuth, session persistence under a fresh install, create,
edit, finalize, cancel, promotion, enrollment, Storage reads or writes, release
signing, publication, download, restore of real photo bytes, or production
acceptance. The persisted session means the login screen was never exercised, and a
read-only navigation pass never becomes Android or production acceptance.

### Continuation-host re-run (2026-10-23)

The continuation host is Windows 11 25H2 with Flutter 3.47.2 / Dart 3.13.2, not the
pinned 3.47.7 / 3.13.5, so this run is a deviation and not a re-certification of the
`757d0c9` record.

| Check | Result |
|---|---|
| `git rev-parse HEAD` | `77e108d7a2405b954da30efda4c6f1f8378086a5`, the base of this run (the commit carrying this section is its child) |
| `pubspec.lock` SHA-256 | `40C22CD01D6E91716F61E090181D610C9BED66769DA107E368BA5A991E53DCE5` (matches the pinned bytes) |
| `flutter pub get` | `Got dependencies!`, lockfile unchanged |
| `flutter test` | 537 passed / 23 failed |
| `flutter analyze` | `No issues found!` (27.9s) |

None of the 23 failures is a product behaviour failure: 21 are `test/database/*`
scenarios that stop because `psql` is absent (no local PostgreSQL on this host), and
2 are `test/operations/configuration_test.dart` scenarios that the Windows
PowerShell execution policy blocks from running `scripts/maintenance_photos.ps1`.
The 3.47.7 record remains `560/560` for the code under test; it is neither replaced
nor confirmed by this run.

## Skill changes

The four form-relevant skills were edited after baseline pressure scenarios and
rechecked with fresh-context green scenarios:

- `design-oo-ux`: conditional form UX applicability table.
- `a11y-ethics`: conditional form review gate.
- `verification-test`: conditional form test matrix.
- `quality-gate`: conditional form Done gate.

Routing evals: `4` passed.

Published commit: `179c32b` on
`CarlosMonteiroNeto/superpowers-two-model-pipeline`, branch `superpowers-v7`.
The requested `CarlosMonteiroNeto/superpowers` repository does not exist; the
existing fork branch was used instead of creating a new public repository.

## Blockers and approval gates

- **Discipulado congregation selection is verified on-device:** the selector fix
  opens the authorized directory, and selecting a server-supplied congregation
  enables navigation to both `Alunos` and `Turmas`. Both screens rendered their
  empty states without a service error; see the post-fix evidence below.
- **Device audit remains partial:** `Início`, Administration, Discipulado,
  Alunos, and Turmas are verified. Convertidos heading/list state and the
  `Cadastrar aluno` entry on the Alunos page remain unverified.
- **Write journey is scheduled later in the current plan:** T11 and D2 cover
  persisted create/edit/finalize/cancel and Storage/file acceptance after their
  prerequisites. This selector/navigation smoke made no data writes. T11's
  local Supabase stack remains deferred under the user's no-Docker instruction.
- **Legacy phone data not backfilled:** 23 of 51 production convert phones are
  reported as not in the 11-digit national shape (21 other formats, 2 empty), with
  28 in 11 digits and none in E.164. The query behind these counts was not recorded
  in this repository, so treat the numbers as a previous-session report rather than
  a reproducible measurement.
- **Legacy phone preservation is broken for unedited values (Critical):** a stored
  phone that is not 11 digits is displayed verbatim by `brPhoneDisplay`, then fails
  `brPhoneValidationError` in `BrPhoneField`, so a convert carrying a legacy phone
  cannot be saved after an unrelated edit until the phone is cleared or rewritten.
  The `resolveBrPhone` preservation path is therefore unreachable for exactly the
  records it was written for. The claim "legacy preservation when the value was not
  edited" holds only for values that already have 11 digits. Fix and form-level
  regression test are follow-ups, not part of this verification pass.
- **Phase 2 deferred:** `ieadpe_ministry_list_students` still has no
  `new_convert` filter, and handoff promotion still does not set it.
- **Legacy credential rotation:** the previously exposed service-role/database
  credential still needs rotation.
- **Restore evidence:** an isolated restore of the full Auth/Storage dumps remains
  outstanding.

No production data was created, edited, canceled, finalized, or written during
this verification pass.

### Continuation evidence — 2026-10-24

The valid-phone and UUID findings were only partly resolved by the source changes: valid Brazilian national phones normalize to `+55` when persisted or prepared for WhatsApp, and imported Base44 UUID-shaped identifiers are validated by structural shape rather than RFC version/variant bits. **Legacy-phone preservation remains open:** a nonempty stored value outside the 11-digit national shape is displayed verbatim, but `BrPhoneField` still rejects it at validation, so an unrelated edit cannot be saved until that phone is cleared or rewritten. The `resolveBrPhone` path does not preserve such an invalid legacy value. Focused tests cover valid-phone normalization and structural UUID parsing; the current full suite was partial (560/563), as recorded below. No production data was backfilled or edited.

A read-only device audit was repeated using UI hierarchy dumps and filtered app logs (no screenshots or writes). The installed APK hash is `d07ab76cb83ede4bd6185c6ac37147719872b2ad59f70e73d2505fcfc1fc0735`; it predates current source edits. In that APK, `Início` and `Convertidos` loaded; `Discipulado` showed both `Falha ao carregar congregações` and `Nenhuma congregação autorizada está disponível para esta sessão.`; `Alunos` remained gated by the missing congregation. The log excerpt did not expose HTTP/RPC status or exception, so runtime cause remains unconfirmed. See ignored raw evidence in `build/verification/phase1-device-2026-10-24/`.

Installed EDB PostgreSQL 17.11 user-local binaries and initialized a disposable cluster restricted to `127.0.0.1:54329`. An earlier checkpoint on the prior source/environment recorded `flutter test --no-pub --concurrency=1` **565/565** and `flutter analyze --no-pub` passing with Flutter 3.47.7; this is historical evidence, not the full-suite result for the current selector fix. At the time of this earlier entry, the current full-suite run was still reserved for final review; its eventual result is recorded below. This closes local PostgreSQL availability for SQL tests only. Docker/WSL and the full Supabase Auth/PostgREST/Storage stack remain unavailable, so T11, complete browser integration, hosted acceptance, release signing and production acceptance remain open. No hosted change, release action, or production mutation occurred.

### Initial receiver-host verification — 2026-10-24, before the selector fix

This run continued on `codex/ministry-production-completion` at `d8dc47e3799405df6723d9216f9e4fc792453477`. It used Flutter 3.47.7 / Dart 3.13.5 and Temurin Java 17.0.20.1. No Docker installation or Docker command was used.

The newly built debug APK at `build/app/outputs/flutter-apk/app-debug.apk` targets `android-arm64`, is 97,479,107 bytes, has SHA-256 `7A241A49C8E471AC2C5ECF9A4E59C100C4A9CFF8833473A1B72A786B325ED244`, and was built at `2026-10-24T16:34:31-03:00`. `adb install -r` returned `Success`; the installed app cold-started as `br.org.ieadpe.ieadpe_converts/.MainActivity`, and Supabase initialization completed. The Xiaomi `2109119DG` is connected through ADB Wi-Fi at `100.86.40.44:41169`.

The authenticated, read-only Supabase query returned **24 active congregations and 0 archived** (`GET public.congregations`, selecting only `id` and `archived_at`). The ministry directory RPC `ieadpe_ministry_list_congregations` returned HTTP 200 with **24 items** and no next page. The Administration screen showed `Administração` and `Congregações`, with three visible catalog labels; names and session tokens were not saved. This confirms the catalog exists and is readable by the app's current session.

The live Discipulado screen showed `Seção do Discipulado`, `Discipulado`, `Congregação autorizada`, `Selecione uma congregação`, and `Página 1`, with no congregation-load error or empty-directory message. The ministry directory RPC returned the same 24 choices. The on-device picker did not open after verified ADB taps, so a congregation could not be selected and the `Alunos` list was not reached. `Alunos` and its registration entry are therefore `BLOCKED` pending a read-only selection check. `Convertidos` is also `BLOCKED` for heading/list verification because its hierarchy exposed only refresh/filter controls. The final drawer still contains `Cadastrar aluno` and omits the redundant handoff entry. Exact verdicts and sanitized evidence are in `build/verification/phase1-device-2026-10-24/navigation.json`, `discipulado.json`, `admin-supabase-read.json`, and `ui/`.

#### Read-only navigation verdicts

| Check | Verdict | Observed | Evidence |
|---|---|---|---|
| Cold-start authenticated shell | PASS | Main activity started and Supabase initialized; persisted session remained in place. | `ui/00-baseline.txt`; sanitized app log summary in `discipulado.json` |
| Início | PASS | `Visão Geral` and `Atualizar início`. | `ui/02-inicio.txt` |
| Convertidos | BLOCKED | Hierarchy exposed `Atualizar` and `Limpar filtros`, but not a heading or list/empty state. | `ui/03-convertidos.txt` |
| Administração / Congregações | PASS | Screen headings present; 24 active rows readable by the authenticated session. | `ui/07-administration.txt`; `admin-supabase-read.json` |
| Discipulado section | PASS | Section and authorized selector rendered; the directory RPC returned 24 choices without an error/empty state. Picker selection itself remains unverified. | `discipulado.json`; `admin-supabase-read.json` |
| Alunos | BLOCKED | No congregation was selected; the student list was not opened. | `navigation.json` |
| `Cadastrar aluno` entry on Alunos | BLOCKED | Alunos page was not reached, so its in-page registration entry was not verified. | `navigation.json` |
| Redundant handoff drawer entry | PASS | Absent from the drawer; `Cadastrar aluno` remains visible there. | `ui/06-drawer-final.txt` |

The app log contained the Supabase-init message, with no exception marker, RPC path, explicit HTTP status, or secret marker in 179 app lines. The startup scope lookup can conditionally bind a legacy access row; the current account row's `updated_at` remained `2026-10-18T02:24:54.778807Z`, so no such update is evidenced in this run. No create, edit, finalization, cancellation, promotion, enrollment, or Storage action was attempted.

`flutter analyze --no-pub` passed with no issues (793.3 seconds). `flutter build web --no-pub` completed successfully (444.8 seconds); its output included the CupertinoIcons font warning and the standard WASM dry-run notice. The source has no `CupertinoIcons` references or direct `cupertino_icons` dependency; the artifact built and passed preflight. `python scripts/web_preflight.py build/web` passed. The full Flutter suite is reserved for the final review, per the user's direction. Docker-dependent T11, local Supabase Auth/PostgREST/Storage integration, and the integrated browser journey remain deferred; release signing/publication and production acceptance remain out of scope.

The earlier 2026-10-23 Discipulado diagnosis is historical: it predates the current identifier-shape correction. The blocked picker verdict in this initial receiver-host run is superseded by the post-fix device verification below.

### Authorized congregation selector fix — 2026-10-24

This continuation stayed on `codex/ministry-production-completion` at source
commit `d8dc47e3799405df6723d9216f9e4fc792453477`, with the selector fix and its
regression test as local changes. Flutter 3.47.2 / Dart 3.13.2 and Temurin
17.0.20.1+1 built the debug APK for `android-arm64` at
`2026-10-24T18:17:19-03:00`. The APK is 136,321,332 bytes with SHA-256
`E60ED6885AB2CD29EBD7661E6D9E9D0A77462A7F79D88D90E25974F720454E9C`.
`adb install -r` returned `Success`; the app cold-started without clearing its
persisted session.

This product behavior fix was a direct user-requested follow-up to the reported
Alunos/Turmas congregation gate, outside the original plan's evidence-only
boundary. It does not reorder or complete the plan's later persisted/write
acceptance tasks.

The Android UI hierarchy now exposes `Selecione uma congregação` as a clickable
button (`[88,976][992,1130]`). Tapping it opened the authorized choice sheet;
the visible options were clickable and the first authorized option was selected.
The `Alunos` route then rendered `Nenhum aluno cadastrado nesta congregação.`;
the `Turmas` route rendered `Nenhuma turma encontrada.`. No service-error label
appeared on either list. Only selection and navigation taps were made; no form,
create/edit/finalize/cancel, enrollment, promotion, Storage or other write action
was used. Sanitized, ignored evidence is in
`build/verification/phase1-device-2026-10-24/selector-fix.json`.

The focused `test/widgets/unified_navigation_test.dart` file passed **9/9**,
including the new regression for opening the choice sheet and enabling both
scoped list routes. The narrow long-scope/paging regression in
`test/features/ministry/ui/ministry_journey_test.dart` passed after updating its
old dropdown-specific finder. `test/operations/configuration_test.dart` passed
**3/3** when run alone in 7.0 seconds. `flutter analyze --no-pub` passed with no
issues in 491.0 seconds. `flutter pub get` refreshed the native-assets hook for
the active SDK; the initial no-pub attempt had stopped before test execution
with an invalid cached Dart SDK hash.

The first final-review run of `flutter test --no-pub --concurrency=1` ended at
**560/563 passed**. Its failures were the dropdown-specific finder in the
long-scope paging test and 30-second timeouts in the two operation tests above.
Those cases passed in narrow reruns. The full suite was later rerun after the
finder correction and is recorded in the final verification section below.
Docker was not installed or used; T11, hosted/storage acceptance, D2's persisted
journey, release signing/publication and production acceptance remain open under
the existing plan.

#### Updated navigation verdicts

| Check | Verdict | Observed | Evidence |
|---|---|---|---|
| Authorized congregation selector | PASS | Clickable button at `[88,976][992,1130]` opened the server-authorized choice sheet; visible option bounds were `[0,580][1080,734]`, and selecting an option updated the active scope. | `selector-fix.json` |
| Alunos | PASS | `Nenhum aluno cadastrado nesta congregação.`; no service error. | `selector-fix.json` |
| Turmas | PASS | `Nenhuma turma encontrada.`; no service error. | `selector-fix.json` |
| Convertidos heading/list | BLOCKED | Not rechecked in this selector follow-up. | Earlier `navigation.json` |
| `Cadastrar aluno` entry on Alunos | BLOCKED | The Alunos list was opened, but the in-page entry was not verified. | `selector-fix.json` |

The post-fix screen evidence supersedes the earlier conclusion that the
remaining Discipulado blocker was selecting a congregation. The user asked to
follow the existing plan order; this follow-up does not replan the later write
journey. T11 remains deferred because the local Supabase stack requires Docker.

### Local Web runtime smoke — 2026-10-24

This smoke stayed on `codex/ministry-production-completion` at source commit
`d8dc47e3799405df6723d9216f9e4fc792453477`. The first configured Web build
contained `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, but no
`AUTH_CALLBACK_URL`. The app therefore rejected its empty Web callback through
`AuthRedirectPolicy` and displayed `Serviço indisponível`. This was a build
configuration omission, not a congregation or Supabase availability failure:
the read-only `/auth/v1/health` request returned HTTP 200.

Rebuilt locally with the same external Dart-defines file plus
`--dart-define=AUTH_CALLBACK_URL=http://127.0.0.1:8767/auth/callback`; no
credential file or product source was changed. `flutter build web --no-pub`
completed in 305.9 seconds and `python scripts/web_preflight.py build/web`
passed. The build emitted Flutter's standard WASM dry-run notice and a
CupertinoIcons font warning; the generated app rendered normally.

Served `build/web` only on `127.0.0.1:8767` and opened it in an isolated
Playwright Chromium 156.0.8078.4 context with SwiftShader enabled. The
unauthenticated login screen rendered at both 1365×900 and 390×844, including
the `Entrar com Google` button and no `Serviço indisponível` state. The browser
reported no page errors, failed requests, or HTTP errors. The Supabase health
check was read-only; the login button was not activated, OAuth was not started,
and no application data was read or written. Sanitized evidence is in the
git-ignored `build/verification/phase1-web-2026-10-24/` directory
(`web-login-smoke.json` and the desktop/mobile captures).

This verifies local Web boot and responsive login rendering only. OAuth,
authenticated ministry journeys, and browser integration remain open; they
require an interactive session and the existing later gates. Docker-dependent
T11 remains deferred per the user's instruction. The full Flutter suite was not
rerun during this interim Web check; its later final result is below.

### Final verification — 2026-10-24

On `codex/ministry-production-completion`, `flutter test --no-pub
--concurrency=1` completed with **566/566 passed** and exit code `0` after the
targeted selector and operation-test reruns. The full output is saved in the
git-ignored `build/verification/phase1-web-2026-10-24/full-suite-final.log`.
This supersedes the earlier 560/563 partial result. `git diff --check` and the
verification-document secret-marker scan passed. The Web build/preflight and
desktop/mobile login smoke are recorded above.

This final run does not close the untested OAuth or authenticated Web journey,
the legacy-phone save blocker, the Convertidos heading/list and Alunos
registration-entry device checks, or Docker-dependent T11/D2. No production
write, release signing, publication, or Docker action was performed.
