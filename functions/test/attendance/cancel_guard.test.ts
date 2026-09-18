import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  attendanceEntryPath,
  rosterEntryPath,
  sessionPath,
} from "../../src/attendance/roster";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import { cancelSession } from "../../src/sessions/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function congregationDoc(): JsonMap {
  return {
    id: "c1",
    name: "Central",
    normalizedName: "central",
    active: true,
    revision: 1,
  };
}

function classDoc(id: string, status: string): JsonMap {
  return {
    id,
    congregationId: "c1",
    name: `Turma ${id}`,
    normalizedName: `turma ${id}`,
    teacherContactId: null,
    startDate: "2026-03-01",
    endDate: "2026-12-01",
    status,
    enrollmentCount: 1,
    activeEnrollmentCount: 0,
    revision: 2,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
  };
}

function sessionDoc(
  id: string,
  classId: string,
  overrides: Record<string, unknown> = {},
): JsonMap {
  return {
    id,
    congregationId: "c1",
    classId,
    date: "2026-06-10",
    topic: null,
    status: "finalized",
    rosterFrozen: true,
    rosterEnrollmentIds: ["e1"],
    revision: 2,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
    ...overrides,
  };
}

function rosterEntryDoc(sessionId: string): JsonMap {
  return {
    id: "e1",
    enrollmentId: "e1",
    studentId: "s1",
    studentName: "Aluno Um",
    sessionId,
    classId: "clCompleted",
    congregationId: "c1",
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
  };
}

function attendanceEntryDoc(sessionId: string): JsonMap {
  return {
    id: "e1",
    enrollmentId: "e1",
    studentId: "s1",
    status: "present",
    sessionId,
    classId: "clCompleted",
    congregationId: "c1",
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
  };
}

function seedDatastore(): InMemoryDatastore {
  const completedId = "sessCompleted";
  const archivedId = "sessArchived";
  return new InMemoryDatastore({
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.congregation("c1")]: congregationDoc(),
    [paths.classGroup("c1", "clActive")]: classDoc("clActive", "active"),
    [paths.classGroup("c1", "clCompleted")]: classDoc("clCompleted", "completed"),
    [paths.classGroup("c1", "clArchived")]: classDoc("clArchived", "archived"),
    [paths.classGroup("c1", "clForeign")]: {
      ...classDoc("clForeign", "active"),
      congregationId: "c2",
    },
    [sessionPath("c1", completedId)]: sessionDoc(completedId, "clCompleted"),
    [rosterEntryPath("c1", completedId, "e1")]: rosterEntryDoc(completedId),
    [attendanceEntryPath("c1", completedId, "e1")]:
      attendanceEntryDoc(completedId),
    [sessionPath("c1", archivedId)]: sessionDoc(archivedId, "clArchived"),
    [rosterEntryPath("c1", archivedId, "e1")]: {
      ...rosterEntryDoc(archivedId),
      classId: "clArchived",
    },
    [attendanceEntryPath("c1", archivedId, "e1")]: {
      ...attendanceEntryDoc(archivedId),
      classId: "clArchived",
    },
    [sessionPath("c1", "sessActive")]: sessionDoc("sessActive", "clActive", {
      status: "open",
      rosterFrozen: false,
      rosterEnrollmentIds: [],
      revision: 1,
    }),
    [sessionPath("c1", "sessMissingClass")]: sessionDoc(
      "sessMissingClass",
      "clGhost",
    ),
    [sessionPath("c1", "sessForeignClass")]: sessionDoc(
      "sessForeignClass",
      "clForeign",
    ),
  });
}

function cancelInput(
  id: string,
  overrides: Record<string, unknown> = {},
): Parameters<typeof cancelSession>[2] {
  return {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    congregationId: "c1",
    expectedRevision: 2,
    ...overrides,
  } as unknown as Parameters<typeof cancelSession>[2];
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

describe("cancelSession class-status guard", () => {
  it("rejects a session in a completed class without writing anything", async () => {
    const datastore = seedDatastore();
    const input = cancelInput("sessCompleted");
    const beforeSession = await datastore.read(sessionPath("c1", "sessCompleted"));
    const beforeRoster = await datastore.read(
      rosterEntryPath("c1", "sessCompleted", "e1"),
    );
    const beforeAttendance = await datastore.read(
      attendanceEntryPath("c1", "sessCompleted", "e1"),
    );

    const error = await expectAppError(() => cancelSession(datastore, clock, input));
    expect(error.code).toBe("conflict");

    expect(await datastore.read(sessionPath("c1", "sessCompleted"))).toEqual(
      beforeSession,
    );
    expect(
      (await datastore.read(sessionPath("c1", "sessCompleted")))?.status,
    ).toBe("finalized");
    expect(
      (await datastore.read(sessionPath("c1", "sessCompleted")))?.revision,
    ).toBe(2);
    expect(
      await datastore.read(rosterEntryPath("c1", "sessCompleted", "e1")),
    ).toEqual(beforeRoster);
    expect(
      await datastore.read(attendanceEntryPath("c1", "sessCompleted", "e1")),
    ).toEqual(beforeAttendance);
    expect(await datastore.read(paths.receipt("sup1", input.requestId))).toBeNull();
  });

  it("rejects a session in an archived class as well", async () => {
    const datastore = seedDatastore();
    const input = cancelInput("sessArchived");

    const error = await expectAppError(() => cancelSession(datastore, clock, input));
    expect(error.code).toBe("conflict");
    const session = await datastore.read(sessionPath("c1", "sessArchived"));
    expect(session?.status).toBe("finalized");
    expect(session?.revision).toBe(2);
    expect(await datastore.read(paths.receipt("sup1", input.requestId))).toBeNull();
  });

  it("rejects a session whose owning class is missing or foreign", async () => {
    const datastore = seedDatastore();

    const missing = await expectAppError(() =>
      cancelSession(datastore, clock, cancelInput("sessMissingClass")),
    );
    expect(missing.code).toBe("conflict");

    const foreign = await expectAppError(() =>
      cancelSession(datastore, clock, cancelInput("sessForeignClass")),
    );
    expect(foreign.code).toBe("conflict");

    expect(
      (await datastore.read(sessionPath("c1", "sessMissingClass")))?.status,
    ).toBe("finalized");
    expect(
      (await datastore.read(sessionPath("c1", "sessForeignClass")))?.status,
    ).toBe("finalized");
  });

  it("still cancels a session whose class is active", async () => {
    const datastore = seedDatastore();
    const input = cancelInput("sessActive", { expectedRevision: 1 });

    const result = await cancelSession(datastore, clock, input);
    expect(result).toEqual({ id: "sessActive", revision: 2, status: "canceled" });

    const session = await datastore.read(sessionPath("c1", "sessActive"));
    expect(session?.status).toBe("canceled");
    expect(session?.revision).toBe(2);
    expect(await datastore.read(paths.receipt("sup1", input.requestId))).not.toBeNull();
  });
});
