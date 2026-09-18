/// Authentication view state, session cleanup and pt-BR form feedback (S04).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/error_mapper.dart';
import '../../domain/access.dart';
import '../../domain/ports.dart';

enum AuthStatus { loading, signedOut, authorized, accessDenied, failure }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.failure,
    this.submitting = false,
    this.resetRequested = false,
  });

  final AuthStatus status;
  final AuthSession? session;
  final AppFailure? failure;
  final bool submitting;
  final bool resetRequested;

  bool get isAuthorized => status == AuthStatus.authorized;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    AppFailure? failure,
    bool clearSession = false,
    bool clearFailure = false,
    bool? submitting,
    bool? resetRequested,
  }) => AuthState(
    status: status ?? this.status,
    session: clearSession ? null : (session ?? this.session),
    failure: clearFailure ? null : (failure ?? this.failure),
    submitting: submitting ?? this.submitting,
    resetRequested: resetRequested ?? this.resetRequested,
  );
}

/// A controller/resource whose in-memory data must die with the session.
abstract interface class SessionScoped {
  void clearSessionData();
}

abstract final class AuthValidation {
  static String? email(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Informe o e-mail.';
    }
    final bool malformed =
        !trimmed.contains('@') ||
        trimmed.startsWith('@') ||
        trimmed.endsWith('@') ||
        trimmed.contains(' ');
    return malformed ? 'Informe um e-mail válido.' : null;
  }

  static String? password(String? value) {
    final String raw = value ?? '';
    if (raw.isEmpty) {
      return 'Informe a senha.';
    }
    return raw.length < 6 ? 'A senha deve ter ao menos 6 caracteres.' : null;
  }

  static Map<String, String> signInFieldErrors(String email, String password) {
    final Map<String, String> errors = <String, String>{};
    final String? emailError = AuthValidation.email(email);
    if (emailError != null) {
      errors['email'] = emailError;
    }
    final String? passwordError = AuthValidation.password(password);
    if (passwordError != null) {
      errors['password'] = passwordError;
    }
    return errors;
  }
}

const List<String> _allowedReturnPrefixes = <String>[
  '/visao-geral',
  '/equipe',
  '/alunos',
  '/turmas',
  '/congregacoes',
];

/// Allows only safe, internal return destinations (S10).
String? sanitizeReturnTo(String? candidate) {
  if (candidate == null) {
    return null;
  }
  final String value = candidate.trim();
  if (value.isEmpty || !value.startsWith('/') || value.startsWith('//')) {
    return null;
  }
  if (value.contains(r'\') || value.contains('://')) {
    return null;
  }
  final String path = value.split('?').first;
  final bool allowed = _allowedReturnPrefixes.any(
    (String prefix) => path == prefix || path.startsWith('$prefix/'),
  );
  return allowed ? value : null;
}

class AuthController extends ChangeNotifier {
  AuthController({
    required this.repository,
    this.errorMapper = const ErrorMapper(),
    this.onSessionCleared,
  });

  final AuthRepository repository;
  final ErrorMapper errorMapper;
  final VoidCallback? onSessionCleared;

  AuthState _state = const AuthState(status: AuthStatus.loading);
  StreamSubscription<AuthSession?>? _subscription;
  final List<SessionScoped> _scoped = <SessionScoped>[];
  bool _disposed = false;

  AuthState get state => _state;

  void start() {
    _subscription ??= repository.watchSession().listen(
      _onSession,
      onError: _onError,
    );
  }

  void _emit(AuthState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void _onSession(AuthSession? session) {
    final AuthSession? previous = _state.session;
    if (session == null) {
      _clearSession();
      _emit(
        _state.copyWith(
          status: AuthStatus.signedOut,
          clearSession: true,
          clearFailure: true,
          submitting: false,
        ),
      );
      return;
    }
    if (!session.profile.active) {
      _onError(_accessDenied());
      return;
    }
    final bool scopeChanged =
        previous != null &&
        (previous.uid != session.uid ||
            previous.profile.congregationId != session.profile.congregationId ||
            previous.profile.accessRole != session.profile.accessRole);
    if (scopeChanged) {
      _clearSession();
    }
    _emit(
      _state.copyWith(
        status: AuthStatus.authorized,
        session: session,
        clearFailure: true,
        submitting: false,
      ),
    );
  }

  void _onError(Object error) {
    final AppFailure failure = errorMapper.map(error);
    if (failure.code == AppFailureCode.forbidden) {
      _clearSession();
      _emit(
        _state.copyWith(
          status: AuthStatus.accessDenied,
          clearSession: true,
          failure: failure,
          submitting: false,
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        status: AuthStatus.failure,
        failure: failure,
        submitting: false,
      ),
    );
  }

  AppFailure _accessDenied() => const AppFailure(
    code: AppFailureCode.forbidden,
    message: kAccessDeniedMessage,
  );

  /// Drops every in-memory session artifact before the next frame renders.
  void _clearSession() {
    for (final SessionScoped scoped in List<SessionScoped>.of(_scoped)) {
      scoped.clearSessionData();
    }
    onSessionCleared?.call();
  }

  Future<void> signIn(String email, String password) async {
    final Map<String, String> errors = AuthValidation.signInFieldErrors(
      email,
      password,
    );
    if (errors.isNotEmpty) {
      _emit(
        _state.copyWith(
          status: AuthStatus.failure,
          failure: AppFailure(
            code: AppFailureCode.validation,
            fieldErrors: errors,
            message: kValidationMessage,
          ),
          submitting: false,
        ),
      );
      return;
    }
    _emit(_state.copyWith(submitting: true, clearFailure: true));
    try {
      await repository.signIn(email.trim(), password);
    } catch (error) {
      _emit(
        _state.copyWith(
          status: AuthStatus.failure,
          failure: errorMapper.map(error),
          submitting: false,
        ),
      );
    }
  }

  Future<void> requestPasswordReset(String email) async {
    final String? error = AuthValidation.email(email);
    if (error != null) {
      _emit(
        _state.copyWith(
          status: AuthStatus.failure,
          failure: AppFailure(
            code: AppFailureCode.validation,
            fieldErrors: <String, String>{'email': error},
            message: kValidationMessage,
          ),
          submitting: false,
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        submitting: true,
        clearFailure: true,
        resetRequested: false,
      ),
    );
    try {
      await repository.requestPasswordReset(email.trim());
      _emit(_state.copyWith(submitting: false, resetRequested: true));
    } catch (failure) {
      _emit(
        _state.copyWith(
          status: AuthStatus.failure,
          failure: errorMapper.map(failure),
          submitting: false,
        ),
      );
    }
  }

  Future<void> signOut() async {
    _emit(_state.copyWith(submitting: true));
    try {
      await repository.signOut();
    } catch (_) {
      // Local session state is cleared regardless of the transport outcome.
    } finally {
      _clearSession();
      _emit(
        _state.copyWith(
          status: AuthStatus.signedOut,
          clearSession: true,
          clearFailure: true,
          submitting: false,
        ),
      );
    }
  }

  void attach(SessionScoped resource) {
    if (!_scoped.contains(resource)) {
      _scoped.add(resource);
    }
  }

  void detach(SessionScoped resource) {
    _scoped.remove(resource);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _scoped.clear();
    super.dispose();
  }
}
