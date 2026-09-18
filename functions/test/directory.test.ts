import { describe, expect, it } from "vitest";
import { toDirectoryProjection } from "../src/core/models";

describe("directory projection", () => {
  it("keeps only the minimal authenticated directory fields", () => {
    const projection = toDirectoryProjection({
      id: "contact-1",
      name: "José da Silva",
      normalizedName: "jose da silva",
      scope: "congregation",
      congregationId: "c1",
      roleCode: "teacher",
      phoneE164: "+5581999998888",
    });
    expect(Object.keys(projection).sort()).toEqual([
      "congregationId",
      "id",
      "name",
      "normalizedName",
      "phoneE164",
      "roleCode",
      "scope",
    ]);
  });

  it("drops birth date, address and every student field", () => {
    const projection = toDirectoryProjection({
      id: "contact-2",
      name: "Ana",
      normalizedName: "ana",
      scope: "congregation",
      congregationId: "c1",
      roleCode: null,
      phoneE164: null,
      birthDate: "1990-01-01",
      address: { street: "Rua A" },
      education: "Ensino médio",
      maritalStatus: "Casado",
      waterBaptized: true,
      wantsBaptism: true,
      newConvert: false,
      archived: true,
    });
    expect(projection).not.toHaveProperty("birthDate");
    expect(projection).not.toHaveProperty("address");
    expect(projection).not.toHaveProperty("education");
    expect(projection).not.toHaveProperty("maritalStatus");
    expect(projection).not.toHaveProperty("waterBaptized");
    expect(projection).not.toHaveProperty("wantsBaptism");
    expect(projection).not.toHaveProperty("newConvert");
    expect(projection).not.toHaveProperty("archived");
  });
});
