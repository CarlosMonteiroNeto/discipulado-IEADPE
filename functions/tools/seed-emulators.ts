/**
 * Synthetic emulator seeds (S04, S13).
 *
 * Refuses to run unless the explicit emulator environment variables are
 * present, so the same tool can never touch a production project. Fixtures are
 * synthetic people and emulator accounts only; no legacy credentials or data
 * are read.
 */
import { Datastore, JsonMap, paths } from "../src/core/datastore";
import { unavailableError } from "../src/core/errors";
import { AccessRole } from "../src/core/models";

export interface SeedSummary {
  supervisors: number;
  congregationStaff: number;
  congregations: number;
  contacts: number;
}

const REQUIRED_EMULATOR_VARS = [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_AUTH_EMULATOR_HOST",
] as const;

/** Refuses to operate unless both Auth and Firestore emulators are declared. */
export function assertEmulatorEnvironment(env: NodeJS.ProcessEnv): void {
  const missing = REQUIRED_EMULATOR_VARS.filter(
    (name) => typeof env[name] !== "string" || (env[name] as string).length === 0,
  );
  if (missing.length > 0) {
    throw unavailableError(
      `Emulator environment is required; missing ${missing.join(", ")}.`,
    );
  }
}

function profile(
  accessRole: AccessRole,
  congregationId: string | null,
  now: Date,
): JsonMap {
  return {
    accessRole,
    congregationId,
    active: true,
    revision: 1,
    updatedAt: now.toISOString(),
  };
}

export async function seedEmulators(
  datastore: Datastore,
  env: NodeJS.ProcessEnv,
  now: Date = new Date(),
): Promise<SeedSummary> {
  assertEmulatorEnvironment(env);

  await datastore.write(paths.user("emulator-supervisor"), profile(AccessRole.supervisor, null, now));
  await datastore.write(
    paths.user("emulator-staff-central"),
    profile(AccessRole.congregationStaff, "emulator-central", now),
  );
  await datastore.write(
    paths.user("emulator-staff-norte"),
    profile(AccessRole.congregationStaff, "emulator-norte", now),
  );

  const congregations: Array<[string, string, string]> = [
    ["emulator-central", "Congregação Central (emulador)", "congregacao central emulador"],
    ["emulator-norte", "Congregação Norte (emulador)", "congregacao norte emulador"],
  ];
  for (const [id, name, normalizedName] of congregations) {
    await datastore.write(paths.congregation(id), {
      id,
      name,
      normalizedName,
      active: true,
      revision: 1,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
      updatedBy: "emulator-seed",
    });
  }

  const contacts: Array<[string, string, string, string]> = [
    ["emulator-contact-ana", "Ana Souza", "ana souza", "emulator-central"],
    ["emulator-contact-ana-homonym", "Ana Souza", "ana souza", "emulator-central"],
    ["emulator-contact-teacher", "Paulo Professor", "paulo professor", "emulator-central"],
  ];
  for (const [id, name, normalizedName, congregationId] of contacts) {
    await datastore.write(paths.contact(congregationId, id), {
      id,
      name,
      normalizedName,
      scope: "congregation",
      congregationId,
      roleCode: null,
      phoneE164: null,
      birthDate: null,
      archived: false,
      revision: 1,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
      updatedBy: "emulator-seed",
    });
    await datastore.write(paths.directory(id), {
      id,
      name,
      normalizedName,
      roleCode: null,
      scope: "congregation",
      congregationId,
      phoneE164: null,
    });
  }

  return {
    supervisors: 1,
    congregationStaff: 2,
    congregations: congregations.length,
    contacts: contacts.length,
  };
}
