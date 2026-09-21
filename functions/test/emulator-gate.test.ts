import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { describe, expect, it } from "vitest";
import {
  assertEmulatorHosts,
  missingEmulatorHosts,
} from "./security/emulator-guard";

/**
 * Behavioral guard for the emulator entry point.
 *
 * The wiring proof does not grep the config source. It re-evaluates
 * `vitest.config.ts` with a cache-busted import under a controlled
 * `npm_lifecycle_event` and inspects the *resolved* test options, so it proves
 * the committed denial matrix is not excluded rather than blessing the
 * exclusion text. The previously buggy configuration (which excluded
 * `test/security/rules.security.test.ts`) fails this assertion.
 *
 * The committed task-2 suite is pinned to its revision object
 * (`f0130cf689aa2b8a300b3f99fad3488eed35f8c9`, write-matrix fix) by content
 * hash, so divergence is detected independent of the working tree or commit
 * state. The task-13 fix commit that added the class-roster and
 * active-enrollment-ref grants to the denial matrix re-pinned this constant
 * before commit and this corrective re-pin re-pointed the revision after it.
 */

const functionsDir = resolve(__dirname, "..");
const rootDir = resolve(functionsDir, "..");
const configPath = resolve(functionsDir, "vitest.config.ts");
const task2Revision = "f0130cf689aa2b8a300b3f99fad3488eed35f8c9";
const task2RulesSuiteSha256 =
  "0a71be857ddf1d996ecb3d9d56fdc19eb89ccea9d965516d091a7cdda996c0f4";

interface ResolvedTestOptions {
  include?: string[];
  exclude?: string[];
}

/** Re-evaluate the Vitest config under the given lifecycle. */
async function resolveTestOptions(
  lifecycle: string | undefined,
): Promise<ResolvedTestOptions> {
  const previous = process.env.npm_lifecycle_event;
  if (lifecycle === undefined) {
    delete process.env.npm_lifecycle_event;
  } else {
    process.env.npm_lifecycle_event = lifecycle;
  }
  try {
    // The query string busts the module cache so the config re-evaluates.
    const url = `${configPath}?lifecycle=${lifecycle ?? "none"}-${Date.now()}`;
    const module = (await import(/* @vite-ignore */ url)) as {
      default: { test: ResolvedTestOptions };
    };
    return module.default.test;
  } finally {
    if (previous === undefined) {
      delete process.env.npm_lifecycle_event;
    } else {
      process.env.npm_lifecycle_event = previous;
    }
  }
}

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
      readFileSync(resolve(functionsDir, "package.json"), "utf8"),
    ) as { scripts: Record<string, string> };
    expect(pkg.scripts["test:emulator"]).toContain("FIRESTORE_EMULATOR_HOST");
    expect(pkg.scripts["test:emulator"]).toContain("process.exit(1)");
  });

  it("loads both security suites under test:emulator and excludes neither", async () => {
    const options = await resolveTestOptions("test:emulator");
    expect(options.include).toContain("test/security/**/*.test.ts");
    // Behavioral proof: the committed task-2 denial matrix is not excluded.
    expect(options.exclude ?? []).not.toContain("test/security/rules.security.test.ts");
    expect(options.exclude ?? []).not.toContain("test/security/**");
  });

  it("keeps security suites out of every non-emulator run", async () => {
    for (const lifecycle of [undefined, "test", "test:unit"]) {
      const options = await resolveTestOptions(lifecycle);
      expect(options.exclude ?? []).toContain("test/security/**");
      expect(options.include).not.toContain("test/security/**/*.test.ts");
    }
  });

  it("keeps the committed task-2 security suite byte-identical to its revision", () => {
    // Line endings are normalized before hashing: the repository stores LF
    // while a Windows checkout materializes CRLF, so the guard must compare
    // content, not the platform's checkout encoding.
    const normalize = (text: string): string => text.replace(/\r\n/g, "\n");
    const committed = spawnSync(
      "git",
      ["show", `${task2Revision}:functions/test/security/rules.security.test.ts`],
      { cwd: rootDir, encoding: "utf8" },
    );
    expect(committed.status).toBe(0);
    expect(createHash("sha256").update(normalize(committed.stdout)).digest("hex")).toBe(
      task2RulesSuiteSha256,
    );
    // And the working file must match that pinned revision content too.
    const working = readFileSync(
      resolve(functionsDir, "test/security/rules.security.test.ts"),
      "utf8",
    );
    expect(createHash("sha256").update(normalize(working)).digest("hex")).toBe(
      task2RulesSuiteSha256,
    );
  });
});
