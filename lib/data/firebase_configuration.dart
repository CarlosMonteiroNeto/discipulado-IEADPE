/// Explicit, environment-supplied Firebase client configuration (S03, S12).
///
/// Configuration never falls back to legacy credentials or a hardcoded
/// project: an absent configuration is a setup error. Emulator mode is
/// explicit and clearly labeled, and persistent browser caching stays off.
library;

import 'package:firebase_core/firebase_core.dart';

import '../domain/ports.dart';
import 'error_mapper.dart';

enum FirebaseEnvironment { production, emulator }

class FirebaseConfiguration {
  const FirebaseConfiguration({
    required this.environment,
    required this.projectId,
    required this.apiKey,
    required this.authDomain,
    required this.appId,
    this.storageBucket,
    this.messagingSenderId,
    this.emulatorHost = 'localhost',
    this.authEmulatorPort = 9099,
    this.firestoreEmulatorPort = 8080,
    this.functionsEmulatorPort = 5001,
  });

  final FirebaseEnvironment environment;
  final String projectId;
  final String apiKey;
  final String authDomain;
  final String appId;
  final String? storageBucket;
  final String? messagingSenderId;
  final String emulatorHost;
  final int authEmulatorPort;
  final int firestoreEmulatorPort;
  final int functionsEmulatorPort;

  bool get usesEmulator => environment == FirebaseEnvironment.emulator;

  /// Persistent browser caching is disabled for this release (S12).
  bool get persistentCacheEnabled => false;

  /// Emulator mode is explicit and unmistakable (S12).
  String get environmentLabel => usesEmulator ? 'Emulador local' : 'Produção';

  static const List<String> requiredKeys = <String>[
    'FIREBASE_PROJECT_ID',
    'FIREBASE_API_KEY',
    'FIREBASE_AUTH_DOMAIN',
    'FIREBASE_APP_ID',
  ];

  /// Build configuration from an explicit environment map, or `null` when the
  /// app is not configured. Never consults a legacy constant.
  static FirebaseConfiguration? fromEnvironment(
    Map<String, String> environment,
  ) {
    for (final String key in requiredKeys) {
      final String? value = environment[key];
      if (value == null || value.trim().isEmpty) {
        return null;
      }
    }
    final bool emulator =
        environment['FIREBASE_USE_EMULATOR']?.trim().toLowerCase() == 'true';
    return FirebaseConfiguration(
      environment: emulator
          ? FirebaseEnvironment.emulator
          : FirebaseEnvironment.production,
      projectId: environment['FIREBASE_PROJECT_ID']!,
      apiKey: environment['FIREBASE_API_KEY']!,
      authDomain: environment['FIREBASE_AUTH_DOMAIN']!,
      appId: environment['FIREBASE_APP_ID']!,
      storageBucket: environment['FIREBASE_STORAGE_BUCKET'],
      messagingSenderId: environment['FIREBASE_MESSAGING_SENDER_ID'],
      emulatorHost:
          environment['FIREBASE_EMULATOR_HOST']?.trim().isNotEmpty == true
          ? environment['FIREBASE_EMULATOR_HOST']!.trim()
          : 'localhost',
      authEmulatorPort: _port(environment['FIREBASE_AUTH_EMULATOR_PORT'], 9099),
      firestoreEmulatorPort: _port(
        environment['FIREBASE_FIRESTORE_EMULATOR_PORT'],
        8080,
      ),
      functionsEmulatorPort: _port(
        environment['FIREBASE_FUNCTIONS_EMULATOR_PORT'],
        5001,
      ),
    );
  }

  /// Like [fromEnvironment], but reports a safe setup failure when absent.
  static FirebaseConfiguration requireFromEnvironment(
    Map<String, String> environment,
  ) {
    final FirebaseConfiguration? configuration = fromEnvironment(environment);
    if (configuration == null) {
      throw const AppFailure(
        code: AppFailureCode.unknown,
        message: kSetupFailureMessage,
      );
    }
    return configuration;
  }

  FirebaseOptions toFirebaseOptions() => FirebaseOptions(
    apiKey: apiKey,
    authDomain: authDomain,
    projectId: projectId,
    storageBucket: storageBucket,
    messagingSenderId: messagingSenderId ?? '',
    appId: appId,
  );

  static int _port(String? raw, int fallback) =>
      int.tryParse(raw?.trim() ?? '') ?? fallback;
}
