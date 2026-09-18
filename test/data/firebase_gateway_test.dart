import 'dart:async';

import 'package:discipulado_ieadpe/data/error_mapper.dart';
import 'package:discipulado_ieadpe/data/firebase_gateway.dart';
import 'package:discipulado_ieadpe/data/query_codec.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements FirebaseTransport {
  final List<QueryPlan> plans = <QueryPlan>[];
  final List<String> operations = <String>[];
  final List<JsonMap> payloads = <JsonMap>[];
  JsonMap? document;
  TransportPage page = const TransportPage(items: <JsonMap>[]);
  JsonMap callResponse = const <String, Object?>{};
  Object? queryError;
  Object? documentError;
  Object? callError;

  @override
  Future<JsonMap?> getDocument(String path) async {
    if (documentError != null) {
      throw documentError!;
    }
    return document;
  }

  @override
  Future<TransportPage> runQuery(QueryPlan plan) async {
    plans.add(plan);
    if (queryError != null) {
      throw queryError!;
    }
    return page;
  }

  @override
  Future<JsonMap> callFunction(String operation, JsonMap payload) async {
    operations.add(operation);
    payloads.add(payload);
    if (callError != null) {
      throw callError!;
    }
    return callResponse;
  }
}

void main() {
  group('query', () {
    test(
      'runs a validated scoped read and returns the transport page',
      () async {
        final _FakeTransport transport = _FakeTransport()
          ..page = const TransportPage(
            items: <JsonMap>[
              <String, Object?>{'id': 's1', 'normalizedName': 'ana'},
            ],
          );
        final FirebaseGateway gateway = FirebaseGateway(transport: transport);

        final PageResult result = await gateway.query(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
          ),
        );

        expect(result.items.single['id'], 's1');
        expect(transport.plans.single.collection, 'congregations/c1/students');
      },
    );

    test('passes a stable cursor back into the next request', () async {
      final _FakeTransport transport = _FakeTransport()
        ..page = const TransportPage(
          items: <JsonMap>[
            <String, Object?>{'id': 's1', 'normalizedName': 'ana'},
          ],
        );
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);

      final PageResult first = await gateway.query(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          limit: 1,
        ),
      );
      expect(first.nextCursor, isNotNull);

      final PageResult second = await gateway.query(
        QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          limit: 1,
          cursor: first.nextCursor,
        ),
      );
      expect(second.items, hasLength(1));
      expect(transport.plans.last.cursor, first.nextCursor);
    });

    test('rejects cursor reuse across scopes', () async {
      final _FakeTransport transport = _FakeTransport()
        ..page = const TransportPage(
          items: <JsonMap>[
            <String, Object?>{'id': 's1', 'normalizedName': 'ana'},
          ],
        );
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);
      final PageResult first = await gateway.query(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          limit: 1,
        ),
      );

      await expectLater(
        gateway.query(
          QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c2',
            limit: 1,
            cursor: first.nextCursor,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test(
      'routes complex student-by-class reads to the callable handler',
      () async {
        final _FakeTransport transport = _FakeTransport()
          ..callResponse = const <String, Object?>{
            'items': <Object?>[
              <String, Object?>{'id': 's1'},
            ],
          };
        final FirebaseGateway gateway = FirebaseGateway(transport: transport);

        final PageResult result = await gateway.query(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            equalityFilters: <String, Object?>{'classId': 'cl1'},
          ),
        );

        expect(transport.operations.single, 'listClassStudents');
        expect(transport.payloads.single['classId'], 'cl1');
        expect(result.items.single['id'], 's1');
      },
    );

    test('translates a transport network error to AppFailure', () async {
      final _FakeTransport transport = _FakeTransport()
        ..queryError = TimeoutException('slow');
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);

      await expectLater(
        gateway.query(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
          ),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.message,
            'message',
            kNetworkFailureMessage,
          ),
        ),
      );
    });
  });

  group('get', () {
    test('reads an explicit record path', () async {
      final _FakeTransport transport = _FakeTransport()
        ..document = const <String, Object?>{'id': 's1'};
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);

      final JsonMap? record = await gateway.get(
        const RecordLocator(
          resource: QueryResource.students,
          id: 's1',
          congregationId: 'c1',
        ),
      );

      expect(record?['id'], 's1');
    });

    test(
      'rejects internal collections before touching the transport',
      () async {
        final _FakeTransport transport = _FakeTransport();
        final FirebaseGateway gateway = FirebaseGateway(transport: transport);

        await expectLater(
          gateway.get(
            const RecordLocator(
              resource: QueryResource.students,
              id: 'users',
              congregationId: 'c1',
            ),
          ),
          throwsA(
            isA<AppFailure>().having(
              (AppFailure f) => f.code,
              'code',
              AppFailureCode.validation,
            ),
          ),
        );
        expect(transport.plans, isEmpty);
      },
    );
  });

  group('mutation identity', () {
    test('retains a generated UUID and requestId for explicit retry', () {
      final _FakeTransport transport = _FakeTransport();
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);

      final MutationRequest first = gateway.newMutation(
        operation: 'saveStudent',
        recordId: 's1',
      );
      final MutationRequest second = gateway.newMutation(
        operation: 'saveStudent',
        recordId: 's2',
      );

      expect(first.recordId, 's1');
      expect(first.requestId, isNotEmpty);
      expect(first.requestId, isNot(second.requestId));
      expect(first.toPayload()['id'], 's1');
      expect(first.toPayload()['requestId'], first.requestId);
    });

    test('times out without retrying and preserves retry identity', () async {
      final _FakeTransport transport = _FakeTransport()
        ..callError = TimeoutException('slow');
      final FirebaseGateway gateway = FirebaseGateway(transport: transport);
      final MutationRequest request = gateway.newMutation(
        operation: 'saveStudent',
        recordId: 's1',
      );

      await expectLater(
        gateway.submitMutation(request),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.unavailable,
          ),
        ),
      );
      expect(transport.operations, hasLength(1));
      expect(transport.operations.single, 'saveStudent');

      transport.callError = null;
      await gateway.submitMutation(request);
      expect(transport.operations, hasLength(2));
      expect(transport.payloads.last['requestId'], request.requestId);
      expect(transport.payloads.last['id'], 's1');
    });
  });

  group('RequestGuard / QueryRunner', () {
    test('discards a stale query response from a superseded request', () async {
      final _ControlledGateway gateway = _ControlledGateway();
      final QueryRunner runner = QueryRunner(gateway);
      const QueryRequest request = QueryRequest(
        resource: QueryResource.students,
        congregationId: 'c1',
      );

      final Future<PageResult?> first = runner.run(request);
      final Future<PageResult?> second = runner.run(request);
      gateway.completers[0].complete(
        const PageResult(
          items: <JsonMap>[
            <String, Object?>{'id': 'old'},
          ],
        ),
      );
      gateway.completers[1].complete(
        const PageResult(
          items: <JsonMap>[
            <String, Object?>{'id': 'new'},
          ],
        ),
      );

      expect(await first, isNull);
      final PageResult? current = await second;
      expect(current?.items.single['id'], 'new');
    });
  });

  test('codec default page size is exposed for repositories', () {
    expect(defaultPageSize, 50);
    expect(maxPageSize, 100);
  });
}

class _ControlledGateway implements BackendGateway {
  final List<Completer<PageResult>> completers = <Completer<PageResult>>[];

  @override
  Future<PageResult> query(QueryRequest request) {
    final Completer<PageResult> completer = Completer<PageResult>();
    completers.add(completer);
    return completer.future;
  }

  @override
  Future<JsonMap?> get(RecordLocator locator) async => null;

  @override
  Future<JsonMap> invoke(String operation, JsonMap payload) async =>
      const <String, Object?>{};
}
