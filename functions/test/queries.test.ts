import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { AccessRole } from "../src/core/models";
import type { AuthorizedContext } from "../src/core/context";
import { AppError } from "../src/core/errors";
import {
  QUERY_MATRIX,
  assertCursorMatches,
  decodeCursor,
  encodeCursor,
  validateQueryRequest,
} from "../src/core/queries";

const staffContext: AuthorizedContext = {
  uid: "staff1",
  profile: {
    accessRole: AccessRole.congregationStaff,
    congregationId: "c1",
    active: true,
    revision: 1,
    updatedAt: "2026-09-18T12:00:00.000Z",
  },
  congregation: { id: "c1", name: "Central", normalizedName: "central", active: true },
  congregationId: "c1",
};

const supervisorContext: AuthorizedContext = {
  uid: "sup1",
  profile: {
    accessRole: AccessRole.supervisor,
    congregationId: null,
    active: true,
    revision: 1,
    updatedAt: "2026-09-18T12:00:00.000Z",
  },
  congregation: null,
  congregationId: null,
};

function expectAppError(run: () => unknown): AppError {
  try {
    run();
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    return error as AppError;
  }
  throw new Error("expected an AppError to be thrown");
}

describe("validateQueryRequest", () => {
  it("defaults and bounds pagination", () => {
    expect(validateQueryRequest({ resource: "directory" }, staffContext).limit).toBe(50);
    expect(
      validateQueryRequest({ resource: "directory", limit: 100 }, staffContext).limit,
    ).toBe(100);
    expect(
      expectAppError(() =>
        validateQueryRequest({ resource: "directory", limit: 101 }, staffContext),
      ).code,
    ).toBe("validation");
    expect(
      expectAppError(() =>
        validateQueryRequest({ resource: "directory", limit: 0 }, staffContext),
      ).code,
    ).toBe("validation");
  });

  it("rejects unknown and internal resources", () => {
    expect(
      expectAppError(() => validateQueryRequest({ resource: "nope" }, staffContext)).code,
    ).toBe("validation");
    expect(
      expectAppError(() => validateQueryRequest({ resource: "operations" }, staffContext))
        .code,
    ).toBe("validation");
    expect(
      expectAppError(() => validateQueryRequest({ resource: "roster" }, staffContext)).code,
    ).toBe("validation");
  });

  it("rejects unsupported filters and name prefixes", () => {
    expect(
      expectAppError(() =>
        validateQueryRequest(
          { resource: "students", filters: { bogus: "x" } },
          staffContext,
        ),
      ).code,
    ).toBe("validation");
    expect(
      expectAppError(() =>
        validateQueryRequest({ resource: "enrollments", namePrefix: "ana" }, staffContext),
      ).code,
    ).toBe("validation");
  });

  it("retains and enforces scope", () => {
    expect(validateQueryRequest({ resource: "students" }, staffContext).congregationId).toBe(
      "c1",
    );
    expect(
      expectAppError(() =>
        validateQueryRequest(
          { resource: "students", congregationId: "c2" },
          staffContext,
        ),
      ).code,
    ).toBe("forbidden");
    expect(
      validateQueryRequest(
        { resource: "students", congregationId: "c2" },
        supervisorContext,
      ).congregationId,
    ).toBe("c2");
  });

  it("accepts normalized name prefix search only where declared", () => {
    expect(
      validateQueryRequest({ resource: "students", namePrefix: "José" }, staffContext)
        .namePrefix,
    ).toBe("jose");
  });
});

describe("cursor identity", () => {
  it("round-trips a cursor", () => {
    const cursor = encodeCursor({
      resource: "students",
      congregationId: "c1",
      filters: { archived: false },
      orderField: "normalizedName",
      orderValue: "ana",
      id: "s1",
    });
    expect(decodeCursor(cursor)).toEqual({
      resource: "students",
      congregationId: "c1",
      filters: { archived: false },
      orderField: "normalizedName",
      orderValue: "ana",
      id: "s1",
    });
  });

  it("rejects reuse after a scope or filter change", () => {
    const query = validateQueryRequest(
      { resource: "students", filters: { archived: false } },
      staffContext,
    );
    const cursor = decodeCursor(
      encodeCursor({
        resource: "students",
        congregationId: "c1",
        filters: { archived: false },
        orderField: "normalizedName",
        orderValue: "ana",
        id: "s1",
      }),
    );
    expect(() => assertCursorMatches(cursor, query)).not.toThrow();

    const otherScope = validateQueryRequest(
      { resource: "students", congregationId: "c2", filters: { archived: false } },
      supervisorContext,
    );
    expect(expectAppError(() => assertCursorMatches(cursor, otherScope)).code).toBe(
      "conflict",
    );

    const otherFilter = validateQueryRequest(
      { resource: "students", filters: { archived: true } },
      staffContext,
    );
    expect(expectAppError(() => assertCursorMatches(cursor, otherFilter)).code).toBe(
      "conflict",
    );
  });
});

describe("query matrix index coverage", () => {
  it("declares an index for every supported combination", () => {
    const indexesFile = JSON.parse(
      readFileSync(resolve(__dirname, "../../firestore.indexes.json"), "utf8"),
    ) as { indexes: Array<{ collectionGroup: string; fields: Array<{ fieldPath: string }> }> };
    for (const entry of QUERY_MATRIX) {
      const match = indexesFile.indexes.find(
        (index) =>
          index.collectionGroup === entry.collectionGroup &&
          index.fields.map((field) => field.fieldPath).join(",") ===
            entry.indexFields.join(","),
      );
      expect(
        match,
        `missing index for ${entry.resource}: ${entry.indexFields.join(",")}`,
      ).toBeTruthy();
    }
  });
});
