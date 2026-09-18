import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  InMemoryOverviewReader,
  listPendingSessions,
} from "../../src/overview/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function session(
  id: string,
  congregationId: string,
  classId: string,
  date: string,
): JsonMap {
  return {
    id,
    congregationId,
    classId,
    date,
    topic: `Tema ${id}`,
    status: "open",
    rosterFrozen: false,
    revision: 1,
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
    [paths.classGroup("c1", "k1")]: {
      id: "k1",
      congregationId: "c1",
      name: "Turma Central",
      normalizedName: "turma central",
      status: "active",
      revision: 1,
    },
    [paths.classGroup("c2", "k4")]: {
      id: "k4",
      congregationId: "c2",
      name: "Turma Norte",
      normalizedName: "turma norte",
      status: "active",
      revision: 1,
    },
  });
}

function seedReader(): InMemoryOverviewReader {
  return new InMemoryOverviewReader({
    sessions: [
      session("x5", "c1", "k1", "2026-09-18"),
      session("x6", "c2", "k4", "2026-09-16"),
      session("x1", "c1", "k1", "2026-09-17"),
      session("x2", "c1", "k1", "2026-09-19"),
    ],
  });
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

describe("listPendingSessions", () => {
  it("pages all congregations ordered by date then ID and links each row to its class/session", async () => {
    const datastore = seedDatastore();
    const reader = seedReader();

    const first = await listPendingSessions(datastore, reader, clock, {
      uid: "sup1",
      congregationId: null,
      limit: 2,
    });

    expect(first.items.map((item) => item.id)).toEqual(["x6", "x1"]);
    expect(first.nextCursor).toEqual(expect.any(String));
    expect(first.items[0]).toEqual({
      id: "x6",
      classId: "k4",
      className: "Turma Norte",
      congregationId: "c2",
      date: "2026-09-16",
      topic: "Tema x6",
      status: "open",
    });
    expect(first.items[1]).toMatchObject({
      id: "x1",
      classId: "k1",
      className: "Turma Central",
      congregationId: "c1",
      date: "2026-09-17",
    });

    const second = await listPendingSessions(datastore, reader, clock, {
      uid: "sup1",
      congregationId: null,
      limit: 2,
      cursor: first.nextCursor,
    });

    expect(second.items.map((item) => item.id)).toEqual(["x5"]);
    expect(second.nextCursor).toBeNull();
  });

  it("excludes future sessions from the pending list", async () => {
    const result = await listPendingSessions(seedDatastore(), seedReader(), clock, {
      uid: "sup1",
      congregationId: null,
      limit: 10,
    });
    expect(result.items.map((item) => item.id)).not.toContain("x2");
  });

  it("rejects cursor reuse across scopes", async () => {
    const first = await listPendingSessions(seedDatastore(), seedReader(), clock, {
      uid: "sup1",
      congregationId: null,
      limit: 1,
    });
    const cursor = first.nextCursor as string;
    expect(cursor).toEqual(expect.any(String));

    const error = await expectAppError(() =>
      listPendingSessions(seedDatastore(), seedReader(), clock, {
        uid: "sup1",
        congregationId: "c1",
        limit: 1,
        cursor,
      }),
    );
    expect(error.code).toBe("conflict");
  });

  it("rejects a cursor minted before the Recife date rollover", async () => {
    const dayOne = fixedClock(new Date("2026-09-18T12:00:00.000Z"));
    const dayTwo = fixedClock(new Date("2026-09-19T12:00:00.000Z"));

    const first = await listPendingSessions(seedDatastore(), seedReader(), dayOne, {
      uid: "sup1",
      congregationId: null,
      limit: 1,
    });
    const cursor = first.nextCursor as string;
    expect(cursor).toEqual(expect.any(String));

    const error = await expectAppError(() =>
      listPendingSessions(seedDatastore(), seedReader(), dayTwo, {
        uid: "sup1",
        congregationId: null,
        limit: 1,
        cursor,
      }),
    );
    expect(error.code).toBe("conflict");
  });

  it("scopes a staff caller to its own congregation and denies a cross-scope request", async () => {
    const scoped = await listPendingSessions(seedDatastore(), seedReader(), clock, {
      uid: "staff1",
      congregationId: null,
      limit: 10,
    });
    expect(scoped.items.map((item) => item.id)).toEqual(["x1", "x5"]);
    expect(scoped.items.every((item) => item.congregationId === "c1")).toBe(true);

    const error = await expectAppError(() =>
      listPendingSessions(seedDatastore(), seedReader(), clock, {
        uid: "staff1",
        congregationId: "c2",
        limit: 10,
      }),
    );
    expect(error.code).toBe("forbidden");
  });

  it("rejects an out-of-range page size", async () => {
    const error = await expectAppError(() =>
      listPendingSessions(seedDatastore(), seedReader(), clock, {
        uid: "sup1",
        congregationId: null,
        limit: 101,
      }),
    );
    expect(error.code).toBe("validation");
  });
});
