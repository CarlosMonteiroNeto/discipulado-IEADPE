import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/firebase_gateway.dart';
import 'package:discipulado_ieadpe/data/firestore_direct_transport.dart';
import 'package:discipulado_ieadpe/data/query_codec.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingReadStore implements DirectStore {
  _ThrowingReadStore(this._inner);

  final DirectStore _inner;

  @override
  Future<JsonMap?> read(String path) {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'denied',
    );
  }

  @override
  Future<void> delete(String path) => _inner.delete(path);

  @override
  Future<List<JsonMap>> query(StoreQuery query) => _inner.query(query);

  @override
  Future<T> runTransaction<T>(Future<T> Function(DirectTransaction tx) work) =>
      _inner.runTransaction(work);

  @override
  Future<void> write(String path, JsonMap data) => _inner.write(path, data);
}

void main() {
  const QueryCodec codec = QueryCodec();

  DirectStore seededStore() => InMemoryDirectStore(<String, JsonMap>{
    'congregations/c1/students/s1': <String, Object?>{
      'id': 's1',
      'name': 'Ana',
      'normalizedName': 'ana',
      'archived': false,
    },
    'congregations/c1/students/s2': <String, Object?>{
      'id': 's2',
      'name': 'Bruno',
      'normalizedName': 'bruno',
      'archived': false,
    },
    'congregations/c1/students/s3': <String, Object?>{
      'id': 's3',
      'name': 'Bruna',
      'normalizedName': 'bruna',
      'archived': true,
    },
    'congregations/c1/students/s4': <String, Object?>{
      'id': 's4',
      'name': 'Carla',
      'normalizedName': 'carla',
      'archived': false,
    },
  });

  FirestoreDirectTransport transportWith({
    DirectStore? store,
    HandlerRegistry? registry,
    String uid = 'u1',
    DateTime? now,
  }) =>
      FirestoreDirectTransport(
        store: store ?? seededStore(),
        registry: registry ?? <String, DirectOperationHandler>{},
        uid: () => uid,
        now: () => now ?? DateTime.utc(2026, 9, 21, 12),
      );

  group('FirestoreDirectTransport contract', () {
    test('implements FirebaseTransport', () {
      expect(transportWith(), isA<FirebaseTransport>());
    });

    test('getDocument returns the decoded document map', () async {
      final JsonMap? document = await transportWith().getDocument(
        'congregations/c1/students/s1',
      );
      expect(document?['id'], 's1');
      expect(document?['normalizedName'], 'ana');
    });

    test('getDocument returns null for a missing document', () async {
      final JsonMap? document = await transportWith().getDocument(
        'congregations/c1/students/missing',
      );
      expect(document, isNull);
    });

    test('getDocument maps store failures through the ErrorMapper', () async {
      await expectLater(
        transportWith(store: _ThrowingReadStore(seededStore())).getDocument(
          'congregations/c1/students/s1',
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.forbidden,
          ),
        ),
      );
    });

    test('runQuery applies equality filters and ordering', () async {
      final TransportPage page = await transportWith().runQuery(
        codec.plan(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            equalityFilters: <String, Object?>{'archived': false},
          ),
        ),
      );
      expect(page.items.map((JsonMap item) => item['id']), <String>[
        's1',
        's2',
        's4',
      ]);
      expect(page.nextCursor, isNull);
    });

    test('runQuery caps items at plan.limit', () async {
      final TransportPage page = await transportWith().runQuery(
        codec.plan(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            limit: 2,
          ),
        ),
      );
      expect(page.items, hasLength(2));
    });

    test('runQuery applies the name-prefix range [prefix, prefix+f8ff)', () async {
      final TransportPage page = await transportWith().runQuery(
        codec.plan(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            namePrefix: 'bru',
          ),
        ),
      );
      expect(page.items.map((JsonMap item) => item['id']), <String>[
        's3',
        's2',
      ]);
    });

    test('runQuery starts after the encoded cursor bound', () async {
      final QueryPlan plan = codec.plan(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          limit: 2,
          cursor: 'encoded-after-ana',
        ),
      );
      final String cursor = codec.encodeCursor(
        QueryCursor(
          resource: QueryResource.students,
          congregationId: 'c1',
          filterFingerprint: plan.filterFingerprint,
          orderBy: plan.orderBy,
          lastSortValue: 'ana',
          lastId: 's1',
        ),
      );
      final TransportPage page = await transportWith().runQuery(
        QueryPlan(
          resource: QueryResource.students,
          collection: 'congregations/c1/students',
          filters: const <QueryFilter>[],
          orderBy: 'normalizedName',
          limit: 2,
          filterFingerprint: plan.filterFingerprint,
          congregationId: 'c1',
          cursor: cursor,
        ),
      );
      expect(page.items.map((JsonMap item) => item['id']), <String>[
        's3',
        's2',
      ]);
    });

    test('callFunction raises a deterministic AppFailure for a registry miss',
        () async {
      await expectLater(
        transportWith().callFunction('saveStudent', const <String, Object?>{}),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('callFunction invokes the handler with uid, clock and payload',
        () async {
      final DateTime fixed = DateTime.utc(2026, 9, 21, 12);
      JsonMap? receivedPayload;
      HandlerContext? receivedContext;
      final FirestoreDirectTransport transport = transportWith(
        registry: <String, DirectOperationHandler>{
          'saveStudent': (HandlerContext context, JsonMap payload) async {
            receivedContext = context;
            receivedPayload = payload;
            return const <String, Object?>{'id': 's1', 'revision': 1};
          },
        },
        now: fixed,
      );

      final JsonMap response = await transport.callFunction(
        'saveStudent',
        const <String, Object?>{'id': 's1'},
      );

      expect(response['revision'], 1);
      expect(receivedPayload?['id'], 's1');
      expect(receivedContext?.uid, 'u1');
      expect(receivedContext?.now, fixed);
    });

    test('callFunction propagates handler AppFailures unchanged', () async {
      final FirestoreDirectTransport transport = transportWith(
        registry: <String, DirectOperationHandler>{
          'saveStudent': (HandlerContext context, JsonMap payload) async {
            throw const AppFailure(
              code: AppFailureCode.conflict,
              message: 'stale',
            );
          },
        },
      );

      await expectLater(
        transport.callFunction('saveStudent', const <String, Object?>{}),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });
  });
}