import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { QUERY_MATRIX } from "../src/core/queries";

/**
 * Hardened S09 index assertions. The committed infrastructure/queries tests
 * are not modified; this file adds the exact-definition, queryScope and
 * ordering proof they lacked.
 */
const root = resolve(__dirname, "../..");

describe("S09 index hardening", () => {
  it("matches the exact index definitions with ascending order and COLLECTION scope", () => {
    const expectedIndexes = [
      { collectionGroup: "directory", queryScope: "COLLECTION", fields: [{ fieldPath: "scope", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "directory", queryScope: "COLLECTION", fields: [{ fieldPath: "scope", order: "ASCENDING" }, { fieldPath: "roleCode", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "directory", queryScope: "COLLECTION", fields: [{ fieldPath: "congregationId", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "students", queryScope: "COLLECTION", fields: [{ fieldPath: "congregationId", order: "ASCENDING" }, { fieldPath: "archived", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "contacts", queryScope: "COLLECTION", fields: [{ fieldPath: "congregationId", order: "ASCENDING" }, { fieldPath: "archived", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "supervisionContacts", queryScope: "COLLECTION", fields: [{ fieldPath: "archived", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "classes", queryScope: "COLLECTION", fields: [{ fieldPath: "congregationId", order: "ASCENDING" }, { fieldPath: "status", order: "ASCENDING" }, { fieldPath: "normalizedName", order: "ASCENDING" }] },
      { collectionGroup: "sessions", queryScope: "COLLECTION", fields: [{ fieldPath: "classId", order: "ASCENDING" }, { fieldPath: "status", order: "ASCENDING" }, { fieldPath: "date", order: "ASCENDING" }] },
      { collectionGroup: "sessions", queryScope: "COLLECTION", fields: [{ fieldPath: "congregationId", order: "ASCENDING" }, { fieldPath: "status", order: "ASCENDING" }, { fieldPath: "date", order: "ASCENDING" }] },
      { collectionGroup: "enrollments", queryScope: "COLLECTION", fields: [{ fieldPath: "classId", order: "ASCENDING" }, { fieldPath: "status", order: "ASCENDING" }, { fieldPath: "startDate", order: "ASCENDING" }] },
      { collectionGroup: "enrollments", queryScope: "COLLECTION", fields: [{ fieldPath: "studentId", order: "ASCENDING" }, { fieldPath: "status", order: "ASCENDING" }, { fieldPath: "startDate", order: "ASCENDING" }] },
      { collectionGroup: "enrollments", queryScope: "COLLECTION", fields: [{ fieldPath: "congregationId", order: "ASCENDING" }, { fieldPath: "studentId", order: "ASCENDING" }, { fieldPath: "status", order: "ASCENDING" }, { fieldPath: "startDate", order: "ASCENDING" }] },
    ];
    const indexes = JSON.parse(
      readFileSync(resolve(root, "firestore.indexes.json"), "utf8"),
    ) as { indexes: unknown; fieldOverrides: unknown };
    expect(indexes.indexes).toEqual(expectedIndexes);
    expect(indexes.fieldOverrides).toEqual([]);
  });

  it("provides a queryScope and ascending order for each declared query matrix entry", () => {
    const indexes = JSON.parse(
      readFileSync(resolve(root, "firestore.indexes.json"), "utf8"),
    ) as {
      indexes: Array<{
        collectionGroup: string;
        queryScope: string;
        fields: Array<{ fieldPath: string; order: string }>;
      }>;
    };
    for (const entry of QUERY_MATRIX) {
      const match = indexes.indexes.find(
        (index) =>
          index.collectionGroup === entry.collectionGroup &&
          index.queryScope === "COLLECTION" &&
          index.fields.map((field) => field.fieldPath).join(",") ===
            entry.indexFields.join(",") &&
          index.fields.every((field) => field.order === "ASCENDING"),
      );
      expect(
        match,
        `missing COLLECTION/ASCENDING index for ${entry.resource}: ${entry.indexFields.join(",")}`,
      ).toBeTruthy();
    }
  });
});
