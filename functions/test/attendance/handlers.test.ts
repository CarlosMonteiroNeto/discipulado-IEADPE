import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { InMemoryClassEnrollmentReader } from "../../src/attendance/roster";
import {
  getEnrollmentProgressCallable,
  getSessionAttendanceCallable,
  saveAttendanceCallable,
} from "../../src/attendance/handlers";
import { getEnrollmentProgress } from "../../src/attendance/progress";
import {
  getSessionAttendance,
  saveAttendance,
} from "../../src/attendance/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import {
  cancelSessionCallable,
  createSessionCallable,
} from "../../src/sessions/handlers";
import { cancelSession, createSession } from "../../src/sessions/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
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
    [paths.classGroup("c1", "cl1")]: {
      id: "cl1",
      congregationId: "c1",
      name: "Turma cl1",
      normalizedName: "turma cl1",
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
    },
  });
}

function deps() {
  return {
    datastore: seedDatastore(),
    clock,
    enrollments: new InMemoryClassEnrollmentReader(),
  };
}

const AUTH = { uid: "sup1", token: {} };
const ANON = undefined;

function sessionData(overrides: Record<string, unknown> = {}): JsonMap {
  return {
    id: randomUUID(),
    requestId: randomUUID(),
    congregationId: "c1",
    classId: "cl1",
    date: "2026-06-10",
    topic: null,
    ...overrides,
  };
}

describe("attendance and session callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof createSessionCallable).toBe("function");
    expect(typeof cancelSessionCallable).toBe("function");
    expect(typeof saveAttendanceCallable).toBe("function");
    expect(typeof getSessionAttendanceCallable).toBe("function");
    expect(typeof getEnrollmentProgressCallable).toBe("function");
    expect(typeof createSession).toBe("function");
    expect(typeof cancelSession).toBe("function");
    expect(typeof saveAttendance).toBe("function");
    expect(typeof getSessionAttendance).toBe("function");
    expect(typeof getEnrollmentProgress).toBe("function");
    expect(createSessionCallable).not.toBe(createSession);
    expect(cancelSessionCallable).not.toBe(cancelSession);
    expect(saveAttendanceCallable).not.toBe(saveAttendance);
    expect(getSessionAttendanceCallable).not.toBe(getSessionAttendance);
    expect(getEnrollmentProgressCallable).not.toBe(getEnrollmentProgress);
  });

  it("denies anonymous callers through every handler", async () => {
    const dependencies = deps();
    const create = createSessionCallable(dependencies);
    const cancel = cancelSessionCallable(dependencies);
    const save = saveAttendanceCallable(dependencies);
    const readSession = getSessionAttendanceCallable(dependencies);
    const readProgress = getEnrollmentProgressCallable(dependencies);

    const calls = [
      create.run({ data: sessionData(), auth: ANON } as never),
      cancel.run({
        data: {
          id: randomUUID(),
          requestId: randomUUID(),
          congregationId: "c1",
          expectedRevision: 1,
        },
        auth: ANON,
      } as never),
      save.run({
        data: {
          requestId: randomUUID(),
          congregationId: "c1",
          sessionId: randomUUID(),
          expectedRevision: 1,
          finalize: false,
          marks: {},
        },
        auth: ANON,
      } as never),
      readSession.run({
        data: { congregationId: "c1", sessionId: randomUUID() },
        auth: ANON,
      } as never),
      readProgress.run({
        data: { congregationId: "c1", enrollmentId: "enr1" },
        auth: ANON,
      } as never),
    ];

    for (const call of calls) {
      await expect(call).rejects.toMatchObject({ code: "unauthenticated" });
    }
  });

  it("denies cross-congregation access through every handler", async () => {
    const dependencies = deps();
    const auth = { uid: "staff2", token: {} };
    const create = createSessionCallable(dependencies);
    const cancel = cancelSessionCallable(dependencies);
    const save = saveAttendanceCallable(dependencies);
    const readSession = getSessionAttendanceCallable(dependencies);
    const readProgress = getEnrollmentProgressCallable(dependencies);

    const calls = [
      create.run({ data: sessionData(), auth } as never),
      cancel.run({
        data: {
          id: randomUUID(),
          requestId: randomUUID(),
          congregationId: "c1",
          expectedRevision: 1,
        },
        auth,
      } as never),
      save.run({
        data: {
          requestId: randomUUID(),
          congregationId: "c1",
          sessionId: randomUUID(),
          expectedRevision: 1,
          finalize: false,
          marks: {},
        },
        auth,
      } as never),
      readSession.run({
        data: { congregationId: "c1", sessionId: randomUUID() },
        auth,
      } as never),
      readProgress.run({
        data: { congregationId: "c1", enrollmentId: "enr1" },
        auth,
      } as never),
    ];

    for (const call of calls) {
      await expect(call).rejects.toMatchObject({ code: "permission-denied" });
    }
  });

  it("executes an authorized session creation through the callable", async () => {
    const dependencies = deps();
    const callable = createSessionCallable(dependencies);
    const data = sessionData();

    const result = await callable.run({ data, auth: AUTH } as never);
    expect(result).toEqual({ id: data.id, revision: 1, status: "open" });
  });
});
