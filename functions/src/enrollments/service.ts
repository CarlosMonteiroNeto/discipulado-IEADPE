/**
 * Enrollment lifecycle over the authorized transaction boundary (S04, S05,
 * S07, S08, S11).
 *
 * An enrollment links one student to one class inside a congregation and
 * preserves history: closing records completed/withdrawn with an explicit end
 * date and never deletes the document or the class's historical capacity. A
 * student has at most one active enrollment, enforced through the internal
 * `activeEnrollmentRefs/{studentId}` uniqueness document the student feature
 * already reads for its archive guard. The per-class cap of 100 total
 * enrollment records is enforced against the class document counter inside the
 * same transaction, so closing an enrollment does not free capacity.
 *
 * Frozen-roster rules read session and roster documents through the injected
 * [ClassSessionReader]; the core Datastore exposes no collection queries and
 * sessions are owned by the session feature (task 6).
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
import { EnrollmentStatus } from "../core/models";
import {
  parseCalendarDate,
  rejectUnknownFields,
  validateEnum,
} from "../core/validation";
import {
  ClassSessionReader,
  MAX_ENROLLMENTS_PER_CLASS,
} from "../classes/service";
import { activeEnrollmentReferencePath } from "../students/service";

export interface EnrollStudentInput {
  uid: string;
  requestId: string;
  id: string;
  expectedRevision?: number;
  congregationId: string;
  classId: string;
  studentId: string;
  startDate: string;
}

export interface CloseEnrollmentInput {
  uid: string;
  requestId: string;
  id: string;
  congregationId: string;
  status: string;
  endDate: string;
  expectedRevision: number;
}

export interface EnrollmentMutationResult {
  id: string;
  revision: number;
}

const ENROLL_STUDENT_FIELDS = [
  "id",
  "expectedRevision",
  "congregationId",
  "classId",
  "studentId",
  "startDate",
] as const;

const CLOSE_ENROLLMENT_FIELDS = [
  "id",
  "congregationId",
  "status",
  "endDate",
  "expectedRevision",
] as const;

/**
 * Serializes enrollment mutations per datastore.
 *
 * The in-memory datastore used by unit tests does not retry concurrent
 * transactions, so two simultaneous enrollments could both observe a free
 * uniqueness document or the same cap counter and each stage a write. The
 * authoritative Firestore datastore retries transactions and does not need
 * this, but the serialization keeps the "one active enrollment" and cap checks
 * true for every datastore implementation.
 */
const enrollmentLocks = new WeakMap<object, Promise<void>>();

async function withEnrollmentLock<T>(
  datastore: object,
  work: () => Promise<T>,
): Promise<T> {
  const previous = enrollmentLocks.get(datastore) ?? Promise.resolve();
  let release!: () => void;
  const tail = new Promise<void>((resolve) => {
    release = resolve;
  });
  enrollmentLocks.set(
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

function requireCongregationId(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw validationError("An enrollment requires congregationId.", {
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

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function referenceCount(document: JsonMap | null, field: string): number {
  const value = document?.[field];
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
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

interface LocatedDocument {
  document: JsonMap;
  path: string;
}

async function locateClass(
  tx: Transaction,
  congregationId: string,
  classId: unknown,
  requireActive: boolean,
): Promise<LocatedDocument> {
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
  if (requireActive && document.status !== "active") {
    throw conflictError("Enrollments require an active class.");
  }
  return { document, path };
}

async function locateStudent(
  tx: Transaction,
  congregationId: string,
  studentId: unknown,
): Promise<JsonMap> {
  if (typeof studentId !== "string" || studentId.length === 0) {
    throw validationError("studentId is required.", {
      studentId: "studentId is required.",
    });
  }
  const path = paths.student(congregationId, studentId);
  const document = await tx.read(path);
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Student not found.");
  }
  return document;
}

async function locateEnrollment(
  tx: Transaction,
  congregationId: string,
  enrollmentId: unknown,
): Promise<LocatedDocument> {
  if (typeof enrollmentId !== "string" || enrollmentId.length === 0) {
    throw validationError("id is required.", { id: "id is required." });
  }
  const path = paths.enrollment(congregationId, enrollmentId);
  const document = await tx.read(path);
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Enrollment not found.");
  }
  return { document, path };
}

function assertWithinClassPeriod(
  date: string,
  field: string,
  classDocument: JsonMap,
): void {
  const classStart = nonEmpty(classDocument.startDate);
  if (classStart !== null && date < classStart) {
    throw validationError(
      "A data deve estar dentro do período da turma.",
      { [field]: "A data deve estar dentro do período da turma." },
    );
  }
  const classEnd = nonEmpty(classDocument.endDate);
  if (classEnd !== null && date > classEnd) {
    throw validationError(
      "A data deve estar dentro do período da turma.",
      { [field]: "A data deve estar dentro do período da turma." },
    );
  }
}

async function listFrozenSessionsContaining(
  sessions: ClassSessionReader,
  congregationId: string,
  classId: string,
  enrollmentId: string,
  includeCanceled: boolean,
): Promise<string[]> {
  const classSessions = await sessions.listSessions({
    congregationId,
    classId,
  });
  const dates: string[] = [];
  for (const session of classSessions) {
    if (session.rosterFrozen !== true) continue;
    if (!includeCanceled && session.status === "canceled") continue;
    const sessionId = nonEmpty(session.id);
    const date = nonEmpty(session.date);
    if (sessionId === null || date === null) continue;
    const entries = await sessions.listRosterEntries({
      congregationId,
      classId,
      sessionId,
    });
    if (entries.some((entry) => entry.enrollmentId === enrollmentId)) {
      dates.push(date);
    }
  }
  return dates;
}

async function isInAnyFrozenRoster(
  sessions: ClassSessionReader,
  congregationId: string,
  classId: string,
  enrollmentId: string,
): Promise<boolean> {
  const dates = await listFrozenSessionsContaining(
    sessions,
    congregationId,
    classId,
    enrollmentId,
    true,
  );
  return dates.length > 0;
}

async function latestNoncanceledFrozenDate(
  sessions: ClassSessionReader,
  congregationId: string,
  classId: string,
  enrollmentId: string,
): Promise<string | null> {
  const dates = await listFrozenSessionsContaining(
    sessions,
    congregationId,
    classId,
    enrollmentId,
    false,
  );
  let latest: string | null = null;
  for (const date of dates) {
    if (latest === null || date > latest) latest = date;
  }
  return latest;
}

/**
 * Rewrites the class document with updated denormalized counters while
 * preserving its user-visible fields and revision. Counter changes are not
 * user edits, so they do not invalidate a client's expectedRevision.
 */
async function writeClassCounters(
  tx: Transaction,
  congregationId: string,
  classDocument: JsonMap,
  updates: { enrollmentCount?: number; activeEnrollmentCount?: number },
): Promise<void> {
  const classId = nonEmpty(classDocument.id);
  if (classId === null) return;
  await tx.write(paths.classGroup(congregationId, classId), {
    ...classDocument,
    ...updates,
  });
}

export async function enrollStudent(
  datastore: Datastore,
  clock: Clock,
  input: EnrollStudentInput,
  sessions: ClassSessionReader,
): Promise<EnrollmentMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, ENROLL_STUDENT_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);

  return withEnrollmentLock(datastore, () =>
    runCommand(
      datastore,
      clock,
      {
        uid: input.uid,
        requestId: input.requestId,
        operation: "enrollStudent",
        payload,
        requestedCongregationId: congregationId,
      },
      async (tx, context) => {
        await assertActiveCongregation(tx, context, congregationId);
        const startDate = requireDate(input.startDate, "startDate");
        const nowIso = clock.now().toISOString();
        const isCreate = input.expectedRevision === undefined;

        if (isCreate) {
          if (!isUuid(input.id)) {
            throw validationError("id must be a UUID.", {
              id: "id must be a UUID.",
            });
          }
          const locatedClass = await locateClass(
            tx,
            congregationId,
            input.classId,
            true,
          );
          const classDocument = locatedClass.document;
          assertWithinClassPeriod(startDate, "startDate", classDocument);
          const student = await locateStudent(
            tx,
            congregationId,
            input.studentId,
          );
          if (student.archived === true) {
            throw conflictError("Archived students cannot be enrolled.");
          }
          const referencePath = activeEnrollmentReferencePath(
            congregationId,
            input.studentId,
          );
          const reference = await tx.read(referencePath);
          if (reference !== null) {
            throw conflictError("Student already has an active enrollment.");
          }
          const enrollmentCount = referenceCount(
            classDocument,
            "enrollmentCount",
          );
          if (enrollmentCount >= MAX_ENROLLMENTS_PER_CLASS) {
            throw conflictError(
              `A class is limited to ${MAX_ENROLLMENTS_PER_CLASS} enrollment records.`,
            );
          }
          await tx.createStable(paths.enrollment(congregationId, input.id), {
            id: input.id,
            congregationId,
            classId: input.classId,
            studentId: input.studentId,
            startDate,
            endDate: null,
            status: EnrollmentStatus.active,
            revision: 1,
            createdAt: nowIso,
            updatedAt: nowIso,
            updatedBy: input.uid,
          });
          await tx.createStable(referencePath, {
            studentId: input.studentId,
            congregationId,
            enrollmentId: input.id,
            classId: input.classId,
            revision: 1,
            createdAt: nowIso,
            updatedAt: nowIso,
            updatedBy: input.uid,
          });
          await writeClassCounters(tx, congregationId, classDocument, {
            enrollmentCount: enrollmentCount + 1,
            activeEnrollmentCount:
              referenceCount(classDocument, "activeEnrollmentCount") + 1,
          });
          return { id: input.id, revision: 1 };
        }

        const expectedRevision = requireRevision(input.expectedRevision);
        const located = await locateEnrollment(tx, congregationId, input.id);
        const stored = located.document;
        if (stored.status !== EnrollmentStatus.active) {
          throw conflictError("A closed enrollment is immutable.");
        }
        if (stored.studentId !== input.studentId) {
          throw validationError("An enrollment cannot change its student.", {
            studentId: "An enrollment cannot change its student.",
          });
        }
        if (stored.classId !== input.classId) {
          throw validationError("An enrollment cannot change its class.", {
            classId: "An enrollment cannot change its class.",
          });
        }
        const locatedClass = await locateClass(
          tx,
          congregationId,
          input.classId,
          true,
        );
        assertWithinClassPeriod(
          startDate,
          "startDate",
          locatedClass.document,
        );
        const storedStart = String(stored.startDate ?? "");
        if (
          startDate !== storedStart &&
          (await isInAnyFrozenRoster(
            sessions,
            congregationId,
            input.classId,
            input.id,
          ))
        ) {
          throw conflictError(
            "The start date cannot change once the enrollment is in a frozen roster.",
          );
        }
        const next = await tx.updateWithRevision(
          located.path,
          expectedRevision,
          (record) => ({
            ...record,
            startDate,
            updatedAt: nowIso,
            updatedBy: input.uid,
          }),
        );
        return { id: input.id, revision: Number(next.revision) };
      },
    ),
  );
}

export async function closeEnrollment(
  datastore: Datastore,
  clock: Clock,
  input: CloseEnrollmentInput,
  sessions: ClassSessionReader,
): Promise<EnrollmentMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, CLOSE_ENROLLMENT_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);
  const targetStatus = validateEnum(input.status, EnrollmentStatus, "status");
  if (targetStatus === EnrollmentStatus.active) {
    throw validationError(
      "Closing an enrollment requires completed or withdrawn.",
      { status: "Closing an enrollment requires completed or withdrawn." },
    );
  }
  const expectedRevision = requireRevision(input.expectedRevision);

  return withEnrollmentLock(datastore, () =>
    runCommand(
      datastore,
      clock,
      {
        uid: input.uid,
        requestId: input.requestId,
        operation: "closeEnrollment",
        payload,
        requestedCongregationId: congregationId,
      },
      async (tx, context) => {
        await assertActiveCongregation(tx, context, congregationId);
        const endDate = requireDate(input.endDate, "endDate");
        const located = await locateEnrollment(tx, congregationId, input.id);
        const stored = located.document;
        if (stored.status !== EnrollmentStatus.active) {
          throw conflictError("A closed enrollment is immutable.");
        }
        const startDate = String(stored.startDate ?? "");
        if (endDate < startDate) {
          throw validationError(
            "A data final deve ser igual ou posterior à data inicial.",
            { endDate: "A data final deve ser igual ou posterior à data inicial." },
          );
        }
        const classId = nonEmpty(stored.classId);
        const studentId = nonEmpty(stored.studentId);
        if (classId === null || studentId === null) {
          throw conflictError("Enrollment is missing its class or student.");
        }
        const locatedClass = await locateClass(
          tx,
          congregationId,
          classId,
          false,
        );
        assertWithinClassPeriod(endDate, "endDate", locatedClass.document);

        const frozenFloor = await latestNoncanceledFrozenDate(
          sessions,
          congregationId,
          classId,
          input.id,
        );
        if (frozenFloor !== null && endDate < frozenFloor) {
          throw conflictError(
            "The end date cannot precede the latest frozen session containing the enrollment.",
          );
        }

        const nowIso = clock.now().toISOString();
        const next = await tx.updateWithRevision(
          located.path,
          expectedRevision,
          (record) => ({
            ...record,
            status: targetStatus,
            endDate,
            updatedAt: nowIso,
            updatedBy: input.uid,
          }),
        );

        const referencePath = activeEnrollmentReferencePath(
          congregationId,
          studentId,
        );
        const reference = await tx.read(referencePath);
        if (reference !== null && reference.enrollmentId === input.id) {
          await tx.delete(referencePath);
        }
        await writeClassCounters(tx, congregationId, locatedClass.document, {
          activeEnrollmentCount: Math.max(
            0,
            referenceCount(locatedClass.document, "activeEnrollmentCount") - 1,
          ),
        });
        return { id: input.id, revision: Number(next.revision) };
      },
    ),
  );
}
