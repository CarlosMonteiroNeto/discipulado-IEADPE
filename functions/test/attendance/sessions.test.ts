import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  sessionDateLockPath,
  sessionIndexPath,
  sessionPath,
} from "../../src/attendance/roster";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import { cancelSession, createSession } from "../../src/sessions/service";

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
  });
}

function createInput(
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
    topic: "Lição 1",
    ...overrides,
  } as unknown as Parameters<typeof createSession>[2];
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

describe("createSession", () => {
  it("creates an open, unfrozen session, indexes it and stores an idempotent receipt", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const input = createInput(id);

    const result = await createSession(datastore, clock, input);
    expect(result).toEqual({ id, revision: 1, status: "open" });

    const stored = await datastore.read(sessionPath("c1", id));
    expect(stored?.id).toBe(id);
    expect(stored?.congregationId).toBe("c1");
    expect(stored?.classId).toBe("cl1");
    expect(stored?.date).toBe("2026-06-10");
    expect(stored?.topic).toBe("Lição 1");
    expect(stored?.status).toBe("open");
    expect(stored?.rosterFrozen).toBe(false);
    expect(stored?.revision).toBe(1);
    expect(stored?.createdAt).toBe(TIMESTAMP);

    const lock = await datastore.read(sessionDateLockPath("c1", "cl1", "2026-06-10"));
    expect(lock?.sessionId).toBe(id);

    const index = await datastore.read(sessionIndexPath("c1", "cl1"));
    expect(index?.sessionIds).toEqual([id]);

    const receipt = await datastore.read(paths.receipt("sup1", input.requestId));
    expect(receipt?.operation).toBe("createSession");
  });

  it("rejects a duplicate noncanceled class/date pair and allows a replacement after cancellation", async () => {
    const datastore = seedDatastore();
    const first = randomUUID();
    await createSession(datastore, clock, createInput(first));

    const duplicate = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID())),
    );
    expect(duplicate.code).toBe("conflict");

    await cancelSession(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: first,
      congregationId: "c1",
      expectedRevision: 1,
    } as unknown as Parameters<typeof cancelSession>[2]);

    const replacement = randomUUID();
    const result = await createSession(datastore, clock, createInput(replacement));
    expect(result).toEqual({ id: replacement, revision: 1, status: "open" });
    const lock = await datastore.read(sessionDateLockPath("c1", "cl1", "2026-06-10"));
    expect(lock?.sessionId).toBe(replacement);
  });

  it("rejects a session outside the class period", async () => {
    const datastore = seedDatastore();

    const before = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID(), { date: "2026-02-28" })),
    );
    expect(before.code).toBe("validation");

    const after = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID(), { date: "2026-12-02" })),
    );
    expect(after.code).toBe("validation");
  });

  it("rejects a topic longer than 200 characters", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID(), { topic: "x".repeat(201) })),
    );
    expect(error.code).toBe("validation");
  });

  it("rejects a session on a completed class", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID(), { classId: "clCompleted" })),
    );
    expect(error.code).toBe("conflict");
    expect(await datastore.read(sessionIndexPath("c1", "clCompleted"))).toBeNull();
  });

  it("denies anonymous and cross-congregation creation", async () => {
    const datastore = seedDatastore();

    const anonymous = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID(), { uid: "ghost" })),
    );
    expect(anonymous.code).toBe("forbidden");

    const crossScope = await expectAppError(() =>
      createSession(datastore, clock, createInput(randomUUID(), { uid: "staff2" })),
    );
    expect(crossScope.code).toBe("forbidden");
  });
});

describe("cancelSession", () => {
  it("preserves the session data, releases the class/date lock and is idempotent", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await createSession(datastore, clock, createInput(id));

    const result = await cancelSession(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      expectedRevision: 1,
    } as unknown as Parameters<typeof cancelSession>[2]);
    expect(result).toEqual({ id, revision: 2, status: "canceled" });

    const stored = await datastore.read(sessionPath("c1", id));
    expect(stored?.status).toBe("canceled");
    expect(stored?.date).toBe("2026-06-10");
    expect(stored?.topic).toBe("Lição 1");
    expect(await datastore.read(sessionDateLockPath("c1", "cl1", "2026-06-10"))).toBeNull();

    const index = await datastore.read(sessionIndexPath("c1", "cl1"));
    expect(index?.sessionIds).toEqual([id]);

    const replay = await cancelSession(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      expectedRevision: 2,
    } as unknown as Parameters<typeof cancelSession>[2]);
    expect(replay).toEqual({ id, revision: 2, status: "canceled" });
  });
});
