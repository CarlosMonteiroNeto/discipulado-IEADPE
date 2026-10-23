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

- **Discipulado scope defect diagnosed, fix pending:** the app shows
  `Não foi possível carregar as congregações autorizadas.` and
  `Nenhuma congregação autorizada está disponível para esta sessão.` while a
  direct scoped RPC returns HTTP 200 with non-empty results. The cause is the
  client-side RFC 4122 validation described above, which rejects the Base44-derived
  congregation ids; the shared-validator fix and its regression test remain a
  follow-up task and are not implemented in this pass.
- **Device audit artifact review open:** the 2026-10-23 `navigation.json` and UI
  dumps were not transferred to the continuation host, so the read-only audit is
  recorded as second-hand provenance and not as a reviewed artifact.
- **Write journey not exercised:** create, edit, finalize, cancellation, and
  Storage writes still require explicit approval.
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
