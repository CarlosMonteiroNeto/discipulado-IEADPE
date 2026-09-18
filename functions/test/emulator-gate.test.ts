import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import {
  assertEmulatorHosts,
  missingEmulatorHosts,
} from "./security/emulator-guard";

describe("emulator security entry point", () => {
  it("fails fast when the required emulator hosts are absent", () => {
    expect(missingEmulatorHosts({})).toContain("FIRESTORE_EMULATOR_HOST");
    expect(() => assertEmulatorHosts({})).toThrow(/FIRESTORE_EMULATOR_HOST/);
    expect(() =>
      assertEmulatorHosts({ FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }),
    ).toThrow(/FIREBASE_AUTH_EMULATOR_HOST/);
    expect(() =>
      assertEmulatorHosts({
        FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
        FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
      }),
    ).not.toThrow();
  });

  it("wires a fail-fast host check into the npm test:emulator script", () => {
    const pkg = JSON.parse(
      readFileSync(resolve(__dirname, "../package.json"), "utf8"),
    ) as { scripts: Record<string, string> };
    expect(pkg.scripts["test:emulator"]).toContain("FIRESTORE_EMULATOR_HOST");
    expect(pkg.scripts["test:emulator"]).toContain("process.exit(1)");
  });

  it("loads the newly authored hardening suite only for the emulator run", () => {
    const config = readFileSync(resolve(__dirname, "../vitest.config.ts"), "utf8");
    expect(config).toContain("npm_lifecycle_event");
    expect(config).toContain("test/security/**/*.test.ts");
    expect(config).toContain("test:emulator");
    // The task-2 suite is committed by an earlier task and is never modified.
    expect(config).toContain("test/security/rules.security.test.ts");
  });

  it("keeps the committed task-2 security suite byte-identical to HEAD", () => {
    const { spawnSync } = require("node:child_process") as typeof import("node:child_process");
    const result = spawnSync(
      "git",
      ["diff", "--quiet", "--", "test/security/rules.security.test.ts"],
      { cwd: resolve(__dirname, ".."), encoding: "utf8" },
    );
    expect(result.status).toBe(0);
  });
});
