import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  attendanceEntryPath,
  InMemoryClassEnrollmentReader,
  rosterEntryPath,
  sessionIndexPath,
  sessionPath,
} from "../../src/attendance/roster";
import { getEnrollmentProgress } from "../../src/attendance/progress";
import { saveAttendance } from "../../src/attendance/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import { cancelSession, createSession } from "../../src/sessions/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function enrollmentDoc(
  id: string,
  studentId: string,
  overrides: Record<string, unknown> = {},
): JsonMap {
  return {
    id,
    congregationId: "c1",
    classId: "cl1",
    studentId,
    startDate: "2026-03-01",
    endDate: null,
    status: "active",
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
    ...overrides,
  };
}

interface SessionSeed {
  id: string;
  date: string;
  sessionStatus: string;
  enrollmentId?: string;
  studentId?: string;
  attendanceStatus?: string;
}

function seedDatastore(sessions: readonly SessionSeed[]): InMemoryDatastore {
  const seed: Record<string, JsonMap> = {
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.user("staff1")]: {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.user("staff2")]: {
      accessRole: "congregationStaff",
      congregationId: "c2",
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
      active: true,
      revision: 1,
    },
    [paths.congregation("c2")]: {
      id: "c2",
      name: "Norte",
      normalizedName: "norte",
      active: true,
      revision: 1,
    },
    [paths.student("c1", "s1")]: {
      id: "s1",
      name: "Aluno Um",
      normalizedName: "aluno um",
      congregationId: "c1",
      archived: false,
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    },
    [paths.classGroup("c1", "cl1")]: {
      id: "cl1",
      congregationId: "c1",
      name: "Turma cl1",
      normalizedName: "turma cl1",
      teacherContactId: null,
      startDate: "2026-03-01",
      endDate: "2026-12-01",
      status: "active",
      enrollmentCount: 1,
      activeEnrollmentCount: 1,
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    },
    [paths.enrollment("c1", "enr1")]: enrollmentDoc("enr1", "s1"),
    [sessionIndexPath("c1", "cl1")]: {
      sessionIds: sessions.map((session) => session.id),
    },
  };

  for (const session of sessions) {
    seed[sessionPath("c1", session.id)] = {
      id: session.id,
      congregationId: "c1",
      classId: "cl1",
      date: session.date,
      topic: null,
      status: session.sessionStatus,
      rosterFrozen: true,
      rosterEnrollmentIds:
        session.enrollmentId === undefined ? [] : [session.enrollmentId],
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    };
    if (session.enrollmentId !== undefined) {
      seed[rosterEntryPath("c1", session.id, session.enrollmentId)] = {
        id: session.enrollmentId,
        enrollmentId: session.enrollmentId,
        studentId: session.studentId ?? "s1",
        studentName: "Aluno Um",
        sessionId: session.id,
        classId: "cl1",
        congregationId: "c1",
        revision: 1,
        createdAt: TIMESTAMP,
        updatedAt: TIMESTAMP,
        updatedBy: "sup1",
      };
      seed[attendanceEntryPath("c1", session.id, session.enrollmentId)] = {
        id: session.enrollmentId,
        enrollmentId: session.enrollmentId,
        studentId: session.studentId ?? "s1",
        status: session.attendanceStatus ?? "unmarked",
        sessionId: session.id,
        classId: "cl1",
        congregationId: "c1",
        revision: 1,
        createdAt: TIMESTAMP,
        updatedAt: TIMESTAMP,
        updatedBy: "sup1",
      };
    }
  }
  return new InMemoryDatastore(seed);
}

function progressInput(
  overrides: Record<string, unknown> = {},
): Parameters<typeof getEnrollmentProgress>[1] {
  return {
    uid: "sup1",
    congregationId: "c1",
    enrollmentId: "enr1",
    ...overrides,
  } as unknown as Parameters<typeof getEnrollmentProgress>[1];
}

async function expectAppError(run: () => Promise<unknown>): Promise<AppError> {
  try {
    await run();
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    return error as AppError;
  }
  throw new Error("expected an AppError to be thrown");
}

describe("getEnrollmentProgress", () => {
  it("counts only finalized noncanceled sessions and excludes excused", async () => {
    const datastore = seedDatastore([
      { id: "sA", date: "2026-04-01", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "present" },
      { id: "sB", date: "2026-04-08", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "absent" },
      { id: "sC", date: "2026-04-15", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "present" },
      { id: "sD", date: "2026-04-22", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "present" },
      { id: "sE", date: "2026-04-29", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "excused" },
      { id: "sF", date: "2026-05-06", sessionStatus: "canceled", enrollmentId: "enr1", attendanceStatus: "present" },
      { id: "sG", date: "2026-05-13", sessionStatus: "open", enrollmentId: "enr1", attendanceStatus: "present" },
    ]);

    const progress = await getEnrollmentProgress(datastore, progressInput());
    expect(progress).toEqual({
      enrollmentId: "enr1",
      studentId: "s1",
      classId: "cl1",
      present: 3,
      absent: 1,
      excused: 1,
      total: 4,
      percentage: 75,
    });
  });

  it("keeps the percentage null when the denominator is zero", async () => {
    const datastore = seedDatastore([
      { id: "sF", date: "2026-05-06", sessionStatus: "canceled", enrollmentId: "enr1", attendanceStatus: "present" },
      { id: "sG", date: "2026-05-13", sessionStatus: "open", enrollmentId: "enr1", attendanceStatus: "present" },
    ]);

    const progress = await getEnrollmentProgress(datastore, progressInput());
    expect(progress).toEqual({
      enrollmentId: "enr1",
      studentId: "s1",
      classId: "cl1",
      present: 0,
      absent: 0,
      excused: 0,
      total: 0,
      percentage: null,
    });
  });

  it("ignores finalized sessions whose frozen roster does not contain the enrollment", async () => {
    const datastore = seedDatastore([
      { id: "sA", date: "2026-04-01", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "present" },
      { id: "sB", date: "2026-04-08", sessionStatus: "finalized", enrollmentId: "other", studentId: "s1", attendanceStatus: "absent" },
    ]);

    const progress = await getEnrollmentProgress(datastore, progressInput());
    expect(progress.present).toBe(1);
    expect(progress.absent).toBe(0);
    expect(progress.total).toBe(1);
    expect(progress.percentage).toBe(100);
  });

  it("excludes a canceled session from a real save, finalize and cancel flow", async () => {
    const datastore = seedDatastore([]);
    const sessionId = randomUUID();
    await createSession(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: sessionId,
      congregationId: "c1",
      classId: "cl1",
      date: "2026-06-10",
      topic: null,
    } as unknown as Parameters<typeof createSession>[2]);
    await saveAttendance(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        congregationId: "c1",
        sessionId,
        expectedRevision: 1,
        finalize: true,
        marks: { enr1: "present" },
      } as unknown as Parameters<typeof saveAttendance>[2],
      new InMemoryClassEnrollmentReader({
        enrollments: [enrollmentDoc("enr1", "s1")],
      }),
    );

    const before = await getEnrollmentProgress(datastore, progressInput());
    expect(before.present).toBe(1);
    expect(before.percentage).toBe(100);

    await cancelSession(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: sessionId,
      congregationId: "c1",
      expectedRevision: 2,
    } as unknown as Parameters<typeof cancelSession>[2]);

    const after = await getEnrollmentProgress(datastore, progressInput());
    expect(after.present).toBe(0);
    expect(after.absent).toBe(0);
    expect(after.total).toBe(0);
    expect(after.percentage).toBeNull();
  });

  it("denies anonymous and cross-congregation access and hides unknown enrollments", async () => {
    const datastore = seedDatastore([
      { id: "sA", date: "2026-04-01", sessionStatus: "finalized", enrollmentId: "enr1", attendanceStatus: "present" },
    ]);

    const anonymous = await expectAppError(() =>
      getEnrollmentProgress(datastore, progressInput({ uid: "ghost" })),
    );
    expect(anonymous.code).toBe("forbidden");

    const crossScope = await expectAppError(() =>
      getEnrollmentProgress(datastore, progressInput({ uid: "staff2" })),
    );
    expect(crossScope.code).toBe("forbidden");

    const unknown = await expectAppError(() =>
      getEnrollmentProgress(datastore, progressInput({ enrollmentId: "missing" })),
    );
    expect(unknown.code).toBe("notFound");
  });
});
