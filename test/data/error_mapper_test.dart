import 'dart:async';

import 'package:discipulado_ieadpe/data/error_mapper.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ErrorMapper mapper = ErrorMapper();

  group('mapSdkCode', () {
    test('hides credential enumeration behind one generic pt-BR message', () {
      expect(
        mapper.mapSdkCode('user-not-found').code,
        AppFailureCode.unauthenticated,
      );
      expect(
        mapper.mapSdkCode('user-not-found').message,
        kInvalidCredentialsMessage,
      );
      expect(
        mapper.mapSdkCode('wrong-password').code,
        AppFailureCode.unauthenticated,
      );
      expect(
        mapper.mapSdkCode('invalid-credential').message,
        kInvalidCredentialsMessage,
      );
      expect(
        mapper.mapSdkCode('invalid-email').code,
        AppFailureCode.validation,
      );
    });

    test(
      'maps authorization denials to forbidden with Acesso não autorizado',
      () {
        expect(
          mapper.mapSdkCode('permission-denied').code,
          AppFailureCode.forbidden,
        );
        expect(
          mapper.mapSdkCode('permission-denied').message,
          kAccessDeniedMessage,
        );
        expect(
          mapper.mapSdkCode('unauthorized').code,
          AppFailureCode.forbidden,
        );
      },
    );

    test('maps network codes to unavailable with pt-BR feedback', () {
      expect(mapper.mapSdkCode('unavailable').code, AppFailureCode.unavailable);
      expect(
        mapper.mapSdkCode('deadline-exceeded').message,
        kNetworkFailureMessage,
      );
      expect(
        mapper.mapSdkCode('network-request-failed').code,
        AppFailureCode.unavailable,
      );
    });

    test('maps remaining SDK codes to their S11 categories', () {
      expect(
        mapper.mapSdkCode('invalid-argument').code,
        AppFailureCode.validation,
      );
      expect(mapper.mapSdkCode('not-found').code, AppFailureCode.notFound);
      expect(mapper.mapSdkCode('not-found').message, kNotFoundMessage);
      expect(mapper.mapSdkCode('already-exists').code, AppFailureCode.conflict);
      expect(mapper.mapSdkCode('aborted').message, kConflictMessage);
      expect(
        mapper.mapSdkCode('failed-precondition').code,
        AppFailureCode.conflict,
      );
      expect(mapper.mapSdkCode('totally-unknown').code, AppFailureCode.unknown);
    });
  });

  group('map', () {
    test('passes an AppFailure through unchanged', () {
      const AppFailure original = AppFailure(
        code: AppFailureCode.conflict,
        message: 'conflito',
      );
      expect(mapper.map(original), same(original));
    });

    test(
      'translates a timeout to unavailable without leaking the raw error',
      () {
        final AppFailure failure = mapper.map(TimeoutException('slow'));
        expect(failure.code, AppFailureCode.unavailable);
        expect(failure.message, kNetworkFailureMessage);
        expect(failure.message.contains('TimeoutException'), isFalse);
      },
    );

    test('wraps an unexpected error in a safe pt-BR message', () {
      final AppFailure failure = mapper.map(StateError('boom'));
      expect(failure.code, AppFailureCode.unknown);
      expect(failure.message, kUnexpectedFailureMessage);
      expect(failure.message.contains('boom'), isFalse);
    });
  });
}
