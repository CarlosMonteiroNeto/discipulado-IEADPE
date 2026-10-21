# Enrollment and attendance transaction sequence

<!-- canonical-document-authority -->
> **Historical integration baseline.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. Retain the original contracts/provenance; use current completion contracts and the task owner to resolve superseded identity, grant and attendance assumptions.

```mermaid
sequenceDiagram
    autonumber
    actor Staff as Verified ministry staff
    participant App as Flutter repository
    participant RPC as Supabase RPC
    participant Auth as Auth and access_versions
    participant DB as Ministry PostgreSQL rows
    participant Receipt as Mutation receipt

    Staff->>App: Enroll student / save attendance
    App->>RPC: operation_id + strict typed payload
    RPC->>Auth: Lock actor and affected UID versions in sorted order
    Auth-->>RPC: Current active grant and congregation scope
    RPC->>Receipt: Check actor + operation_id + payload digest
    alt Same operation and same payload
        Receipt-->>RPC: Original minimal result
        RPC-->>App: Stored result after current authorization check
    else New operation
        RPC->>DB: Lock congregation, class, student/enrollment/session rows in stable order
        DB-->>RPC: Authoritative rows and revisions
        alt Enroll student
            RPC->>DB: Validate same scope, active class/student, uniqueness and historical count <= 100
            RPC->>DB: Insert enrollment and increment class revision/count atomically
        else First attendance save
            RPC->>DB: Resolve eligible enrollments by session date
            RPC->>DB: Freeze enrollment IDs and student-name snapshots
        end
        RPC->>DB: Require marks map keys exactly equal frozen roster
        RPC->>DB: Validate statuses, revision and finalize rules
        RPC->>DB: Write complete marks and session revision atomically
        RPC->>Receipt: Store digest and safe result in same transaction
        RPC-->>App: IDs, revisions and status/counts only
    end
    App-->>Staff: Render confirmed typed state or safe failure
```

## Ownership sketch

- `MinistryRepository` coordinates typed feature ports and the existing gateway.
- `EnrollmentCommand` owns student/class IDs, congregation, start date and operation ID.
- `AttendanceCommand` owns session ID, expected revision, complete enrollment-keyed marks and finalize flag.
- PostgreSQL owns authorization, roster snapshot, transaction boundaries, revision, timestamps and replay receipt.
- `EnrollmentProgress` is a read projection over finalized, non-canceled session marks; it is not a client-maintained counter.
