/// Task 13 acceptance: composed entry points, routing, session guards and the
/// real-repository wiring (S04, S10, S11, S12).
///
/// Black-box tests: they drive the composed [DiscipuladoApp] with an injected
/// transport, so no Firebase project, emulator or production credential is
/// involved.
library;

import 'dart:async';

import 'package:discipulado_ieadpe/app/app.dart';
import 'package:discipulado_ieadpe/app/dependencies.dart';
import 'package:discipulado_ieadpe/app/navigation.dart';
import 'package:discipulado_ieadpe/app/not_found_page.dart';
import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A scripted [AuthRepository]: the test decides when a session arrives. The
/// controller is single-subscription so a state emitted before the app starts
/// (for example the initial signed-out `null`) is delivered on subscribe.
class _FakeAuthRepository implements AuthRepository {
  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>();

  @override
  Stream<AuthSession?> watchSession() => _controller.stream;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  void emit(AuthSession? session) => _controller.add(session);
}

/// An injectable [BackendGateway] that records operations and returns empty
/// pages; the composed app must route every feature through it.
class _FakeGateway implements BackendGateway {
  final List<String> operations = <String>[];

  @override
  Future<JsonMap> invoke(String operation, JsonMap payload) async {
    operations.add(operation);
    return <String, Object?>{'id': 'record', 'revision': 1};
  }

  @override
  Future<PageResult> query(QueryRequest request) async =>
      const PageResult(items: <JsonMap>[]);

  @override
  Future<JsonMap?> get(RecordLocator locator) async => null;
}

AuthSession _session({
  AccessRole role = AccessRole.congregationStaff,
  String? congregationId = 'congregation-a',
  bool active = true,
}) => AuthSession(
  uid: 'uid-1',
  profile: AccessProfile(
    accessRole: role,
    congregationId: congregationId,
    active: active,
    revision: 1,
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
);

Uri _location(GoRouter router) => router.routeInformationProvider.value.uri;

Future<void> _pumpApp(WidgetTester tester, AppDependencies dependencies) async {
  await tester.pumpWidget(DiscipuladoApp(dependencies: dependencies));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'entry points inject the real feature repositories over one gateway',
    () {
      final _FakeGateway gateway = _FakeGateway();
      final _FakeAuthRepository auth = _FakeAuthRepository();
      final AppDependencies dependencies = AppDependencies.fromPorts(
        authRepository: auth,
        gateway: gateway,
      );

      expect(dependencies.authController.repository, same(auth));
      expect(dependencies.teamRepository.gateway, same(gateway));
      expect(dependencies.studentRepository.gateway, same(gateway));
      expect(dependencies.academicRepository.gateway, same(gateway));
      expect(dependencies.overviewRepository.gateway, same(gateway));
      expect(dependencies.congregationRepository.gateway, same(gateway));
      expect(dependencies.configuration?.usesEmulator ?? false, isFalse);
    },
  );

  testWidgets('signed-out deep link is guarded and the destination survives '
      'the session load', (WidgetTester tester) async {
    final _FakeAuthRepository auth = _FakeAuthRepository();
    final AppDependencies dependencies = AppDependencies.fromPorts(
      authRepository: auth,
      gateway: _FakeGateway(),
    );
    auth.emit(null);
    await _pumpApp(tester, dependencies);

    dependencies.router.go('/alunos?busca=ana');
    await tester.pumpAndSettle();

    expect(_location(dependencies.router).path, AppRoutes.signIn);
    expect(
      _location(dependencies.router).queryParameters['from'],
      '/alunos?busca=ana',
    );

    auth.emit(_session());
    await tester.pumpAndSettle();

    expect(_location(dependencies.router).path, AppRoutes.students);
    expect(_location(dependencies.router).queryParameters['busca'], 'ana');
  });

  testWidgets('authenticated staff see the specification navigation labels '
      'without the supervisor-only destination', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _FakeAuthRepository auth = _FakeAuthRepository();
    final AppDependencies dependencies = AppDependencies.fromPorts(
      authRepository: auth,
      gateway: _FakeGateway(),
    );
    await _pumpApp(tester, dependencies);
    auth.emit(_session());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    for (final String label in <String>[
      'Visão geral',
      'Equipe',
      'Alunos',
      'Turmas',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Congregações'), findsNothing);
  });

  testWidgets('navigation offers Congregações to a supervisor', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _FakeAuthRepository auth = _FakeAuthRepository();
    final AppDependencies dependencies = AppDependencies.fromPorts(
      authRepository: auth,
      gateway: _FakeGateway(),
    );
    await _pumpApp(tester, dependencies);
    auth.emit(_session(role: AccessRole.supervisor, congregationId: null));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Congregações'), findsWidgets);
  });

  testWidgets('an unknown path renders the accessible not-found page', (
    WidgetTester tester,
  ) async {
    final _FakeAuthRepository auth = _FakeAuthRepository();
    final AppDependencies dependencies = AppDependencies.fromPorts(
      authRepository: auth,
      gateway: _FakeGateway(),
    );
    await _pumpApp(tester, dependencies);
    auth.emit(_session());
    await tester.pumpAndSettle();

    dependencies.router.go('/caminho-inexistente');
    await tester.pumpAndSettle();

    expect(find.byKey(NotFoundPage.pageKey), findsOneWidget);
    expect(find.text(NotFoundPage.title), findsOneWidget);
  });

  testWidgets('a forged congregation scope is refused without rendering the '
      'other scope list', (WidgetTester tester) async {
    final _FakeAuthRepository auth = _FakeAuthRepository();
    final AppDependencies dependencies = AppDependencies.fromPorts(
      authRepository: auth,
      gateway: _FakeGateway(),
    );
    await _pumpApp(tester, dependencies);
    auth.emit(_session(congregationId: 'congregation-a'));
    await tester.pumpAndSettle();

    dependencies.router.go('/alunos?congregacao=congregation-b');
    await tester.pumpAndSettle();

    expect(find.byKey(ForbiddenPage.pageKey), findsOneWidget);
  });

  testWidgets(
    'sign-out disposes loaded private content and returns to Entrar',
    (WidgetTester tester) async {
      final _FakeAuthRepository auth = _FakeAuthRepository();
      final AppDependencies dependencies = AppDependencies.fromPorts(
        authRepository: auth,
        gateway: _FakeGateway(),
      );
      await _pumpApp(tester, dependencies);
      auth.emit(_session());
      await tester.pumpAndSettle();

      dependencies.router.go('/alunos');
      await tester.pumpAndSettle();
      expect(_location(dependencies.router).path, AppRoutes.students);

      auth.emit(null);
      await tester.pumpAndSettle();

      expect(_location(dependencies.router).path, AppRoutes.signIn);
      expect(find.text('Alunos'), findsNothing);
    },
  );

  testWidgets('a deactivated profile is replaced by the access-denied screen', (
    WidgetTester tester,
  ) async {
    final _FakeAuthRepository auth = _FakeAuthRepository();
    final AppDependencies dependencies = AppDependencies.fromPorts(
      authRepository: auth,
      gateway: _FakeGateway(),
    );
    await _pumpApp(tester, dependencies);
    auth.emit(_session());
    await tester.pumpAndSettle();
    dependencies.router.go('/alunos');
    await tester.pumpAndSettle();

    auth.emit(_session(active: false));
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  test('scope selectors and navigation labels follow the specification', () {
    expect(
      navEntriesFor(AccessRole.congregationStaff).map((NavEntry e) => e.label),
      <String>['Visão geral', 'Equipe', 'Alunos', 'Turmas'],
    );
    expect(
      navEntriesFor(AccessRole.supervisor).map((NavEntry e) => e.label),
      <String>['Visão geral', 'Equipe', 'Alunos', 'Turmas', 'Congregações'],
    );
  });
}
