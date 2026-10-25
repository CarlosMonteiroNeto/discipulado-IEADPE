# Web completion review — 2026-10-25

## Review identity

- Reviewer: GPT-6.1 Sol, low reasoning effort.
- Verdict: **W5 NOT READY for general Web acceptance**.
- Worktree: `C:/Users/Carlos_Neto/.codex/worktrees/ministry-production-completion`.
- Branch and HEAD: `codex/ministry-production-completion`, `6f02664af3bd86ce5c71771c02e834eb83f9ab8c`.
- Candidate manifest reviewed: `docs/verification/2026-10-25-web-completion-candidate.json`, SHA-256 `c53c9fd5a7324dad22464826ad823badbfa229e2dbc8e9ee31999465295ca13d`.
- Reviewer verified all 17 source/report and Web artifact hashes and sizes listed in that manifest, inspected the current source/test changes and relevant plan/report documents, and found `git diff --check` clean.
- Reviewer did not run the complete Flutter suite or perform hosted writes.

## Findings

### Critical

- None identified.

### Important

1. **Web photo upload remains broken.** `lib/features/photos/photo_repository.dart` reaches the authenticated Storage upload, but the hosted SDK multipart upload and bounded raw JPEG POST both fail with Storage RLS denial. The convert form cannot finish saving when a new photo is attached. The more accurate photo-specific error message and focused regression test improve feedback but do not restore the feature. Cause-specific resolution and a successful hosted Web upload/cleanup are still required.
2. **Hosted authorization boundaries remain unproven.** There is no hosted evidence for cross-congregation denial or revocation of an already-issued token because an authorized least-privilege actor and separate revocable token were unavailable. This is an acceptance blocker; it is not evidence of a proven authorization vulnerability.

### Minor / operational residual

- The prior misleading “access changed” message was corrected; the reviewer found no new issue in its error mapping or focused tests.
- Rotation of the exposed legacy service-role credential remains required before external publication. The review found no evidence that it is in the current Web bundle; this operational owner/security action is separate from the two functional/acceptance blockers.
- The fixes for registration idempotency, contextual student fallback, static redirects, and photo error reporting were considered adequate in the reviewed diff.

## Gate disposition

- W5: **NOT READY** until both Important findings are resolved and a fresh candidate-bound general Web review passes.
- W6: **BLOCKED BY W5**. The complete suite remains unrun in this continuation, consistent with the user's requested order.
- W7 and conditional branch push: **PENDING**. The branch is not Web-ready, so no push or merge has occurred.
- Docker and Android/Wi-Fi work remain excluded from this Web continuation.

This receipt records the reviewer’s exact candidate and verdict. The candidate manifest was subsequently refreshed only to include this review result and updated plan/report digests; no application source or built Web artifact changed as part of recording the receipt.

## Focused follow-up after local policy correction

A read-only GPT-6.1 Sol low follow-up initially reviewed the forward migration and photo SQL scenario after the local correction. It returned **local policy review PASS** with no new Critical or Important findings. Further inspection of the tagged Storage 1.80.2 implementation showed that `metadata.contentLength` is the full HTTP request length for multipart uploads, including the form envelope. The migration and test were therefore refined after that focused review: the policy now permits up to 8 KiB of envelope above the 1 MiB bucket file limit, and the SQL case exercises that boundary. The actual JPEG part remains limited by `storage.buckets.file_size_limit`. This final refinement has passed the focused SQL scenario, but still requires fresh reviewer assessment and hosted proof; the initial follow-up verdict does not bind to this later diff.

The candidate-bound whole-branch review for manifest `d76efddb…ee661d1e` returned **W5 NOT READY** and found the manifest omitted the changed `supabase/tests/database/photos_test.sql`; that identity gap was corrected before the next review.

## Current candidate-bound general review

- Reviewer: GPT-6.1 Sol, low reasoning effort.
- Candidate manifest SHA-256: `d3adab1c13af69253cb28aeb50e23352cc0eac6d93fcefe203c81d155afddfa4`.
- All 20 listed source/report and Web-artifact digests and sizes were verified; `git diff --check` passed.
- Local code review: **PASS**, no new Critical or Important code findings. The reviewer verified that the 8 KiB request-envelope allowance is adequate for the installed `storage_client 2.8.1`/`http 1.6.0` multipart request: estimated overhead 366 bytes for a 1 MiB JPEG. The bucket remains the actual 1 MiB JPEG-part enforcement boundary.
- W5 general acceptance: **NOT READY**. Important blockers remain: the hosted policy is unchanged and the hosted upload/attach/reload/read/cleanup journey is unproven; W2 still lacks an authorized least-privilege actor/token for cross-congregation denial and existing-token revocation.
- No hosted writes or complete Flutter suite were run by the reviewer.
