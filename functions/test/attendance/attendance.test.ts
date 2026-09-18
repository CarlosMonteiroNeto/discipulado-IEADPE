import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { InMemoryClassEnrollmentReader } from "../../src/attendance/roster";
import {
  attendanceEntryPath,
  rosterEntryPath,
  sessionPath,
} from "../../src/attendance/roster";
import { getSessionAttendance, saveAttendance } from "../../src/attendance/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import { createSession } from "../../src/sessions/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function classDoc(id: string, overrides: Record<string, unknown> = {}): JsonMap {
  return {
    id,
    congregationId: "c1",
    name: `Turma ${id}`,
    normalizedName: `turma ${id}`,
    teacherContactId: null,
    startDate: "2026-03-01",
    endDate: "2026-12-01",
    status: "active",
    enrollmentCount: 0,
    activeEnrollmentCount: 0,
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
    ...overrides,
  };
}

function studentDoc(id: string, name: string, overrides: Record<string, unknown> = {}): JsonMap {
  return {
    id,
    name,
    normalizedName: name.toLowerCase(),
    congregationId: "c1",
    phoneE164: null,
    birthDate: null,
    address: null,
    education: null,
    maritalStatus: null,
    newConvert: null,
    waterBaptized: null,
    wantsBaptism: null,
    archived: false,
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "sup1",
    ...overrides,
  };
}

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

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
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
    [paths.classGroup("c1", "cl1")]: classDoc("cl1"),
    [paths.classGroup("c1", "clCompleted")]: classDoc("clCompleted", {
      status: "completed",
      revision: 2,
    }),
    [paths.student("c1", "s1")]: studentDoc("s1", "Aluno Um"),
    [paths.student("c1", "s2")]: studentDoc("s2", "Aluno Dois"),
    [paths.student("c1", "s3")]: studentDoc("s3", "Aluno Três"),
    [paths.student("c1", "s4")]: studentDoc("s4", "Aluno Quatro"),
    [paths.student("c1", "s5")]: studentDoc("s5", "Aluno Cinco"),
  });
}

function defaultReader(): InMemoryClassEnrollmentReader {
  return new InMemoryClassEnrollmentReader({
    enrollments: [
      enrollmentDoc("e1", "s1"),
      enrollmentDoc("e2", "s2"),
      enrollmentDoc("e4", "s4", {
        startDate: "2026-01-01",
        endDate: "2026-08-01",
        status: "withdrawn",
      }),
      enrollmentDoc("e3late", "s3", { startDate: "2026-09-01" }),
      enrollmentDoc("e5", "s5", { startDate: "2026-07-01" }),
    ],
  });
}

const ELIGIBLE = ["e1", "e2", "e4"];

function sessionInput(
  id: string,
  overrides: Record<string, unknown> = {},
): Parameters<typeof createSession>[2] {
  return {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    congregationId: "c1",
    classId: "cl1",
    date: "2026-06-10",
    topic: null,
    ...overrides,
  } as unknown as Parameters<typeof createSession>[2];
}

function saveInput(
  sessionId: string,
  overrides: Record<string, unknown> = {},
): Parameters<typeof saveAttendance>[2] {
  return {
    uid: "sup1",
    requestId: randomUUID(),
    congregationId: "c1",
    sessionId,
    expectedRevision: 1,
    finalize: false,
    marks: { e1: "present", e2: "absent", e4: "excused" },
    ...overrides,
  } as unknown as Parameters<typeof saveAttendance>[2];
}

function readInput(
  sessionId: string,
  overrides: Record<string, unknown> = {},
): Parameters<typeof getSessionAttendance>[1] {
  return {
    uid: "sup1",
    congregationId: "c1",
    sessionId,
    ...overrides,
  } as unknown as Parameters<typeof getSessionAttendance>[1];
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

describe("saveAttendance", () => {
  it("freezes the eligible interval roster with historical names and writes a receipt", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    const input = saveInput(sessionId);

    const result = await saveAttendance(datastore, clock, input, defaultReader());
    expect(result).toEqual({ id: sessionId, revision: 2, status: "open" });

    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.rosterFrozen).toBe(true);
    expect(session?.rosterEnrollmentIds).toEqual(ELIGIBLE);
    expect(session?.revision).toBe(2);

    for (const [enrollmentId, name, status] of [
      ["e1", "Aluno Um", "present"],
      ["e2", "Aluno Dois", "absent"],
      ["e4", "Aluno Quatro", "excused"],
    ] as const) {
      const entry = await datastore.read(
        rosterEntryPath("c1", sessionId, enrollmentId),
      );
      expect(entry?.studentName).toBe(name);
      expect(entry?.enrollmentId).toBe(enrollmentId);
      const attendance = await datastore.read(
        attendanceEntryPath("c1", sessionId, enrollmentId),
      );
      expect(attendance?.status).toBe(status);
    }
    expect(
      await datastore.read(rosterEntryPath("c1", sessionId, "e3late")),
    ).toBeNull();

    const receipt = await datastore.read(paths.receipt("sup1", input.requestId));
    expect(receipt?.operation).toBe("saveAttendance");
  });

  it("keeps historical names after the student is renamed", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(datastore, clock, saveInput(sessionId), defaultReader());

    await datastore.write(
      paths.student("c1", "s1"),
      studentDoc("s1", "Aluno Um Renomeado"),
    );

    const view = await getSessionAttendance(datastore, readInput(sessionId));
    const entry = view.roster.find((row) => row.enrollmentId === "e1");
    expect(entry?.studentName).toBe("Aluno Um");
  });

  it("does not let a late enrollment silently alter the frozen roster", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(datastore, clock, saveInput(sessionId), defaultReader());

    // A new enrollment appears for the class after the roster froze. Even
    // though a fresh freeze would have included it, the frozen membership
    // wins and the submission is rejected.
    const lateReader = new InMemoryClassEnrollmentReader({
      enrollments: [
        enrollmentDoc("e1", "s1"),
        enrollmentDoc("e2", "s2"),
        enrollmentDoc("e4", "s4", {
          startDate: "2026-01-01",
          endDate: "2026-08-01",
          status: "withdrawn",
        }),
        enrollmentDoc("e6", "s1", { startDate: "2026-06-01" }),
      ],
    });

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          expectedRevision: 2,
          marks: { e1: "present", e2: "absent", e4: "excused", e6: "present" },
        }),
        lateReader,
      ),
    );
    expect(error.code).toBe("validation");

    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.rosterEnrollmentIds).toEqual(ELIGIBLE);
    expect(session?.revision).toBe(2);
    expect(
      await datastore.read(attendanceEntryPath("c1", sessionId, "e6")),
    ).toBeNull();
  });

  it("rejects incomplete, extra and invalid roster maps", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(datastore, clock, saveInput(sessionId), defaultReader());

    const incomplete = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, { expectedRevision: 2, marks: { e1: "present" } }),
        defaultReader(),
      ),
    );
    expect(incomplete.code).toBe("validation");

    const extra = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          expectedRevision: 2,
          marks: { e1: "present", e2: "absent", e4: "excused", e5: "present" },
        }),
        defaultReader(),
      ),
    );
    expect(extra.code).toBe("validation");

    const invalid = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          expectedRevision: 2,
          marks: { e1: "maybe", e2: "absent", e4: "excused" },
        }),
        defaultReader(),
      ),
    );
    expect(invalid.code).toBe("validation");

    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.revision).toBe(2);
  });

  it("rolls back every staged write when the session revision is stale", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(datastore, clock, saveInput(sessionId), defaultReader());

    const stale = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          expectedRevision: 1,
          finalize: true,
          marks: { e1: "absent", e2: "present", e4: "present" },
        }),
        defaultReader(),
      ),
    );
    expect(stale.code).toBe("conflict");

    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("open");
    expect(session?.revision).toBe(2);
    expect(session?.rosterEnrollmentIds).toEqual(ELIGIBLE);
    expect(
      (await datastore.read(attendanceEntryPath("c1", sessionId, "e1")))?.status,
    ).toBe("present");
  });

  it("replays an identical request idempotently without another revision", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    const input = saveInput(sessionId);

    const first = await saveAttendance(datastore, clock, input, defaultReader());
    const replay = await saveAttendance(datastore, clock, input, defaultReader());
    expect(replay).toEqual(first);
    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.revision).toBe(2);
  });

  it("rejects finalization of an empty roster", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    const emptyReader = new InMemoryClassEnrollmentReader();

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, { finalize: true, marks: {} }),
        emptyReader,
      ),
    );
    expect(error.code).toBe("conflict");

    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("open");
    expect(session?.rosterFrozen).toBe(false);
    expect(session?.revision).toBe(1);
  });

  it("rejects finalization while any member is unmarked", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          finalize: true,
          marks: { e1: "present", e2: "unmarked", e4: "present" },
        }),
        defaultReader(),
      ),
    );
    expect(error.code).toBe("validation");
    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("open");
    expect(session?.rosterFrozen).toBe(false);
  });

  it("rejects finalization of a future session", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(
      datastore,
      clock,
      sessionInput(sessionId, { date: "2026-09-19" }),
    );

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          finalize: true,
          marks: { e1: "present", e2: "absent", e4: "present" },
        }),
        defaultReader(),
      ),
    );
    expect(error.code).toBe("validation");
    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("open");
    expect(session?.revision).toBe(1);
  });

  it("saves and finalizes in one atomic command", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));

    const result = await saveAttendance(
      datastore,
      clock,
      saveInput(sessionId, {
        finalize: true,
        marks: { e1: "present", e2: "absent", e4: "present" },
      }),
      defaultReader(),
    );
    expect(result).toEqual({ id: sessionId, revision: 2, status: "finalized" });
    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("finalized");
    expect(session?.rosterFrozen).toBe(true);
    expect(session?.rosterEnrollmentIds).toEqual(ELIGIBLE);
  });

  it("corrects a finalized session while keeping status and frozen membership", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(
      datastore,
      clock,
      saveInput(sessionId, {
        finalize: true,
        marks: { e1: "present", e2: "absent", e4: "present" },
      }),
      defaultReader(),
    );

    const corrected = await saveAttendance(
      datastore,
      clock,
      saveInput(sessionId, {
        expectedRevision: 2,
        finalize: true,
        marks: { e1: "absent", e2: "present", e4: "present" },
      }),
      defaultReader(),
    );
    expect(corrected).toEqual({ id: sessionId, revision: 3, status: "finalized" });

    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("finalized");
    expect(session?.rosterFrozen).toBe(true);
    expect(session?.rosterEnrollmentIds).toEqual(ELIGIBLE);
    const entry = await datastore.read(rosterEntryPath("c1", sessionId, "e1"));
    expect(entry?.studentName).toBe("Aluno Um");
    expect(
      (await datastore.read(attendanceEntryPath("c1", sessionId, "e1")))?.status,
    ).toBe("absent");
  });

  it("refuses to reopen a finalized session without finalization", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(
      datastore,
      clock,
      saveInput(sessionId, {
        finalize: true,
        marks: { e1: "present", e2: "absent", e4: "present" },
      }),
      defaultReader(),
    );

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, {
          expectedRevision: 2,
          finalize: false,
          marks: { e1: "present", e2: "absent", e4: "present" },
        }),
        defaultReader(),
      ),
    );
    expect(error.code).toBe("conflict");
    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("finalized");
  });

  it("refuses attendance on a canceled session", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await datastore.write(sessionPath("c1", sessionId), {
      ...(await datastore.read(sessionPath("c1", sessionId))),
      status: "canceled",
      revision: 2,
    });

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, { expectedRevision: 2 }),
        defaultReader(),
      ),
    );
    expect(error.code).toBe("conflict");
  });

  it("rejects attendance mutations on a completed class", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await datastore.write(sessionPath("c1", sessionId), {
      id: sessionId,
      congregationId: "c1",
      classId: "clCompleted",
      date: "2026-06-10",
      topic: null,
      status: "open",
      rosterFrozen: false,
      rosterEnrollmentIds: [],
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    });

    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId),
        defaultReader(),
      ),
    );
    expect(error.code).toBe("conflict");
    const session = await datastore.read(sessionPath("c1", sessionId));
    expect(session?.status).toBe("open");
    expect(session?.revision).toBe(1);
  });

  it("bounds the atomic roster at the 100-member class capacity", async () => {
    const datastore = seedDatastore();
    const members = (count: number, classId: string) =>
      new InMemoryClassEnrollmentReader({
        enrollments: Array.from({ length: count }, (_, index) =>
          enrollmentDoc(`r${index.toString().padStart(3, "0")}`, "s1", {
            classId,
            startDate: "2026-03-01",
          }),
        ),
      });

    const full = randomUUID();
    await createSession(datastore, clock, sessionInput(full));
    const fullMarks = Object.fromEntries(
      Array.from({ length: 100 }, (_, index) => [
        `r${index.toString().padStart(3, "0")}`,
        "present",
      ]),
    );
    const result = await saveAttendance(
      datastore,
      clock,
      saveInput(full, { marks: fullMarks, expectedRevision: 1 }),
      members(100, "cl1"),
    );
    expect(result.revision).toBe(2);
    const fullSession = await datastore.read(sessionPath("c1", full));
    expect((fullSession?.rosterEnrollmentIds as string[]).length).toBe(100);

    const over = randomUUID();
    await createSession(
      datastore,
      clock,
      sessionInput(over, { date: "2026-06-11" }),
    );
    const overMarks = Object.fromEntries(
      Array.from({ length: 101 }, (_, index) => [
        `r${index.toString().padStart(3, "0")}`,
        "present",
      ]),
    );
    const error = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(over, { marks: overMarks, expectedRevision: 1 }),
        members(101, "cl1"),
      ),
    );
    expect(error.code).toBe("conflict");
    const overSession = await datastore.read(sessionPath("c1", over));
    expect(overSession?.rosterFrozen).toBe(false);
    expect(overSession?.revision).toBe(1);
  });

  it("denies anonymous and cross-congregation saves and reads", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));

    const anonymousWrite = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, { uid: "ghost" }),
        defaultReader(),
      ),
    );
    expect(anonymousWrite.code).toBe("forbidden");

    const crossScopeWrite = await expectAppError(() =>
      saveAttendance(
        datastore,
        clock,
        saveInput(sessionId, { uid: "staff2" }),
        defaultReader(),
      ),
    );
    expect(crossScopeWrite.code).toBe("forbidden");

    const anonymousRead = await expectAppError(() =>
      getSessionAttendance(datastore, readInput(sessionId, { uid: "ghost" })),
    );
    expect(anonymousRead.code).toBe("forbidden");

    const crossScopeRead = await expectAppError(() =>
      getSessionAttendance(datastore, readInput(sessionId, { uid: "staff2" })),
    );
    expect(crossScopeRead.code).toBe("forbidden");
  });
});

describe("getSessionAttendance", () => {
  it("returns the frozen roster with names and current marks, defaulting to unmarked", async () => {
    const datastore = seedDatastore();
    const sessionId = randomUUID();
    await createSession(datastore, clock, sessionInput(sessionId));
    await saveAttendance(
      datastore,
      clock,
      saveInput(sessionId, {
        marks: { e1: "present", e2: "unmarked", e4: "excused" },
      }),
      defaultReader(),
    );

    const view = await getSessionAttendance(datastore, readInput(sessionId));
    expect(view.session.id).toBe(sessionId);
    expect(view.session.status).toBe("open");
    expect(view.session.rosterFrozen).toBe(true);
    expect(view.roster.map((row) => row.enrollmentId).sort()).toEqual(ELIGIBLE);
    const byId = new Map(view.roster.map((row) => [row.enrollmentId, row]));
    expect(byId.get("e1")?.status).toBe("present");
    expect(byId.get("e2")?.status).toBe("unmarked");
    expect(byId.get("e4")?.status).toBe("excused");
  });
});
