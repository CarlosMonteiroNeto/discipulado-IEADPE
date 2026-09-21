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

describe("firestore.rules internal-mode write matrix structure", () => {
  it("has no recursive wildcard under /congregations/{congregationId}", () => {
    expect(congregationBlock()).not.toContain("{document=**}");
    expect(rules).not.toContain("match /congregations/{congregationId}/{document=**}");
  });

  it("matches each client-writable subcollection explicitly, scoped by read and write predicates", () => {
    const block = congregationBlock();
    for (const collection of [
      "contacts",
      "students",
      "classes",
      "enrollments",
      "activeEnrollmentRefs",
    ]) {
      expect(block).toContain(`match /${collection}/{`);
    }
    expect(block).toContain("match /sessions/{sessionId}");
    expect(block).toContain("match /attendance/{attendanceId}");
    expect(block).toContain("match /roster/{rosterId}");
    expect(block).toContain("match /roleSlots/{slotId}");
    expect(block).toContain("mayReadCongregation(congregationId)");
    expect(block).toContain("mayWriteCongregation(congregationId)");
  });

  it("enumerates the congregation-subtree write matrix for the nine record groups", () => {
    const writeGrants = congregationBlock().match(
      /allow write: if mayWriteCongregation\(congregationId\);/g,
    );
    // The parent congregation document plus contacts, students, classes
    // (with its class-level roster), enrollments, activeEnrollmentRefs,
    // sessions (with session attendance and session roster) and roleSlots all
    // grant the same scoped write; nothing else in the subtree does.
    expect(writeGrants?.length).toBe(11);
  });

  it("lists roleSlots, roster and activeEnrollmentRefs grants explicitly while uniqueness stays unenumerated", () => {
    const block = congregationBlock();
    expect(block).toMatch(/match \/roleSlots\/\{slotId\}/);
    expect(block).toMatch(/match \/roster\/\{rosterId\}/);
    expect(block).toMatch(/match \/activeEnrollmentRefs\/\{refId\}/);
    expect(block).not.toMatch(/match \/uniqueness\//);
  });

  it("guards the parent congregation read by active or supervisor", () => {
    const block = congregationBlock();
    expect(block).toContain("resource.data.active == true");
    expect(block).toContain("isSupervisor()");
    expect(block).toContain("allow write: if mayWriteCongregation(congregationId);");
  });

  it("scopes the self-profile bootstrap write and the allowlisted supervisor claim", () => {
    const usersBlockStart = rules.indexOf("match /users/{userId}");
    const usersBlockEnd = rules.indexOf("match /congregations/{congregationId}");
    expect(usersBlockStart).toBeGreaterThanOrEqual(0);
    expect(usersBlockEnd).toBeGreaterThan(usersBlockStart);
    const usersBlock = rules.slice(usersBlockStart, usersBlockEnd);
    expect(usersBlock).toContain("userId == currentUid()");
    expect(usersBlock).toContain("in ['congregationStaff', 'supervisor']");
    expect(usersBlock).toContain("allowlistedOwner()");
  });

  it("keeps supervision records supervisor-only and gates the directory write by congregation", () => {
    expect(rules).toContain("match /supervisionContacts/{contactId}");
    expect(rules).toContain("match /supervisionRoleSlots/{slotId}");
    const supervisionStart = rules.indexOf("match /supervisionContacts/{contactId}");
    const groupStart = rules.indexOf("match /{path=**}/students/{studentId}");
    expect(supervisionStart).toBeGreaterThanOrEqual(0);
    expect(groupStart).toBeGreaterThan(supervisionStart);
    const supervisionGrant = rules
      .slice(supervisionStart, groupStart)
      .match(/allow (read|write): if isSupervisor\(\);/g);
    // supervisionContacts and supervisionRoleSlots: read + write each.
    expect(supervisionGrant?.length).toBe(4);
    expect(rules).toContain("match /directory/{contactId}");
    expect(rules).toContain("allow write: if mayWriteDirectory();");
  });

  it("stays deny-by-default for unspecified reads and writes", () => {
    expect(rules).toContain("match /{document=**}");
    expect(rules).toContain("allow read, write: if false");
  });
});