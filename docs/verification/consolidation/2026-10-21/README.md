# Local branch and worktree consolidation — 2026-10-21

The user explicitly authorized preserving and committing the local work and merging useful branch changes into `codex/ministry-production-completion`. `main` remains a source of reviewed changes, not the integration destination. Hosted Supabase operations, APK builds and publication remain outside this operation.

## Canonical workspace

Use `C:/Users/Carlos_Neto/.codex/worktrees/ministry-production-completion` for subsequent work. Two independent clones of the same GitHub repository caused the workspace ambiguity:

- `C:/Users/Carlos_Neto/FlutterProjects/discipulado-IEADPE` owns the canonical worktree and its branch refs.
- `C:/Users/Carlos_Neto/FlutterProjects/App discipulado` owns the older `flutter-supabase`, `implementation/supabase-free` and `ministry-supabase-config/App discipulado` checkouts.

The second clone's `origin/main` was stale. Fresh `git fetch origin` and `git ls-remote --heads origin` in the canonical repository confirmed exactly two hosted branches: `main` at `c71534d` and `codex/ministry-production-completion` at `d0d0e0f` before consolidation.

## Branch disposition before integration

| Source | Tip | Relationship to canonical `d0d0e0f` | Disposition |
| --- | --- | --- | --- |
| `origin/codex/ministry-production-completion` | `d0d0e0f` | Same commit | Preserve today's dirty delta on this branch. |
| Local `codex/base44-unified-access` | `b9daebc` | Already an ancestor | No code needs reapplication. |
| Local `codex/supabase-unification` | `1ad3c3b` | Already an ancestor | No code needs reapplication. Its 13 commits ahead of `main` are already included here. |
| Other clone `implementation/supabase-free` | `f821d62` | Already an ancestor | No code needs reapplication. |
| Other clone `flutter-supabase` | `c321e81` | One distinct commit identity, equivalent patch already present as `22ff68d` | Record integration using the `ours` strategy only after equivalence review; keep the current implementation. |
| `origin/main` | `c71534d` | Two commits absent from the destination: `0a0f4db`, `c71534d` | Merge documentation into the destination, preserving current contracts. |

`git cherry HEAD local-app/flutter-supabase` marked `c321e81` with `-`. Independent review confirmed both it and `22ff68d` have patch-id `00f7a9bdc6a66feeaa749d338faf2a729cf300b1`. The local `local-app/flutter-supabase` remote-tracking ref was imported from the other on-disk clone solely to compare and integrate this history.

## Uncommitted file disposition

- The seven modified Python/Dart source and test files, current plan amendment and local report are preserved as the reviewed local correction delta. This is verification infrastructure and test-fixture work; it does not add a new application feature.
- Four untracked 2026-10-18 requirements/design documents match the versions in `main` after newline normalization. They are recovered once, without duplicating their contents.
- Thirteen package research JSON files in the old clone are identical to existing canonical files. Hooks differ only by newlines; the cloud setup document differs only by a trailing blank line.
- Old specs/plans, an old handoff test, and unique old pipeline tools are retained in `recovered-local-history.zip` with per-file hashes and original source paths in its manifest. These 16 historical files are not activated or substituted for current versions. The old handoff test omits canonical-person/revision/structured-address checks now present in the canonical test.
- Personal image attachments, machine-local `.codex/config.toml`, CLI caches and diagnostic logs remain in the external recovery backup. No credentials or device-specific settings are intentionally committed.
- Sixteen synthetic golden failure images are included in `reviewed-local-evidence.zip`. They document failures; they do not replace or approve golden baselines. Raw generated copies remain local.

## Durable recovery and evidence

External recovery directory: `C:/Users/Carlos_Neto/AppData/Local/IEADPE/consolidation-2026-10-21`. It holds both clones' all-ref Git bundles, working-file ZIPs, an additional old pipeline worktree ZIP, file hashes and copies of the portable archives. Source checkouts are preserved.

| Portable archive | SHA-256 |
| --- | --- |
| `recovered-local-history.zip` | `31bcadd71ec0066088b4008b39a1538d73b21911516e3d1ffbb4dda20ff4f3c0` |
| `reviewed-local-evidence.zip` | `034df43a08dd675e7d958a0872785e2d70e066d73c0e9a6312f980a40d6361eb` |

The evidence ZIP has 28 entries: the original candidate manifest, its 11 referenced reports/logs/reviews, and 16 failure PNGs. All original evidence hashes and ZIP CRCs were checked before staging. Original `build/...` paths are retained within the archive so older report references remain interpretable. Existing tracked handoff archives remain available separately.

## Verification and limitations

The existing source-bound evidence reports Flutter 3.47.7/Dart 3.13.5: 546/548 tests, analyzer/Web build/static preflight passing. Independent Sol 6.1 low review approved preserving this local delta and reviewed the branch strategy and recovery archives. This approval does not close L0 or approve release.

A new consolidation run of `python -m unittest scripts.test_verification_cases scripts.test_unified_gate scripts.test_hosted_upgrade` executed 54 tests in 348.596 seconds and exited 1: 53 completed without errors and one Bash gate subprocess exceeded its 90-second timeout (`test_database_child_failure_is_retained_as_its_exact_exit_code`). A focused rerun of that exact test passed in 27.988 seconds (exit 0). This identifies an intermittent subprocess timeout; its underlying timing cause is not established and the broader run remains failed. Both logs are retained alongside this report. The default installed Flutter is 3.47.2/Dart 3.13.2 and must not be confused with the previously recorded pinned SDK.

Historical 528/529 disposition, the two current golden failures, real local T11, Android execution and the remaining hosted/signing/release gates stay open. Finalized attendance remains immutable: cancel a finalized call and record a linked replacement to correct it. No SQL, application `lib/`, Android signing or hosted configuration change is required for this consolidation.

## Integration outcome

The checkpoint and merge identities are recorded in the final consolidation result document after Git integration and review. A commit preserves unfinished work; it is not acceptance of the application or permission to build/publish an APK.
