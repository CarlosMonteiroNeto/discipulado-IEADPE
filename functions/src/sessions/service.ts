/**
 * Session lifecycle over the authorized transaction boundary (S04, S05, S08,
 * S11).
 *
 * A session is an open record until attendance is saved or it is finalized;
 * cancellation keeps the document and its roster/marks as history. Uniqueness
 * is per class/date for noncanceled sessions: creation claims the internal
 * `sessionDates/{date}` document and cancellation releases it, so a canceled
 * session never blocks a replacement. Every class session ID is appended to an
 * internal index so progress reads do not need a collection scan.
 */
import {
  sessionDateLockPath,
  sessionIndexPath,
  sessionPath,
} from "../attendance/roster";
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
import { ClassStatus, SessionStatus } from "../core/models";
import {
  SESSION_TOPIC_MAX_LENGTH,
  parseCalendarDate,
  rejectUnknownFields,
  validateOptionalText,
} from "../core/validation";

export interface CreateSessionInput {
  uid: string;
  requestId: string;
  id: string;
  congregationId: string;
  classId: string;
  date: string;
  topic?: string | null;
}

export interface CancelSessionInput {
  uid: string;
  requestId: string;
  id: string;
  congregationId: string;
  expectedRevision: number;
}

export interface SessionMutationResult {
  id: string;
  revision: number;
  status: string;
}

const CREATE_SESSION_FIELDS = [
  "id",
  "congregationId",
  "classId",
  "date",
  "topic",
] as const;

const CANCEL_SESSION_FIELDS = [
  "id",
  "congregationId",
  "expectedRevision",
] as const;

function requireCongregationId(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw validationError("A session requires congregationId.", {
      congregationId: "congregationId is required.",
    });
  }
  return value;
}

function requireId(value: unknown, field: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw validationError(`${field} is required.`, {
      [field]: `${field} is required.`,
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

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

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

function assertWithinClassPeriod(date: string, classDocument: JsonMap): void {
  const classStart = nonEmpty(classDocument.startDate);
  if (classStart !== null && date < classStart) {
    throw validationError("A data deve estar dentro do período da turma.", {
      date: "A data deve estar dentro do período da turma.",
    });
  }
  const classEnd = nonEmpty(classDocument.endDate);
  if (classEnd !== null && date > classEnd) {
    throw validationError("A data deve estar dentro do período da turma.", {
      date: "A data deve estar dentro do período da turma.",
    });
  }
}

async function locateActiveClass(
  tx: Transaction,
  congregationId: string,
  classId: string,
): Promise<JsonMap> {
  const path = paths.classGroup(congregationId, classId);
  const document = await tx.read(path);
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Class not found.");
  }
  if (document.status !== ClassStatus.active) {
    throw conflictError("Sessions require an active class.");
  }
  return document;
}

/**
 * Completed and archived classes are read-only (S08), so cancellation is
 * refused for the same reason createSession and saveAttendance refuse it.
 * The owning class is resolved from the authoritative datastore record inside
 * the transaction, never from caller-supplied class data.
 */
async function assertMutableClass(
  tx: Transaction,
  congregationId: string,
  classId: unknown,
): Promise<void> {
  if (typeof classId !== "string" || classId.length === 0) {
    throw conflictError("The session class is unavailable.");
  }
  const document = await tx.read(paths.classGroup(congregationId, classId));
  if (document === null || document.congregationId !== congregationId) {
    throw conflictError("The session class is unavailable.");
  }
  if (document.status !== ClassStatus.active) {
    throw conflictError("Completed and archived classes are read-only.");
  }
}

async function appendSessionIndex(
  tx: Transaction,
  congregationId: string,
  classId: string,
  sessionId: string,
): Promise<void> {
  const path = sessionIndexPath(congregationId, classId);
  const current = await tx.read(path);
  const ids = Array.isArray(current?.sessionIds)
    ? (current?.sessionIds as unknown[]).filter(
        (value): value is string => typeof value === "string",
      )
    : [];
  if (!ids.includes(sessionId)) ids.push(sessionId);
  if (current === null) {
    await tx.createStable(path, {
      congregationId,
      classId,
      sessionIds: ids,
    });
    return;
  }
  await tx.write(path, { ...current, sessionIds: ids });
}

export async function createSession(
  datastore: Datastore,
  clock: Clock,
  input: CreateSessionInput,
): Promise<SessionMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, CREATE_SESSION_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "createSession",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) => {
      await assertActiveCongregation(tx, context, congregationId);
      const classId = requireId(input.classId, "classId");
      const classDocument = await locateActiveClass(tx, congregationId, classId);
      const date = requireDate(input.date, "date");
      assertWithinClassPeriod(date, classDocument);
      validateOptionalText(input.topic, SESSION_TOPIC_MAX_LENGTH, "topic");
      if (!isUuid(input.id)) {
        throw validationError("id must be a UUID.", { id: "id must be a UUID." });
      }
      const topic =
        typeof input.topic === "string" && input.topic.trim().length > 0
          ? input.topic.trim()
          : null;

      const lockPath = sessionDateLockPath(congregationId, classId, date);
      const lock = await tx.read(lockPath);
      if (lock !== null) {
        throw conflictError("A session already exists for this class and date.");
      }

      const nowIso = clock.now().toISOString();
      await tx.createStable(sessionPath(congregationId, input.id), {
        id: input.id,
        congregationId,
        classId,
        date,
        topic,
        status: SessionStatus.open,
        rosterFrozen: false,
        rosterEnrollmentIds: [],
        revision: 1,
        createdAt: nowIso,
        updatedAt: nowIso,
        updatedBy: input.uid,
      });
      await tx.createStable(lockPath, {
        congregationId,
        classId,
        date,
        sessionId: input.id,
      });
      await appendSessionIndex(tx, congregationId, classId, input.id);
      return { id: input.id, revision: 1, status: SessionStatus.open };
    },
  );
}

export async function cancelSession(
  datastore: Datastore,
  clock: Clock,
  input: CancelSessionInput,
): Promise<SessionMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, CANCEL_SESSION_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);
  const expectedRevision = requireRevision(input.expectedRevision);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "cancelSession",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) => {
      await assertActiveCongregation(tx, context, congregationId);
      const sessionId = requireId(input.id, "id");
      const path = sessionPath(congregationId, sessionId);
      const session = await tx.read(path);
      if (session === null || session.congregationId !== congregationId) {
        throw notFoundError("Session not found.");
      }
      if (session.status === SessionStatus.canceled) {
        return {
          id: sessionId,
          revision: Number(session.revision),
          status: SessionStatus.canceled,
        };
      }

      // The owning class must still be active; completed and archived classes
      // are read-only, so their sessions cannot be canceled after completion.
      await assertMutableClass(tx, congregationId, session.classId);

      const nowIso = clock.now().toISOString();
      const next = await tx.updateWithRevision(
        path,
        expectedRevision,
        (record) => ({
          ...record,
          status: SessionStatus.canceled,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );

      const classId = nonEmpty(session.classId);
      const date = nonEmpty(session.date);
      if (classId !== null && date !== null) {
        const lockPath = sessionDateLockPath(congregationId, classId, date);
        const lock = await tx.read(lockPath);
        if (lock !== null && lock.sessionId === sessionId) {
          await tx.delete(lockPath);
        }
      }
      return {
        id: sessionId,
        revision: Number(next.revision),
        status: SessionStatus.canceled,
      };
    },
  );
}
