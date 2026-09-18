/**
 * Class lifecycle over the authorized transaction boundary (S04, S05, S08,
 * S11).
 *
 * A class is a scoped record keyed by a stable ID whose name and eligible
 * teacher may change while active; its dates freeze once any enrollment or
 * session exists. Status moves active -> completed -> archived, with an
 * archived class allowed to reactivate; a completed class is never reopened.
 * Active-class and teacher-reference counters are adjusted in the same
 * transaction as the status change, so congregation and contact archive guards
 * observe real class operations.
 *
 * Session prerequisites (completion requires no open session, archiving an
 * active class requires no session at all, and dates freeze after the first
 * session) are read through the injected [ClassSessionReader]. The core
 * Datastore deliberately exposes no collection queries, and session documents
 * are owned by the session feature (task 6), so this port is the boundary
 * between the two.
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
import { ClassStatus } from "../core/models";
import {
  normalizeName,
  parseCalendarDate,
  rejectUnknownFields,
  validateDisplayName,
  validateEnum,
} from "../core/validation";
import { adjustScopeReference } from "../congregations/service";
import { teacherClassReferencePath } from "../contacts/role_slots";

/** One class scope for session/roster reads. */
export interface ClassSessionQuery {
  congregationId: string;
  classId: string;
}

/**
 * Read port over session and frozen-roster state owned by the session feature.
 *
 * The in-memory implementation backs deterministic tests and emulator runs;
 * the Admin adapter is implemented where sessions live. Roster entries carry
 * `sessionId`, `classId` and `enrollmentId` so membership can be resolved
 * without exposing the roster to clients.
 */
export interface ClassSessionReader {
  listSessions(query: ClassSessionQuery): Promise<JsonMap[]>;
  listRosterEntries(
    query: ClassSessionQuery & { sessionId: string },
  ): Promise<JsonMap[]>;
}

/** Deterministic in-memory session/roster reader for tests and emulators. */
export class InMemoryClassSessionReader implements ClassSessionReader {
  private readonly sessions: JsonMap[];
  private readonly rosterEntries: JsonMap[];

  constructor(
    seed: {
      sessions?: readonly JsonMap[];
      rosterEntries?: readonly JsonMap[];
    } = {},
  ) {
    this.sessions = (seed.sessions ?? []).map((entry) => structuredClone(entry));
    this.rosterEntries = (seed.rosterEntries ?? []).map((entry) =>
      structuredClone(entry),
    );
  }

  async listSessions(query: ClassSessionQuery): Promise<JsonMap[]> {
    return this.sessions
      .filter(
        (session) =>
          session.congregationId === query.congregationId &&
          session.classId === query.classId,
      )
      .map((entry) => structuredClone(entry));
  }

  async listRosterEntries(
    query: ClassSessionQuery & { sessionId: string },
  ): Promise<JsonMap[]> {
    return this.rosterEntries
      .filter(
        (entry) =>
          entry.sessionId === query.sessionId &&
          (entry.classId === undefined || entry.classId === query.classId),
      )
      .map((entry) => structuredClone(entry));
  }
}

export interface SaveClassInput {
  uid: string;
  requestId: string;
  id: string;
  expectedRevision?: number;
  congregationId: string;
  name: string;
  teacherContactId?: string | null;
  startDate: string;
  endDate?: string | null;
}

export interface SetClassStatusInput {
  uid: string;
  requestId: string;
  id: string;
  congregationId: string;
  status: string;
  expectedRevision: number;
}

export interface ClassMutationResult {
  id: string;
  revision: number;
}

export const MAX_ENROLLMENTS_PER_CLASS = 100;

const SAVE_CLASS_FIELDS = [
  "id",
  "expectedRevision",
  "congregationId",
  "name",
  "teacherContactId",
  "startDate",
  "endDate",
] as const;

const SET_CLASS_STATUS_FIELDS = [
  "id",
  "congregationId",
  "status",
  "expectedRevision",
] as const;

function requireCongregationId(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw validationError("A class requires congregationId.", {
      congregationId: "congregationId is required.",
    });
  }
  return value;
}

function requireRevision(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    throw validationError("expectedRevision must be a positive integer.", {
      expectedRevision: "expectedRevision must be a positive integer.",
    });
  }
  return value;
}

function requireDate(value: unknown, field: string): string {
  parseCalendarDate(value, field);
  return value as string;
}

function optionalDate(value: unknown, field: string): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string" && value.trim().length === 0) return null;
  parseCalendarDate(value, field);
  return value as string;
}

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

/** Missing or malformed counters read as zero rather than NaN. */
function referenceCount(document: JsonMap | null, field: string): number {
  const value = document?.[field];
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

/**
 * Archived congregations are read-only except restoration (S06), so every
 * class mutation refuses work inside an inactive congregation for every role.
 */
async function assertActiveCongregation(
  tx: Transaction,
  context: AuthorizedContext,
  congregationId: string,
): Promise<void> {
  const cached = context.congregation;
  const congregation =
    cached !== null && cached.id === congregationId
      ? cached
      : await tx.read(paths.congregation(congregationId));
  if (congregation === null) {
    throw notFoundError("Congregation not found.");
  }
  if (congregation.active !== true) {
    throw forbiddenError("Congregation is inactive.");
  }
}

interface LocatedClass {
  document: JsonMap;
  path: string;
}

/** Resolves a class inside the caller's scope; cross-scope IDs are not found. */
async function locateClass(
  tx: Transaction,
  congregationId: string,
  classId: unknown,
): Promise<LocatedClass> {
  if (typeof classId !== "string" || classId.length === 0) {
    throw validationError("classId is required.", {
      classId: "classId is required.",
    });
  }
  const path = paths.classGroup(congregationId, classId);
  const document = await tx.read(path);
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Class not found.");
  }
  return { document, path };
}

/**
 * The assigned teacher must be an active local contact holding the teacher
 * role (S05). A contact from another congregation, an archived contact or a
 * non-teacher is rejected before any write.
 */
async function assertEligibleTeacher(
  tx: Transaction,
  congregationId: string,
  contactId: string,
): Promise<void> {
  const contact = await tx.read(paths.contact(congregationId, contactId));
  if (contact === null || contact.congregationId !== congregationId) {
    throw conflictError("Teacher must be a local contact.");
  }
  if (contact.archived === true) {
    throw conflictError("The teacher contact is archived.");
  }
  if (contact.roleCode !== "teacher") {
    throw conflictError("The assigned contact does not hold the teacher role.");
  }
}

/**
 * Keeps `congregations/{id}/teacherClassRefs/{contactId}.activeClassCount` in
 * step with the real class lifecycle. Contact archiving and role release read
 * this reference (S06), so a teacher with an active class cannot be removed.
 */
async function adjustTeacherClassReference(
  tx: Transaction,
  congregationId: string,
  contactId: string,
  delta: number,
  nowIso: string,
  uid: string,
): Promise<void> {
  const path = teacherClassReferencePath(congregationId, contactId);
  const current = await tx.read(path);
  if (current === null && delta <= 0) return;
  const activeClassCount = Math.max(
    0,
    referenceCount(current, "activeClassCount") + delta,
  );
  if (current === null) {
    await tx.createStable(path, {
      id: contactId,
      congregationId,
      activeClassCount,
      revision: 1,
      createdAt: nowIso,
      updatedAt: nowIso,
      updatedBy: uid,
    });
    return;
  }
  await tx.write(path, {
    ...current,
    activeClassCount,
    updatedAt: nowIso,
    updatedBy: uid,
  });
}

export async function saveClass(
  datastore: Datastore,
  clock: Clock,
  input: SaveClassInput,
  sessions: ClassSessionReader,
): Promise<ClassMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SAVE_CLASS_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "saveClass",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) => {
      await assertActiveCongregation(tx, context, congregationId);
      validateDisplayName(input.name);
      const startDate = requireDate(input.startDate, "startDate");
      const endDate = optionalDate(input.endDate, "endDate");
      if (endDate !== null && endDate < startDate) {
        throw validationError(
          "A data final deve ser igual ou posterior à data inicial.",
          { endDate: "A data final deve ser igual ou posterior à data inicial." },
        );
      }
      const teacherContactId = nonEmpty(input.teacherContactId);
      if (teacherContactId !== null) {
        await assertEligibleTeacher(tx, congregationId, teacherContactId);
      }
      const name = input.name.trim();
      const normalizedName = normalizeName(input.name);
      const nowIso = clock.now().toISOString();
      const isCreate = input.expectedRevision === undefined;

      if (isCreate) {
        if (!isUuid(input.id)) {
          throw validationError("id must be a UUID.", {
            id: "id must be a UUID.",
          });
        }
        const document: JsonMap = {
          id: input.id,
          congregationId,
          name,
          normalizedName,
          teacherContactId,
          startDate,
          endDate,
          status: ClassStatus.active,
          enrollmentCount: 0,
          activeEnrollmentCount: 0,
          revision: 1,
          createdAt: nowIso,
          updatedAt: nowIso,
          updatedBy: input.uid,
        };
        await tx.createStable(
          paths.classGroup(congregationId, input.id),
          document,
        );
        if (teacherContactId !== null) {
          await adjustTeacherClassReference(
            tx,
            congregationId,
            teacherContactId,
            1,
            nowIso,
            input.uid,
          );
        }
        await adjustScopeReference(tx, congregationId, "activeClasses", 1);
        return { id: input.id, revision: 1 };
      }

      const expectedRevision = requireRevision(input.expectedRevision);
      const located = await locateClass(tx, congregationId, input.id);
      const stored = located.document;
      if (stored.status !== ClassStatus.active) {
        throw conflictError("Completed and archived classes are read-only.");
      }
      const enrollmentCount = referenceCount(stored, "enrollmentCount");
      const classSessions = await sessions.listSessions({
        congregationId,
        classId: input.id,
      });
      const datesFrozen = enrollmentCount > 0 || classSessions.length > 0;
      const storedStart = String(stored.startDate ?? "");
      const storedEnd = nonEmpty(stored.endDate);
      if (
        datesFrozen &&
        (startDate !== storedStart || endDate !== storedEnd)
      ) {
        throw conflictError(
          "Class dates cannot change once an enrollment or session exists.",
        );
      }
      const previousTeacher = nonEmpty(stored.teacherContactId);

      const next = await tx.updateWithRevision(
        located.path,
        expectedRevision,
        (record) => ({
          ...record,
          name,
          normalizedName,
          teacherContactId,
          startDate,
          endDate,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );
      if (previousTeacher !== teacherContactId) {
        if (previousTeacher !== null) {
          await adjustTeacherClassReference(
            tx,
            congregationId,
            previousTeacher,
            -1,
            nowIso,
            input.uid,
          );
        }
        if (teacherContactId !== null) {
          await adjustTeacherClassReference(
            tx,
            congregationId,
            teacherContactId,
            1,
            nowIso,
            input.uid,
          );
        }
      }
      return { id: input.id, revision: Number(next.revision) };
    },
  );
}

export async function setClassStatus(
  datastore: Datastore,
  clock: Clock,
  input: SetClassStatusInput,
  sessions: ClassSessionReader,
): Promise<ClassMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SET_CLASS_STATUS_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);
  const targetStatus = validateEnum(input.status, ClassStatus, "status");
  const expectedRevision = requireRevision(input.expectedRevision);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "setClassStatus",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) => {
      await assertActiveCongregation(tx, context, congregationId);
      const located = await locateClass(tx, congregationId, input.id);
      const stored = located.document;
      const currentStatus = stored.status as ClassStatus;
      if (currentStatus === targetStatus) {
        return { id: input.id, revision: Number(stored.revision) };
      }

      const teacherContactId = nonEmpty(stored.teacherContactId);
      const enrollmentCount = referenceCount(stored, "enrollmentCount");
      const activeEnrollmentCount = referenceCount(
        stored,
        "activeEnrollmentCount",
      );
      const classSessions = await sessions.listSessions({
        congregationId,
        classId: input.id,
      });

      if (targetStatus === ClassStatus.completed) {
        if (currentStatus !== ClassStatus.active) {
          throw conflictError(
            "Completed and archived classes cannot be reopened.",
          );
        }
        if (activeEnrollmentCount > 0) {
          throw conflictError(
            "Class completion requires every enrollment to close.",
          );
        }
        if (classSessions.some((session) => session.status === "open")) {
          throw conflictError(
            "Class completion requires every session to be finalized or canceled.",
          );
        }
      } else if (targetStatus === ClassStatus.archived) {
        if (currentStatus === ClassStatus.active) {
          if (enrollmentCount > 0 || classSessions.length > 0) {
            throw conflictError(
              "An active class can only be archived when it has no enrollments or sessions.",
            );
          }
        } else if (currentStatus === ClassStatus.completed) {
          // Completed classes may be archived; no counter changes apply.
        } else {
          throw conflictError("Archived classes cannot be re-archived.");
        }
      } else {
        // targetStatus === active: archived classes may reactivate only.
        if (currentStatus !== ClassStatus.archived) {
          throw conflictError(
            "Completed and archived classes cannot be reopened.",
          );
        }
        if (teacherContactId !== null) {
          await assertEligibleTeacher(tx, congregationId, teacherContactId);
        }
      }

      const wasActive = currentStatus === ClassStatus.active;
      const becomesActive = targetStatus === ClassStatus.active;
      const nowIso = clock.now().toISOString();

      const next = await tx.updateWithRevision(
        located.path,
        expectedRevision,
        (record) => ({
          ...record,
          status: targetStatus,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );

      if (wasActive !== becomesActive) {
        await adjustScopeReference(
          tx,
          congregationId,
          "activeClasses",
          becomesActive ? 1 : -1,
        );
        if (teacherContactId !== null) {
          await adjustTeacherClassReference(
            tx,
            congregationId,
            teacherContactId,
            becomesActive ? 1 : -1,
            nowIso,
            input.uid,
          );
        }
      }
      return { id: input.id, revision: Number(next.revision) };
    },
  );
}
