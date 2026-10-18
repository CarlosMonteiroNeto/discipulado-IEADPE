import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models.dart';
import '../../configuration.dart';
import '../../routing/router.dart';

abstract interface class AuthGateway {
  Session? get currentSession;
  Stream<Session?> watchSession();
  Future<void> signInWithGoogle({String? intendedRoute});
  Future<AccessScope> loadScope();
  Future<void> signOut();
}

/// Exact callback endpoint; SDK performs the PKCE verifier/code exchange.
class AuthRedirectPolicy {
  AuthRedirectPolicy(this.callback) {
    final local = ['localhost', '127.0.0.1'].contains(callback.host);
    if (callback.host.isEmpty ||
        callback.userInfo.isNotEmpty ||
        callback.hasQuery ||
        callback.hasFragment ||
        callback.path != '/auth/callback' ||
        !(callback.scheme == 'https' ||
            (callback.scheme == 'http' && local) ||
            callback.toString() == androidCallback)) {
      throw ArgumentError('Invalid OAuth callback endpoint');
    }
  }
  static const androidCallback = 'ieadpe://login/auth/callback';
  final Uri callback;

  bool accepts(Uri uri) {
    if (uri.scheme != callback.scheme ||
        uri.host != callback.host ||
        uri.port != callback.port ||
        uri.userInfo.isNotEmpty ||
        uri.path != callback.path ||
        uri.hasFragment) {
      return false;
    }
    final params = uri.queryParametersAll;
    if (params.values.any((values) => values.length != 1) ||
        params.keys.any((key) => !{'code', 'next'}.contains(key))) {
      return false;
    }
    return (params['code']?.single.trim().isNotEmpty ?? false) &&
        (!params.containsKey('next') || isSafeRoute(params['next']!.single));
  }

  Uri redirectFor(String? intended) =>
      callback.replace(queryParameters: {'next': safeRoute(intended)});

  String intendedFrom(Uri uri) =>
      accepts(uri) ? safeRoute(uri.queryParameters['next']) : '/register';

  FlutterAuthClientOptions get options => FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    detectSessionInUriPredicate: accepts,
  );
}

class AuthRepository implements AuthGateway {
  AuthRepository(this.client, this.redirectPolicy);
  final SupabaseClient client;
  final AuthRedirectPolicy redirectPolicy;

  /// Task 19 calls once before constructing the application root.
  static Future<AuthRepository> initialize(
    Configuration configuration,
    AuthRedirectPolicy policy,
  ) async {
    if (!configuration.isValid) throw ArgumentError('Invalid configuration');
    final supabase = await Supabase.initialize(
      url: configuration.supabaseUrl,
      publishableKey: configuration.supabasePublishableKey,
      authOptions: policy.options,
    );
    return AuthRepository(supabase.client, policy);
  }

  @override
  Session? get currentSession => client.auth.currentSession;
  @override
  Stream<Session?> watchSession() =>
      client.auth.onAuthStateChange.map((event) => event.session);
  @override
  Future<void> signInWithGoogle({String? intendedRoute}) async {
    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      scopes: 'openid email profile',
      redirectTo: redirectPolicy.redirectFor(intendedRoute).toString(),
    );
    if (!launched) throw const AuthException('OAuth browser did not open');
  }

  @override
  Future<AccessScope> loadScope() async {
    if (currentSession == null) throw const AuthException('Session required');
    final value = await client.rpc('ieadpe_get_scope');
    if (value is! Map ||
        value['is_admin'] is! bool ||
        value['is_supervision'] is! bool ||
        value['congregation_ids'] is! List ||
        value['ministry_supervision'] is! bool ||
        value['ministry_congregation_ids'] is! List) {
      throw const FormatException('Invalid scope response');
    }
    final ids = _scopeIds(value['congregation_ids']);
    final ministryIds = _scopeIds(value['ministry_congregation_ids']);
    return AccessScope(
      isAdmin: value['is_admin'] as bool,
      isSupervision: value['is_supervision'] as bool,
      congregationIds: ids,
      isMinistrySupervision: value['ministry_supervision'] as bool,
      ministryCongregationIds: ministryIds,
    );
  }

  static List<String> _scopeIds(Object? raw) {
    final validId = RegExp(
      r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
    );
    if (raw is! List || raw.any((id) => id is! String || !validId.hasMatch(id))) {
      throw const FormatException('Invalid scope congregation IDs');
    }
    return raw.cast<String>();
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}
