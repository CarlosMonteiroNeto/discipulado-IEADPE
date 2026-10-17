# Unified Convert-to-Student Journey — Design Spec

Status: app composition and local journey implemented through commit `0c6b969`; integrated-browser and human accessibility/release evidence remain incomplete. Depends on the completed convert app and ministry Supabase port.

## User journey

A campaign registrar adds a convert; authorized direction or supervision follows campaign visits. Authorized ministry staff can create a student from a convert after a congregation is assigned. The student is linked once to the original convert, then may be enrolled in a class by a separate action. The linked view shows only data that the current grant permits. Conversion history and attendance remain separate histories and metrics.

Default role matrix for planning: an authenticated registrar may create converts and submit feedback, but may not list records; direction reads/writes campaign records in granted congregations; supervision manages campaign records globally; ministry staff read a minimal referral and manage students/classes/attendance only in their granted congregation; the trusted admin manages grants and both modules. A ministry staff grant alone never permits full conversion history, photos or campaign reports. A supervisor may grant the same verified UID multiple roles explicitly; no role is inferred from an email string. Existing IEADPE email/password users need trusted identity mapping to Google OAuth before their old access is retired; local implementation uses synthetic accounts and leaves real-user cutover to release work.

Campaign supervision and ministry supervision are separate permissions. A ministry supervisor with no granted congregation chooses one explicitly from the bounded server directory before scoped reads/actions; the client never selects the first result implicitly. Empty, loading and failed directory states remain visible and retryable. The server rechecks the selected scope on every RPC.

## Handoff contract

One server-owned, idempotent `ieadpe_promote_convert_to_student(operation_id uuid,payload jsonb)` RPC locks actor scope and relevant records in documented order, validates `convert_id`, chosen congregation and optional reviewed `student_id`, and returns minimal IDs/status. `ministry_students.convert_id` is unique. Two concurrent requests or a lost response must produce one link. Name-only matching never auto-merges. If a student already exists, an authorized reviewer chooses the exact scoped student; out-of-scope candidates are not listed. Terminal/archived convert behavior is specified in a lifecycle matrix before code. An unassigned convert cannot be promoted until an authorized assignment is made.

Default lifecycle matrix: a non-deleted convert, including one completed or deviated, may be linked for historical continuity if congregation and actor scope match; a soft-deleted convert cannot be newly linked. Existing links remain after terminal status changes or later archival and are visible only through the appropriate module's projection. Promotion never reopens campaign lifecycle actions. The detailed acceptance tests must pin this matrix before the RPC is written.

Conversion fields are canonical on the convert record; student education/baptism/enrollment fields are canonical on the student record. On first promotion, copy name/phone/address as an initial snapshot with provenance; later edits do not silently synchronize. A congregation change after linking requires an explicit authorized transfer rule and is deferred unless the first implementation includes a safe transfer command. UI labels disclose which record owns an editable field.

## UI and skills

Use the existing convert shell and compose IEADPE ministry routes through one session/role guard. Compare both palettes and define shared semantic tokens before visual composition. `design-oo-ux` supplies a class sketch and one sequence diagram for handoff; `apple-design` governs responsive navigation, direct feedback and interruptible motion; `a11y-ethics` supplies keyboard, screen-reader, contrast, privacy and deliberate WhatsApp checks. Automated layout/accessibility assertions are regression evidence only; 360/768/1440 visual inspection, 200% text, keyboard, screen reader, reduced motion and contrast require a recorded human review before release. Errors preserve drafts and do not announce success.

## Acceptance

Test no-congregation, duplicate existing student, archived/terminal convert, revoked grant, concurrency, retry, route refresh and identity switch. Route tests exercise the history adapter's refresh/back/forward decisions and direct unauthorized paths; hosted static-site rewrite and refresh remain release checks. A staff user with student scope but no convert scope receives only a minimal referral projection if authorized by the finalized role matrix, never full conversion history by accidental join. This projection must be RLS/RPC-enforced. No automatic enrollment, baptism inference or historical event rewrite.
