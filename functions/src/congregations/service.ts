/**
 * Congregation lifecycle over the authorized transaction boundary (S04, S05,
 * S06, S11).
 *
 * Only supervisors create, rename, archive and restore congregations. Names
 * are unique by normalized value through an internal index document; renaming
 * never changes the ID, so relations and directory rendering keep resolving.
 * Archiving is refused while active users, unarchived students/contacts or
 * active classes reference the congregation.
 */
import { createHash } from "node:crypto";
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
import { AccessRole } from "../core/models";
import { normalizeName, rejectUnknownFields, validateDisplayName } from "../core/validation";

export interface SaveCongregationInput {
  uid: string;
  requestId: string;
  id: string;
  name: string;
  expectedRevision?: number;
}

export interface SetCongregationArchivedInput {
  uid: string;
  requestId: string;
  id: string;
  archived: boolean;
  expectedRevision: number;
}

export interface CongregationMutationResult {
  id: string;
  revision: number;
}

const SAVE_CONGREGATION_FIELDS = ["id", "name", "expectedRevision"] as const;
const SET_CONGREGATION_ARCHIVED_FIELDS = [
  "id",
  "archived",
  "expectedRevision",
] as const;

export type ScopeReferenceField =
  | "activeUsers"
  | "unarchivedStudents"
  | "unarchivedContacts"
  | "activeClasses";

export interface ScopeReferences {
  activeUsers: number;
  unarchivedStudents: number;
  unarchivedContacts: number;
  activeClasses: number;
}

/**
 * Internal denormalized dependency counts for one congregation. The owning
 * feature service adjusts the count it owns inside its own transaction; the
 * archive check reads all four so no dependency is inferred from a partial
 * list. Scope is part of the path, so counts never leak between congregations.
 */
export function scopeReferencePath(congregationId: string): string {
  return `congregations/${congregationId}/internal/references`;
}

function referenceCount(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

export async function readScopeReferences(
  tx: Transaction,
  congregationId: string,
): Promise<ScopeReferences> {
  const document = await tx.read(scopeReferencePath(congregationId));
  return {
    activeUsers: referenceCount(document?.activeUsers),
    unarchivedStudents: referenceCount(document?.unarchivedStudents),
    unarchivedContacts: referenceCount(document?.unarchivedContacts),
    activeClasses: referenceCount(document?.activeClasses),
  };
}

export async function adjustScopeReference(
  tx: Transaction,
  congregationId: string,
  field: ScopeReferenceField,
  delta: number,
): Promise<void> {
  const current = await readScopeReferences(tx, congregationId);
  const next: JsonMap = { ...current };
  next[field] = Math.max(0, current[field] + delta);
  await tx.write(scopeReferencePath(congregationId), next);
}

/** Internal uniqueness index; scoped by the normalized name hash. */
function congregationIndexPath(normalizedName: string): string {
  return `congregationNames/${createHash("sha256")
    .update(normalizedName)
    .digest("hex")}`;
}

function assertSupervisor(context: AuthorizedContext): void {
  if (context.profile.accessRole !== AccessRole.supervisor) {
    throw forbiddenError("Only supervisors may manage congregations.");
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

export async function saveCongregation(
  datastore: Datastore,
  clock: Clock,
  input: SaveCongregationInput,
): Promise<CongregationMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SAVE_CONGREGATION_FIELDS);
  const isCreate = input.expectedRevision === undefined;
  if (!isCreate) requireRevision(input.expectedRevision);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "saveCongregation",
      payload,
      requestedCongregationId: null,
    },
    async (tx, context) => {
      assertSupervisor(context);
      validateDisplayName(input.name);
      const name = input.name.trim();
      const normalizedName = normalizeName(input.name);
      const version = isCreate ? 1 : requireRevision(input.expectedRevision);
      const nowIso = clock.now().toISOString();
      const documentPath = paths.congregation(input.id);
      const indexPath = congregationIndexPath(normalizedName);
      const existingIndex = await tx.read(indexPath);

      if (isCreate) {
        if (!isUuid(input.id)) {
          throw validationError("id must be a UUID.", {
            id: "id must be a UUID.",
          });
        }
        if (existingIndex !== null) {
          throw conflictError("Congregation name already exists.");
        }
        await tx.createStable(documentPath, {
          id: input.id,
          name,
          normalizedName,
          active: true,
          revision: 1,
          createdAt: nowIso,
          updatedAt: nowIso,
          updatedBy: input.uid,
        });
        await tx.createStable(indexPath, {
          congregationId: input.id,
          normalizedName,
        });
        return { id: input.id, revision: 1 };
      }

      const current = await tx.read(documentPath);
      if (current === null) {
        throw notFoundError("Congregation not found.");
      }
      if (current.active !== true) {
        throw conflictError(
          "Archived congregations are read-only except restoration.",
        );
      }
      if (
        existingIndex !== null &&
        existingIndex.congregationId !== input.id
      ) {
        throw conflictError("Congregation name already exists.");
      }
      const currentNormalized =
        typeof current.normalizedName === "string"
          ? current.normalizedName
          : normalizeName(String(current.name ?? ""));
      const next = await tx.updateWithRevision(
        documentPath,
        version,
        (record) => ({
          ...record,
          name,
          normalizedName,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );
      if (currentNormalized !== normalizedName) {
        const oldIndexPath = congregationIndexPath(currentNormalized);
        const oldIndex = await tx.read(oldIndexPath);
        if (oldIndex !== null && oldIndex.congregationId === input.id) {
          await tx.delete(oldIndexPath);
        }
        if (existingIndex === null) {
          await tx.createStable(indexPath, {
            congregationId: input.id,
            normalizedName,
          });
        }
      }
      return { id: input.id, revision: Number(next.revision) };
    },
  );
}

export async function setCongregationArchived(
  datastore: Datastore,
  clock: Clock,
  input: SetCongregationArchivedInput,
): Promise<CongregationMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SET_CONGREGATION_ARCHIVED_FIELDS);
  const version = requireRevision(input.expectedRevision);
  if (typeof input.archived !== "boolean") {
    throw validationError("archived must be true or false.", {
      archived: "archived must be true or false.",
    });
  }

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "setCongregationArchived",
      payload,
      requestedCongregationId: null,
    },
    async (tx, context) => {
      assertSupervisor(context);
      const current = await tx.read(paths.congregation(input.id));
      if (current === null) {
        throw notFoundError("Congregation not found.");
      }
      const archived = current.active !== true;
      if (archived === input.archived) {
        return { id: input.id, revision: Number(current.revision) };
      }
      if (input.archived) {
        const references = await readScopeReferences(tx, input.id);
        if (
          references.activeUsers > 0 ||
          references.unarchivedStudents > 0 ||
          references.unarchivedContacts > 0 ||
          references.activeClasses > 0
        ) {
          throw conflictError(
            "Congregation has active users, students, contacts or classes.",
          );
        }
      }
      const nowIso = clock.now().toISOString();
      const next = await tx.updateWithRevision(
        paths.congregation(input.id),
        version,
        (record) => ({
          ...record,
          active: !input.archived,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );
      return { id: input.id, revision: Number(next.revision) };
    },
  );
}
