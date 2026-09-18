/**
 * Student persistence over the authorized transaction boundary (S04, S05,
 * S07, S11).
 *
 * Students are private congregational records keyed by stable IDs: a name is
 * never an identity, so homonyms coexist and a rename keeps the same document.
 * Name is the only required personal field; every optional personal, address
 * and religious answer is nullable and `null` means "not informed". The
 * congregation binding is immutable. Creating or restoring an unarchived
 * student and archiving one adjust the congregation's internal
 * `unarchivedStudents` reference inside the same transaction, so the
 * congregation archive guard is driven by real student operations.
 */
import { Clock } from "../core/clock";
import { isUuid, runCommand } from "../core/commands";
import { AuthorizedContext } from "../core/context";
import { Datastore, JsonMap, Transaction, paths } from "../core/datastore";
import {
  conflictError,
  forbiddenError,
  notFoundError,
  validationError,
} from "../core/errors";
import {
  OPTIONAL_TEXT_MAX_LENGTH,
  normalizeBrazilianPhone,
  normalizeName,
  rejectUnknownFields,
  validateAddressFields,
  validateBaptismAnswers,
  validateBirthDate,
  validateDisplayName,
  validateOptionalBool,
  validateOptionalText,
} from "../core/validation";
import { adjustScopeReference } from "../congregations/service";

export interface StudentAddressInput {
  street?: unknown;
  district?: unknown;
  city?: unknown;
  postalCode?: unknown;
  stateCode?: unknown;
}

export interface SaveStudentInput {
  uid: string;
  requestId: string;
  id: string;
  expectedRevision?: number;
  congregationId: string;
  name: string;
  phone?: string | null;
  birthDate?: string | null;
  address?: StudentAddressInput | null;
  education?: string | null;
  maritalStatus?: string | null;
  newConvert?: boolean | null;
  waterBaptized?: boolean | null;
  wantsBaptism?: boolean | null;
}

export interface SetStudentArchivedInput {
  uid: string;
  requestId: string;
  id: string;
  congregationId: string;
  archived: boolean;
  expectedRevision: number;
}

export interface StudentMutationResult {
  id: string;
  revision: number;
}

const SAVE_STUDENT_FIELDS = [
  "id",
  "expectedRevision",
  "congregationId",
  "name",
  "phone",
  "birthDate",
  "address",
  "education",
  "maritalStatus",
  "newConvert",
  "waterBaptized",
  "wantsBaptism",
] as const;

const SET_STUDENT_ARCHIVED_FIELDS = [
  "id",
  "congregationId",
  "archived",
  "expectedRevision",
] as const;

const ADDRESS_FIELDS = [
  "street",
  "district",
  "city",
  "postalCode",
  "stateCode",
] as const;

/**
 * Internal uniqueness document for a student's single active enrollment (S05).
 * The enrollment feature (task 5) creates and clears it; archiving a student
 * reads it to refuse work that would strand an active enrollment.
 */
export function activeEnrollmentReferencePath(
  congregationId: string,
  studentId: string,
): string {
  return `congregations/${congregationId}/activeEnrollmentRefs/${studentId}`;
}

function requireCongregationId(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw validationError("A student requires congregationId.", {
      congregationId: "congregationId is required.",
    });
  }
  return value;
}

function requireRevision(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    throw validationError("expectedRevision must be a positive integer.", {
      expectedRevision: "expectedRevision must be a positive integer.",
    });
  }
  return value;
}

function optionalTrimmed(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") {
    throw validationError("O texto é inválido.");
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function optionalBoolean(value: unknown, field: string): boolean | null {
  validateOptionalBool(value, field);
  return value === true || value === false ? value : null;
}

function normalizeAddress(
  address: StudentAddressInput | null | undefined,
): JsonMap | null {
  if (address === null || address === undefined) return null;
  if (typeof address !== "object" || Array.isArray(address)) {
    throw validationError("Endereço inválido.", {
      address: "Endereço inválido.",
    });
  }
  rejectUnknownFields(address as Record<string, unknown>, ADDRESS_FIELDS);
  validateAddressFields(address);
  const normalized: JsonMap = {
    street: optionalTrimmed(address.street),
    district: optionalTrimmed(address.district),
    city: optionalTrimmed(address.city),
    postalCode: optionalTrimmed(address.postalCode),
    stateCode: optionalTrimmed(address.stateCode),
  };
  const hasValue = Object.values(normalized).some((value) => value !== null);
  return hasValue ? normalized : null;
}

/**
 * Archived congregations are read-only except restoration (S06), so every
 * student mutation resolves the authoritative congregation record and refuses
 * work inside an inactive one for every access role.
 */
async function assertActiveCongregation(
  tx: Transaction,
  context: AuthorizedContext,
  congregationId: string,
): Promise<void> {
  const cached = context.congregation;
  const congregation =
    cached !== null && cached.id === congregationId
      ? cached
      : await tx.read(paths.congregation(congregationId));
  if (congregation === null) {
    throw notFoundError("Congregation not found.");
  }
  if (congregation.active !== true) {
    throw forbiddenError("Congregation is inactive.");
  }
}

interface LocatedStudent {
  document: JsonMap;
  path: string;
}

/**
 * Resolves the stored student by its stable ID inside the caller's scope.
 * An ID that exists in another congregation is simply not found here, so an
 * out-of-scope or forged ID never returns personal data.
 */
async function locateStoredStudent(
  tx: Transaction,
  congregationId: string,
  studentId: string,
): Promise<LocatedStudent> {
  const path = paths.student(congregationId, studentId);
  const document = await tx.read(path);
  if (document === null || document.congregationId !== congregationId) {
    throw notFoundError("Student not found.");
  }
  return { document, path };
}

async function executeSaveStudent(
  tx: Transaction,
  context: AuthorizedContext,
  clock: Clock,
  input: SaveStudentInput,
): Promise<StudentMutationResult> {
  const congregationId = requireCongregationId(input.congregationId);
  await assertActiveCongregation(tx, context, congregationId);
  validateDisplayName(input.name);
  validateOptionalText(input.education, OPTIONAL_TEXT_MAX_LENGTH, "education");
  validateOptionalText(
    input.maritalStatus,
    OPTIONAL_TEXT_MAX_LENGTH,
    "maritalStatus",
  );
  validateBaptismAnswers({
    waterBaptized: input.waterBaptized,
    wantsBaptism: input.wantsBaptism,
  });
  const phoneE164 = normalizeBrazilianPhone(input.phone ?? null);
  validateBirthDate(input.birthDate ?? null, clock.now());
  const address = normalizeAddress(input.address);
  const newConvert = optionalBoolean(input.newConvert, "newConvert");
  const waterBaptized = optionalBoolean(input.waterBaptized, "waterBaptized");
  const wantsBaptism = optionalBoolean(input.wantsBaptism, "wantsBaptism");
  const name = input.name.trim();
  const normalizedName = normalizeName(input.name);
  const birthDate = input.birthDate ?? null;
  const education = optionalTrimmed(input.education);
  const maritalStatus = optionalTrimmed(input.maritalStatus);
  const nowIso = clock.now().toISOString();
  const isCreate = input.expectedRevision === undefined;

  if (isCreate) {
    if (!isUuid(input.id)) {
      throw validationError("id must be a UUID.", { id: "id must be a UUID." });
    }
    const document: JsonMap = {
      id: input.id,
      name,
      normalizedName,
      congregationId,
      phoneE164,
      birthDate,
      address,
      education,
      maritalStatus,
      newConvert,
      waterBaptized,
      wantsBaptism,
      archived: false,
      revision: 1,
      createdAt: nowIso,
      updatedAt: nowIso,
      updatedBy: input.uid,
    };
    await tx.createStable(paths.student(congregationId, input.id), document);
    await adjustScopeReference(tx, congregationId, "unarchivedStudents", 1);
    return { id: input.id, revision: 1 };
  }

  const expectedRevision = requireRevision(input.expectedRevision);
  const located = await locateStoredStudent(tx, congregationId, input.id);
  if (located.document.archived === true) {
    throw conflictError("Student is archived; restore it before editing.");
  }
  const next = await tx.updateWithRevision(
    located.path,
    expectedRevision,
    (record) => ({
      ...record,
      name,
      normalizedName,
      phoneE164,
      birthDate,
      address,
      education,
      maritalStatus,
      newConvert,
      waterBaptized,
      wantsBaptism,
      updatedAt: nowIso,
      updatedBy: input.uid,
    }),
  );
  return { id: input.id, revision: Number(next.revision) };
}

export async function saveStudent(
  datastore: Datastore,
  clock: Clock,
  input: SaveStudentInput,
): Promise<StudentMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SAVE_STUDENT_FIELDS);
  const congregationId = requireCongregationId(input.congregationId);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "saveStudent",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) =>
      executeSaveStudent(tx, context, clock, input),
  );
}

export async function setStudentArchived(
  datastore: Datastore,
  clock: Clock,
  input: SetStudentArchivedInput,
): Promise<StudentMutationResult> {
  const { uid: _uid, requestId: _requestId, ...payload } = input;
  rejectUnknownFields(payload, SET_STUDENT_ARCHIVED_FIELDS);
  const version = requireRevision(input.expectedRevision);
  if (typeof input.archived !== "boolean") {
    throw validationError("archived must be true or false.", {
      archived: "archived must be true or false.",
    });
  }
  const congregationId = requireCongregationId(input.congregationId);

  return runCommand(
    datastore,
    clock,
    {
      uid: input.uid,
      requestId: input.requestId,
      operation: "setStudentArchived",
      payload,
      requestedCongregationId: congregationId,
    },
    async (tx, context) => {
      await assertActiveCongregation(tx, context, congregationId);
      const located = await locateStoredStudent(tx, congregationId, input.id);
      const stored = located.document;
      if ((stored.archived === true) === input.archived) {
        return { id: input.id, revision: Number(stored.revision) };
      }
      if (input.archived) {
        const enrollmentReference = await tx.read(
          activeEnrollmentReferencePath(congregationId, input.id),
        );
        if (enrollmentReference !== null) {
          throw conflictError(
            "Student has an active enrollment and cannot be archived.",
          );
        }
      }
      const nowIso = clock.now().toISOString();
      const next = await tx.updateWithRevision(
        located.path,
        version,
        (record) => ({
          ...record,
          archived: input.archived,
          updatedAt: nowIso,
          updatedBy: input.uid,
        }),
      );
      await adjustScopeReference(
        tx,
        congregationId,
        "unarchivedStudents",
        input.archived ? -1 : 1,
      );
      return { id: input.id, revision: Number(next.revision) };
    },
  );
}
