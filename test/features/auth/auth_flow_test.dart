import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/features/auth/login_page.dart';
import 'package:ieadpe_converts/routing/router.dart';
import 'package:ieadpe_converts/routing/browser_route_history.dart';

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

class _FakeBrowserHistory implements BrowserRouteHistory {
  final entries = <String>[];
  int index = -1;
  String? initialPath;
  void Function(String path)? onPop;
  @override
  String? get currentPath =>
      initialPath == null ? null : Uri.parse(initialPath!).path;
  @override
  void listen(void Function(String path) callback) => onPop = callback;
  @override
  void push(String path) {
    entries.removeRange(index + 1, entries.length);
    entries.add(path);
    index = entries.length - 1;
  }

  @override
  void replace(String path) {
    if (index < 0) {
      entries.add(path);
      index = 0;
    } else {
      entries[index] = path;
    }
  }

  void back() {
    if (index > 0) onPop?.call(entries[--index]);
  }

  void forward() {
    if (index + 1 < entries.length) onPop?.call(entries[++index]);
  }

  @override
  void dispose() => onPop = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('registrar can navigate only to Register', () {
    expect(routesFor(AccessScope()), ['/register']);
    expect(routesFor(AccessScope(congregationIds: ['one'])), [
      '/register',
      '/home',
      '/converts',
      '/pending',
    ]);
    expect(routesFor(AccessScope(isSupervision: true)), [
      '/register',
      '/home',
      '/converts',
      '/pending',
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

  test('ministry grant changes alter scope equality', () {
    final campaign = AccessScope(
      isAdmin: true,
      congregationIds: ['11111111-1111-1111-1111-111111111111'],
    );
    final ministry = AccessScope(
      isAdmin: true,
      congregationIds: ['11111111-1111-1111-1111-111111111111'],
      ministryCongregationIds: ['22222222-2222-2222-2222-222222222222'],
    );
    final equivalent = AccessScope(
      isAdmin: true,
      congregationIds: ['11111111-1111-1111-1111-111111111111'],
      ministryCongregationIds: ['22222222-2222-2222-2222-222222222222'],
    );
    final revoked = AccessScope(
      isAdmin: true,
      congregationIds: ['11111111-1111-1111-1111-111111111111'],
    );
    expect(ministry, isNot(campaign));
    expect(ministry, isNot(revoked));
    expect(ministry, equals(equivalent));
    expect(ministry.hashCode, equivalent.hashCode);
  });
  test('ministry routes require ministry grants and stay separate from campaign routes', () {
    final campaign = AccessScope(congregationIds: ['campaign-id']);
    final ministry = AccessScope(ministryCongregationIds: ['ministry-id']);
    expect(routesFor(campaign), contains('/converts'));
    expect(routesFor(campaign), isNot(contains('/ministry')));
    expect(routesFor(ministry), contains('/ministry'));
    expect(routesFor(ministry), contains('/ministry/students/register'));
    expect(routesFor(ministry), isNot(contains('/converts')));
    expect(routesFor(campaign), isNot(contains('/ministry/students/register')));
    expect(safeRoute('/ministry/students/register'), '/ministry/students');
  });
  test(
    'student registration route requires an authorized ministry scope',
    () async {
      final authorized = FakeAuth()
        ..access = AccessScope(ministryCongregationIds: ['ministry-id']);
      final allowed = SessionRouter(
        authorized,
        clearProtectedCaches: () {},
        intendedRoute: '/ministry/students/register',
      );
      await Future<void>.delayed(Duration.zero);
      expect(allowed.route, '/ministry/students');
      expect(allowed.allowedRoutes, contains('/ministry/students/register'));
      allowed.dispose();
      await authorized.events.close();

      final denied = FakeAuth()
        ..access = AccessScope(congregationIds: ['campaign']);
      final rejected = SessionRouter(
        denied,
        clearProtectedCaches: () {},
        intendedRoute: '/ministry/students/register',
      );
      await Future<void>.delayed(Duration.zero);
      expect(rejected.route, '/register');
      rejected.go('/ministry/students/register');
      expect(rejected.route, '/register');
      rejected.dispose();
      await denied.events.close();
    },
  );
  test('a campaign session cannot open a ministry deep link', () async {
    final auth = FakeAuth()
      ..access = AccessScope(congregationIds: ['campaign']);
    final router = SessionRouter(
      auth,
      clearProtectedCaches: () {},
      intendedRoute: '/ministry/students',
    );
    await Future<void>.delayed(Duration.zero);
    expect(router.route, '/register');
    router.go('/ministry/students');
    expect(router.route, '/register');
    router.dispose();
    await auth.events.close();
  });
  test(
    'browser back and forward restore only server authorized routes',
    () async {
      final auth = FakeAuth();
      final history = _FakeBrowserHistory();
      final router = SessionRouter(
        auth,
        clearProtectedCaches: () {},
        intendedRoute: '/home',
        browserHistory: history,
      );
      await Future<void>.delayed(Duration.zero);
      router.go('/converts');
      expect(history.entries, ['/home', '/converts']);
      expect(history.entries.every((entry) => !entry.contains('?')), isTrue);
      history.back();
      expect(router.route, '/home');
      history.forward();
      expect(router.route, '/converts');
      router.dispose();
      await auth.events.close();
    },
  );
  test(
    'unauthenticated router leaves public pop paths for bootstrap',
    () async {
      final auth = FakeAuth()..currentSession = null;
      final history = _FakeBrowserHistory()..initialPath = '/home';
      final router = SessionRouter(
        auth,
        clearProtectedCaches: () {},
        browserHistory: history,
      );
      await Future<void>.delayed(Duration.zero);

      history.onPop?.call('/');
      expect(
        history.entries,
        isEmpty,
        reason:
            'bootstrap owns the public root path during unauthenticated login',
      );
      history.onPop?.call('/register');
      expect(history.entries, isEmpty);

      router.dispose();
      await auth.events.close();
    },
  );
  test('browser refresh restores only a server authorized path', () async {
    final auth = FakeAuth()
      ..access = AccessScope(ministryCongregationIds: ['ministry-id']);
    final history = _FakeBrowserHistory()
      ..initialPath = '/ministry/students?campaign=ignored';
    final router = SessionRouter(
      auth,
      clearProtectedCaches: () {},
      browserHistory: history,
    );
    await Future<void>.delayed(Duration.zero);
    expect(router.route, '/ministry/students');
    expect(history.entries, ['/ministry/students']);
    router.dispose();
    await auth.events.close();
  });
  test(
    'browser refresh rejects a path outside the current session scope',
    () async {
      final auth = FakeAuth()
        ..access = AccessScope(congregationIds: ['campaign']);
      final history = _FakeBrowserHistory()..initialPath = '/ministry/students';
      final router = SessionRouter(
        auth,
        clearProtectedCaches: () {},
        browserHistory: history,
      );
      await Future<void>.delayed(Duration.zero);
      expect(router.route, '/register');
      expect(history.entries, ['/register']);
      router.dispose();
      await auth.events.close();
    },
  );
  test(
    'revoking a ministry grant during resume clears the protected owner',
    () async {
      final auth = FakeAuth()
        ..access = AccessScope(ministryCongregationIds: ['ministry-id']);
      var clears = 0;
      final router = SessionRouter(auth, clearProtectedCaches: () => clears++);
      await Future<void>.delayed(Duration.zero);
      expect(router.allowedRoutes, contains('/ministry'));
      final before = clears;
      auth.access = AccessScope();
      await router.revalidate();
      expect(clears, greaterThan(before));
      expect(router.allowedRoutes, isNot(contains('/ministry')));
      expect(router.route, '/register');
      router.dispose();
      await auth.events.close();
    },
  );
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
  test(
    'ordinary resume preserves authorized owner and latest destination',
    () async {
      final auth = FakeAuth();
      var clears = 0;
      final router = SessionRouter(auth, clearProtectedCaches: () => clears++);
      await Future<void>.delayed(Duration.zero);
      router.go('/admin');
      final before = clears;
      auth.pending = Completer<AccessScope>();
      router.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(
        clears,
        before,
        reason: 'ordinary resume must retain picker and weekly owner',
      );
      auth.pending!.complete(auth.access);
      await Future<void>.delayed(Duration.zero);
      expect(router.route, '/admin');
      await router.refresh();
      expect(
        clears,
        greaterThan(before),
        reason: 'explicit permission refresh replaces owner',
      );
      router.dispose();
      await auth.events.close();
    },
  );
  test(
    'overlapping explicit refresh retains last authorized destination',
    () async {
      final auth = FakeAuth();
      final router = SessionRouter(auth, clearProtectedCaches: () {});
      await Future<void>.delayed(Duration.zero);
      router.go('/admin');
      auth.pending = Completer<AccessScope>();
      final first = router.refresh();
      final second = router.refresh();
      auth.pending!.complete(auth.access);
      await Future.wait([first, second]);
      expect(router.route, '/admin');
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
