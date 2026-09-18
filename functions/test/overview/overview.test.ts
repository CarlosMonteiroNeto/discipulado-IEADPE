import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  InMemoryOverviewReader,
  getOverview,
} from "../../src/overview/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function user(
  accessRole: string,
  congregationId: string | null,
  active = true,
): JsonMap {
  return { accessRole, congregationId, active, revision: 1, updatedAt: TIMESTAMP };
}

function student(id: string, congregationId: string, archived = false): JsonMap {
  return {
    id,
    name: `Aluno ${id}`,
    normalizedName: `aluno ${id}`,
    congregationId,
    archived,
    revision: 1,
  };
}

function classGroup(
  id: string,
  congregationId: string,
  status: string,
): JsonMap {
  return {
    id,
    congregationId,
    name: `Turma ${id}`,
    normalizedName: `turma ${id}`,
    teacherContactId: null,
    startDate: "2026-01-01",
    endDate: null,
    status,
    revision: 1,
  };
}

function session(
  id: string,
  congregationId: string,
  classId: string,
  date: string,
  status: string,
): JsonMap {
  return {
    id,
    congregationId,
    classId,
    date,
    topic: null,
    status,
    rosterFrozen: false,
    revision: 1,
  };
}

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("sup1")]: user("supervisor", null),
    [paths.user("staff1")]: user("congregationStaff", "c1"),
    [paths.user("inactive1")]: user("congregationStaff", "c1", false),
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
  });
}

/** Two congregations with archived students, nonactive classes and sessions
 * that must be excluded because they are canceled, finalized or in the future. */
function seedReader(): InMemoryOverviewReader {
  return new InMemoryOverviewReader({
    students: [
      student("s1", "c1"),
      student("s3", "c1"),
      student("s2", "c1", true),
      student("s4", "c2"),
    ],
    classes: [
      classGroup("k1", "c1", "active"),
      classGroup("k2", "c1", "completed"),
      classGroup("k3", "c1", "archived"),
      classGroup("k4", "c2", "active"),
    ],
    sessions: [
      session("x1", "c1", "k1", "2026-09-17", "open"),
      session("x2", "c1", "k1", "2026-09-19", "open"),
      session("x3", "c1", "k1", "2026-09-16", "canceled"),
      session("x4", "c1", "k1", "2026-09-15", "finalized"),
      session("x5", "c1", "k1", "2026-09-18", "open"),
      session("x6", "c2", "k4", "2026-09-16", "open"),
    ],
  });
}

function overviewInput(uid: string, congregationId?: string | null) {
  return { uid, congregationId: congregationId ?? null };
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

describe("getOverview", () => {
  it("aggregates two congregations and excludes archived students and nonactive classes", async () => {
    const result = await getOverview(
      seedDatastore(),
      seedReader(),
      clock,
      overviewInput("sup1", null),
    );

    expect(result).toEqual({
      students: 3,
      classes: 2,
      openSessions: 3,
      throughDate: "2026-09-18",
    });
  });

  it("counts open sessions through today and excludes canceled, finalized and future sessions", async () => {
    const result = await getOverview(
      seedDatastore(),
      seedReader(),
      clock,
      overviewInput("staff1"),
    );

    // x1 (09-17) and x5 (09-18) are open through today; x2 is future, x3 and
    // x4 are canceled/finalized.
    expect(result.openSessions).toBe(2);
    expect(result.students).toBe(2);
    expect(result.classes).toBe(1);
  });

  it("uses today's Recife calendar date, not the UTC date", async () => {
    const justAfterUtcMidnight = fixedClock(
      new Date("2026-09-18T01:00:00.000Z"),
    );
    const result = await getOverview(
      seedDatastore(),
      seedReader(),
      justAfterUtcMidnight,
      overviewInput("staff1"),
    );

    // Recife is still 2026-09-17, so the 09-18 session is not due yet.
    expect(result.throughDate).toBe("2026-09-17");
    expect(result.openSessions).toBe(1);
  });

  it("pins a staff caller without an explicit scope to the bound congregation", async () => {
    const result = await getOverview(
      seedDatastore(),
      seedReader(),
      clock,
      overviewInput("staff1"),
    );

    expect(result).toEqual({
      students: 2,
      classes: 1,
      openSessions: 2,
      throughDate: "2026-09-18",
    });
  });

  it("denies a staff caller that requests another congregation", async () => {
    const error = await expectAppError(() =>
      getOverview(seedDatastore(), seedReader(), clock, overviewInput("staff1", "c2")),
    );
    expect(error.code).toBe("forbidden");
  });

  it("lets a supervisor select exactly one congregation", async () => {
    const result = await getOverview(
      seedDatastore(),
      seedReader(),
      clock,
      overviewInput("sup1", "c2"),
    );

    expect(result.students).toBe(1);
    expect(result.classes).toBe(1);
    expect(result.openSessions).toBe(1);
  });

  it("rejects an inactive profile before any read", async () => {
    const error = await expectAppError(() =>
      getOverview(seedDatastore(), seedReader(), clock, overviewInput("inactive1")),
    );
    expect(error.code).toBe("forbidden");
  });

  it("rejects a missing profile", async () => {
    const error = await expectAppError(() =>
      getOverview(seedDatastore(), seedReader(), clock, overviewInput("ghost")),
    );
    expect(error.code).toBe("forbidden");
  });

});
