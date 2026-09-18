import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../src/core/clock";
import { payloadDigest, runCommand } from "../src/core/commands";
import { InMemoryDatastore, paths } from "../src/core/datastore";
import { AppError } from "../src/core/errors";

const now = new Date("2026-09-18T12:00:00.000Z");
const clock = fixedClock(now);

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: "2026-09-18T12:00:00.000Z",
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

describe("runCommand payload digest scope binding", () => {
  it("binds the digest to operation, payload and requestedCongregationId", () => {
    const payload = { name: "Ana" };
    const c1 = payloadDigest("saveStudent", payload, "c1");
    const c2 = payloadDigest("saveStudent", payload, "c2");
    expect(c1).not.toBe(c2);
    expect(c1).toBe(payloadDigest("saveStudent", { name: "Ana" }, "c1"));
    expect(c1).not.toBe(payloadDigest("saveContact", payload, "c1"));
  });

  it("does not serve the prior-scope result when the requested scope differs", async () => {
    const datastore = seedDatastore();
    const requestId = randomUUID();
    let runs = 0;
    const execute = async () => {
      runs += 1;
      return { id: "id-1", revision: 1 };
    };

    const first = await runCommand(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId,
        operation: "saveStudent",
        payload: { name: "Ana" },
        requestedCongregationId: "c1",
      },
      execute,
    );
    expect(first).toEqual({ id: "id-1", revision: 1 });

    const error = await expectAppError(() =>
      runCommand(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId,
          operation: "saveStudent",
          payload: { name: "Ana" },
          requestedCongregationId: "c2",
        },
        execute,
      ),
    );
    expect(error.code).toBe("conflict");
    expect(runs).toBe(1);
  });

  it("records the altered-payload replay as a documented `conflict` (not `validation`)", async () => {
    // S11 wording says an altered-payload replay "fails validation"; this
    // foundation deliberately maps it to the transport `aborted` (conflict)
    // code. This assertion keeps the deviation recorded and intentional.
    const datastore = seedDatastore();
    const requestId = randomUUID();
    await runCommand(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId,
        operation: "saveStudent",
        payload: { name: "Ana" },
        requestedCongregationId: "c1",
      },
      async () => ({ id: "id-1", revision: 1 }),
    );
    const error = await expectAppError(() =>
      runCommand(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId,
          operation: "saveStudent",
          payload: { name: "Bia" },
          requestedCongregationId: "c1",
        },
        async () => ({ id: "id-2", revision: 1 }),
      ),
    );
    expect(error.code).toBe("conflict");
  });
});
