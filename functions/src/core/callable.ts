/**
 * Thin callable wrapper (S11).
 *
 * Handlers are plain functions receiving the request payload; this wrapper
 * only maps [AppError] to the transport error and never carries business
 * logic. `functions/src/index.ts` (final composition task) is the sole
 * registration point.
 */
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { AppError, AppErrorCode } from "./errors";

type HttpsCode =
  | "invalid-argument"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "aborted"
  | "unavailable"
  | "internal";

const HTTPS_CODE_BY_APP_CODE: Record<AppErrorCode, HttpsCode> = {
  validation: "invalid-argument",
  unauthenticated: "unauthenticated",
  forbidden: "permission-denied",
  notFound: "not-found",
  conflict: "aborted",
  unavailable: "unavailable",
  unknown: "internal",
};

export function toHttpsError(error: unknown): HttpsError {
  if (error instanceof AppError) {
    return new HttpsError(
      HTTPS_CODE_BY_APP_CODE[error.code],
      error.message,
      error.fieldErrors ?? null,
    );
  }
  return new HttpsError("internal", "Unexpected error.");
}

export type CallableHandler<TResult> = (
  data: unknown,
  request: unknown,
) => Promise<TResult>;

export function defineCallable<TResult>(
  handler: CallableHandler<TResult>,
): ReturnType<typeof onCall> {
  return onCall(async (request) => {
    try {
      return await handler(request.data, request);
    } catch (error) {
      throw toHttpsError(error);
    }
  });
}
