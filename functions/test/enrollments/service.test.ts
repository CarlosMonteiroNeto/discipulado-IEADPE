import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { InMemoryClassSessionReader } from "../../src/classes/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import { closeEnrollment, enrollStudent } from "../../src/enrollments/service";
import { activeEnrollmentReferencePath } from "../../src/students/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function studentDoc(id: string, overrides: Record<string, unknown> = {}): JsonMap {
  return {
    id,
    name: `Aluno ${id}`,
    normalizedName: `aluno ${id}`,
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

function classDoc(id: string, overrides: Record<string, unknown> = {}): JsonMap {
  return {
    id,
    congregationId: "c1",
    name: `Turma ${id}`,
    normalizedName: `turma ${id}`,
    teacherContactId: "t1",
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
    [paths.student("c1", "s1")]: studentDoc("s1"),
    [paths.student("c1", "s2")]: studentDoc("s2"),
    [paths.student("c1", "sArchived")]: studentDoc("sArchived", {
      archived: true,
    }),
    [paths.student("c2", "sOther")]: studentDoc("sOther", {
      congregationId: "c2",
    }),
    [paths.classGroup("c1", "cl1")]: classDoc("cl1"),
    [paths.classGroup("c1", "cl2")]: classDoc("cl2"),
    [paths.classGroup("c1", "clArchived")]: classDoc("clArchived", {
      status: "archived",
      revision: 2,
    }),
    [paths.classGroup("c1", "clCompleted")]: classDoc("clCompleted", {
      status: "completed",
      revision: 2,
    }),
    [paths.classGroup("c2", "clOther")]: classDoc("clOther", {
      congregationId: "c2",
    }),
  });
}

function emptyReader(): InMemoryClassSessionReader {
  return new InMemoryClassSessionReader();
}

function enrollInput(
  id: string,
  overrides: Record<string, unknown> = {},
): Parameters<typeof enrollStudent>[2] {
  return {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    congregationId: "c1",
    classId: "cl1",
    studentId: "s1",
    startDate: "2026-03-05",
    ...overrides,
  } as unknown as Parameters<typeof enrollStudent>[2];
}

async function enroll(
  datastore: InMemoryDatastore,
  input: Parameters<typeof enrollStudent>[2],
  reader: InMemoryClassSessionReader = emptyReader(),
): Promise<{ id: string; revision: number }> {
  return enrollStudent(datastore, clock, input, reader);
}

async function close(
  datastore: InMemoryDatastore,
  input: Parameters<typeof closeEnrollment>[2],
  reader: InMemoryClassSessionReader = emptyReader(),
): Promise<{ id: string; revision: number }> {
  return closeEnrollment(datastore, clock, input, reader);
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

describe("enrollStudent", () => {
  it("enrolls an unarchived same-congregation student and records capacity", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const input = enrollInput(id);

    const result = await enroll(datastore, input);
    expect(result).toEqual({ id, revision: 1 });

    const stored = await datastore.read(paths.enrollment("c1", id));
    expect(stored?.id).toBe(id);
    expect(stored?.congregationId).toBe("c1");
    expect(stored?.classId).toBe("cl1");
    expect(stored?.studentId).toBe("s1");
    expect(stored?.startDate).toBe("2026-03-05");
    expect(stored?.endDate).toBeNull();
    expect(stored?.status).toBe("active");
    expect(stored?.revision).toBe(1);
    expect(stored?.createdAt).toBe(TIMESTAMP);

    const reference = await datastore.read(
      activeEnrollmentReferencePath("c1", "s1"),
    );
    expect(reference?.enrollmentId).toBe(id);
    expect(reference?.classId).toBe("cl1");
    expect(reference?.congregationId).toBe("c1");

    const classDocument = await datastore.read(paths.classGroup("c1", "cl1"));
    expect(classDocument?.enrollmentCount).toBe(1);
    expect(classDocument?.activeEnrollmentCount).toBe(1);

    const receipt = await datastore.read(paths.receipt("sup1", input.requestId));
    expect(receipt?.operation).toBe("enrollStudent");
  });

  it("rejects archived, cross-congregation and unknown students", async () => {
    const datastore = seedDatastore();

    const archived = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { studentId: "sArchived" })),
    );
    expect(archived.code).toBe("conflict");

    const foreign = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { studentId: "sOther" })),
    );
    expect(foreign.code).toBe("notFound");

    const unknown = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { studentId: "ghost" })),
    );
    expect(unknown.code).toBe("notFound");
  });

  it("rejects inactive and foreign classes", async () => {
    const datastore = seedDatastore();

    const archivedClass = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { classId: "clArchived" })),
    );
    expect(archivedClass.code).toBe("conflict");

    const completedClass = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { classId: "clCompleted" })),
    );
    expect(completedClass.code).toBe("conflict");

    const foreignClass = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { classId: "clOther" })),
    );
    expect(foreignClass.code).toBe("notFound");
  });

  it("enforces the class date period", async () => {
    const datastore = seedDatastore();

    const before = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { startDate: "2026-02-28" })),
    );
    expect(before.code).toBe("validation");

    const after = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { startDate: "2026-12-02" })),
    );
    expect(after.code).toBe("validation");
  });

  it("allows only one active enrollment per student", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    await enroll(datastore, enrollInput(firstId));

    const duplicate = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID())),
    );
    expect(duplicate.code).toBe("conflict");

    const otherClass = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { classId: "cl2" })),
    );
    expect(otherClass.code).toBe("conflict");
    expect(
      (await datastore.read(activeEnrollmentReferencePath("c1", "s1")))
        ?.enrollmentId,
    ).toBe(firstId);

    await close(datastore, {
      uid: "sup1",
      requestId: randomUUID(),
      id: firstId,
      congregationId: "c1",
      status: "completed",
      endDate: "2026-06-01",
      expectedRevision: 1,
    });

    const secondId = randomUUID();
    await enroll(datastore, enrollInput(secondId, { classId: "cl2" }));
    expect(
      (await datastore.read(activeEnrollmentReferencePath("c1", "s1")))
        ?.enrollmentId,
    ).toBe(secondId);
  });

  it("commits exactly one active enrollment under concurrent attempts", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    const secondId = randomUUID();

    const results = await Promise.allSettled([
      enroll(datastore, enrollInput(firstId)),
      enroll(datastore, enrollInput(secondId)),
    ]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    const rejected = results.filter(
      (result): result is PromiseRejectedResult => result.status === "rejected",
    );
    expect(rejected).toHaveLength(1);
    const reason = rejected[0]?.reason as AppError;
    expect(reason).toBeInstanceOf(AppError);
    expect(reason.code).toBe("conflict");

    const first = await datastore.read(paths.enrollment("c1", firstId));
    const second = await datastore.read(paths.enrollment("c1", secondId));
    expect([first, second].filter((document) => document !== null)).toHaveLength(1);
    expect(
      await datastore.read(activeEnrollmentReferencePath("c1", "s1")),
    ).not.toBeNull();
  });

  it("updates the start date while no roster is frozen", async () => {    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));

    const result = await enroll(
      datastore,
      enrollInput(id, { startDate: "2026-03-10", expectedRevision: 1 }),
    );
    expect(result).toEqual({ id, revision: 2 });
    expect((await datastore.read(paths.enrollment("c1", id)))?.startDate).toBe(
      "2026-03-10",
    );
  });

  it("does not change the start date once the enrollment is in a frozen roster", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));
    const reader = new InMemoryClassSessionReader({
      sessions: [
        {
          id: "sess1",
          congregationId: "c1",
          classId: "cl1",
          date: "2026-04-01",
          status: "finalized",
          rosterFrozen: true,
        },
      ],
      rosterEntries: [
        {
          sessionId: "sess1",
          classId: "cl1",
          enrollmentId: id,
          studentId: "s1",
        },
      ],
    });

    const error = await expectAppError(() =>
      enroll(
        datastore,
        enrollInput(id, { startDate: "2026-03-10", expectedRevision: 1 }),
        reader,
      ),
    );
    expect(error.code).toBe("conflict");
    expect((await datastore.read(paths.enrollment("c1", id)))?.startDate).toBe(
      "2026-03-05",
    );
  });

  it("enforces the 100 total enrollment records including closed", async () => {
    const datastore = seedDatastore();
    await datastore.write(
      paths.classGroup("c1", "cl1"),
      classDoc("cl1", { enrollmentCount: 99, activeEnrollmentCount: 0 }),
    );

    const firstId = randomUUID();
    await enroll(datastore, enrollInput(firstId));
    expect(
      (await datastore.read(paths.classGroup("c1", "cl1")))?.enrollmentCount,
    ).toBe(100);

    const overCap = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { studentId: "s2" })),
    );
    expect(overCap.code).toBe("conflict");

    await close(datastore, {
      uid: "sup1",
      requestId: randomUUID(),
      id: firstId,
      congregationId: "c1",
      status: "completed",
      endDate: "2026-06-01",
      expectedRevision: 1,
    });
    const classDocument = await datastore.read(paths.classGroup("c1", "cl1"));
    expect(classDocument?.enrollmentCount).toBe(100);
    expect(classDocument?.activeEnrollmentCount).toBe(0);

    const stillFull = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { studentId: "s2" })),
    );
    expect(stillFull.code).toBe("conflict");
  });

  it("replays an identical enrollment request idempotently", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const input = enrollInput(id);

    const first = await enroll(datastore, input);
    const replay = await enroll(datastore, input);
    expect(replay).toEqual(first);
    expect(await datastore.read(paths.enrollment("c1", id))).not.toBeNull();
    expect(
      (await datastore.read(paths.classGroup("c1", "cl1")))?.enrollmentCount,
    ).toBe(1);
  });

  it("rejects a stale enrollment revision", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));

    const error = await expectAppError(() =>
      enroll(
        datastore,
        enrollInput(id, { startDate: "2026-03-10", expectedRevision: 5 }),
      ),
    );
    expect(error.code).toBe("conflict");
    expect((await datastore.read(paths.enrollment("c1", id)))?.startDate).toBe(
      "2026-03-05",
    );
  });

  it("denies anonymous and cross-scope enrollment", async () => {
    const datastore = seedDatastore();

    const anonymous = await expectAppError(() =>
      enroll(datastore, enrollInput(randomUUID(), { uid: "ghost" })),
    );
    expect(anonymous.code).toBe("forbidden");

    const crossScope = await expectAppError(() =>
      enroll(
        datastore,
        enrollInput(randomUUID(), {
          uid: "staff1",
          congregationId: "c2",
          classId: "clOther",
        }),
      ),
    );
    expect(crossScope.code).toBe("forbidden");
  });
});

describe("closeEnrollment", () => {
  it("closes as completed or withdrawn with an explicit end date and keeps history", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));

    const closed = await close(datastore, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      status: "completed",
      endDate: "2026-06-30",
      expectedRevision: 1,
    });
    expect(closed).toEqual({ id, revision: 2 });

    const stored = await datastore.read(paths.enrollment("c1", id));
    expect(stored?.status).toBe("completed");
    expect(stored?.endDate).toBe("2026-06-30");
    expect(stored?.startDate).toBe("2026-03-05");
    expect(
      await datastore.read(activeEnrollmentReferencePath("c1", "s1")),
    ).toBeNull();
    const classDocument = await datastore.read(paths.classGroup("c1", "cl1"));
    expect(classDocument?.enrollmentCount).toBe(1);
    expect(classDocument?.activeEnrollmentCount).toBe(0);

    const immutable = await expectAppError(() =>
      close(datastore, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "withdrawn",
        endDate: "2026-07-01",
        expectedRevision: 2,
      }),
    );
    expect(immutable.code).toBe("conflict");
    expect((await datastore.read(paths.enrollment("c1", id)))?.status).toBe(
      "completed",
    );

    const secondId = randomUUID();
    await enroll(datastore, enrollInput(secondId, { studentId: "s2" }));
    await close(datastore, {
      uid: "sup1",
      requestId: randomUUID(),
      id: secondId,
      congregationId: "c1",
      status: "withdrawn",
      endDate: "2026-05-20",
      expectedRevision: 1,
    });
    expect((await datastore.read(paths.enrollment("c1", secondId)))?.status).toBe(
      "withdrawn",
    );
  });

  it("rejects a closing status other than completed or withdrawn", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));

    const error = await expectAppError(() =>
      close(datastore, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "active",
        endDate: "2026-06-30",
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("validation");
    expect((await datastore.read(paths.enrollment("c1", id)))?.status).toBe(
      "active",
    );
  });

  it("rejects an end date before the start date or after the class period", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));

    const before = await expectAppError(() =>
      close(datastore, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "completed",
        endDate: "2026-03-04",
        expectedRevision: 1,
      }),
    );
    expect(before.code).toBe("validation");

    const after = await expectAppError(() =>
      close(datastore, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "completed",
        endDate: "2026-12-02",
        expectedRevision: 1,
      }),
    );
    expect(after.code).toBe("validation");
  });

  it("enforces the frozen roster floor and ignores canceled sessions", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));
    const reader = new InMemoryClassSessionReader({
      sessions: [
        {
          id: "sess1",
          congregationId: "c1",
          classId: "cl1",
          date: "2026-06-10",
          status: "finalized",
          rosterFrozen: true,
        },
        {
          id: "sess2",
          congregationId: "c1",
          classId: "cl1",
          date: "2026-08-15",
          status: "canceled",
          rosterFrozen: true,
        },
      ],
      rosterEntries: [
        { sessionId: "sess1", classId: "cl1", enrollmentId: id, studentId: "s1" },
        { sessionId: "sess2", classId: "cl1", enrollmentId: id, studentId: "s1" },
      ],
    });

    const tooEarly = await expectAppError(() =>
      close(
        datastore,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id,
          congregationId: "c1",
          status: "completed",
          endDate: "2026-06-09",
          expectedRevision: 1,
        },
        reader,
      ),
    );
    expect(tooEarly.code).toBe("conflict");

    const allowed = await close(
      datastore,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "completed",
        endDate: "2026-06-10",
        expectedRevision: 1,
      },
      reader,
    );
    expect(allowed).toEqual({ id, revision: 2 });
  });

  it("rejects a stale revision and denies cross-scope closing", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await enroll(datastore, enrollInput(id));

    const crossScope = await expectAppError(() =>
      close(datastore, {
        uid: "staff2",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "completed",
        endDate: "2026-06-30",
        expectedRevision: 1,
      }),
    );
    expect(crossScope.code).toBe("forbidden");

    const stale = await expectAppError(() =>
      close(datastore, {
        uid: "staff1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        status: "completed",
        endDate: "2026-06-30",
        expectedRevision: 5,
      }),
    );
    expect(stale.code).toBe("conflict");
    expect((await datastore.read(paths.enrollment("c1", id)))?.status).toBe(
      "active",
    );
  });
});
