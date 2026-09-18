import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  saveCongregation,
  setCongregationArchived,
} from "../../src/congregations/service";

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

describe("archived congregation rename", () => {
  it("refuses a rename, keeps the revision and leaves the name index unchanged", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveCongregation(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      name: "Central",
    });
    await setCongregationArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      archived: true,
      expectedRevision: 1,
    });

    const error = await expectAppError(() =>
      saveCongregation(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        expectedRevision: 2,
        name: "Central Renovada",
      }),
    );
    expect(error.code).toBe("conflict");

    const stored = await datastore.read(paths.congregation(id));
    expect(stored?.name).toBe("Central");
    expect(stored?.normalizedName).toBe("central");
    expect(stored?.active).toBe(false);
    expect(stored?.revision).toBe(2);

    // The old normalized name is still reserved (index untouched).
    const oldName = await expectAppError(() =>
      saveCongregation(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: randomUUID(),
        name: "Central",
      }),
    );
    expect(oldName.code).toBe("conflict");

    // The attempted new name was never indexed.
    const newName = await saveCongregation(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: randomUUID(),
      name: "Central Renovada",
    });
    expect(newName.revision).toBe(1);
  });
});
