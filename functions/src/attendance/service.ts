/**
 * Atomic attendance saves and session-attendance reads (S04, S05, S08, S11).
 *
 * The first saved attendance freezes the eligible enrollment interval from the
 * authoritative enrollment reader and copies each student's display name into
 * the internal roster, so later renaming never changes historical labels and a
 * late enrollment can never silently join the session. Every save validates
 * the complete map against the frozen membership, checks the expected session
 * revision, and commits roster, marks, session revision and receipt in one
 * transaction; a stale revision or injected failure leaves everything
 * unchanged.
 */
import { Clock, recifeToday } from "../core/clock";
import { runCommand } from "../core/commands";
import { AuthorizedContext, authorizeContext } from "../core/context";
import { Datastore, JsonMap, Transaction, paths } from "../core/datastore";
import {
  conflictError,
  forbiddenError,
  notFoundError,
  validationError,
} from "../core/errors";
import { AttendanceStatus, ClassStatus, SessionStatus } from "../core/models";
import { rejectUnknownFields } from "../core/validation";
import {
  ClassEnrollmentReader,
  MAX_ROSTER_MEMBERS,
  attendanceEntryPath,
  enrollmentIdOf,
  isEligibleOnDate,
  readAttendance,
  readRoster,
  rosterEntryPath,
  sessionPath,
} from "./roster";

export interface SaveAttendanceInput {
  uid: string;
  requestId: string;
  congregationId: string;
  sessionId: string;
  expectedRevision: number;
  finalize: boolean;
  marks: Record<string, string>;
}

export interface AttendanceMutationResult {
  id: string;
  revision: number;
  status: string;
}

export interface RosterRow {
  enrollmentId: string;
  studentId: string;
  studentName: string;
  status: string;
}

export interface SessionAttendanceView {
  session: JsonMap;
  roster: RosterRow[];
}

export interface GetSessionAttendanceInput {
  uid: string;
  congregationId?: string | null;
  sessionId: string;
}

const SAVE_ATTENDANCE_FIELDS = [
  "congregationId",
  "sessionId",
  "expectedRevision",
  "finalize",
  "marks",
] as const;

const ATTENDANCE_STATUSES: ReadonlySet<string> = new Set(
  Object.values(AttendanceStatus),
);

function requireCongregationId(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw validationError("Attendance requires congregationId.", {
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

interface LocatedSession {
  document: JsonMap;
  path: string;
}

async function locateSession(
  tx: Transaction,
  congregationId: string,
  sessionId: string,
): Promise<LocatedSession> {
  const path = sessionPath(congregationId, sessionId);
  const document = await tx.read(path);
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Session not found.");
  }
  return { document, path };
}

/** Completed and archived classes are read-only for attendance (S08). */
async function assertMutableClass(
  tx: Transaction,
  congregationId: string,
  classId: string,
): Promise<void> {
  const document = await tx.read(paths.classGroup(congregationId, classId));
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Class not found.");
  }
  if (document.status !== ClassStatus.active) {
    throw conflictError("Completed classes are read-only.");
  }
}

function validateMarksShape(marks: unknown): asserts marks is Record<string, string> {
  if (marks === null || typeof marks !== "object" || Array.isArray(marks)) {
    throw validationError("Attendance marks must be a map of enrollment IDs.", {
      marks: "Attendance marks must be a map of enrollment IDs.",
    });
  }
}

function sortedKeys(value: Record<string, string>): string[] {
  return Object.keys(value).sort();
}

export async function saveAttendance(
  datastore: Datastore,
  clock: Clock,
  input: SaveAttendanceInput,
  enrollments: ClassEnrollmentReader,
): Promise<AttendanceMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SAVE_ATTENDANCE_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);
  const expectedRevision = requireRevision(input.expectedRevision);
  if (typeof input.finalize !== "boolean") {
    throw validationError("finalize must be true or false.", {
      finalize: "finalize must be true or false.",
    });
  }
  validateMarksShape(input.marks);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "saveAttendance",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) => {
      await assertActiveCongregation(tx, context, congregationId);
      const sessionId = requireId(input.sessionId, "sessionId");
      const located = await locateSession(tx, congregationId, sessionId);
      const session = located.document;
      const classId = requireId(session.classId, "classId");

      if (session.status === SessionStatus.canceled) {
        throw conflictError("Canceled sessions cannot be edited.");
      }
      if (session.status === SessionStatus.finalized && input.finalize !== true) {
        throw conflictError(
          "A finalized session can only be corrected with finalization.",
        );
      }
      await assertMutableClass(tx, congregationId, classId);

      const marks = input.marks;
      const markKeys = sortedKeys(marks);
      if (markKeys.length > MAX_ROSTER_MEMBERS) {
        throw conflictError(
          `A session is limited to ${MAX_ROSTER_MEMBERS} roster members.`,
        );
      }

      const nowIso = clock.now().toISOString();
      const sessionPatch: JsonMap = {};
      let rosterEntries: JsonMap[];

      if (session.rosterFrozen === true) {
        rosterEntries = await readRoster(tx, congregationId, sessionId);
      } else {
        // First saved attendance freezes the eligible interval. Completed and
        // withdrawn enrollment intervals are included; the class cap bounds
        // the transaction.
        const eligible = await enrollments.listClassEnrollments({
          congregationId,
          classId,
        });
        const members = eligible
          .filter((enrollment) => isEligibleOnDate(enrollment, String(session.date)))
          .sort((a, b) =>
            String(enrollmentIdOf(a) ?? "").localeCompare(
              String(enrollmentIdOf(b) ?? ""),
            ),
          );
        if (members.length > MAX_ROSTER_MEMBERS) {
          throw conflictError(
            `A session is limited to ${MAX_ROSTER_MEMBERS} roster members.`,
          );
        }
        rosterEntries = [];
        const frozenIds: string[] = [];
        for (const enrollment of members) {
          const enrollmentId = enrollmentIdOf(enrollment);
          if (enrollmentId === null) continue;
          const studentId = nonEmpty(enrollment.studentId) ?? "";
          const student = await tx.read(paths.student(congregationId, studentId));
          const studentName = nonEmpty(student?.name) ?? studentId;
          const entry: JsonMap = {
            id: enrollmentId,
            enrollmentId,
            studentId,
            studentName,
            sessionId,
            classId,
            congregationId,
            revision: 1,
            createdAt: nowIso,
            updatedAt: nowIso,
            updatedBy: input.uid,
          };
          await tx.write(
            rosterEntryPath(congregationId, sessionId, enrollmentId),
            entry,
          );
          frozenIds.push(enrollmentId);
          rosterEntries.push(entry);
        }
        sessionPatch.rosterFrozen = true;
        sessionPatch.rosterEnrollmentIds = frozenIds;
      }

      const rosterIds = rosterEntries
        .map((entry) => String(entry.enrollmentId))
        .sort();
      const sameMembership =
        rosterIds.length === markKeys.length &&
        rosterIds.every((id, index) => id === markKeys[index]);
      if (!sameMembership) {
        throw validationError(
          "A chamada deve conter exatamente o quadro de alunos congelado.",
          {
            marks:
              "A chamada deve conter exatamente o quadro de alunos congelado.",
          },
        );
      }

      const statusById = new Map<string, string>();
      for (const key of markKeys) {
        const status = marks[key];
        if (typeof status !== "string" || !ATTENDANCE_STATUSES.has(status)) {
          throw validationError("Status de presença inválido.", {
            marks: "Status de presença inválido.",
          });
        }
        statusById.set(key, status);
      }

      if (input.finalize) {
        if (rosterIds.length === 0) {
          throw conflictError(
            "A finalização exige pelo menos um aluno no quadro.",
          );
        }
        if (markKeys.some((key) => statusById.get(key) === AttendanceStatus.unmarked)) {
          throw validationError(
            "Todos os alunos devem ser marcados antes da finalização.",
            { marks: "Todos os alunos devem ser marcados antes da finalização." },
          );
        }
        if (String(session.date) > recifeToday(clock.now())) {
          throw validationError(
            "Uma chamada não pode ser finalizada antes da data da aula.",
            { date: "Uma chamada não pode ser finalizada antes da data da aula." },
          );
        }
      }

      for (const key of markKeys) {
        const rosterEntry = rosterEntries.find(
          (entry) => String(entry.enrollmentId) === key,
        );
        const studentId = nonEmpty(rosterEntry?.studentId) ?? "";
        const attendancePath = attendanceEntryPath(
          congregationId,
          sessionId,
          key,
        );
        const existing = await tx.read(attendancePath);
        await tx.write(attendancePath, {
          id: key,
          enrollmentId: key,
          studentId,
          status: statusById.get(key),
          sessionId,
          classId,
          congregationId,
          revision:
            existing === null ? 1 : Number(existing.revision ?? 0) + 1,
          createdAt: existing?.createdAt ?? nowIso,
          updatedAt: nowIso,
          updatedBy: input.uid,
        });
      }

      const targetStatus =
        input.finalize || session.status === SessionStatus.finalized
          ? SessionStatus.finalized
          : SessionStatus.open;
      const next = await tx.updateWithRevision(
        located.path,
        expectedRevision,
        (record) => ({
          ...record,
          ...sessionPatch,
          status: targetStatus,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );
      return {
        id: sessionId,
        revision: Number(next.revision),
        status: targetStatus,
      };
    },
  );
}

export async function getSessionAttendance(
  datastore: Datastore,
  input: GetSessionAttendanceInput,
): Promise<SessionAttendanceView> {
  const context = await authorizeContext({
    datastore,
    uid: input.uid,
    requestedCongregationId: input.congregationId ?? null,
  });
  const congregationId = context.congregationId;
  if (congregationId === null || congregationId.length === 0) {
    throw validationError("congregationId is required.", {
      congregationId: "congregationId is required.",
    });
  }
  const sessionId = requireId(input.sessionId, "sessionId");
  const session = await datastore.read(sessionPath(congregationId, sessionId));
  if (session === null || session.congregationId !== congregationId) {
    throw notFoundError("Session not found.");
  }

  const rosterEntries = await readRoster(datastore, congregationId, sessionId);
  const attendanceEntries = await readAttendance(
    datastore,
    congregationId,
    sessionId,
  );
  const statusById = new Map<string, string>();
  for (const entry of attendanceEntries) {
    statusById.set(String(entry.enrollmentId), String(entry.status));
  }

  const sessionView: JsonMap = {
    id: session.id,
    classId: session.classId,
    date: session.date,
    topic: session.topic ?? null,
    status: session.status,
    rosterFrozen: session.rosterFrozen === true,
    revision: session.revision,
  };
  const roster: RosterRow[] = rosterEntries.map((entry) => ({
    enrollmentId: String(entry.enrollmentId),
    studentId: String(entry.studentId ?? ""),
    studentName: String(entry.studentName ?? ""),
    status:
      statusById.get(String(entry.enrollmentId)) ?? AttendanceStatus.unmarked,
  }));

  return { session: sessionView, roster };
}
