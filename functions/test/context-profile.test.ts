import { describe, expect, it } from "vitest";
import { authorizeContext } from "../src/core/context";
import { InMemoryDatastore, paths } from "../src/core/datastore";
import { AppError } from "../src/core/errors";

const validProfile = {
  accessRole: "congregationStaff",
  congregationId: "c1",
  active: true,
  revision: 1,
  updatedAt: "2026-09-18T12:00:00.000Z",
};

function datastoreWith(profile: Record<string, unknown>): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("u")]: profile,
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
      active: true,
      revision: 1,
    },
  });
}

async function authorizationError(
  profile: Record<string, unknown>,
): Promise<AppError> {
  try {
    await authorizeContext({ datastore: datastoreWith(profile), uid: "u" });
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    return error as AppError;
  }
  throw new Error("expected authorizeContext to reject the malformed profile");
}

describe("authorizeContext malformed stored profiles", () => {
  it("accepts a well-formed profile", async () => {
    const context = await authorizeContext({
      datastore: datastoreWith(validProfile),
      uid: "u",
    });
    expect(context.profile.revision).toBe(1);
    expect(context.profile.updatedAt).toBe("2026-09-18T12:00:00.000Z");
  });

  it("rejects a non-integer, NaN or impossible revision", async () => {
    expect((await authorizationError({ ...validProfile, revision: "1" })).code).toBe(
      "validation",
    );
    expect((await authorizationError({ ...validProfile, revision: 1.5 })).code).toBe(
      "validation",
    );
    expect(
      (await authorizationError({ ...validProfile, revision: Number.NaN })).code,
    ).toBe("validation");
    expect((await authorizationError({ ...validProfile, revision: -1 })).code).toBe(
      "validation",
    );
    expect(
      (await authorizationError({ ...validProfile, revision: undefined })).code,
    ).toBe("validation");
  });

  it("rejects a missing or invalid updatedAt instead of fabricating one", async () => {
    expect((await authorizationError({ ...validProfile, updatedAt: undefined })).code).toBe(
      "validation",
    );
    expect((await authorizationError({ ...validProfile, updatedAt: "" })).code).toBe(
      "validation",
    );
    expect(
      (await authorizationError({ ...validProfile, updatedAt: "not-a-timestamp" })).code,
    ).toBe("validation");
  });

  it("rejects a non-boolean active flag and a non-string congregation id", async () => {
    expect((await authorizationError({ ...validProfile, active: "true" })).code).toBe(
      "validation",
    );
    expect(
      (await authorizationError({ ...validProfile, congregationId: 7 })).code,
    ).toBe("validation");
  });
});
