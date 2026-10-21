# B0/L0 toolchain and evidence identity — 2026-10-21 continuation

<!-- canonical-document-authority -->
> **Dated evidence record.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. This record documents B0/L0 prerequisites only; it does not approve product, L0, hosted, Android or release acceptance.

## Scope and candidate

| Item | Observed value |
| --- | --- |
| Worktree | `C:/Users/Carlos_Neto/.codex/worktrees/ministry-supabase-config/App discipulado` |
| Branch | `codex/ministry-production-completion` |
| HEAD | `ea0875b3f235be664c66bd7cb4ae17cbb6205119` |
| Working tree | clean (`git status --porcelain=v1` empty) |
| `pubspec.lock` SHA-256 | `40c22cd01d6e91716f61e090181d610c9bed66769da107e368ba5a991e53dce5` |
| Prior local candidate manifest | `final-local-candidate-manifest.json`, SHA-256 `6428611dbcc5a8464a4b1949bffc1462795e41e3db24523f6212032eab70a0c6` |

All seven tracked source/test deltas named by that manifest match the current committed bytes (7/7, including `test/workflows_test.dart`, `scripts/test_unified_gate.py`, `scripts/test_verification_cases.py`, `scripts/verification_cases.py`, `scripts/test_hosted_upgrade.py`, and the two `test/operations/corrective_*` wrappers). No dirty or untracked source change exists outside git-ignored evidence directories at capture time.

## Resolved executors

| Role | Absolute path | Version / proof |
| --- | --- | --- |
| Pinned Flutter SDK bin | `C:/Users/Carlos_Neto/.codex/tools/flutter-3.47.7-full/flutter/bin` | `flutter --version` exit 0 |
| Pinned Flutter | `.../flutter-3.47.7-full/flutter/bin/flutter.bat` | Flutter 3.47.7, framework `abaf9c5237`, engine `deb287481e`, Dart 3.13.5 |
| Pinned Dart | `.../flutter-3.47.7-full/flutter/bin/dart.bat` | Dart 3.13.5 (stable), windows_x64 |
| Git Bash | `C:/Program Files/Git/bin/bash.exe` | `--noprofile --norc` probes exit 0 |
| Git Bash bin | `C:/Program Files/Git/bin` | provides `bash`, Unix utilities |
| Python | `C:/Users/Carlos_Neto/AppData/Local/Programs/Python/Python312/python.exe` | Python 3.12.10 |
| `python3` (Bash) | `C:/Users/Carlos_Neto/bin/python3` | wrapper `exec`s the same Python312 `python.exe` (verified `sys.executable`) |
| PowerShell | `C:/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe` | Windows PowerShell 5.1.19041.3930; `pwsh` is not installed |
| Global command runner | `C:/Users/Carlos_Neto/.codex/skills/two-model-sdd-pipeline/scripts/cmd` | `--full-file FILE -- CMD...` contract observed |

The pinned SDK is the `flutter-3.47.7-full` extraction. The sibling `flutter-3.47.7` directory is incomplete (`packages/flutter_tools/pubspec.yaml` absent) and loops on `pub upgrade`; it must not be used. `flutter-3.47.7-fast` and `-runtime` are partial copies. The official Windows archive at `C:/Users/Carlos_Neto/.codex/tools/flutter_windows_3.47.7-stable.zip` hashes to the published release digest `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`.

## Three-process PATH resolution proof

Each process ran with a process-only appended PATH (`pinned SDK bin`, `Git bin`, `Python312`); the parent PATH was restored in a `finally` block (`PARENT_PATH_RESTORED=True`).

| Process | Flutter | Dart | Python |
| --- | --- | --- | --- |
| Python `shutil.which` | pinned `flutter.BAT` | pinned `dart.BAT` | `Python312\python.EXE`; `python3.EXE` |
| Bash `command -v` | pinned SDK `flutter` | pinned SDK `dart` | `~/bin/python3` → same Python312 interpreter |
| PowerShell `Get-Command` | pinned `flutter.bat` | pinned `dart.bat` | `Python312\python.exe` |

Child versions observed in every process: Flutter 3.47.7, Dart 3.13.5, Python 3.12.10. Raw log: `build/verification/corrective-release/B0-toolchain-2026-10-21/probes.log` (local, git-ignored).

## Platform inventory

| Component | Observed value | Disposition |
| --- | --- | --- |
| JDK | Temurin 25.0.4+7 LTS, `JAVA_HOME` set | present; Gradle/AGP compatibility not exercised (no build) |
| Gradle wrapper | `gradle-9.3.1-all.zip` | configured only |
| Android SDK | platform 36, build-tools 36.0.0, platforms 33/34/35/36, cmdline-tools latest | present |
| Android emulator | 33.1.24.0; AVDs `codex_android_smoke_api31`, `codex_android_smoke_api34` | bootable state not established; no device attached |
| Emulator acceleration | HAXM 7.6.5 installed and usable; HAXM deprecation warning | boot/ADB still unproven |
| Android licenses | some not accepted (`flutter doctor`) | prerequisite gap, not a product failure |
| Chrome | 155.0.8059.85 | present |
| ChromeDriver | 155.0.8059.84 | major version matches Chrome; patch build differs by one |
| Supabase CLI | 2.121.0 | version only; no credential/status probe |
| Docker engine | `docker info` timed out with no output | BLOCKED; prior evidence records WSL Virtual Machine Platform disabled |

## Evidence archive validation

Read-only validation (no extraction or execution of archived tooling): 522 tar members are regular relative files with matching declared sizes/SHA-256, total 18,148,750 bytes; the reviewed ZIP has 28 entries (27 manifest-indexed plus the candidate manifest whose published SHA is checked); the recovered-history ZIP has 16 entries matched through its documented `archive_path` mapping. CRC, path-safety, presence and hash checks all pass.

| Archive | SHA-256 | Result |
| --- | --- | --- |
| `docs/verification/handoff/2026-10-21-corrective-evidence.tar.gz` | `a2eca52bab31566dfc2cdaa7aca2ef93e9cc8a78f598473745fd9be58dd2104e` | 522/522 members, PASS |
| `docs/verification/consolidation/2026-10-21/reviewed-local-evidence.zip` | `034df43a08dd675e7d958a0872785e2d70e066d73c0e9a6312f980a40d6361eb` | 28/28 entries, PASS |
| `docs/verification/consolidation/2026-10-21/recovered-local-history.zip` | `31bcadd71ec0066088b4008b39a1538d73b21911516e3d1ffbb4dda20ff4f3c0` | 16/16 entries, PASS |

## Unit evidence locator index

Every current-plan locator was resolved or explicitly absent:

| Unit | Locator | Result | SHA-256 |
| --- | --- | --- | --- |
| B1 | `tar:B1/review.md` | present | `cdb91b98b10c06ecb97105c88457ab6fc20efef1fef1a7bfed68f887af8cdfe9` |
| B2 | `tar:B2/review.md` | present | `ed9e0b29c8fd386b37b387c680d81b777ecae279175ccd478f8bed8000a1994e` |
| B2 | `tar:B2/promotion-review.md` | present | `02b22662a60c11a8c76b7ab79a5da06b1617f1b7b9a8fdc430325fc72183f21c` |
| B3 | `tar:B3/review.md` | present | `44283b6db8b42b9ed5b7e8b3f6df8ada345e7669efb6b74606ca4de2ecfb21f4` |
| T01 | `tar:T01/review.md` | present | `996453d84dcad924900fc94e906e6405458de3c6a7a1b82be2b6337341cb5c86` |
| T02 | `tar:T02/review.md` | present | `8802ac09232341c4c01eff5871f6ad3edd4ae5ab4aa797771eb204c6a5868962` |
| T03 | `tar:T03/coder-report.json` | present (director-attributed; no final review) | `51c084f2496dc989c2f322f25a97da8e611182f8259c7582642b79f24af24945` |
| T04 | `tar:T04/coder-report.json` | present (director-attributed; no final review) | `6a8d589c9fac7e4440d9e3b0486c0a29cc71cee77ab586d18fa8b26be362c371` |
| T04-P | `tar:T04-first-save/sol-final-review.md` | present | `1da3702da9dc3c67f8bd1790e89cba7a48db1e1da4e0c9dc6302b1d6e59f2ba8` |
| T05 | `tar:T05/coder-report.json` | present (director-attributed; no final review) | `9ef6c744143046f11ba8c19c910f2e2ad26714e262125bd4466f7bf6da6a9b7a` |
| T06 | `tar:T06/coder-report.json` | present (director-attributed; no final review) | `03d4495df47e59488fdc0c31f8786055f76004e36da4570942a1b4304a0d2e22` |
| T07 | `tar:T07/coder-report.json` | present (director-attributed; no final review) | `502c7eee06e98b3ab8a112ecfadc19b0c21cbd8639e823bd9cf7f50a65f64985` |
| T08 | `zip:T08/captured-zone-stage-report.json` | present | `a9fb4febe64594277a1a082458768884ad393ef6222ce2c450136e7b0768afa3` |
| T09 | `zip:T09/coder-report.json` | present | `39291ccb71088a978faadff71756d7dc186e65f886c2e1588c9385321f2d97ea` |
| T10 | `zip:T10/final-candidate-report.json` | present | `d3059daa84f9ec6655372f946e1b3c8bb3671d81faee5c887047a024c31c775b` |
| T12 | `tar:T12/continuation-006/sol-final-review.md` | present | `fa2ebd74f8d60c208061354162691d7c1faef1e64352ed4fbff3da24798f5372` |
| T12 | `zip:T12/windows-fixture-followup/sol-final-review.md` | present | `7d5bcf537844f5385d0aeb6ac7982f2480a82de7ab239ff8d4fa9abe2fdb6ff6` |
| L0 | `tar:CHECKPOINT-T04-T07/checkpoint-report.json` | present | `9dd81ad322cfc6f70fbfa507abfb941b7225ed3772b0032f98f95bd01683271c` |
| L0 | `zip:final-local-candidate-manifest.json` | present | `6428611dbcc5a8464a4b1949bffc1462795e41e3db24523f6212032eab70a0c6` |

Explicit absences retained, not reconstructed: individual durable final reviews for T03–T10 (T03 has an initial review only); the two L0 approval-index JSONs excluded by credential scanning; missing later device/smoke/timeout raw logs referenced only by dated reports. No absent artifact is treated as PASS.

## Environment disposition

- Pinned toolchain and evidence identity: **resolved** for this candidate.
- Docker/owned local Supabase: **BLOCKED** (`docker info` timed out; prior WSL Virtual Machine Platform root cause remains the recorded evidence).
- Bootable Android target: **BLOCKED** (no attached device; both AVDs exist but prior boot attempts stayed ADB `offline`; licenses not fully accepted). No APK was built or installed.
- PowerShell gate: **adapted, not blocked** — see ruling below.

Ruling: `$MinistryPwsh` is Windows PowerShell 5.1 because `pwsh` is not installed and 5.1 rejects `-CommandWithArgs`; gate scripts must use `-NoProfile -File` or an explicit `-Command` argument array, and `scripts/verify_unified.ps1` already documents 5.1 handling. Cost if wrong: a PS7-only construct would fail visibly at the gate; no product result is inferred.

No product test, migration, hosted access, build or publication was performed for this B0 record.
