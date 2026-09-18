/// Auth emulator integration: a valid password alone never bypasses profile
/// authorization (S04, S13).
///
/// Requires local Firebase Auth + Firestore emulators (`firebase emulators:start`).
/// This file is not executed by `flutter test`; run it with
/// `flutter test integration_test/auth_emulator_test.dart -d chrome` against the
/// emulators.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:discipulado_ieadpe/data/firebase_auth_repository.dart';
import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);
const int _authPort = int.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const int _firestorePort = int.fromEnvironment(
  'FIREBASE_FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a valid password alone does not bypass profile authorization', (
    WidgetTester tester,
  ) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1:web:emulator',
        messagingSenderId: '1',
        projectId: 'demo-discipulado',
        authDomain: 'demo-discipulado.firebaseapp.com',
      ),
    );
    final FirebaseAuth auth = FirebaseAuth.instance;
    auth.useAuthEmulator(_emulatorHost, _authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(
      _emulatorHost,
      _firestorePort,
    );

    final String email =
        'no-profile-${DateTime.now().microsecondsSinceEpoch}@example.com';
    const String password = 'Emulator-Only-123';
    // The fixture creates a real Auth identity, but deliberately no
    // users/{uid} access profile.
    await auth.createUserWithEmailAndPassword(email: email, password: password);

    final FirebaseAuthRepository repository = FirebaseAuthRepository(
      adapter: FirebaseAuthAdapter(
        auth: auth,
        firestore: FirebaseFirestore.instance,
      ),
    );
    final Completer<AppFailure> denial = Completer<AppFailure>();
    final List<AuthSession?> sessions = <AuthSession?>[];
    final StreamSubscription<AuthSession?> subscription = repository
        .watchSession()
        .listen(
          sessions.add,
          onError: (Object error) {
            if (!denial.isCompleted && error is AppFailure) {
              denial.complete(error);
            }
          },
        );
    addTearDown(subscription.cancel);

    // Happy path: the valid password produced a real Firebase identity.
    expect(auth.currentUser, isNotNull);

    // Deterministic bounded wait: resolve only when the profile-authorization
    // outcome arrives; pumping frames would race the emulator round-trip.
    final AppFailure failure = await denial.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'No profile-authorization outcome within 10 seconds.',
      ),
    );

    expect(sessions, isEmpty);
    expect(failure.code, AppFailureCode.forbidden);

    await auth.currentUser?.delete();
    await auth.signOut();
  });
}
