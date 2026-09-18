/**
 * Contact storage paths and the minimal authenticated directory projection
 * (S04, S05).
 *
 * The directory projection is the only contact shape readable across scopes:
 * it carries the S04 fields and never a birth date, address or student field.
 * It is written together with the contact inside the same transaction, so a
 * rename, a role change or an archive is never observable half-applied.
 */
import { JsonMap, Transaction, paths } from "../core/datastore";
import { validationError } from "../core/errors";
import {
  ContactScope,
  DIRECTORY_PROJECTION_FIELDS,
  toDirectoryProjection,
} from "../core/models";

/** The scoped full record path; only the owning scope can read it. */
export function contactPath(
  scope: ContactScope,
  congregationId: string | null,
  contactId: string,
): string {
  if (scope === ContactScope.supervision) {
    return paths.supervisionContact(contactId);
  }
  if (congregationId === null || congregationId.length === 0) {
    throw validationError("A congregation contact requires a congregation.");
  }
  return paths.contact(congregationId, contactId);
}

/**
 * Writes the directory projection for an active contact and removes it for an
 * archived one, so archived contacts have no active directory availability.
 */
export async function writeDirectoryProjection(
  tx: Transaction,
  contact: JsonMap,
): Promise<void> {
  const id = typeof contact.id === "string" ? contact.id : "";
  if (id.length === 0) return;
  if (contact.archived === true) {
    await tx.delete(paths.directory(id));
    return;
  }
  await tx.write(paths.directory(id), toDirectoryProjection(contact));
}

/**
 * Composes one directory entry with the authoritative congregation name
 * resolved by ID. Renaming a congregation therefore updates every rendered
 * entry without rewriting contact documents, and private fields stay out.
 */
export function renderDirectoryEntry(
  projection: JsonMap,
  congregation: JsonMap | null,
): JsonMap {
  const entry: JsonMap = {};
  for (const field of DIRECTORY_PROJECTION_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(projection, field)) {
      entry[field] = projection[field];
    }
  }
  entry.congregationName =
    congregation !== null && typeof congregation.name === "string"
      ? congregation.name
      : null;
  return entry;
}
