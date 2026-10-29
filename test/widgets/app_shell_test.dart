import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';
import 'package:ieadpe_converts/routing/router.dart';

import '../features/auth/auth_flow_test.dart' show FakeAuth;

Future<void> _pumpShell(
  WidgetTester tester, {
  required double width,
  required Widget shell,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: shell));
}

void main() {
  testWidgets('mobile current route exposes selected semantics', (t) async {
    await _pumpShell(
      t,
      width: 360,
      shell: AppShell(
        scope: AccessScope(isAdmin: true),
        currentRoute: '/converts',
        onNavigate: (_) {},
        onSignOut: () {},
        child: const Text('Conteúdo'),
      ),
    );
    final selected = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.selected == true,
    );
    expect(
      find.descendant(of: selected, matching: find.text('Convertidos')),
      findsOneWidget,
    );
  });

  testWidgets('mobile navigation has no Menu tab and no side drawer', (
    t,
  ) async {
    final opened = <String>[];
    await _pumpShell(
      t,
      width: 360,
      shell: AppShell(
        scope: AccessScope(isAdmin: true, isMinistrySupervision: true),
        currentRoute: '/home',
        onNavigate: opened.add,
        onSignOut: () {},
        child: const Text('Conteúdo'),
      ),
    );

    expect(find.text('Menu'), findsNothing);
    expect(find.byTooltip('Abrir menu'), findsNothing);
    expect(t.widget<Scaffold>(find.byType(Scaffold)).endDrawer, isNull);
    expect(find.text('Pendentes'), findsNothing);
    expect(
      find.byKey(const ValueKey('app-shell-nav-/ministry/students/register')),
      findsNothing,
    );
    expect(find.text('Cadastrar aluno'), findsNothing);

    await t.tap(find.byKey(const ValueKey('app-shell-nav-/ministry')));
    expect(opened, ['/ministry']);
  });

  testWidgets('signed-in shell offers Sair in the header', (t) async {
    var signedOut = 0;
    await _pumpShell(
      t,
      width: 360,
      shell: AppShell(
        scope: AccessScope(isAdmin: true),
        onNavigate: (_) {},
        onSignOut: () => signedOut++,
        child: const Text('Conteúdo'),
      ),
    );

    await t.tap(find.byKey(const ValueKey('app-shell-sign-out')));
    expect(signedOut, 1);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('public shell offers Entrar and no bottom destinations', (
    t,
  ) async {
    var signIns = 0;
    await _pumpShell(
      t,
      width: 360,
      shell: AppShell(
        scope: AccessScope(),
        publicMode: true,
        onNavigate: (_) {},
        onSignOut: () {},
        onSignIn: () => signIns++,
        child: const Text('Cadastro'),
      ),
    );

    expect(find.text('Entrar'), findsOneWidget);
    expect(
      t.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
      isNull,
    );
    expect(find.byKey(const ValueKey('app-shell-nav-/register')), findsNothing);
    expect(find.text('Sair'), findsNothing);

    await t.tap(find.byKey(const ValueKey('app-shell-sign-in')));
    expect(signIns, 1);
  });

  testWidgets('register-only scope keeps protected destinations out', (
    t,
  ) async {
    await _pumpShell(
      t,
      width: 320,
      shell: AppShell(
        scope: AccessScope(),
        onNavigate: (_) {},
        onSignOut: () {},
        child: const Text('Cadastro'),
      ),
    );

    expect(find.text('Início'), findsNothing);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Discipulado'), findsNothing);
    expect(find.text('Menu'), findsNothing);
    expect(find.text('Sair'), findsOneWidget);
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('navigation at $width with 200% text and reduced motion', (
      t,
    ) async {
      String? tapped;
      var feedback = 0;
      await _pumpShell(
        t,
        width: width,
        shell: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: AppShell(
            scope: AccessScope(isAdmin: true),
            onNavigate: (route) => tapped = route,
            onSignOut: () {},
            onFeedback: () => feedback++,
            child: const Text('Conteúdo'),
          ),
        ),
      );
      await t.tap(find.text('Convertidos').first);
      expect(tapped, '/converts');
      await t.tap(find.byTooltip('Enviar sugestão'));
      expect(feedback, 1);
      expect(find.text('Menu'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  test('real SessionRouter redirects registrar private deep link', () async {
    final auth = FakeAuth()..access = AccessScope();
    final router = SessionRouter(
      auth,
      clearProtectedCaches: () {},
      intendedRoute: '/home',
    );
    await Future<void>.delayed(Duration.zero);
    expect(router.route, '/register');
    router.dispose();
    await auth.events.close();
  });
}
