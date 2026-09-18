import 'dart:async';

import 'package:discipulado_ieadpe/data/error_mapper.dart';
import 'package:discipulado_ieadpe/data/firebase_auth_repository.dart';
import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthAdapter implements AuthAdapter {
  final StreamController<String?> _uids = StreamController<String?>.broadcast();
  final Map<String, StreamController<JsonMap?>> _profileControllers =
      <String, StreamController<JsonMap?>>{};
  final Map<String, JsonMap?> profiles = <String, JsonMap?>{};

  Object? signInError;
  Object? resetError;
  int signOutCalls = 0;

  @override
  Stream<String?> watchUid() => _uids.stream;

  @override
  Stream<JsonMap?> watchProfile(String uid) async* {
    yield profiles[uid];
    yield* _profileControllers
        .putIfAbsent(uid, () => StreamController<JsonMap?>.broadcast())
        .stream;
  }

  void emitUid(String? uid) => _uids.add(uid);

  @override
  Future<void> configureSessionPersistence() async {}

  @override
  Future<void> signInWithPassword(String email, String password) async {
    if (signInError != null) {
      throw signInError!;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (resetError != null) {
      throw resetError!;
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

JsonMap _profile({bool active = true}) => <String, Object?>{
  'accessRole': 'congregationStaff',
  'congregationId': 'c1',
  'active': active,
  'revision': 1,
  'updatedAt': '2026-01-01T00:00:00.000Z',
};

void main() {
  group('watchSession', () {
    test('resolves Firebase identity and an active access profile', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter();
      adapter.profiles['u1'] = _profile();
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );
      final List<AuthSession?> sessions = <AuthSession?>[];
      final List<Object> errors = <Object>[];
      final StreamSubscription<AuthSession?> subscription = repository
          .watchSession()
          .listen(sessions.add, onError: errors.add);
      addTearDown(subscription.cancel);

      adapter.emitUid('u1');
      await pumpEventQueue();

      expect(sessions, hasLength(1));
      expect(sessions.single?.uid, 'u1');
      expect(sessions.single?.profile.accessRole, AccessRole.congregationStaff);
      expect(errors, isEmpty);
    });

    test('reports Acesso não autorizado for an inactive profile', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter();
      adapter.profiles['u1'] = _profile(active: false);
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );
      final List<Object> errors = <Object>[];
      final StreamSubscription<AuthSession?> subscription = repository
          .watchSession()
          .listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);

      adapter.emitUid('u1');
      await pumpEventQueue();

      expect(errors, hasLength(1));
      final AppFailure failure = errors.single as AppFailure;
      expect(failure.code, AppFailureCode.forbidden);
      expect(failure.message, kAccessDeniedMessage);
    });

    test('reports Acesso não autorizado for a missing profile', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter();
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );
      final List<Object> errors = <Object>[];
      final StreamSubscription<AuthSession?> subscription = repository
          .watchSession()
          .listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);

      adapter.emitUid('u1');
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect((errors.single as AppFailure).message, kAccessDeniedMessage);
    });

    test('emits null after an explicit sign-out', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter();
      adapter.profiles['u1'] = _profile();
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );
      final List<AuthSession?> sessions = <AuthSession?>[];
      final StreamSubscription<AuthSession?> subscription = repository
          .watchSession()
          .listen(sessions.add);
      addTearDown(subscription.cancel);

      adapter.emitUid('u1');
      await pumpEventQueue();
      await repository.signOut();
      adapter.emitUid(null);
      await pumpEventQueue();

      expect(adapter.signOutCalls, 1);
      expect(sessions.last, isNull);
    });
  });

  group('signIn', () {
    test('translates a rejected credential to a generic AppFailure', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter()
        ..signInError = const AppFailure(
          code: AppFailureCode.unauthenticated,
          message: kInvalidCredentialsMessage,
        );
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );

      await expectLater(
        repository.signIn('ana@example.com', 'wrong'),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.message,
            'message',
            kInvalidCredentialsMessage,
          ),
        ),
      );
    });
  });

  group('requestPasswordReset', () {
    test('answers generically without revealing account existence', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter()
        ..resetError = const AppFailure(
          code: AppFailureCode.unauthenticated,
          message: kInvalidCredentialsMessage,
        );
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );

      await expectLater(
        repository.requestPasswordReset('missing@example.com'),
        completes,
      );
    });

    test('still surfaces non-credential failures', () async {
      final _FakeAuthAdapter adapter = _FakeAuthAdapter()
        ..resetError = TimeoutException('slow');
      final FirebaseAuthRepository repository = FirebaseAuthRepository(
        adapter: adapter,
      );

      await expectLater(
        repository.requestPasswordReset('ana@example.com'),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.unavailable,
          ),
        ),
      );
    });
  });
}
