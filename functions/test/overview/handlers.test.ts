import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import {
  Datastore,
  InMemoryDatastore,
  JsonMap,
  Transaction,
  paths,
} from "../../src/core/datastore";
import {
  getOverviewCallable,
  listPendingSessionsCallable,
} from "../../src/overview/handlers";
import {
  InMemoryOverviewReader,
  OpenSessionCountQuery,
  OverviewQueryReader,
  PendingSessionQuery,
  getOverview,
  listPendingSessions,
} from "../../src/overview/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

/**
 * Records every document path the service reads, so a test can prove which
 * authenticated profile was resolved against the datastore.
 */
class RecordingDatastore implements Datastore {
  readonly reads: string[] = [];

  constructor(private readonly inner: Datastore) {}

  read(path: string): Promise<JsonMap | null> {
    this.reads.push(path);
    return this.inner.read(path);
  }

  write(path: string, data: JsonMap): Promise<void> {
    return this.inner.write(path, data);
  }

  runTransaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T> {
    return this.inner.runTransaction(work);
  }
}

/** Records whether the read port was touched at all. */
class RecordingReader implements OverviewQueryReader {
  readonly calls: string[] = [];

  constructor(
    private readonly inner: OverviewQueryReader = new InMemoryOverviewReader(),
  ) {}

  countUnarchivedStudents(congregationId: string | null): Promise<number> {
    this.calls.push("students");
    return this.inner.countUnarchivedStudents(congregationId);
  }

  countActiveClasses(congregationId: string | null): Promise<number> {
    this.calls.push("classes");
    return this.inner.countActiveClasses(congregationId);
  }

  countOpenSessions(query: OpenSessionCountQuery): Promise<number> {
    this.calls.push("open");
    return this.inner.countOpenSessions(query);
  }

  listOpenSessions(query: PendingSessionQuery): Promise<JsonMap[]> {
    this.calls.push("pending");
    return this.inner.listOpenSessions(query);
  }
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
    // A payload-supplied UID must never resolve to this profile.
    [paths.user("attacker")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
  });
}

function deps() {
  return {
    datastore: new RecordingDatastore(seedDatastore()),
    clock,
    reader: new RecordingReader(),
  };
}

describe("overview callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof getOverviewCallable).toBe("function");
    expect(typeof listPendingSessionsCallable).toBe("function");
    expect(typeof getOverview).toBe("function");
    expect(typeof listPendingSessions).toBe("function");
    expect(getOverviewCallable).not.toBe(getOverview);
    expect(listPendingSessionsCallable).not.toBe(listPendingSessions);
  });

  it("builds a callable from injected infrastructure", () => {
    const dependencies = deps();
    expect(typeof getOverviewCallable(dependencies)).toBe("function");
    expect(typeof listPendingSessionsCallable(dependencies)).toBe("function");
  });

  it("rejects a request without request.auth.uid before any read", async () => {
    const dependencies = deps();
    const overview = getOverviewCallable(dependencies);
    const pending = listPendingSessionsCallable(dependencies);

    // `defineCallable` maps the AppError("unauthenticated") thrown by
    // `requireUid` to the transport HttpsError with code `unauthenticated`.
    await expect(
      overview.run({
        data: { congregationId: null },
        auth: undefined,
      } as never),
    ).rejects.toMatchObject({
      code: "unauthenticated",
      message: "Authentication is required.",
    });
    await expect(
      pending.run({
        data: { congregationId: null, limit: 10 },
        auth: undefined,
      } as never),
    ).rejects.toMatchObject({
      code: "unauthenticated",
      message: "Authentication is required.",
    });

    expect(dependencies.datastore.reads).toEqual([]);
    expect(dependencies.reader.calls).toEqual([]);
  });

  it("uses request.auth.uid and never the payload uid", async () => {
    const dependencies = deps();
    const overview = getOverviewCallable(dependencies);
    const pending = listPendingSessionsCallable(dependencies);

    await overview.run({
      data: { uid: "attacker", congregationId: null },
      auth: { uid: "sup1", token: {} },
    } as never);
    expect(dependencies.datastore.reads).toContain("users/sup1");
    expect(dependencies.datastore.reads).not.toContain("users/attacker");

    dependencies.datastore.reads.length = 0;
    await pending.run({
      data: { uid: "attacker", congregationId: null, limit: 10 },
      auth: { uid: "sup1", token: {} },
    } as never);
    expect(dependencies.datastore.reads).toContain("users/sup1");
    expect(dependencies.datastore.reads).not.toContain("users/attacker");
    expect(dependencies.reader.calls).toContain("pending");
  });
});
