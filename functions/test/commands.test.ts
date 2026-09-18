import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { payloadDigest, runCommand } from "../src/core/commands";
import { fixedClock } from "../src/core/clock";
import { InMemoryDatastore, paths } from "../src/core/datastore";
import { AppError } from "../src/core/errors";

const timestamp = "2026-09-18T12:00:00.000Z";
const now = new Date("2026-09-18T12:00:00.000Z");
const clock = fixedClock(now);

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("staff1")]: {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: true,
      revision: 1,
      updatedAt: timestamp,
    },
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: timestamp,
    },
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
      active: true,
      revision: 1,
    },
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

describe("payload digests", () => {
  it("is stable regardless of object key order", () => {
    expect(payloadDigest("saveContact", { a: 1, b: { d: 2, c: 3 } })).toBe(
      payloadDigest("saveContact", { b: { c: 3, d: 2 }, a: 1 }),
    );
    expect(payloadDigest("saveContact", { a: 1 })).not.toBe(
      payloadDigest("saveStudent", { a: 1 }),
    );
  });
});

describe("runCommand", () => {
  it("executes once and returns the cached result for an identical replay", async () => {
    const datastore = seedDatastore();
    let runs = 0;
    const requestId = randomUUID();
    const input = {
      uid: "staff1",
      requestId,
      operation: "saveContact",
      payload: { name: "Ana" },
      requestedCongregationId: "c1",
    };
    const execute = async () => {
      runs += 1;
      return { id: "id-1", revision: 1 };
    };

    const first = await runCommand(datastore, clock, input, execute);
    const replay = await runCommand(datastore, clock, input, execute);

    expect(first).toEqual({ id: "id-1", revision: 1 });
    expect(replay).toEqual(first);
    expect(runs).toBe(1);
  });

  it("rejects reusing the requestId with another payload without executing", async () => {
    const datastore = seedDatastore();
    let runs = 0;
    const requestId = randomUUID();
    const execute = async () => {
      runs += 1;
      return { id: "id-1", revision: 1 };
    };

    await runCommand(
      datastore,
      clock,
      { uid: "staff1", requestId, operation: "saveContact", payload: { name: "Ana" } },
      execute,
    );
    const error = await expectAppError(() =>
      runCommand(
        datastore,
        clock,
        { uid: "staff1", requestId, operation: "saveContact", payload: { name: "Bia" } },
        execute,
      ),
    );
    expect(error.code).toBe("conflict");
    expect(runs).toBe(1);
  });

  it("validates the requestId format", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      runCommand(
        datastore,
        clock,
        { uid: "staff1", requestId: "not-a-uuid", operation: "saveContact", payload: {} },
        async () => ({}),
      ),
    );
    expect(error.code).toBe("validation");
  });

  it("stores seven-day receipts with the original result", async () => {
    const datastore = seedDatastore();
    const requestId = randomUUID();
    await runCommand(
      datastore,
      clock,
      { uid: "staff1", requestId, operation: "saveContact", payload: { name: "Ana" } },
      async () => ({ id: "id-1", revision: 1 }),
    );
    const receipt = await datastore.read(paths.receipt("staff1", requestId));
    expect(receipt).not.toBeNull();
    expect(receipt?.result).toEqual({ id: "id-1", revision: 1 });
    expect(
      Number(receipt?.expiresAt) - Number(receipt?.createdAt),
    ).toBe(7 * 24 * 60 * 60 * 1000);
  });

  it("authorizes even when returning an existing receipt", async () => {
    const datastore = seedDatastore();
    let runs = 0;
    const requestId = randomUUID();
    const input = {
      uid: "staff1",
      requestId,
      operation: "saveContact",
      payload: { name: "Ana" },
      requestedCongregationId: "c1",
    };
    const execute = async () => {
      runs += 1;
      return { id: "id-1", revision: 1 };
    };
    await runCommand(datastore, clock, input, execute);

    await datastore.write(paths.user("staff1"), {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: false,
      revision: 2,
      updatedAt: timestamp,
    });
    const error = await expectAppError(() =>
      runCommand(datastore, clock, input, execute),
    );
    expect(error.code).toBe("forbidden");
    expect(runs).toBe(1);
  });
});

describe("transactional record guards", () => {
  it("rejects an existing unrelated record for a stable-ID create", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      datastore.runTransaction(async (tx) => {
        await tx.createStable(paths.congregation("c1"), { id: "other" });
      }),
    );
    expect(error.code).toBe("conflict");
  });

  it("fails a stale revision without writing", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      datastore.runTransaction(async (tx) =>
        tx.updateWithRevision(paths.congregation("c1"), 99, (current) => ({
          ...current,
          name: "Changed",
        })),
      ),
    );
    expect(error.code).toBe("conflict");
    const record = await datastore.read(paths.congregation("c1"));
    expect(record?.name).toBe("Central");
    expect(record?.revision).toBe(1);
  });

  it("rolls back every write when the command throws", async () => {
    const datastore = seedDatastore();
    await expect(
      datastore.runTransaction(async (tx) => {
        await tx.write(paths.congregation("new"), { id: "new" });
        throw new Error("boom");
      }),
    ).rejects.toThrow("boom");
    expect(await datastore.read(paths.congregation("new"))).toBeNull();
  });
});
