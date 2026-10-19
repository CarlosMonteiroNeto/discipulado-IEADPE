import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import '../features/auth/auth_repository.dart';
import 'browser_route_history.dart';

const _knownRoutes = {
  '/register',
  '/home',
  '/converts',
  '/admin',
  '/ministry',
  '/ministry/team',
  '/ministry/students',
  '/ministry/students/register',
  '/ministry/classes',
  '/ministry/attendance',
  '/ministry/handoff',
};
bool isSafeRoute(String? value) => _knownRoutes.contains(value);
String safeRoute(String? value) => isSafeRoute(value) ? value! : '/register';
List<String> routesFor(AccessScope scope) => [
  '/register',
  if (scope.isGlobalManager || scope.congregationIds.isNotEmpty) ...[
    '/home',
    '/converts',
  ],
  if (scope.isGlobalManager) '/admin',
  if (scope.hasMinistryAccess) ...[
    '/ministry',
    '/ministry/team',
    if (scope.ministryCongregationIds.isNotEmpty ||
        scope.isMinistrySupervision) ...[
      '/ministry/students',
      '/ministry/students/register',
      '/ministry/classes',
      '/ministry/attendance',
      '/ministry/handoff',
    ],
  ],
];

/// Root listens to this guard and supplies real feature pages for allowed paths.
/// Every protected repository/cache must register its synchronous clear callback.
class SessionRouter extends ChangeNotifier with WidgetsBindingObserver {
  SessionRouter(
    this.auth, {
    required this.clearProtectedCaches,
    String? intendedRoute,
    BrowserRouteHistory? browserHistory,
  }) {
    _browserHistory = browserHistory ?? createBrowserRouteHistory();
    _intended = safeRoute(intendedRoute ?? _browserHistory.currentPath);
    _browserHistory.listen(_browserPathChanged);
    WidgetsBinding.instance.addObserver(this);
    _subscription = auth.watchSession().listen(
      (_) {
        unawaited(revalidate());
      },
      onError: (Object error, StackTrace stack) {
        _invalidate();
      },
    );
    unawaited(refresh());
  }
  final AuthGateway auth;
  final VoidCallback clearProtectedCaches;
  late final BrowserRouteHistory _browserHistory;
  late final String _intended;
  String? _lastAuthorized;
  String? _identity;
  Future<void>? _validation;
  int _refreshSequence = 0;
  int refreshRevision = 0;
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

  /// Permission failures and grant edits always destroy the previous owner.
  Future<void> refresh() => _startValidation(invalidate: true);

  /// Ordinary resume retains same-identity owners while the root hides them.
  Future<void> revalidate() => _startValidation(invalidate: false);

  Future<void> _startValidation({required bool invalidate}) {
    final future = _validate(invalidate: invalidate);
    _validation = future;
    return future;
  }

  /// Chooser results wait for the newest lifecycle check before publication.
  Future<void> ensureValidated() async {
    while (true) {
      final pending = _validation;
      await pending;
      if (identical(pending, _validation)) break;
    }
    if (_disposed ||
        _scope == null ||
        _checking ||
        _identity != auth.currentSession?.user.id) {
      throw const AuthException('Session unavailable');
    }
  }

  bool _sameScope(AccessScope a, AccessScope b) => a == b;

  Future<void> _validate({required bool invalidate}) async {
    final sequence = ++_refreshSequence;
    final session = auth.currentSession;
    final previousScope = _scope;
    if (invalidate || session == null || _identity != session.user.id) {
      _invalidate();
    }
    final generation = _generation;
    if (session == null || _disposed || _signingOut) return;
    _identity = session.user.id;
    _checking = true;
    _unavailable = false;
    notifyListeners();
    try {
      final loaded = await auth.loadScope();
      if (_disposed ||
          sequence != _refreshSequence ||
          generation != _generation ||
          auth.currentSession?.user.id != session.user.id) {
        return;
      }
      if (!invalidate &&
          previousScope != null &&
          !_sameScope(previousScope, loaded)) {
        _invalidate();
      }
      _scope = loaded;
      final candidate = _lastAuthorized ?? _intended;
      _route = routesFor(loaded).contains(candidate) ? candidate : '/register';
      _lastAuthorized = _route;
      _browserHistory.replace(_route);
      refreshRevision++;
    } catch (_) {
      if (!_disposed &&
          sequence == _refreshSequence &&
          generation == _generation) {
        _invalidate();
        _unavailable = true;
      }
    } finally {
      if (!_disposed && sequence == _refreshSequence) {
        _checking = false;
        notifyListeners();
      }
    }
  }

  void go(String route) {
    final next = allowedRoutes.contains(route)
        ? route
        : (_scope == null ? '/login' : '/register');
    if (next != _route && next != '/login') _browserHistory.push(next);
    _route = next;
    if (_route != '/login') _lastAuthorized = _route;
    notifyListeners();
  }

  void _browserPathChanged(String path) {
    final candidate = safeRoute(path);
    if (_scope != null && allowedRoutes.contains(candidate)) {
      _route = candidate;
      _lastAuthorized = candidate;
      notifyListeners();
      return;
    }
    _browserHistory.replace(_scope == null ? '/login' : '/register');
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
    if (state == AppLifecycleState.resumed) unawaited(revalidate());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _browserHistory.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    clearProtectedCaches();
    super.dispose();
  }
}
