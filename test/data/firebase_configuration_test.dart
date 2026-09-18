import 'package:discipulado_ieadpe/data/error_mapper.dart';
import 'package:discipulado_ieadpe/data/firebase_configuration.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _environment() => <String, String>{
  'FIREBASE_PROJECT_ID': 'discipulado-dev',
  'FIREBASE_API_KEY': 'api-key-123',
  'FIREBASE_AUTH_DOMAIN': 'discipulado-dev.firebaseapp.com',
  'FIREBASE_APP_ID': '1:123:web:abc',
  'FIREBASE_STORAGE_BUCKET': 'discipulado-dev.appspot.com',
  'FIREBASE_MESSAGING_SENDER_ID': '123',
  'FIREBASE_USE_EMULATOR': 'true',
  'FIREBASE_EMULATOR_HOST': 'localhost',
  'FIREBASE_AUTH_EMULATOR_PORT': '9099',
  'FIREBASE_FIRESTORE_EMULATOR_PORT': '8080',
  'FIREBASE_FUNCTIONS_EMULATOR_PORT': '5001',
};

void main() {
  group('fromEnvironment', () {
    test('uses exactly the supplied environment values', () {
      final FirebaseConfiguration config =
          FirebaseConfiguration.fromEnvironment(_environment())!;
      expect(config.projectId, 'discipulado-dev');
      expect(config.apiKey, 'api-key-123');
      expect(config.authDomain, 'discipulado-dev.firebaseapp.com');
      expect(config.appId, '1:123:web:abc');
    });

    test('labels emulator mode explicitly', () {
      final FirebaseConfiguration config =
          FirebaseConfiguration.fromEnvironment(_environment())!;
      expect(config.usesEmulator, isTrue);
      expect(config.environmentLabel, 'Emulador local');
      expect(config.authEmulatorPort, 9099);
      expect(config.firestoreEmulatorPort, 8080);
      expect(config.functionsEmulatorPort, 5001);
    });

    test('defaults to production, never to a legacy project', () {
      final Map<String, String> env = _environment()
        ..remove('FIREBASE_USE_EMULATOR');
      final FirebaseConfiguration config =
          FirebaseConfiguration.fromEnvironment(env)!;
      expect(config.usesEmulator, isFalse);
      expect(config.environmentLabel, 'Produção');
    });

    test('disables persistent browser caching', () {
      final FirebaseConfiguration config =
          FirebaseConfiguration.fromEnvironment(_environment())!;
      expect(config.persistentCacheEnabled, isFalse);
    });

    test('returns null when any required value is absent', () {
      expect(FirebaseConfiguration.fromEnvironment(<String, String>{}), isNull);
      final Map<String, String> partial = _environment()
        ..remove('FIREBASE_APP_ID');
      expect(FirebaseConfiguration.fromEnvironment(partial), isNull);
      expect(
        FirebaseConfiguration.fromEnvironment(<String, String>{
          'FIREBASE_PROJECT_ID': 'legacy-project',
        }),
        isNull,
      );
    });
  });

  group('requireFromEnvironment', () {
    test('reports a setup error instead of falling back', () {
      expect(
        () => FirebaseConfiguration.requireFromEnvironment(<String, String>{}),
        throwsA(
          isA<AppFailure>()
              .having(
                (AppFailure f) => f.message,
                'message',
                kSetupFailureMessage,
              )
              .having(
                (AppFailure f) => f.message.contains('legacy'),
                'no legacy leak',
                isFalse,
              ),
        ),
      );
    });

    test('returns the configuration when complete', () {
      final FirebaseConfiguration config =
          FirebaseConfiguration.requireFromEnvironment(_environment());
      expect(config.projectId, 'discipulado-dev');
    });
  });
}
