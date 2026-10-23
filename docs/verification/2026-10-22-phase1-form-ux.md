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
`ui-text.txt`. This pass installed, cold-started, and read the screen only: no
write or mutation, no Storage access, and no screenshot.

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

- **Discipulado scope defect remains open:** the app previously showed
  `Não foi possível carregar as congregações autorizadas.` and
  `Nenhuma congregação autorizada está disponível para esta sessão.` while a
  direct scoped RPC returned HTTP 200 with non-empty results.
- **Write journey not exercised:** create, edit, finalize, cancellation, and
  Storage writes still require explicit approval.
- **Legacy phone data not backfilled:** 23 of 51 production convert phones are
  not in the 11-digit national shape (21 other formats, 2 empty); 28 have 11
  digits and none are E.164. New input does not silently rewrite them.
- **Phase 2 deferred:** `ieadpe_ministry_list_students` still has no
  `new_convert` filter, and handoff promotion still does not set it.
- **Legacy credential rotation:** the previously exposed service-role/database
  credential still needs rotation.
- **Restore evidence:** an isolated restore of the full Auth/Storage dumps remains
  outstanding.

No production data was created, edited, canceled, finalized, or written during
this verification pass.
