# Convert-to-Student Handoff Sequence

<!-- canonical-document-authority -->
> **Supporting technical reference.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. Reuse procedures/contracts only through the corresponding current task and its reviewed interface, prerequisites and authorization. Counts, completed operations and old environment statements retain their original observation date.

The sequence defines the boundary between convert intake and ministry follow-up. All decisions and writes inside the transaction are server-owned. The ministry client receives only the referral projection and minimal promotion result allowed by the handoff contract.

```mermaid
sequenceDiagram
    autonumber
    actor Staff as Ministry staff with congregation C
    participant UI as Flutter handoff screen
    participant Repo as MinistryRepository
    participant Referral as ieadpe_ministry_list_convert_referrals
    participant Candidates as ieadpe_ministry_list_convert_student_candidates
    participant RPC as ieadpe_promote_convert_to_student
    participant Access as access_versions and active grants
    participant Congregation as congregations
    participant Convert as converts
    participant Student as ministry_students
    participant Link as unique link and provenance
    participant Receipt as mutation receipt

    Staff->>UI: Open handoff queue for C
    UI->>Repo: Request minimal referral page for C
    Repo->>Referral: congregation_id, limit, cursor
    Referral->>Access: Lock actor access version; validate ministry grant or trusted admin scope for C
    Access-->>Referral: Authorized congregation scope
    Referral->>Convert: Select non-deleted converts assigned to C; omit campaign history and photos
    Convert-->>Referral: Minimal eligible referral rows
    Referral-->>Repo: Bounded referral page
    Repo-->>UI: Typed minimal referral projection
    Staff->>UI: Review convert and choose create or an exact existing student
    opt Existing-student review
        UI->>Repo: Search by non-empty name prefix in C
        Repo->>Candidates: congregation_id, name_prefix, limit, cursor
        Candidates->>Access: Validate active ministry grant or trusted admin scope for C
        Access-->>Candidates: Authorized congregation scope
        Candidates->>Student: Filter same-scope, unlinked, non-archived students; page by normalized name and ID
        Student-->>Candidates: Bounded candidate fields
        Candidates-->>Repo: Candidate page; no archived or cross-scope students
        Repo-->>UI: Scoped ministry student candidates only
        Staff->>UI: Select exact candidate and confirm any field differences
    end
    UI->>UI: Create operation UUID once; retain it with the draft
    UI->>Repo: Promote(convert_id, C, optional student_id, operation_id)
    Repo->>RPC: Strict allow-list payload + operation_id
    RPC->>Access: Lock actor access version; read current ministry grant or trusted admin capability
    Access-->>RPC: Current authority for C
    RPC->>Congregation: Lock selected congregation row; validate active scope
    Congregation-->>RPC: Authoritative congregation state
    RPC->>Convert: Lock convert row; verify assigned C
    Convert-->>RPC: Authoritative convert state
    RPC->>Receipt: Look up actor + operation UUID + canonical payload
    alt Matching receipt (retry or response was lost)
        Receipt-->>RPC: Original minimal result
        RPC-->>Repo: Same linked IDs/status after current authorization
        Repo-->>UI: Confirmed linked state
    else New valid operation
        RPC->>Convert: Check new-link lifecycle eligibility (deleted_at is null)
        alt Existing student selected
            RPC->>Student: Lock exact candidate; verify same C and unlinked
            Student-->>RPC: Candidate eligibility only
            Note over RPC,Student: Preserve all candidate fields; do not synchronize or overwrite
        else No existing student selected
            RPC->>Student: Insert one student with name, phone and address initial snapshots
            Note over RPC,Student: Address free text maps to address.street; copy phone_e164 only if source already matches strict E.164, otherwise leave null
        end
        RPC->>Link: Insert unique convert_id + server promoted_at + exact JSON source snapshot
        Note over RPC,Link: Snapshot keys are name, phone, address; nullable phone/address are preserved as JSON null. Existing-student fields are never overwritten.
        RPC->>Receipt: Store canonical payload digest + safe result in same transaction
        RPC-->>Repo: convert_id, student_id, congregation_id, status=linked
        Repo-->>UI: Typed success only after committed RPC result
    end
    UI-->>Staff: Show linked student; offer separate explicit enrollment action
    Note over RPC,UI: Unassigned/deleted convert or invalid/out-of-scope candidate returns a safe error with no partial write; UI preserves draft and operation UUID.
    Note over UI,Receipt: Concurrent submissions serialize on scope/record locks; the unique convert_id constraint guarantees one link. A loser receives safe already-linked/conflict handling.
```

## Sequence invariants

- Authorization is checked before referrals, candidate details, replay receipts, or protected failures are disclosed.
- Referral reads expose only the contract's minimal fields; convert history, event counts/details, photos, worship type, age, and campaign reports are excluded.
- Every lock and validation precedes the write; student creation, one-to-one link, provenance, and receipt commit atomically.
- Response loss is recovered with the same actor, operation UUID, and payload. The user must not mint a new operation ID for a retry.
- Linking is not enrollment. Enrollment is a separate explicit command after the link is confirmed.
- Promotion creates no campaign event and changes no convert lifecycle/history fields.
