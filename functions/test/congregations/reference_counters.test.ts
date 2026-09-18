import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  saveContact,
  setContactArchived,
} from "../../src/contacts/service";
import { setCongregationArchived } from "../../src/congregations/service";
import { provisionAccess } from "../../tools/provision-access";

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

function archiveCongregation(
  datastore: InMemoryDatastore,
  id: string,
  expectedRevision: number,
): Promise<unknown> {
  return setCongregationArchived(datastore, clock, {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    archived: true,
    expectedRevision,
  });
}

describe("archive dependency counters driven by real operations", () => {
  it("tracks active user profiles created, deactivated and rebound", async () => {
    const datastore = seedDatastore();
    await provisionAccess(datastore, {
      uid: "staff-a",
      accessRole: "congregationStaff",
      active: true,
      congregationId: "c1",
    });
    const blocked = await expectAppError(() =>
      archiveCongregation(datastore, "c1", 1),
    );
    expect(blocked.code).toBe("conflict");

    await provisionAccess(datastore, {
      uid: "staff-a",
      accessRole: "congregationStaff",
      active: false,
      congregationId: "c1",
    });
    await archiveCongregation(datastore, "c1", 1);
    expect((await datastore.read(paths.congregation("c1")))?.active).toBe(false);
  });

  it("moves the active-user count when a profile is rebound", async () => {
    const datastore = seedDatastore();
    await provisionAccess(datastore, {
      uid: "staff-b",
      accessRole: "congregationStaff",
      active: true,
      congregationId: "c1",
    });
    await provisionAccess(datastore, {
      uid: "staff-b",
      accessRole: "congregationStaff",
      active: true,
      congregationId: "c2",
    });

    await archiveCongregation(datastore, "c1", 1);
    const blocked = await expectAppError(() =>
      archiveCongregation(datastore, "c2", 1),
    );
    expect(blocked.code).toBe("conflict");
  });

  it("tracks unarchived contacts created and archived", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Contato",
    });
    const blocked = await expectAppError(() =>
      archiveCongregation(datastore, "c1", 1),
    );
    expect(blocked.code).toBe("conflict");

    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });
    await archiveCongregation(datastore, "c1", 1);
    expect((await datastore.read(paths.congregation("c1")))?.active).toBe(false);
  });

  it("blocks archiving again when a contact is restored", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Contato",
    });
    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });
    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      archived: false,
      expectedRevision: 2,
    });

    const blocked = await expectAppError(() =>
      archiveCongregation(datastore, "c1", 1),
    );
    expect(blocked.code).toBe("conflict");
  });
});
