# Convert UI and ethics audit

Scope: completed convert UI only, using source inspection and existing test artifacts. This is not a manual browser/device or assistive-technology audit. No screenshots or human task observations are recorded; unexecuted checks are marked incomplete. The integration comparison belongs to the unified journey and no theme change is proposed here.

## Structure and composition sketch

**UML choice: sequence diagram.** The highest-risk design question is temporal: how a route obtains scope, hides protected content during revalidation, and clears caches on identity/scope loss. A static class diagram would not show that ordering. The view below captures the existing convert shell boundary and the future ministry composition point.

```mermaid
sequenceDiagram
    actor User
    participant Root as App / SessionRouter
    participant Auth as AuthGateway
    participant Ports as Feature repositories (typed ports)
    participant Adapter as Supabase gateway / Storage adapter
    participant UI as AppShell + feature pages
    User->>Root: Open guarded route / resume / identity change
    Root->>Auth: refresh() or revalidate()
    Auth->>Adapter: load current session scope
    Adapter-->>Auth: current grants or failure
    alt allowed and same identity/scope
        Auth-->>Root: authorized AccessScope
        Root->>UI: show allowed feature route
        UI->>Ports: request scoped feature data
        Ports->>Adapter: typed query / RPC
        Adapter-->>Ports: scoped result
        Ports-->>UI: domain result
    else identity, scope or validation failure
        Root->>Root: clear protected caches; hide route
        Root-->>UI: login, safe route or recoverable unavailable state
    end
```

Composition-first port sketch: `SessionRouter` owns session/scope and safe route selection; `AppShell` receives a child, current route, navigation/sign-out callbacks and an `AccessScope`; each feature page composes a repository interface; repositories depend on typed domain operations; one Supabase adapter implements Auth, scoped reads, RPC and Storage. The existing `lib/routing/router.dart` documents that every protected repository/cache registers a synchronous clear callback. The future ministry module should compose into those ports and guard, not duplicate the root session or cache owner. Enforcement remains PostgreSQL RLS/RPC; route affordances are presentation only.

## Screen and accessibility evidence

| Review dimension | Evidence inspected | Finding / status |
|---|---|---|
| 360 px | `test/widgets/app_shell_test.dart` sets 360×800; `test/app_smoke_test.dart` sets 360×640; `lib/widgets/app_shell.dart` switches navigation below 768 px. | Automated narrow shell/smoke paths exist and are included in the reported 240 passing tests. This does not establish every screen's no-overflow behavior. Severity: SQC follow-up, medium. |
| 768 px | Shell breakpoint is explicitly `< 768`; `test/widgets/app_shell_test.dart` exercises configured widths. | Boundary logic has automated coverage. Exact per-page layout at the breakpoint has not been manually reviewed. Incomplete. |
| 1440 px | No audit evidence found that exercises every screen at 1440 px. | Incomplete; no claim of wide-screen visual review. |
| 200% text | Shell, Home, weekly, reports, feedback, convert forms/lists tests use `TextScaler.linear(2)`; final report says suite passed. | Automated scaling coverage exists for selected feature surfaces; not a substitute for visual/manual review across all pages. |
| Keyboard/focus | Flutter controls provide focusable buttons/forms; `test/app_smoke_test.dart` inspects focus; feature traversal and form tests exist. | Some automated focus evidence, but complete keyboard-only end-to-end paths and focus restoration after dialogs/drawers are not documented. Incomplete, medium SQC. |
| Screen reader | `Semantics(selected: ...)` in shell, tooltips on menu/feedback, and `liveRegion` status/error messages in form, registration, reports, weekly and other views; associated widget tests exist. | Source has explicit names/state/outcome patterns. No actual TalkBack/VoiceOver run or full announcement review is recorded. Incomplete, medium SQC. |
| Reduced motion | Tests set `MediaQueryData(disableAnimations: true)` in shell and feature tests; design says respect this signal. | Automated configuration is exercised; no manual motion inventory or device-level reduced-motion review recorded. Incomplete. |
| Contrast | Existing navy/blue branding and semantic states are visible in source; no measured contrast report found. | Incomplete; quantify text/control contrast before unified theme work. |
| Motion/feedback | Forms, reports and feedback expose loading/error/success states; final report notes reduced-motion widget coverage. | No evidence of gesture-driven motion requiring a new spring system. Keep current restrained behavior; manually assess latency and interruptibility when future UI adds motion. |

Nielsen severity classification based on inspected artifacts: **S0** none established; **S1** none established; **S2** medium follow-up for undocumented complete keyboard/screen-reader and 1440 px/contrast validation; **S3** low completeness gap for manual reduced-motion/feedback observations. These are evidence gaps, not confirmed user-facing defects. Record actionable code fixes only after a reproducible behavior assertion identifies an owning file.

## Privacy and contact ethics

`lib/features/converts/convert_card.dart` calls `launchUrl` only from the visible WhatsApp button handler. `lib/features/converts/convert_actions.dart` strips non-digits, rejects letters, applies Brazil country code policy and builds a `wa.me` URI; `test/features/converts/list_test.dart` covers URI formatting and disables invalid-phone actions. This is deliberate user activation; there is no automatic message send or prefilled religious text in the inspected code. No separate user consent-recording workflow is evidenced. Future contact UX should disclose that the external app receives the number and require the same deliberate tap.

Router paths are fixed known route names (`/login`, `/register`, `/home`, `/converts`, `/admin`); inspected code does not encode phone or religious fields in query parameters. Error/status UI uses human-readable messages; no targeted log audit was run, so absence of PII from all runtime logs is unproven. Protected convert data/photos have a private bucket protocol in migration `202610140006_photos.sql` and require scoped access. Religious data and phone remain sensitive: future referral projection must be minimal and authorized server-side.

## Actionable findings for unified work

| Finding | Owner and checkable assertion | Disposition |
|---|---|---|
| Unified 1440 px, contrast and full assistive-tech evidence is missing. | `test/widgets/unified_navigation_test.dart` and unified quality plan: at 360/768/1440 and 200% text, no page-wide horizontal overflow; keyboard-only route/form completion; screen-reader labels and outcomes; measured contrast; reduced-motion path. | Journey/final gate action, not a current confirmed defect. |
| Contact privacy needs to stay deliberate during convert referral. | `lib/features/ministry/ui/convert_handoff_page.dart` (planned): no WhatsApp launch on page load; contact requires explicit tap; outbound message contains no religious/conversion data by default. Widget behavior test required. | Journey plan action. |
| Shared route/session/cache ownership must survive ministry composition. | `lib/routing/router.dart` and `test/workflows_test.dart`: identity switch or scope revocation clears protected caches and cannot render a forbidden route. | Journey plan action; current convert behavior is covered by existing reported synthetic tests. |

The existing IEADPE palette must be compared against convert tokens in the unified journey before any shared-theme decision. No speculative visual rewrite is recommended by this audit.
