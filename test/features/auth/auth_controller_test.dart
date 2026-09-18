import 'dart:async';

import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AuthSession?> sessions =
      StreamController<AuthSession?>.broadcast();
  Object? signInError;
  int signOutCalls = 0;
  int signInCalls = 0;

  @override
  Stream<AuthSession?> watchSession() => sessions.stream;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (signInError != null) {
      throw signInError!;
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeScoped implements SessionScoped {
  int clearCalls = 0;

  @override
  void clearSessionData() => clearCalls++;
}

AuthSession _session({
  String uid = 'u1',
  String? congregationId = 'c1',
  AccessRole role = AccessRole.congregationStaff,
  bool active = true,
}) => AuthSession(
  uid: uid,
  profile: AccessProfile(
    accessRole: role,
    congregationId: congregationId,
    active: active,
    revision: 1,
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
);

void main() {
  late _FakeAuthRepository repository;
  late AuthController controller;

  setUp(() {
    repository = _FakeAuthRepository();
    controller = AuthController(repository: repository);
    controller.start();
  });

  tearDown(() async {
    controller.dispose();
    await repository.sessions.close();
  });

  test('authorizes an active profile returned by watchSession', () async {
    repository.sessions.add(_session());
    await pumpEventQueue();

    expect(controller.state.status, AuthStatus.authorized);
    expect(controller.state.session?.uid, 'u1');
  });

  test('shows Acesso não autorizado for an inactive profile', () async {
    repository.sessions.addError(
      const AppFailure(
        code: AppFailureCode.forbidden,
        message: 'Acesso não autorizado',
      ),
    );
    await pumpEventQueue();

    expect(controller.state.status, AuthStatus.accessDenied);
    expect(controller.state.failure?.message, 'Acesso não autorizado');
    expect(controller.state.session, isNull);
  });

  test(
    'clears scoped controllers when the congregation scope changes',
    () async {
      repository.sessions.add(_session(congregationId: 'c1'));
      await pumpEventQueue();
      final _FakeScoped scoped = _FakeScoped();
      controller.attach(scoped);

      repository.sessions.add(_session(congregationId: 'c2'));
      await pumpEventQueue();

      expect(scoped.clearCalls, 1);
      expect(controller.state.status, AuthStatus.authorized);
      expect(controller.state.session?.profile.congregationId, 'c2');
    },
  );

  test(
    'clears scoped controllers on profile revocation before notifying',
    () async {
      repository.sessions.add(_session());
      await pumpEventQueue();
      final _FakeScoped scoped = _FakeScoped();
      controller.attach(scoped);
      int clearsWhenNotified = -1;
      controller.addListener(() {
        if (controller.state.status == AuthStatus.accessDenied) {
          clearsWhenNotified = scoped.clearCalls;
        }
      });

      repository.sessions.addError(
        const AppFailure(
          code: AppFailureCode.forbidden,
          message: 'Acesso não autorizado',
        ),
      );
      await pumpEventQueue();

      expect(controller.state.status, AuthStatus.accessDenied);
      expect(clearsWhenNotified, 1);
    },
  );

  test('sign-out disposes listeners and in-memory session data', () async {
    repository.sessions.add(_session());
    await pumpEventQueue();
    final _FakeScoped scoped = _FakeScoped();
    controller.attach(scoped);
    bool clearedCallback = false;
    final AuthController signingOut = AuthController(
      repository: repository,
      onSessionCleared: () => clearedCallback = true,
    )..start();
    addTearDown(signingOut.dispose);
    repository.sessions.add(_session());
    await pumpEventQueue();
    signingOut.attach(scoped);

    await signingOut.signOut();
    await pumpEventQueue();

    expect(repository.signOutCalls, 1);
    expect(scoped.clearCalls, 1);
    expect(clearedCallback, isTrue);
    expect(signingOut.state.status, AuthStatus.signedOut);
    expect(signingOut.state.session, isNull);
  });

  test('reports pt-BR field feedback without calling the backend', () async {
    await controller.signIn('', '');

    expect(
      controller.state.failure?.fieldErrors?['email'],
      'Informe o e-mail.',
    );
    expect(
      controller.state.failure?.fieldErrors?['password'],
      'Informe a senha.',
    );
    expect(repository.signInCalls, 0);
  });

  test('rejects a malformed email before submitting', () async {
    await controller.signIn('ana', 'segredo123');

    expect(
      controller.state.failure?.fieldErrors?['email'],
      'Informe um e-mail válido.',
    );
    expect(repository.signInCalls, 0);
  });

  group('sanitizeReturnTo', () {
    test('keeps internal allowlisted destinations', () {
      expect(sanitizeReturnTo('/alunos/s1'), '/alunos/s1');
      expect(sanitizeReturnTo('/turmas'), '/turmas');
      expect(
        sanitizeReturnTo('/visao-geral?congregacao=c1'),
        '/visao-geral?congregacao=c1',
      );
    });

    test('rejects external and unknown destinations', () {
      expect(sanitizeReturnTo('https://evil.example'), isNull);
      expect(sanitizeReturnTo('//evil.example'), isNull);
      expect(sanitizeReturnTo('javascript:alert(1)'), isNull);
      expect(sanitizeReturnTo('/etc/passwd'), isNull);
      expect(sanitizeReturnTo(''), isNull);
      expect(sanitizeReturnTo(null), isNull);
    });
  });
}
