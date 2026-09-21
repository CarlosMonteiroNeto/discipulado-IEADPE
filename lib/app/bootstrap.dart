/// Real browser bootstrap: explicit environment configuration, optional local
/// emulators, no production fallback and no legacy credentials (S03, S12).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/error_mapper.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firebase_configuration.dart';
import '../data/firebase_gateway.dart';
import '../data/firestore_direct_store.dart';
import '../data/firestore_direct_transport.dart';
import '../data/handlers/registry.dart';
import '../ui/app_theme.dart';
import 'app.dart';
import 'dependencies.dart';

/// Build-time configuration. An absent value is a setup error, never a
/// fallback to a hardcoded project (S12).
const Map<String, String> _environment = <String, String>{
  'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
  'FIREBASE_API_KEY': String.fromEnvironment('FIREBASE_API_KEY'),
  'FIREBASE_AUTH_DOMAIN': String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
  'FIREBASE_APP_ID': String.fromEnvironment('FIREBASE_APP_ID'),
  'FIREBASE_STORAGE_BUCKET': String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  'FIREBASE_MESSAGING_SENDER_ID': String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  ),
  'FIREBASE_USE_EMULATOR': String.fromEnvironment('FIREBASE_USE_EMULATOR'),
  'FIREBASE_EMULATOR_HOST': String.fromEnvironment('FIREBASE_EMULATOR_HOST'),
  'FIREBASE_AUTH_EMULATOR_PORT': String.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
  ),
  'FIREBASE_FIRESTORE_EMULATOR_PORT': String.fromEnvironment(
    'FIREBASE_FIRESTORE_EMULATOR_PORT',
  ),
  'FIREBASE_FUNCTIONS_EMULATOR_PORT': String.fromEnvironment(
    'FIREBASE_FUNCTIONS_EMULATOR_PORT',
  ),
};

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FirebaseConfiguration? configuration =
      FirebaseConfiguration.fromEnvironment(_environment);
  if (configuration == null) {
    runApp(const _SetupErrorApp());
    return;
  }

  await Firebase.initializeApp(options: configuration.toFirebaseOptions());

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  // Persistent browser caching is disabled for this release (S12).
  firestore.settings = const Settings(persistenceEnabled: false);
  final FirebaseAuth auth = FirebaseAuth.instance;

  if (configuration.usesEmulator) {
    // Only Auth and Firestore run locally: the direct transport never calls a
    // Functions emulator or a Cloud Functions backend.
    auth.useAuthEmulator(
      configuration.emulatorHost,
      configuration.authEmulatorPort,
    );
    firestore.useFirestoreEmulator(
      configuration.emulatorHost,
      configuration.firestoreEmulatorPort,
    );
  }

  final FirebaseAuthRepository authRepository = FirebaseAuthRepository(
    adapter: FirebaseAuthAdapter(auth: auth, firestore: firestore),
  );
  await authRepository.adapter.configureSessionPersistence();

  final FirebaseGateway gateway = FirebaseGateway(
    transport: FirestoreDirectTransport(
      store: FirestoreDirectStore(firestore: firestore),
      registry: composeHandlerRegistry(),
      uid: () => auth.currentUser?.uid ?? 'system',
      now: DateTime.now,
    ),
  );

  runApp(
    DiscipuladoApp(
      dependencies: AppDependencies.fromPorts(
        authRepository: authRepository,
        gateway: gateway,
        configuration: configuration,
      ),
    ),
  );
}

/// Shown when configuration is absent; it never connects to a legacy project.
class _SetupErrorApp extends StatelessWidget {
  const _SetupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Discipulado IEADPE',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Text(
              kSetupFailureMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
