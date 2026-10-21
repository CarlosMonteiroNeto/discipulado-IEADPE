# SDK and font provenance for visual tests (B2)

Observed on 2026-10-20 with `PATH=/workspace/.toolchains/flutter/bin:/workspace/.local/bin:$PATH`.

## Toolchain

| Item | Observed value |
|---|---|
| Flutter | 3.47.7, channel stable, `https://github.com/flutter/flutter.git` |
| Framework revision | `abaf9c523780a608bd46686fd5e53740a07077f8` (reported as `abaf9c5237`, 2026-10-08) |
| Engine revision | `deb287481e3ce9468f3434937ced4240a70539ca` (reported as `deb287481e`) |
| Engine hash | `d8a2d6c768c334d53e16277f837970ffa1e2de81` |
| Dart | 3.13.5 |
| DevTools | 2.60.0 |

Raw command output is retained in
`build/verification/corrective-release/B2/toolchain.txt` and
`build/verification/corrective-release/B2/framework-git.txt`.

## Font files

The SDK material-fonts directory is
`/workspace/.toolchains/flutter/bin/cache/artifacts/material_fonts`.

| Role | Canonical file | Size | SHA-256 |
|---|---|---|---|
| Regular text | `Roboto-Regular.ttf` | 171676 bytes | `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95` |
| Icons | `MaterialIcons-Regular.otf` | 1645184 bytes | `d9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453` |

The environment also contains lowercase symlink aliases:

- `roboto-regular.ttf -> Roboto-Regular.ttf`
- `materialicons-regular.otf -> MaterialIcons-Regular.otf`

They resolve to the same bytes (the alias hashes match the canonical hashes above).
B2 did not modify these aliases.

## Helper contract and proof

`test/support/sdk_fonts.dart` provides:

```dart
Future<void> loadSdkFont(String family, List<String> candidateNames)
File resolveSdkFontFile(String family, List<String> candidateNames)
```

`resolveSdkFontFile` walks upward from `Platform.resolvedExecutable`, appends
`bin/cache/artifacts/material_fonts`, and also considers `FLUTTER_ROOT` when set.
It checks candidate filenames in the supplied order, so every suite passes the
canonical filename first:

```dart
await loadSdkFont(family, const [
  'Roboto-Regular.ttf',
  'roboto-regular.ttf',
]);
await loadSdkFont('MaterialIcons', const [
  'MaterialIcons-Regular.otf',
  'materialicons-regular.otf',
]);
```

If no candidate exists, the thrown `StateError` includes the requested family,
all candidate filenames and every searched path.

The gallery suite contains two targeted proof tests:

1. Resolution of both fonts ends in the canonical `material_fonts/<Canonical>.ttf|.otf` path, and `FileSystemEntity.isLinkSync` is false for both resolved paths.
2. A deliberately missing family/candidate fails with the family, candidate and `material_fonts` search root in the message.

The focused test log is
`build/verification/corrective-release/B2/focused-green.log` (exit 0). The helper
RED evidence is retained as `helper-red-assertion.log`.

All four visual suites use this shared helper; no suite contains its own SDK font
lookup. The font-family substitutions remain deterministic:
`GalleryRoboto`, `TeamGoldenRoboto`, `SessionVisualRoboto`,
`ClassManagementGoldenRoboto`, and `MaterialIcons`.

## Captures produced by the tests

- Session: `build/verification/corrective-release/B2/session-captures/` (21 PNGs).
- Class: `build/verification/corrective-release/B2/class-captures/` (1 PNG).
- Gallery/Team candidate references used for review before promotion:
  `build/verification/corrective-release/B2/golden-candidates/` (24 PNGs).

The tests do not write to tracked documentation. Font and capture hashes are
environment evidence; they do not assert that every future SDK ships identical
font bytes.
