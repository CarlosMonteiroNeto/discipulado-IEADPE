import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';
import 'package:ieadpe_converts/routing/router.dart';

import '../features/auth/auth_flow_test.dart' show FakeAuth;

void main() {
  testWidgets('mobile current route exposes selected semantics', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          scope: AccessScope(isAdmin: true),
          currentRoute: '/converts',
          onNavigate: (_) {},
          onSignOut: () {},
          child: const Text('Conteúdo'),
        ),
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
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('navigation at $width with 200% text and reduced motion', (
      t,
    ) async {
      t.view.resetPhysicalSize();
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      String? route;
      var feedback = 0;
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: AppShell(
              scope: AccessScope(isAdmin: true),
              onNavigate: (r) => route = r,
              onSignOut: () {},
              onFeedback: () => feedback++,
              child: const Text('Conteúdo'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Convertidos'));
      expect(route, '/converts');
      await t.tap(find.byTooltip('Enviar sugestão'));
      expect(feedback, 1);
      if (width < 768) {
        await t.tap(find.byTooltip('Abrir menu'));
        await t.pumpAndSettle();
        expect(find.text('Menu'), findsOneWidget);
      }
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
