/**
 * Deterministic validation shared with the Dart domain layer (S05).
 *
 * The Dart tests in `test/domain/validation_test.dart` are the example set;
 * the backend repeats the same semantics because it is authoritative. Every
 * rejection is an [AppError] with code `validation`.
 */
import { recifeToday } from "./clock";
import { AppError, validationError } from "./errors";

export const NAME_MIN_LENGTH = 2;
export const NAME_MAX_LENGTH = 120;
export const ADDRESS_STREET_MAX_LENGTH = 200;
export const ADDRESS_DISTRICT_MAX_LENGTH = 100;
export const ADDRESS_CITY_MAX_LENGTH = 100;
export const OPTIONAL_TEXT_MAX_LENGTH = 80;
export const SESSION_TOPIC_MAX_LENGTH = 200;
export const MINIMUM_BIRTH_YEAR = 1900;

export const BRAZILIAN_STATE_CODES: ReadonlySet<string> = new Set([
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS",
  "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC",
  "SP", "SE", "TO",
]);

const DIACRITIC_FOLD: Record<string, string> = {
  "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "ā": "a",
  "ă": "a", "ą": "a", "ç": "c", "ć": "c", "č": "c", "é": "e", "è": "e",
  "ê": "e", "ë": "e", "ē": "e", "ė": "e", "ę": "e", "ě": "e", "í": "i",
  "ì": "i", "î": "i", "ï": "i", "ī": "i", "į": "i", "ñ": "n", "ń": "n",
  "ň": "n", "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
  "ō": "o", "ő": "o", "ú": "u", "ù": "u", "û": "u", "ü": "u", "ū": "u",
  "ů": "u", "ű": "u", "ý": "y", "ÿ": "y", "š": "s", "ś": "s", "ž": "z",
  "ź": "z", "ż": "z", "đ": "d", "ğ": "g", "ł": "l", "ť": "t", "ř": "r",
};

/** Deterministic search key: trim, lowercase and remove diacritics. */
export function normalizeName(displayName: string): string {
  const trimmed = displayName.trim().toLowerCase();
  let normalized = "";
  for (const character of Array.from(trimmed)) {
    normalized += DIACRITIC_FOLD[character] ?? character;
  }
  return normalized;
}

/** Rejects a missing or non-string display name with `validation`. */
export function validateDisplayName(value: unknown, field = "name"): void {
  if (typeof value !== "string") {
    throw validationError("O nome é obrigatório.", { [field]: "O nome é obrigatório." });
  }
  const trimmed = value.trim();
  if (trimmed.length < NAME_MIN_LENGTH) {
    throw validationError(`O nome deve ter pelo menos ${NAME_MIN_LENGTH} caracteres.`, {
      [field]: `O nome deve ter pelo menos ${NAME_MIN_LENGTH} caracteres.`,
    });
  }
  if (trimmed.length > NAME_MAX_LENGTH) {
    throw validationError(`O nome deve ter no máximo ${NAME_MAX_LENGTH} caracteres.`, {
      [field]: `O nome deve ter no máximo ${NAME_MAX_LENGTH} caracteres.`,
    });
  }
}

/** Null/undefined are accepted; a present value must be within [maxLength]. */
export function validateOptionalText(
  value: unknown,
  maxLength: number,
  field = "text",
): void {
  if (value === null || value === undefined) return;
  if (typeof value !== "string") {
    throw validationError("O texto é inválido.", { [field]: "O texto é inválido." });
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return;
  if (trimmed.length > maxLength) {
    throw validationError(`O texto deve ter no máximo ${maxLength} caracteres.`, {
      [field]: `O texto deve ter no máximo ${maxLength} caracteres.`,
    });
  }
}

/** Null/undefined are accepted; a present value must be a boolean. */
export function validateOptionalBool(value: unknown, field: string): void {
  if (value === null || value === undefined) return;
  if (typeof value !== "boolean") {
    throw validationError("O valor deve ser verdadeiro ou falso.", {
      [field]: "O valor deve ser verdadeiro ou falso.",
    });
  }
}

/**
 * Normalizes an optional Brazilian number to E.164. Empty input yields null;
 * malformed structure is a `validation` failure.
 */
export function normalizeBrazilianPhone(raw: unknown): string | null {
  if (raw === null || raw === undefined) return null;
  if (typeof raw !== "string") {
    throw validationError("Telefone inválido.");
  }
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;

  if (/[A-Za-z]/.test(trimmed)) {
    throw validationError("Telefone inválido.");
  }
  if (/[^0-9+()\-.\s]/.test(trimmed)) {
    throw validationError("Telefone inválido.");
  }

  let digits: string;
  if (trimmed.startsWith("+")) {
    if (!trimmed.startsWith("+55")) {
      throw validationError("Apenas números brasileiros são aceitos.");
    }
    digits = trimmed.slice(3).replace(/[^0-9]/g, "");
  } else {
    if (trimmed.includes("+")) {
      throw validationError("Telefone inválido.");
    }
    digits = trimmed.replace(/[^0-9]/g, "");
  }

  if (digits.length !== 10 && digits.length !== 11) {
    throw validationError("Telefone deve ter 10 ou 11 dígitos.");
  }
  if (digits.startsWith("0")) {
    throw validationError("DDD inválido.");
  }
  if (digits.length === 11 && digits[2] !== "9") {
    throw validationError("Celular deve começar com 9.");
  }
  return `+55${digits}`;
}

export interface CalendarDateParts {
  year: number;
  month: number;
  day: number;
}

export function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

export function daysInMonth(year: number, month: number): number {
  if (month < 1 || month > 12) return 0;
  if (month === 2) return isLeapYear(year) ? 29 : 28;
  if ([4, 6, 9, 11].includes(month)) return 30;
  return 31;
}

export function isValidCalendarDate(year: number, month: number, day: number): boolean {
  return month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(year, month);
}

/** Parses `yyyy-MM-dd`; malformed or impossible dates are `validation`. */
export function parseCalendarDate(value: unknown, field = "date"): CalendarDateParts {
  if (typeof value !== "string") {
    throw validationError("Data inválida.", { [field]: "Data inválida." });
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (match === null) {
    throw validationError("Data inválida.", { [field]: "Data inválida." });
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (!isValidCalendarDate(year, month, day)) {
    throw validationError("Data inválida.", { [field]: "Data inválida." });
  }
  return { year, month, day };
}

function compareParts(a: CalendarDateParts, b: CalendarDateParts): number {
  if (a.year !== b.year) return a.year - b.year;
  if (a.month !== b.month) return a.month - b.month;
  return a.day - b.day;
}

/**
 * Null/undefined birth dates are accepted. A present date must be a real
 * calendar date from 1900-01-01 through today in America/Recife.
 */
export function validateBirthDate(value: unknown, nowUtc: Date): void {
  if (value === null || value === undefined) return;
  const date = parseCalendarDate(value, "birthDate");
  const minimum: CalendarDateParts = { year: MINIMUM_BIRTH_YEAR, month: 1, day: 1 };
  if (compareParts(date, minimum) < 0) {
    throw validationError(`A data de nascimento deve ser a partir de 01/01/${MINIMUM_BIRTH_YEAR}.`, {
      birthDate: `A data de nascimento deve ser a partir de 01/01/${MINIMUM_BIRTH_YEAR}.`,
    });
  }
  const today = recifeToday(nowUtc);
  if (`${value}` > today) {
    throw validationError("A data de nascimento não pode estar no futuro.", {
      birthDate: "A data de nascimento não pode estar no futuro.",
    });
  }
}

/** Baptized and wanting baptism cannot both be true; null means not informed. */
export function validateBaptismAnswers(answers: {
  waterBaptized?: unknown;
  wantsBaptism?: unknown;
}): void {
  validateOptionalBool(answers.waterBaptized, "waterBaptized");
  validateOptionalBool(answers.wantsBaptism, "wantsBaptism");
  if (answers.waterBaptized === true && answers.wantsBaptism === true) {
    throw validationError("Quem já foi batizado não pode desejar o batismo.", {
      wantsBaptism: "Quem já foi batizado não pode desejar o batismo.",
    });
  }
}

export interface AddressFields {
  street?: unknown;
  district?: unknown;
  city?: unknown;
  postalCode?: unknown;
  stateCode?: unknown;
}

/** Validates optional address fields; empty or absent fields are accepted. */
export function validateAddressFields(address: AddressFields): void {
  validateOptionalText(address.street, ADDRESS_STREET_MAX_LENGTH, "street");
  validateOptionalText(address.district, ADDRESS_DISTRICT_MAX_LENGTH, "district");
  validateOptionalText(address.city, ADDRESS_CITY_MAX_LENGTH, "city");

  if (address.postalCode !== null && address.postalCode !== undefined) {
    if (typeof address.postalCode !== "string") {
      throw validationError("O CEP deve ter exatamente 8 dígitos.", {
        postalCode: "O CEP deve ter exatamente 8 dígitos.",
      });
    }
    const trimmed = address.postalCode.trim();
    if (trimmed.length > 0 && !/^\d{8}$/.test(trimmed)) {
      throw validationError("O CEP deve ter exatamente 8 dígitos.", {
        postalCode: "O CEP deve ter exatamente 8 dígitos.",
      });
    }
  }

  if (address.stateCode !== null && address.stateCode !== undefined) {
    if (typeof address.stateCode !== "string") {
      throw validationError("UF inválida.", { stateCode: "UF inválida." });
    }
    const trimmed = address.stateCode.trim();
    if (trimmed.length > 0 && !BRAZILIAN_STATE_CODES.has(trimmed)) {
      throw validationError("UF inválida.", { stateCode: "UF inválida." });
    }
  }
}

/** Validates a wire enum value, returning the enum member. */
export function validateEnum<T extends Record<string, string>>(
  value: unknown,
  enumType: T,
  field: string,
): T[keyof T] {
  if (typeof value === "string" && Object.values(enumType).includes(value)) {
    return value as T[keyof T];
  }
  throw new AppError("validation", `Unknown ${field}.`, {
    [field]: `Unknown ${field}.`,
  });
}

/**
 * Rejects any payload key that is not explicitly allowed, so unknown fields
 * are never copied into Admin SDK writes.
 */
export function rejectUnknownFields(
  payload: Record<string, unknown>,
  allowed: readonly string[],
): void {
  const allowedSet = new Set(allowed);
  const fieldErrors: Record<string, string> = {};
  for (const key of Object.keys(payload)) {
    if (!allowedSet.has(key)) {
      fieldErrors[key] = "Campo desconhecido.";
    }
  }
  if (Object.keys(fieldErrors).length > 0) {
    throw new AppError("validation", "Payload contains unknown fields.", fieldErrors);
  }
}
