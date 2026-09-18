import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore } from "../../src/core/datastore";
import {
  replaceRoleHolderCallable,
  saveContactCallable,
  setContactArchivedCallable,
} from "../../src/contacts/handlers";
import {
  replaceRoleHolder,
  saveContact,
  setContactArchived,
} from "../../src/contacts/service";

const clock = fixedClock(new Date("2026-09-18T12:00:00.000Z"));

describe("contact callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof saveContactCallable).toBe("function");
    expect(typeof replaceRoleHolderCallable).toBe("function");
    expect(typeof setContactArchivedCallable).toBe("function");
    expect(typeof saveContact).toBe("function");
    expect(typeof replaceRoleHolder).toBe("function");
    expect(typeof setContactArchived).toBe("function");
    expect(saveContactCallable).not.toBe(saveContact);
    expect(replaceRoleHolderCallable).not.toBe(replaceRoleHolder);
    expect(setContactArchivedCallable).not.toBe(setContactArchived);
  });

  it("builds a callable from injected infrastructure", () => {
    const deps = { datastore: new InMemoryDatastore(), clock };
    expect(typeof saveContactCallable(deps)).toBe("function");
    expect(typeof replaceRoleHolderCallable(deps)).toBe("function");
    expect(typeof setContactArchivedCallable(deps)).toBe("function");
  });
});
