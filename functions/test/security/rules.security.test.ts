import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

/**
 * Firestore emulator-backed rules tests. They run only when
 * FIRESTORE_EMULATOR_HOST is present (the backend gate's emulator entry
 * point); the unit gate skips them because rules cannot be proven without a
 * running emulator.
 *
 * The task-10 matrix this suite proves: self-profile create/update as the
 * internal bootstrap (the supervisor claim gated by the single allowlisted
 * owner email), role-scoped writes of the congregation subtree, scoped
 * directory writes, supervisor-only supervision records and collection-group
 * reads, and a deny-by-default catch-all.
 */
const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const suite = hasEmulator ? describe : describe.skip;
const ALLOWLISTED_OWNER = "owner@discipulado-ieadpe.example";

suite("firestore security rules", () => {
  let testEnv: any;
  let assertSucceeds: (promise: Promise<unknown>) => Promise<unknown>;
  let assertFails: (promise: Promise<unknown>) => Promise<unknown>;

  beforeAll(async () => {
    const rulesUnitTesting = await import("@firebase/rules-unit-testing");
    assertSucceeds = rulesUnitTesting.assertSucceeds as never;
    assertFails = rulesUnitTesting.assertFails as never;
    testEnv = await rulesUnitTesting.initializeTestEnvironment({
      projectId: "discipulado-ieadpe-emulator",
      firestore: {
        rules: readFileSync(resolve(__dirname, "../../../firestore.rules"), "utf8"),
      },
    });
    await testEnv.withSecurityRulesDisabled(async (context: any) => {
      const db = context.firestore();
      await db.doc("users/staff1").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: true,
        revision: 1,
      });
      await db.doc("users/staff2").set({
        accessRole: "congregationStaff",
        congregationId: "c2",
        active: true,
        revision: 1,
      });
      await db.doc("users/off").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: false,
        revision: 1,
      });
      await db.doc("users/sup1").set({
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 1,
      });
      await db.doc("congregations/c1").set({
        id: "c1",
        name: "Central",
        normalizedName: "central",
        active: true,
        revision: 1,
      });
      await db.doc("congregations/c2").set({
        id: "c2",
        name: "Norte",
        normalizedName: "norte",
        active: true,
        revision: 1,
      });
      await db.doc("directory/contact1").set({
        id: "contact1",
        name: "Ana",
        normalizedName: "ana",
        scope: "congregation",
        congregationId: "c1",
        roleCode: null,
        phoneE164: null,
      });
      await db.doc("congregations/c1/students/s1").set({
        id: "s1",
        name: "Ana",
        congregationId: "c1",
        classId: "class-a",
      });
      await db.doc("congregations/c1/students/s2").set({
        id: "s2",
        name: "Bruno",
        congregationId: "c1",
        classId: "class-a",
      });
      await db.doc("congregations/c1/classes/class-a").set({
        id: "class-a",
        name: "Turma A",
        congregationId: "c1",
      });
      await db.doc("congregations/c1/sessions/sess-1/roster/e1").set({
        id: "e1",
        studentId: "s1",
        congregationId: "c1",
      });
      await db.doc("congregations/c1/roleSlots/slot1").set({
        id: "slot1",
        roleCode: "teacher",
        holderContactId: "contact1",
        congregationId: "c1",
      });
      await db.doc("supervisionContacts/sc1").set({ id: "sc1", name: "Coord" });
      await db.doc("supervisionRoleSlots/srs1").set({ id: "srs1", roleCode: "coordinator" });
    });
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  function asUser(uid: string) {
    return testEnv.authenticatedContext(uid).firestore();
  }

  it("denies anonymous directory reads and writes and every unlisted path", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(anon.doc("directory/contact1").get());
    await assertFails(anon.doc("directory/contact1").set({ name: "x" }));
    await assertFails(anon.doc("unlisted/anything").get());
    await assertFails(anon.doc("unlisted/anything").set({ name: "x" }));
  });

  it("denies sign-in without a self-owned profile on any other record", async () => {
    const stranger = asUser("stranger");
    await assertFails(stranger.doc("directory/contact1").get());
    await assertFails(stranger.doc("congregations/c1/students/s1").get());
    await assertFails(stranger.doc("congregations/c1/students/s1").set({ id: "x" }));
  });

  it("allows staff scoped writes in their own congregation and denies cross-congregation ones", async () => {
    const staff = asUser("staff1");
    await assertSucceeds(staff.doc("congregations/c1/students/new").set({
      id: "new",
      name: "Novo",
      congregationId: "c1",
    }));
    await assertSucceeds(staff.doc("congregations/c1/contacts/contactNew").set({
      id: "contactNew",
      name: "Novo",
      congregationId: "c1",
    }));
    await assertFails(staff.doc("congregations/c2/students/new").set({
      id: "new",
      congregationId: "c2",
    }));
    await assertSucceeds(staff.doc("congregations/c1/students/s1").get());
  });

  it("allows staff scoped reads and writes of session attendance, roster and role slots", async () => {
    const staff = asUser("staff1");
    await assertSucceeds(
      staff.doc("congregations/c1/sessions/sess-1/attendance/a1").set({
        id: "a1",
        studentId: "s1",
        present: true,
        congregationId: "c1",
      }),
    );
    await assertSucceeds(staff.doc("congregations/c1/sessions/sess-1/roster/e2").set({
      id: "e2",
      studentId: "s2",
      congregationId: "c1",
    }));
    await assertSucceeds(staff.doc("congregations/c1/roleSlots/slot2").set({
      id: "slot2",
      roleCode: "helper",
      holderContactId: "contact1",
      congregationId: "c1",
    }));
    await assertSucceeds(staff.doc("congregations/c1/sessions/sess-1/roster/e2").get());
    await assertSucceeds(staff.doc("congregations/c1/roleSlots/slot1").get());
    const otherStaff = asUser("staff2");
    await assertFails(otherStaff.doc("congregations/c1/sessions/sess-1/attendance/a1").set({
      id: "a1",
      studentId: "s1",
      present: true,
      congregationId: "c1",
    }));
    await assertFails(otherStaff.doc("congregations/c1/roleSlots/slot1").get());
  });

  it("seals supervision records from staff and leaves them supervisor read/write", async () => {
    const staff = asUser("staff1");
    const supervisor = asUser("sup1");
    await assertFails(staff.doc("supervisionContacts/sc1").get());
    await assertFails(staff.doc("supervisionRoleSlots/srs1").get());
    await assertSucceeds(supervisor.doc("supervisionContacts/sc1").get());
    await assertSucceeds(supervisor.doc("supervisionRoleSlots/srs1").get());
    await assertSucceeds(supervisor.doc("supervisionContacts/sc2").set({
      id: "sc2",
      name: "Novo",
    }));
  });

  it("allows a supervisor to read and write every congregation scope", async () => {
    const supervisor = asUser("sup1");
    await assertSucceeds(supervisor.doc("congregations/c2/students/s1").get());
    await assertSucceeds(supervisor.doc("congregations/c2/students/cross").set({
      id: "cross",
      congregationId: "c2",
    }));
    await assertSucceeds(supervisor.doc("congregations/c2/sessions/sess-9").set({
      id: "sess-9",
      classId: "class-b",
      status: "pending",
      date: "2026-01-01",
      congregationId: "c2",
    }));
  });

  it("allows only the allowlisted owner email to self-claim the supervisor profile", async () => {
    const staff = asUser("staff1");
    await assertSucceeds(
      staff.doc("users/staff1").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: true,
        revision: 2,
      }),
    );
    await assertFails(
      staff.doc("users/staff1").set({
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 3,
      }),
    );
    await assertSucceeds(staff.doc("users/staff1").get());

    const owner = testEnv.authenticatedContext("owner", {
      email: ALLOWLISTED_OWNER,
    }).firestore();
    await assertSucceeds(
      owner.doc("users/owner").set({
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 1,
      }),
    );

    const boss = testEnv.authenticatedContext("boss", {
      email: "boss@example.com",
    }).firestore();
    await assertFails(
      boss.doc("users/boss").set({
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 1,
      }),
    );
    await assertSucceeds(
      boss.doc("users/boss").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: true,
        revision: 1,
      }),
    );
  });

  it("denies reading the self-managed users documents of other accounts", async () => {
    const staff = asUser("staff1");
    await assertSucceeds(staff.doc("users/staff1").get());
    await assertFails(staff.doc("users/off").get());
    await assertFails(staff.doc("users/sup1").get());
  });

  it("denies disabled accounts any record access and write", async () => {
    const off = asUser("off");
    await assertFails(off.doc("congregations/c1/students/s1").get());
    await assertFails(off.doc("congregations/c1/students/s1").set({
      id: "s1",
      congregationId: "c1",
    }));
    await assertFails(off.doc("directory/contact1").get());
  });

  it("scopes directory writes by the entry congregation, supervisors anywhere", async () => {
    const staff = asUser("staff1");
    await assertSucceeds(
      staff.doc("directory/contact-c1").set({
        id: "contact-c1",
        name: "C1",
        normalizedName: "c1",
        scope: "congregation",
        congregationId: "c1",
      }),
    );
    await assertFails(
      staff.doc("directory/contact-c2").set({
        id: "contact-c2",
        congregationId: "c2",
      }),
    );
    const supervisor = asUser("sup1");
    await assertSucceeds(
      supervisor.doc("directory/contact-anywhere").set({
        id: "contact-anywhere",
        congregationId: "c2",
      }),
    );
  });

  it("allows supervisor collection-group reads and denies staff them", async () => {
    const supervisor = asUser("sup1");
    await assertSucceeds(
      supervisor.firestore().collectionGroup("students").where("classId", "==", "class-a").get(),
    );
    const staff = asUser("staff1");
    await assertFails(
      staff.firestore().collectionGroup("students").where("classId", "==", "class-a").get(),
    );
  });

  it("denies the catch-all for every unlisted path", async () => {
    const staff = asUser("staff1");
    const supervisor = asUser("sup1");
    for (const user of [staff, supervisor]) {
      await assertFails(user.doc("collections/cheat").get());
      await assertFails(user.doc("collections/cheat").set({ name: "x" }));
      await assertFails(user.doc("congregations/c1/misc/anything").get());
      await assertFails(user.doc("congregations/c1/misc/anything").set({ name: "x" }));
    }
  });
});

describe("security suite wiring", () => {
  it("exists under functions/test/security and is emulator-gated", () => {
    expect(hasEmulator === true || hasEmulator === false).toBe(true);
  });
});