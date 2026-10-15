import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import '../features/auth/auth_repository.dart';

const _knownRoutes = {'/register', '/home', '/converts', '/admin'};
bool isSafeRoute(String? value) => _knownRoutes.contains(value);
String safeRoute(String? value) => isSafeRoute(value) ? value! : '/register';
List<String> routesFor(AccessScope scope) => [
  '/register',
  if (scope.isGlobalManager || scope.congregationIds.isNotEmpty) ...[
    '/home',
    '/converts',
  ],
  if (scope.isGlobalManager) '/admin',
];

/// Root listens to this guard and supplies real feature pages for allowed paths.
/// Every protected repository/cache must register its synchronous clear callback.
class SessionRouter extends ChangeNotifier with WidgetsBindingObserver {
  SessionRouter(
    this.auth, {
    required this.clearProtectedCaches,
    String? intendedRoute,
  }) : _intended = safeRoute(intendedRoute) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = auth.watchSession().listen(
      (_) {
        unawaited(refresh());
      },
      onError: (Object error, StackTrace stack) {
        _invalidate();
      },
    );
    unawaited(refresh());
  }
  final AuthGateway auth;
  final VoidCallback clearProtectedCaches;
  final String _intended;
  late final StreamSubscription<Session?> _subscription;
  AccessScope? _scope;
  int _generation = 0;
  bool _disposed = false;
  bool _signingOut = false;
  String _route = '/login';
  String get route => _route;
  AccessScope? get scope => _scope;
  bool get isChecking => _checking;
  bool _checking = false;
  bool get unavailable => _unavailable;
  bool _unavailable = false;
  List<String> get allowedRoutes => _scope == null ? [] : routesFor(_scope!);

  void _invalidate() {
    _generation++;
    _scope = null;
    _route = '/login';
    _checking = false;
    clearProtectedCaches();
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final previous = _route;
    _invalidate();
    final generation = _generation;
    final session = auth.currentSession;
    if (session == null || _disposed || _signingOut) return;
    _checking = true;
    _unavailable = false;
    notifyListeners();
    try {
      final loaded = await auth.loadScope();
      if (_disposed ||
          generation != _generation ||
          auth.currentSession?.user.id != session.user.id) {
        return;
      }
      _scope = loaded;
      final candidate = previous == '/login' ? _intended : previous;
      _route = routesFor(loaded).contains(candidate) ? candidate : '/register';
    } catch (_) {
      if (!_disposed && generation == _generation) _unavailable = true;
    } finally {
      if (!_disposed && generation == _generation) {
        _checking = false;
        notifyListeners();
      }
    }
  }

  void go(String route) {
    _route = allowedRoutes.contains(route)
        ? route
        : (_scope == null ? '/login' : '/register');
    notifyListeners();
  }

  Future<void> signOut() async {
    _signingOut = true;
    _invalidate();
    try {
      await auth.signOut();
    } finally {
      _signingOut = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    clearProtectedCaches();
    super.dispose();
  }
}
