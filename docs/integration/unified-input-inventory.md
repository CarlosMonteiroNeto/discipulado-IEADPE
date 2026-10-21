# Unified input inventory and proposed ownership

<!-- canonical-document-authority -->
> **Supporting technical reference.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. Reuse procedures/contracts only through the corresponding current task and its reviewed interface, prerequisites and authorization. Counts, completed operations and old environment statements retain their original observation date.

Planning evidence, 2026-10-18. Sources: retained Base44 UserAccessManager.jsx and ConvertForm.jsx; original Flutter Git revision 4acb563 domain/contact.dart, student.dart, class_group.dart, congregation.dart and features/team/contact_form.dart; current ministry UI and contracts. This is a planning comparison, not a completed migration.

| Input | Base44 | Original Flutter/Firebase | Unified proposal |
| --- | --- | --- | --- |
| Team/access | Login email, direction/supervision role, congregation for direction | Contact name, scope, congregation, organizational role, phone; model also has birth date. Contact form inspected exposes name/role/phone, not evidence of every model field being editable. Account authorization is separate. | One Team entry with name, phone, optional birth date, login email, organizational function and congregation/global scope. Link contact to access assignment; preserve existing email assignments without inventing missing names/phones. |
| Organizational functions | Two access categories | Twelve named functions, listed below | Preserve detailed functions; access category is a separate explicit field in the same form, managed by authorized global managers. |
| Person identity | Name, congregation, photo, address, landmark, phone, age, gender, conversion date, worship type | Student name, congregation, phone, birth date, structured address | Two task-specific entries using shared components and canonical identity: default quick new-convert registration and protected student registration. Preserve original address/historical age; add structured details/birth date without fabricating conversion values or destructively converting old values. |
| Academic/person complement | Discipleship/contact flags and event history | Education, marital status, new-convert answer, water-baptized answer, wants-baptism answer | Optional complementary section in the shared person form/detail. Derived discipleship/contact state comes from enrollment/attendance; do not duplicate manual input. Preserve unknown/null answers. |
| Congregation | Name and references from people/access | Name, active/archive state | One congregation catalog and ID mapping for every module; never maintain two editable name lists. |
| Classes | No equivalent | Congregation, name, teacher contact, start/end dates, active/completed/archived status | Keep academic class entry; teacher selects the unified Team contact, not a repeated name. |
| Enrollment | No equivalent | Student/class association, dates/status/history | Select shared registered person and class; create/reuse academic extension automatically and publish discipleship state atomically. |
| Lesson/attendance | Manual visit/contact and discipleship checks | Session date/topic, frozen roster, attendance marks, finalization/cancellation | Keep lesson input; qualifying presence feeds shared follow-up without creating fictitious visits. |
| Weekly confirmation, conversion reports, events, photos, feedback, backup | Existing campaign workflows | Academic overview/progress and history | Preserve workflows with unified congregation/person references and explicit event types. Do not merge weekly-report confirmation with attendance: they record different facts. Include exports/imports in field mapping and authorization tests. |

Original functions: Supervisor das campanhas; Vice-supervisor das campanhas; Coordenador do discipulado; Vice-coordenador do discipulado; Secretária da coordenação; Vice-secretária da coordenação; Assistente de congregação; Dirigente de campanha; Vice-dirigente de campanha; Professor(a) do discipulado; Secretária do discipulado; Vice-secretária do discipulado.

## Access and lifecycle requirements

Administrators and authorized supervision accounts have global access. Congregational team accounts have access to their congregation's converts, students, classes and attendance. Existing multiple-congregation assignments remain explicit. A job title is not an authentication credential: only a global authorized actor can grant/change scope. Local team may not create global access or move itself to another congregation.

One Team screen must maintain contact and linked login access together for authorized managers, including view/edit/revoke status; local users see only allowed team data/actions. A person can remain an archived historical teacher after login access is revoked. Show the distinction clearly; do not leave live access accidentally when an operator chooses removal of membership/access. Define the archive confirmation and resulting access changes explicitly in implementation contracts.

Use verified-email binding already implemented; do not create Auth passwords/accounts from the form. Email change/reassignment must revoke the old binding safely, handle duplicate/conflicting assignments and refresh affected scope. Contact creation plus requested access grant must be atomic or expose a recoverable explicit pending state; never silently save only half.

Before schema changes, reconcile existing Base44 access emails and original contacts by explicit identifiers/verified operator decisions. No name-only merge, no email inferred from name, no privilege inferred solely from imported job titles. Technical-admin allowlist remains protected outside routine team-role editing.

## Decisions to finalize before execution

Confirm required versus optional email for contacts with no app account; proposed behavior is optional email for directory-only contacts and required email when enabling login access. Confirm whether local teams can maintain contact details or only global managers do so; access grants remain global-manager-only under current server rules. Resolve registration of legacy pupils without known conversion date/worship type without inventing conversion events. These do not block documenting the unified fields, but block implementing the affected validation/policy.
