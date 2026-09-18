import 'dart:async';

import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AuthSession?> _session =
      StreamController<AuthSession?>.broadcast();
  String? signedInEmail;
  String? signedInPassword;
  String? resetEmail;
  bool signedOut = false;

  @override
  Stream<AuthSession?> watchSession() => _session.stream;

  @override
  Future<void> signIn(String email, String password) async {
    signedInEmail = email;
    signedInPassword = password;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    await _session.close();
  }
}

class _FakeBackendGateway implements BackendGateway {
  QueryRequest? lastQuery;
  RecordLocator? lastLocator;

  @override
  Future<JsonMap> invoke(String operation, JsonMap payload) async {
    return <String, Object?>{'operation': operation, 'echo': payload};
  }

  @override
  Future<PageResult> query(QueryRequest request) async {
    lastQuery = request;
    return const PageResult(items: <JsonMap>[], nextCursor: null);
  }

  @override
  Future<JsonMap?> get(RecordLocator locator) async {
    lastLocator = locator;
    return null;
  }
}

void main() {
  group('QueryResource allowlist', () {
    test('exposes exactly the generic S11 query resources', () {
      expect(QueryResource.values.map((resource) => resource.wire).toSet(), {
        'directory',
        'congregations',
        'contacts',
        'students',
        'classes',
        'enrollments',
        'sessions',
      });
    });

    test('internal collections cannot be addressed through a query', () {
      for (final forbidden in const [
        'users',
        'supervisionRoleSlots',
        'roleSlots',
        'operations',
        'receipts',
        'roster',
        'attendance',
      ]) {
        expect(
          () => QueryResource.fromWire(forbidden),
          throwsA(isA<DataFormatException>()),
          reason: '$forbidden must not be a generic query resource',
        );
      }
    });
  });

  group('transport value objects', () {
    test('QueryRequest keeps scope, filters, prefix, limit and cursor', () {
      const request = QueryRequest(
        resource: QueryResource.students,
        congregationId: 'cong-1',
        equalityFilters: {'archived': false},
        namePrefix: 'jo',
        limit: 50,
        cursor: 'opaque-cursor',
      );

      expect(request.resource, QueryResource.students);
      expect(request.congregationId, 'cong-1');
      expect(request.equalityFilters, {'archived': false});
      expect(request.namePrefix, 'jo');
      expect(request.limit, 50);
      expect(request.cursor, 'opaque-cursor');
    });

    test('QueryRequest defaults to no scope, prefix, limit or cursor', () {
      const request = QueryRequest(resource: QueryResource.directory);
      expect(request.congregationId, isNull);
      expect(request.equalityFilters, isNull);
      expect(request.namePrefix, isNull);
      expect(request.limit, isNull);
      expect(request.cursor, isNull);
    });

    test('RecordLocator carries resource, id and parent scope', () {
      const locator = RecordLocator(
        resource: QueryResource.sessions,
        id: 'se-1',
        congregationId: 'cong-1',
        parentClassId: 'cl-1',
        parentSessionId: null,
      );

      expect(locator.resource, QueryResource.sessions);
      expect(locator.id, 'se-1');
      expect(locator.congregationId, 'cong-1');
      expect(locator.parentClassId, 'cl-1');
      expect(locator.parentSessionId, isNull);
    });

    test('PageResult exposes items and an opaque next cursor', () {
      const page = PageResult(
        items: <JsonMap>[
          {'id': 'st-1'},
        ],
        nextCursor: 'next',
      );
      expect(page.items, hasLength(1));
      expect(page.items.first['id'], 'st-1');
      expect(page.nextCursor, 'next');
    });
  });

  group('AppFailure', () {
    test('exposes the seven S11 failure codes', () {
      expect(AppFailureCode.values.map((code) => code.wire).toSet(), {
        'validation',
        'unauthenticated',
        'forbidden',
        'notFound',
        'conflict',
        'unavailable',
        'unknown',
      });
    });

    test('carries field errors and a safe user message', () {
      const failure = AppFailure(
        code: AppFailureCode.validation,
        fieldErrors: {'phoneE164': 'Número inválido'},
        message: 'Dados inválidos',
      );

      expect(failure.code, AppFailureCode.validation);
      expect(failure.fieldErrors, {'phoneE164': 'Número inválido'});
      expect(failure.message, 'Dados inválidos');
    });
  });

  group('port contracts', () {
    test(
      'AuthRepository supports sign in, reset, sign out and a session stream',
      () async {
        final repository = _FakeAuthRepository();
        final events = <AuthSession?>[];
        final subscription = repository.watchSession().listen(events.add);
        addTearDown(subscription.cancel);

        await repository.signIn('staff@example.test', 'secret');
        expect(repository.signedInEmail, 'staff@example.test');
        expect(repository.signedInPassword, 'secret');

        await repository.requestPasswordReset('staff@example.test');
        expect(repository.resetEmail, 'staff@example.test');

        await repository.signOut();
        expect(repository.signedOut, isTrue);
      },
    );

    test(
      'BackendGateway invokes, queries and locates typed requests',
      () async {
        final gateway = _FakeBackendGateway();

        final result = await gateway.invoke('saveStudent', {'id': 'st-1'});
        expect(result['operation'], 'saveStudent');
        expect(result['echo'], {'id': 'st-1'});

        final page = await gateway.query(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'cong-1',
          ),
        );
        expect(page.items, isEmpty);
        expect(gateway.lastQuery!.resource, QueryResource.students);

        final record = await gateway.get(
          const RecordLocator(resource: QueryResource.directory, id: 'ct-1'),
        );
        expect(record, isNull);
        expect(gateway.lastLocator!.id, 'ct-1');
      },
    );
  });
}
