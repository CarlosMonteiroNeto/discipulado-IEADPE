/**
 * Contact operations over the authorized transaction boundary (S04, S05, S06,
 * S11).
 *
 * A contact lives either under a congregation (`contacts`) or in the
 * supervision collection; its scope and congregation binding are immutable.
 * Administrative roles are claimed through per-scope transactional slots while
 * teacher keeps multiple holders. Directory projections are written in the same
 * transaction as the contact, so rename, replacement and archive are atomic.
 */
import { Clock } from "../core/clock";
import { isUuid, runCommand } from "../core/commands";
import { AuthorizedContext } from "../core/context";
import { Datastore, JsonMap, Transaction, paths } from "../core/datastore";
import {
  conflictError,
  forbiddenError,
  notFoundError,
  validationError,
} from "../core/errors";
import { AccessRole, ContactScope, isRoleCode, RoleCode } from "../core/models";
import {
  normalizeBrazilianPhone,
  normalizeName,
  rejectUnknownFields,
  validateBirthDate,
  validateDisplayName,
} from "../core/validation";
import { adjustScopeReference } from "../congregations/service";
import { contactPath, writeDirectoryProjection } from "./directory";
import {
  assertRoleScope,
  assertTeacherReleasable,
  claimAdministrativeSlot,
  isAdministrativeRole,
  releaseAdministrativeSlot,
  roleSlotPath,
  withRoleAssignmentLock,
} from "./role_slots";

export interface SaveContactInput {
  uid: string;
  requestId: string;
  id: string;
  expectedRevision?: number;
  scope: string;
  congregationId?: string | null;
  name: string;
  roleCode?: string | null;
  phone?: string | null;
  birthDate?: string | null;
}

export interface SetContactArchivedInput {
  uid: string;
  requestId: string;
  id: string;
  scope: string;
  congregationId?: string | null;
  archived: boolean;
  expectedRevision: number;
}

export interface ReplaceRoleHolderInput {
  uid: string;
  requestId: string;
  scope: string;
  congregationId?: string | null;
  roleCode: string;
  previousContactId: string;
  previousExpectedRevision: number;
  id: string;
  expectedRevision: number;
}

export interface ContactMutationResult {
  id: string;
  revision: number;
}

export interface ReplaceRoleHolderResult extends ContactMutationResult {
  previousContactId: string;
  previousRevision: number;
}

const SAVE_CONTACT_FIELDS = [
  "id",
  "expectedRevision",
  "scope",
  "congregationId",
  "name",
  "roleCode",
  "phone",
  "birthDate",
] as const;

const SET_CONTACT_ARCHIVED_FIELDS = [
  "id",
  "scope",
  "congregationId",
  "archived",
  "expectedRevision",
] as const;

const REPLACE_ROLE_HOLDER_FIELDS = [
  "scope",
  "congregationId",
  "roleCode",
  "previousContactId",
  "previousExpectedRevision",
  "id",
  "expectedRevision",
] as const;

function parseContactScope(value: unknown): ContactScope {
  if (value === ContactScope.congregation || value === ContactScope.supervision) {
    return value;
  }
  throw validationError("Invalid contact scope.", {
    scope: "Invalid contact scope.",
  });
}

function requireCongregationId(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw validationError("A congregation-scoped contact requires congregationId.", {
      congregationId: "congregationId is required.",
    });
  }
  return value;
}

function assertScopeMutation(
  context: AuthorizedContext,
  scope: ContactScope,
  congregationId: string | null,
): void {
  if (context.profile.accessRole === AccessRole.supervisor) return;
  if (scope === ContactScope.supervision) {
    throw forbiddenError("Only supervisors manage supervision contacts.");
  }
  if (congregationId !== context.profile.congregationId) {
    throw forbiddenError("Cross-congregation access is denied.");
  }
}

function requireRevision(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    throw validationError("expectedRevision must be a positive integer.", {
      expectedRevision: "expectedRevision must be a positive integer.",
    });
  }
  return value;
}

function parseRoleCode(value: unknown, scope: ContactScope): RoleCode | null {
  if (value === null || value === undefined || value === "") return null;
  if (!isRoleCode(value)) {
    throw validationError("Unknown role code.", {
      roleCode: "Unknown role code.",
    });
  }
  assertRoleScope(value, scope);
  return value;
}

interface LocatedContact {
  document: JsonMap;
  path: string;
}

/**
 * Resolves the stored contact at its declared scope. A record found under the
 * other scope proves an attempt to change scope, which is rejected: scope is
 * immutable and IDs are never reused across scopes.
 */
async function locateStoredContact(
  tx: Transaction,
  scope: ContactScope,
  congregationId: string | null,
  contactId: string,
): Promise<LocatedContact> {
  const primary = contactPath(scope, congregationId, contactId);
  const document = await tx.read(primary);
  if (document !== null) return { document, path: primary };

  const alternative =
    scope === ContactScope.congregation
      ? paths.supervisionContact(contactId)
      : congregationId !== null
        ? paths.contact(congregationId, contactId)
        : null;
  if (alternative !== null) {
    const other = await tx.read(alternative);
    if (other !== null) {
      throw validationError("Contact scope cannot change.", {
        scope: "Contact scope cannot change.",
      });
    }
  }
  throw notFoundError("Contact not found.");
}

async function executeSaveContact(
  tx: Transaction,
  context: AuthorizedContext,
  clock: Clock,
  input: SaveContactInput,
  scope: ContactScope,
  congregationId: string | null,
): Promise<ContactMutationResult> {
  assertScopeMutation(context, scope, congregationId);
  validateDisplayName(input.name);
  const roleCode = parseRoleCode(input.roleCode, scope);
  const phoneE164 = normalizeBrazilianPhone(input.phone ?? null);
  validateBirthDate(input.birthDate ?? null, clock.now());
  const nowIso = clock.now().toISOString();
  const name = input.name.trim();
  const normalizedName = normalizeName(input.name);
  const birthDate = input.birthDate ?? null;
  const isCreate = input.expectedRevision === undefined;

  if (isCreate) {
    if (!isUuid(input.id)) {
      throw validationError("id must be a UUID.", { id: "id must be a UUID." });
    }
    const document: JsonMap = {
      id: input.id,
      name,
      normalizedName,
      scope,
      congregationId,
      roleCode,
      phoneE164,
      birthDate,
      archived: false,
      revision: 1,
      createdAt: nowIso,
      updatedAt: nowIso,
      updatedBy: input.uid,
    };
    await tx.createStable(contactPath(scope, congregationId, input.id), document);
    if (roleCode !== null && isAdministrativeRole(roleCode)) {
      await claimAdministrativeSlot(tx, {
        scope,
        congregationId,
        roleCode,
        contactId: input.id,
        nowIso,
        uid: input.uid,
      });
    }
    await writeDirectoryProjection(tx, document);
    if (congregationId !== null) {
      await adjustScopeReference(tx, congregationId, "unarchivedContacts", 1);
    }
    return { id: input.id, revision: 1 };
  }

  const expectedRevision = requireRevision(input.expectedRevision);
  const located = await locateStoredContact(tx, scope, congregationId, input.id);
  const stored = located.document;
  if (
    stored.scope !== scope ||
    (typeof stored.congregationId === "string" ? stored.congregationId : null) !==
      congregationId
  ) {
    throw validationError("Contact scope cannot change.", {
      scope: "Contact scope cannot change.",
    });
  }
  if (stored.archived === true) {
    throw conflictError("Contact is archived; restore it before editing.");
  }
  const previousRole = isRoleCode(stored.roleCode) ? stored.roleCode : null;
  if (
    previousRole === "teacher" &&
    roleCode !== "teacher" &&
    congregationId !== null
  ) {
    await assertTeacherReleasable(tx, congregationId, input.id);
  }
  const next = await tx.updateWithRevision(
    located.path,
    expectedRevision,
    (record) => ({
      ...record,
      name,
      normalizedName,
      roleCode,
      phoneE164,
      birthDate,
      updatedAt: nowIso,
      updatedBy: input.uid,
    }),
  );
  if (
    previousRole !== null &&
    previousRole !== roleCode &&
    isAdministrativeRole(previousRole)
  ) {
    await releaseAdministrativeSlot(tx, {
      scope,
      congregationId,
      roleCode: previousRole,
      contactId: input.id,
      nowIso,
      uid: input.uid,
    });
  }
  if (roleCode !== null && isAdministrativeRole(roleCode)) {
    await claimAdministrativeSlot(tx, {
      scope,
      congregationId,
      roleCode,
      contactId: input.id,
      nowIso,
      uid: input.uid,
    });
  }
  await writeDirectoryProjection(tx, next);
  return { id: input.id, revision: Number(next.revision) };
}

export async function saveContact(
  datastore: Datastore,
  clock: Clock,
  input: SaveContactInput,
): Promise<ContactMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SAVE_CONTACT_FIELDS);
  const scope = parseContactScope(input.scope);
  const congregationId =
    scope === ContactScope.congregation
      ? requireCongregationId(input.congregationId)
      : null;

  return withRoleAssignmentLock(datastore, () =>
    runCommand(
      datastore,
      clock,
      {
        uid: input.uid,
        requestId: input.requestId,
        operation: "saveContact",
        payload,
        requestedCongregationId: congregationId,
      },
      async (tx, context) =>
        executeSaveContact(tx, context, clock, input, scope, congregationId),
    ),
  );
}

export async function setContactArchived(
  datastore: Datastore,
  clock: Clock,
  input: SetContactArchivedInput,
): Promise<ContactMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SET_CONTACT_ARCHIVED_FIELDS);
  if (typeof input.archived !== "boolean") {
    throw validationError("archived must be true or false.", {
      archived: "archived must be true or false.",
    });
  }
  requireRevision(input.expectedRevision);
  const scope = parseContactScope(input.scope);
  const congregationId =
    scope === ContactScope.congregation
      ? requireCongregationId(input.congregationId)
      : null;

  return withRoleAssignmentLock(datastore, () =>
    runCommand(
      datastore,
      clock,
      {
        uid: input.uid,
        requestId: input.requestId,
        operation: "setContactArchived",
        payload,
        requestedCongregationId: congregationId,
      },
      async (tx, context) => {
        assertScopeMutation(context, scope, congregationId);
        const located = await locateStoredContact(
          tx,
          scope,
          congregationId,
          input.id,
        );
        const stored = located.document;
        if (
          stored.scope !== scope ||
          (typeof stored.congregationId === "string"
            ? stored.congregationId
            : null) !== congregationId
        ) {
          throw validationError("Contact scope cannot change.", {
            scope: "Contact scope cannot change.",
          });
        }
        if ((stored.archived === true) === input.archived) {
          return { id: input.id, revision: Number(stored.revision) };
        }
        const previousRole = isRoleCode(stored.roleCode) ? stored.roleCode : null;
        if (input.archived && previousRole === "teacher" && congregationId !== null) {
          await assertTeacherReleasable(tx, congregationId, input.id);
        }
        const nowIso = clock.now().toISOString();
        const next = await tx.updateWithRevision(
          located.path,
          input.expectedRevision,
          (record) => ({
            ...record,
            archived: input.archived,
            roleCode: null,
            updatedAt: nowIso,
            updatedBy: input.uid,
          }),
        );
        if (previousRole !== null && isAdministrativeRole(previousRole)) {
          await releaseAdministrativeSlot(tx, {
            scope,
            congregationId,
            roleCode: previousRole,
            contactId: input.id,
            nowIso,
            uid: input.uid,
          });
        }
        await writeDirectoryProjection(tx, next);
        if (congregationId !== null) {
          await adjustScopeReference(
            tx,
            congregationId,
            "unarchivedContacts",
            input.archived ? -1 : 1,
          );
        }
        return { id: input.id, revision: Number(next.revision) };
      },
    ),
  );
}

export async function replaceRoleHolder(
  datastore: Datastore,
  clock: Clock,
  input: ReplaceRoleHolderInput,
): Promise<ReplaceRoleHolderResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, REPLACE_ROLE_HOLDER_FIELDS);
  requireRevision(input.expectedRevision);
  requireRevision(input.previousExpectedRevision);
  const scope = parseContactScope(input.scope);
  const congregationId =
    scope === ContactScope.congregation
      ? requireCongregationId(input.congregationId)
      : null;
  const roleCode = parseRoleCode(input.roleCode, scope);
  if (roleCode === null) {
    throw validationError("roleCode is required.", {
      roleCode: "roleCode is required.",
    });
  }
  if (!isAdministrativeRole(roleCode)) {
    throw validationError("Teacher keeps multiple holders; replace is not supported.", {
      roleCode: "Teacher keeps multiple holders.",
    });
  }

  return withRoleAssignmentLock(datastore, () =>
    runCommand(
      datastore,
      clock,
      {
        uid: input.uid,
        requestId: input.requestId,
        operation: "replaceRoleHolder",
        payload,
        requestedCongregationId: congregationId,
      },
      async (tx, context) => {
        assertScopeMutation(context, scope, congregationId);
        const previous = await locateStoredContact(
          tx,
          scope,
          congregationId,
          input.previousContactId,
        );
        const target = await locateStoredContact(
          tx,
          scope,
          congregationId,
          input.id,
        );
        if (previous.document.roleCode !== roleCode) {
          throw validationError("The previous holder does not hold this role.", {
            previousContactId: "The previous holder does not hold this role.",
          });
        }
        const slotPath = roleSlotPath(scope, congregationId, roleCode);
        const slot = await tx.read(slotPath);
        const holder =
          typeof slot?.contactId === "string" && slot.contactId.length > 0
            ? slot.contactId
            : null;
        if (holder !== input.previousContactId) {
          throw conflictError("Role holder changed since it was loaded.");
        }
        const nowIso = clock.now().toISOString();
        const targetPreviousRole = isRoleCode(target.document.roleCode)
          ? target.document.roleCode
          : null;
        if (
          targetPreviousRole !== null &&
          targetPreviousRole !== roleCode &&
          isAdministrativeRole(targetPreviousRole)
        ) {
          await releaseAdministrativeSlot(tx, {
            scope,
            congregationId,
            roleCode: targetPreviousRole,
            contactId: input.id,
            nowIso,
            uid: input.uid,
          });
        }
        const previousNext = await tx.updateWithRevision(
          previous.path,
          input.previousExpectedRevision,
          (record) => ({
            ...record,
            roleCode: null,
            updatedAt: nowIso,
            updatedBy: input.uid,
          }),
        );
        const targetNext = await tx.updateWithRevision(
          target.path,
          input.expectedRevision,
          (record) => ({
            ...record,
            roleCode,
            updatedAt: nowIso,
            updatedBy: input.uid,
          }),
        );
        await tx.updateWithRevision(slotPath, Number(slot?.revision), (record) => ({
          ...record,
          contactId: input.id,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }));
        await writeDirectoryProjection(tx, previousNext);
        await writeDirectoryProjection(tx, targetNext);
        return {
          id: input.id,
          revision: Number(targetNext.revision),
          previousContactId: input.previousContactId,
          previousRevision: Number(previousNext.revision),
        };
      },
    ),
  );
}
