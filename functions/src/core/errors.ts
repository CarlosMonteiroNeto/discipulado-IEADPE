/**
 * Explicit failure semantics for the backend boundary (S11).
 *
 * Handlers throw [AppError]; the thin callable wrapper translates it into a
 * safe transport error. Stack traces, tokens and raw backend responses never
 * cross the boundary.
 */
export type AppErrorCode =
  | "validation"
  | "unauthenticated"
  | "forbidden"
  | "notFound"
  | "conflict"
  | "unavailable"
  | "unknown";

export class AppError extends Error {
  readonly code: AppErrorCode;
  readonly fieldErrors?: Record<string, string>;

  constructor(
    code: AppErrorCode,
    message: string,
    fieldErrors?: Record<string, string>,
  ) {
    super(message);
    this.name = "AppError";
    this.code = code;
    if (fieldErrors !== undefined) {
      this.fieldErrors = fieldErrors;
    }
  }
}

export function isAppError(value: unknown): value is AppError {
  return value instanceof AppError;
}

export function validationError(
  message: string,
  fieldErrors?: Record<string, string>,
): AppError {
  return new AppError("validation", message, fieldErrors);
}

export function forbiddenError(message: string): AppError {
  return new AppError("forbidden", message);
}

export function notFoundError(message: string): AppError {
  return new AppError("notFound", message);
}

export function conflictError(message: string): AppError {
  return new AppError("conflict", message);
}

export function unavailableError(message: string): AppError {
  return new AppError("unavailable", message);
}
