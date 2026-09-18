/**
 * Fail-fast guard for the emulator-backed security suite.
 *
 * The security suite must never report green by being skipped, so it is
 * excluded from the unit run and loaded only by the `test:emulator` entry
 * point. This guard throws whenever the emulator environment is absent.
 */
const REQUIRED_EMULATOR_VARS = [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_AUTH_EMULATOR_HOST",
] as const;

export function missingEmulatorHosts(env: NodeJS.ProcessEnv): string[] {
  return REQUIRED_EMULATOR_VARS.filter(
    (name) => typeof env[name] !== "string" || (env[name] as string).length === 0,
  );
}

export function assertEmulatorHosts(env: NodeJS.ProcessEnv): void {
  const missing = missingEmulatorHosts(env);
  if (missing.length > 0) {
    throw new Error(
      `The emulator security suite requires: ${missing.join(", ")}. ` +
        "Run it through `npm run test:emulator` against local emulators.",
    );
  }
}
