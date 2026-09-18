/// Centralized translation of SDK/transport errors into safe [AppFailure]s
/// (S11, S12). No stack trace, token or raw backend response ever reaches the
/// resulting failure.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../domain/common.dart';
import '../domain/ports.dart';

const String kInvalidCredentialsMessage = 'E-mail ou senha inválidos.';
const String kAccessDeniedMessage = 'Acesso não autorizado';
const String kNetworkFailureMessage =
    'Não foi possível conectar. Verifique sua conexão e tente novamente.';
const String kUnexpectedFailureMessage =
    'Ocorreu um erro inesperado. Tente novamente.';
const String kSetupFailureMessage =
    'O aplicativo não está configurado. Contate o administrador.';
const String kConflictMessage =
    'O registro foi alterado por outra pessoa. Recarregue e tente novamente.';
const String kNotFoundMessage = 'Registro não encontrado.';
const String kValidationMessage = 'Verifique os dados informados.';
const String kInvalidCursorMessage = 'A consulta não pôde ser continuada.';

class ErrorMapper {
  const ErrorMapper();

  /// Translate any error at the adapter boundary into a displayable failure.
  AppFailure map(Object error) {
    if (error is AppFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const AppFailure(
        code: AppFailureCode.unavailable,
        message: kNetworkFailureMessage,
      );
    }
    if (error is DataFormatException) {
      return const AppFailure(
        code: AppFailureCode.unknown,
        message: kUnexpectedFailureMessage,
      );
    }
    if (error is FirebaseException) {
      return mapSdkCode(error.code);
    }
    return const AppFailure(
      code: AppFailureCode.unknown,
      message: kUnexpectedFailureMessage,
    );
  }

  /// Translate a Firebase/Functions/Storage SDK error code.
  AppFailure mapSdkCode(String code) {
    switch (code) {
      case 'invalid-argument':
      case 'invalid-email':
        return const AppFailure(
          code: AppFailureCode.validation,
          message: kValidationMessage,
        );
      case 'unauthenticated':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // Deliberately one generic message: never reveal whether the account
        // exists (anti-enumeration).
        return const AppFailure(
          code: AppFailureCode.unauthenticated,
          message: kInvalidCredentialsMessage,
        );
      case 'permission-denied':
      case 'unauthorized':
      case 'user-disabled':
        return const AppFailure(
          code: AppFailureCode.forbidden,
          message: kAccessDeniedMessage,
        );
      case 'not-found':
        return const AppFailure(
          code: AppFailureCode.notFound,
          message: kNotFoundMessage,
        );
      case 'already-exists':
      case 'aborted':
      case 'failed-precondition':
        return const AppFailure(
          code: AppFailureCode.conflict,
          message: kConflictMessage,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'too-many-requests':
        return const AppFailure(
          code: AppFailureCode.unavailable,
          message: kNetworkFailureMessage,
        );
      default:
        return const AppFailure(
          code: AppFailureCode.unknown,
          message: kUnexpectedFailureMessage,
        );
    }
  }
}
