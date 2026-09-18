import { describe, expect, it } from "vitest";
import {
  normalizeName,
  normalizeBrazilianPhone,
  rejectUnknownFields,
  validateAddressFields,
  validateBaptismAnswers,
  validateBirthDate,
  validateDisplayName,
  validateEnum,
  validateOptionalBool,
  validateOptionalText,
} from "../src/core/validation";
import { AppError } from "../src/core/errors";
import { ClassStatus } from "../src/core/models";

const nowUtc = new Date("2026-09-18T12:00:00Z");

function expectAppError(run: () => unknown): AppError {
  try {
    run();
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    return error as AppError;
  }
  throw new Error("expected an AppError to be thrown");
}

describe("name normalization and lengths", () => {
  it("trims, lowercases and folds diacritics", () => {
    expect(normalizeName("  José  ")).toBe("jose");
    expect(normalizeName("Ana")).toBe("ana");
    expect(normalizeName("Ação")).toBe("acao");
  });

  it("accepts 2..120 trimmed characters and rejects the rest", () => {
    expect(validateDisplayName("Ana")).toBeUndefined();
    expect(validateDisplayName("A".repeat(120))).toBeUndefined();
    expect(validateDisplayName(" Ab ")).toBeUndefined();
    expect(expectAppError(() => validateDisplayName("A")).code).toBe("validation");
    expect(expectAppError(() => validateDisplayName("A".repeat(121))).code).toBe(
      "validation",
    );
    expect(expectAppError(() => validateDisplayName(null)).code).toBe("validation");
  });

  it("bounds optional text and treats blank as absent", () => {
    expect(validateOptionalText(null, 80)).toBeUndefined();
    expect(validateOptionalText("   ", 80)).toBeUndefined();
    expect(validateOptionalText("ok", 80)).toBeUndefined();
    expect(expectAppError(() => validateOptionalText("x".repeat(81), 80)).code).toBe(
      "validation",
    );
  });
});

describe("Brazilian phone normalization", () => {
  it("normalizes formatted 10 and 11 digit numbers to E.164", () => {
    expect(normalizeBrazilianPhone("(81) 99999-8888")).toBe("+5581999998888");
    expect(normalizeBrazilianPhone("+55 (81) 99999-8888")).toBe("+5581999998888");
    expect(normalizeBrazilianPhone("8133334444")).toBe("+558133334444");
  });

  it("treats empty input as absent", () => {
    expect(normalizeBrazilianPhone(null)).toBeNull();
    expect(normalizeBrazilianPhone("   ")).toBeNull();
  });

  it("rejects malformed structure", () => {
    expect(expectAppError(() => normalizeBrazilianPhone("123")).code).toBe(
      "validation",
    );
    expect(expectAppError(() => normalizeBrazilianPhone("08199998888")).code).toBe(
      "validation",
    );
    expect(expectAppError(() => normalizeBrazilianPhone("81899998888")).code).toBe(
      "validation",
    );
    expect(expectAppError(() => normalizeBrazilianPhone("+1 555 1234")).code).toBe(
      "validation",
    );
    expect(expectAppError(() => normalizeBrazilianPhone("abc")).code).toBe(
      "validation",
    );
  });
});

describe("calendar and nullable answer validation", () => {
  it("accepts a leap day and rejects an impossible date", () => {
    expect(validateBirthDate("2000-02-29", nowUtc)).toBeUndefined();
    expect(expectAppError(() => validateBirthDate("1900-02-29", nowUtc)).code).toBe(
      "validation",
    );
  });

  it("rejects dates before 1900 and after today in America/Recife", () => {
    expect(expectAppError(() => validateBirthDate("1899-12-31", nowUtc)).code).toBe(
      "validation",
    );
    expect(expectAppError(() => validateBirthDate("2026-09-19", nowUtc)).code).toBe(
      "validation",
    );
    expect(validateBirthDate("2026-09-18", nowUtc)).toBeUndefined();
    expect(validateBirthDate(null, nowUtc)).toBeUndefined();
  });

  it("rejects a baptized student who still wants baptism", () => {
    expect(
      expectAppError(() =>
        validateBaptismAnswers({ waterBaptized: true, wantsBaptism: true }),
      ).code,
    ).toBe("validation");
    expect(
      validateBaptismAnswers({ waterBaptized: true, wantsBaptism: null }),
    ).toBeUndefined();
    expect(
      validateBaptismAnswers({ waterBaptized: null, wantsBaptism: null }),
    ).toBeUndefined();
  });

  it("rejects non-boolean nullable answers instead of coercing", () => {
    expect(expectAppError(() => validateOptionalBool("true", "newConvert")).code).toBe(
      "validation",
    );
    expect(validateOptionalBool(null, "newConvert")).toBeUndefined();
    expect(validateOptionalBool(true, "newConvert")).toBeUndefined();
  });
});

describe("address, enums and unknown fields", () => {
  it("validates postal code, UF and field lengths", () => {
    expect(
      validateAddressFields({ postalCode: "12345678", stateCode: "PE" }),
    ).toBeUndefined();
    expect(
      expectAppError(() => validateAddressFields({ postalCode: "1234567" })).code,
    ).toBe("validation");
    expect(
      expectAppError(() => validateAddressFields({ stateCode: "XX" })).code,
    ).toBe("validation");
    expect(
      expectAppError(() => validateAddressFields({ street: "x".repeat(201) })).code,
    ).toBe("validation");
  });

  it("validates enum wire values", () => {
    expect(validateEnum("active", ClassStatus, "status")).toBe(ClassStatus.active);
    expect(expectAppError(() => validateEnum("bogus", ClassStatus, "status")).code).toBe(
      "validation",
    );
  });

  it("rejects unknown fields rather than copying them", () => {
    const payload = { name: "Ana", roleCode: "teacher", accessRole: "supervisor" };
    const error = expectAppError(() =>
      rejectUnknownFields(payload, ["name", "roleCode"]),
    );
    expect(error.code).toBe("validation");
    expect(error.fieldErrors).toHaveProperty("accessRole");
    expect(() => rejectUnknownFields({ name: "Ana" }, ["name"])).not.toThrow();
  });
});
