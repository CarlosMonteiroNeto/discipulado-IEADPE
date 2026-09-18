import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const rules = readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8");

function congregationBlock(): string {
  const start = rules.indexOf("match /congregations/{congregationId}");
  const end = rules.indexOf("match /directory/{contactId}");
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);
  return rules.slice(start, end);
}

describe("firestore.rules congregational scoping structure", () => {
  it("has no recursive wildcard under /congregations/{congregationId}", () => {
    expect(congregationBlock()).not.toContain("{document=**}");
    expect(rules).not.toContain("match /congregations/{congregationId}/{document=**}");
  });

  it("matches each client-readable subcollection explicitly, gated by the read predicate", () => {
    const block = congregationBlock();
    for (const collection of ["contacts", "students", "classes", "enrollments"]) {
      expect(block).toContain(`match /${collection}/`);
    }
    expect(block).toContain("match /sessions/{sessionId}");
    expect(block).toContain("mayReadCongregation(congregationId)");
    expect(block).toContain("allow write: if false");
  });

  it("keeps internal role-slot, roster and uniqueness records unenumerated", () => {
    const block = congregationBlock();
    expect(block).not.toMatch(/match \/roleSlots\//);
    expect(block).not.toMatch(/match \/roster\//);
    expect(block).not.toMatch(/match \/uniqueness\//);
  });

  it("guards the parent congregation read by active or supervisor", () => {
    const block = congregationBlock();
    expect(block).toContain("resource.data.active == true");
    expect(block).toContain("isSupervisor()");
  });

  it("stays deny-by-default for unspecified reads and every write", () => {
    expect(rules).toContain("match /{document=**}");
    expect(rules).toContain("allow read, write: if false");
  });
});
