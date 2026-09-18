/**
 * Per-scope administrative role slots and the S06 role catalog (S05, S06, S11).
 *
 * Administrative roles are single-holder per scope and are claimed through one
 * transactional slot document whose path includes the scope in the key, so two
 * congregations (or supervision and a congregation) never share a slot.
 * Teacher is a multi-holder role and therefore has no slot.
 */
import { JsonMap, Transaction, paths } from "../core/datastore";
import { conflictError, validationError } from "../core/errors";
import { ContactScope, RoleCode, roleScope } from "../core/models";

/** The twelve stable S06 role codes with their pt-BR labels. */
export const ROLE_LABELS: Record<RoleCode, string> = {
  campaignSupervisor: "Supervisor das campanhas",
  campaignDeputy: "Vice-supervisor das campanhas",
  discipleshipCoordinator: "Coordenador do discipulado",
  discipleshipDeputy: "Vice-coordenador do discipulado",
  coordinationSecretary: "Secretária da coordenação",
  coordinationDeputySecretary: "Vice-secretária da coordenação",
  congregationAssistant: "Assistente de congregação",
  campaignLeader: "Dirigente de campanha",
  campaignDeputyLeader: "Vice-dirigente de campanha",
  teacher: "Professor(a) do discipulado",
  discipleshipSecretary: "Secretária do discipulado",
  discipleshipDeputySecretary: "Vice-secretária do discipulado",
};

/** Roles that may hold more than one active contact in the same scope. */
export const MULTI_HOLDER_ROLES: ReadonlySet<RoleCode> = new Set<RoleCode>([
  "teacher",
]);

export function isAdministrativeRole(roleCode: RoleCode): boolean {
  return !MULTI_HOLDER_ROLES.has(roleCode);
}

export function assertRoleScope(roleCode: RoleCode, scope: ContactScope): void {
  if (roleScope(roleCode) !== scope) {
    throw validationError("Role does not belong to the contact scope.", {
      roleCode: "Invalid role for this scope.",
    });
  }
}

/** The deterministic slot document for one administrative role in one scope. */
export function roleSlotPath(
  scope: ContactScope,
  congregationId: string | null,
  roleCode: RoleCode | string,
): string {
  if (scope === ContactScope.supervision) {
    return paths.supervisionRoleSlot(String(roleCode));
  }
  if (congregationId === null || congregationId.length === 0) {
    throw validationError("A congregation-scoped role requires a congregation.");
  }
  return `congregations/${congregationId}/roleSlots/${roleCode}`;
}

/**
 * Internal index of active classes that reference a teacher. The class feature
 * owns the writes; archiving or unassigning a teacher reads it to refuse work
 * that would leave an active class without its teacher (S06).
 */
export function teacherClassReferencePath(
  congregationId: string,
  contactId: string,
): string {
  return `congregations/${congregationId}/teacherClassRefs/${contactId}`;
}

export async function readRoleSlot(
  tx: Transaction,
  scope: ContactScope,
  congregationId: string | null,
  roleCode: RoleCode,
): Promise<JsonMap | null> {
  return tx.read(roleSlotPath(scope, congregationId, roleCode));
}

export async function assertTeacherReleasable(
  tx: Transaction,
  congregationId: string,
  contactId: string,
): Promise<void> {
  const reference = await tx.read(
    teacherClassReferencePath(congregationId, contactId),
  );
  if (reference !== null && Number(reference.activeClassCount ?? 0) > 0) {
    throw conflictError("Teacher is referenced by an active class.");
  }
}

export async function claimAdministrativeSlot(
  tx: Transaction,
  args: {
    scope: ContactScope;
    congregationId: string | null;
    roleCode: RoleCode;
    contactId: string;
    nowIso: string;
    uid: string;
  },
): Promise<void> {
  const path = roleSlotPath(args.scope, args.congregationId, args.roleCode);
  const slot = await tx.read(path);
  if (slot === null) {
    await tx.createStable(path, {
      id: args.roleCode,
      scope: args.scope,
      congregationId: args.congregationId,
      roleCode: args.roleCode,
      contactId: args.contactId,
      revision: 1,
      createdAt: args.nowIso,
      updatedAt: args.nowIso,
      updatedBy: args.uid,
    });
    return;
  }
  const holder =
    typeof slot.contactId === "string" && slot.contactId.length > 0
      ? slot.contactId
      : null;
  if (holder !== null && holder !== args.contactId) {
    throw conflictError("Administrative role is already held.");
  }
  await tx.updateWithRevision(path, Number(slot.revision), (current) => ({
    ...current,
    contactId: args.contactId,
    updatedAt: args.nowIso,
    updatedBy: args.uid,
  }));
}

export async function releaseAdministrativeSlot(
  tx: Transaction,
  args: {
    scope: ContactScope;
    congregationId: string | null;
    roleCode: RoleCode;
    contactId: string;
    nowIso: string;
    uid: string;
  },
): Promise<void> {
  const path = roleSlotPath(args.scope, args.congregationId, args.roleCode);
  const slot = await tx.read(path);
  if (slot === null || slot.contactId !== args.contactId) return;
  await tx.updateWithRevision(path, Number(slot.revision), (current) => ({
    ...current,
    contactId: null,
    updatedAt: args.nowIso,
    updatedBy: args.uid,
  }));
}

/**
 * Serializes role-affecting contact mutations per datastore.
 *
 * The in-memory datastore used by unit tests does not retry concurrent
 * transactions, so two simultaneous claims of the same slot could otherwise
 * both observe it free and each stage a write. The authoritative production
 * datastore (Firestore) retries transactions and does not need this, but the
 * serialization keeps the pessimistic check ("one holder per scope") true for
 * every datastore implementation.
 */
const assignmentLocks = new WeakMap<object, Promise<void>>();

export async function withRoleAssignmentLock<T>(
  datastore: object,
  work: () => Promise<T>,
): Promise<T> {
  const previous = assignmentLocks.get(datastore) ?? Promise.resolve();
  let release!: () => void;
  const tail = new Promise<void>((resolve) => {
    release = resolve;
  });
  assignmentLocks.set(
    datastore,
    previous.then(() => tail),
  );
  await previous;
  try {
    return await work();
  } finally {
    release();
  }
}
