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
- SHA-256: `941070376770C5DF238AF406BA20F5A4274DD0BE7631865963AA4EB6068943EA`

The APK is a debug build. Release signing, publication, and production-device
acceptance remain gated.

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

- **Device pass blocked:** `adb devices -l` reported no attached device. The APK
  could not be installed and the read-only Android navigation pass could not be
  repeated.
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
