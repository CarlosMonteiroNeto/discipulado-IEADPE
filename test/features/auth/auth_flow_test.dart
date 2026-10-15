import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/features/auth/login_page.dart';
import 'package:ieadpe_converts/routing/router.dart';

Session session(String id) => Session(
  accessToken: 'synthetic',
  tokenType: 'bearer',
  user: User(
    id: id,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-15T00:00:00Z',
  ),
);

class FakeAuth implements AuthGateway {
  @override
  Session? currentSession = session('user-a');
  final events = StreamController<Session?>.broadcast(sync: true);
  AccessScope access = AccessScope(isAdmin: true);
  Completer<AccessScope>? pending;
  bool failLogin = false;
  Completer<void>? signingOut;
  @override
  Stream<Session?> watchSession() => events.stream;
  @override
  Future<void> signInWithGoogle({String? intendedRoute}) async {
    if (failLogin) throw const AuthException('cancelled');
  }

  @override
  Future<AccessScope> loadScope() => pending?.future ?? Future.value(access);
  @override
  Future<void> signOut() async {
    await signingOut?.future;
    currentSession = null;
    events.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('registrar can navigate only to Register', () {
    expect(routesFor(AccessScope()), ['/register']);
    expect(routesFor(AccessScope(congregationIds: ['one'])), [
      '/register',
      '/home',
      '/converts',
    ]);
    expect(routesFor(AccessScope(isSupervision: true)), [
      '/register',
      '/home',
      '/converts',
      '/admin',
    ]);
  });
  test('intended route rejects external and encoded navigation', () {
    for (final value in [
      'https://evil.test',
      '//evil.test',
      '/%2fadmin',
      '/admin?next=evil',
      '/unknown',
    ]) {
      expect(safeRoute(value), '/register');
    }
    expect(safeRoute('/converts'), '/converts');
  });
  test('restores safe intent after server scope and clears data on lost grants/logout', () async {
    final auth = FakeAuth();
    final cache = <String>['protected'];
    final router = SessionRouter(
      auth,
      clearProtectedCaches: cache.clear,
      intendedRoute: '/converts',
    );
    await Future<void>.delayed(Duration.zero);
    expect(router.route, '/converts');
    cache.add('protected');
    auth.access = AccessScope();
    await router.refresh();
    expect(cache, isEmpty);
    expect(router.route, '/register');
    router.go('/admin');
    expect(router.route, '/register');
    cache.add('protected');
    await router.signOut();
    expect(cache, isEmpty);
    expect(router.route, '/login');
    router.dispose();
    await auth.events.close();
  });
  test('stale scope request cannot restore access after signout', () async {
    final auth = FakeAuth()..pending = Completer<AccessScope>();
    final router = SessionRouter(auth, clearProtectedCaches: () {});
    await router.signOut();
    auth.pending!.complete(AccessScope(isAdmin: true));
    await Future<void>.delayed(Duration.zero);
    expect(router.scope, isNull);
    expect(router.route, '/login');
    router.dispose();
    await auth.events.close();
  });
  test(
    'resume cannot reopen protected pages while signout is pending',
    () async {
      final auth = FakeAuth()..signingOut = Completer<void>();
      final router = SessionRouter(
        auth,
        clearProtectedCaches: () {},
        intendedRoute: '/admin',
      );
      await Future<void>.delayed(Duration.zero);
      final logout = router.signOut();
      await router.refresh();
      expect(router.route, '/login');
      expect(router.scope, isNull);
      auth.signingOut!.complete();
      await logout;
      router.dispose();
      await auth.events.close();
    },
  );
  testWidgets('cancelled login and browser return leave retry usable', (
    tester,
  ) async {
    final auth = FakeAuth()..failLogin = true;
    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível entrar. Tente novamente.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    auth.failLogin = false;
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await auth.events.close();
  });
}
