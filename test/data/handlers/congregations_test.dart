import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/congregations.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

const String _congregationUuid = '1f2e4321-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _secondUuid = '2a4c6e82-abcd-46ae-9f0e-6c7f1a2b3c4d';

HandlerContext contextWith(
  DirectStore store, {
  String uid = 'u1',
  DateTime? now,
}) =>
    HandlerContext(
      store: store,
      uid: uid,
      now: now ?? DateTime.utc(2026, 9, 21, 12),
    );

void main() {
  group('congregations handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;
    late HandlerContext context;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/$_congregationUuid': <String, Object?>{
          'id': _congregationUuid,
          'name': 'Abra',
          'normalizedName': 'abra',
          'active': true,
          'revision': 1,
          'createdAt': '2025-01-01T12:00:00.000Z',
          'updatedAt': '2025-01-01T12:00:00.000Z',
          'updatedBy': 'u0',
        },
      });
      handlers = congregationsHandlers();
      context = contextWith(store);
    });

    test('exposes saveCongregation and setCongregationArchived', () {
      expect(
        handlers.keys,
        containsAll(<String>['saveCongregation', 'setCongregationArchived']),
      );
    });

    test('create writes the record and returns revision 1', () async {
      final JsonMap result = await handlers['saveCongregation']!(
        context,
        <String, Object?>{
          'id': _secondUuid,
          'name': 'Betânia',
          'requestId': 'req-1',
        },
      );

      expect(result, <String, Object?>{
        'id': _secondUuid,
        'revision': 1,
      });
      final JsonMap? record = await store.read('congregations/$_secondUuid');
      expect(record?['name'], 'Betânia');
      expect(record?['normalizedName'], 'betania');
      expect(record?['active'], true);
      expect(record?['revision'], 1);
      expect(record?['createdAt'], record?['updatedAt']);
      expect(record?['updatedBy'], 'u1');
    });

    test('rename preserves identity and createdAt and bumps revision', () async {
      final JsonMap result = await handlers['saveCongregation']!(
        context,
        <String, Object?>{
          'id': _congregationUuid,
          'name': 'Abra de Ipojuca',
          'expectedRevision': 1,
          'requestId': 'req-2',
        },
      );

      expect(result['revision'], 2);
      final JsonMap? record = await store.read('congregations/$_congregationUuid');
      expect(record?['id'], _congregationUuid);
      expect(record?['name'], 'Abra de Ipojuca');
      expect(record?['normalizedName'], 'abra de ipojuca');
      expect(record?['createdAt'], '2025-01-01T12:00:00.000Z');
      expect(record?['revision'], 2);
    });

    test('rejects a duplicate normalized name as an advisory conflict', () async {
      await expectLater(
        handlers['saveCongregation']!(
          context,
          <String, Object?>{
            'id': _secondUuid,
            'name': 'ABRA',
            'requestId': 'req-3',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
      final JsonMap? record = await store.read('congregations/$_secondUuid');
      expect(record, isNull);
    });

    test('rejects a blank or short display name', () async {
      await expectLater(
        handlers['saveCongregation']!(
          context,
          <String, Object?>{
            'id': _secondUuid,
            'name': ' ',
            'requestId': 'req-4',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a non-UUID id on create', () async {
      await expectLater(
        handlers['saveCongregation']!(
          context,
          <String, Object?>{
            'id': 'not-a-uuid',
            'name': 'Salém',
            'requestId': 'req-5',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a stale expected revision on rename', () async {
      await expectLater(
        handlers['saveCongregation']!(
          context,
          <String, Object?>{
            'id': _congregationUuid,
            'name': 'Camboas',
            'expectedRevision': 7,
            'requestId': 'req-6',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects renaming an archived congregation', () async {
      await handlers['setCongregationArchived']!(
        context,
        <String, Object?>{
          'id': _congregationUuid,
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-7',
        },
      );
      await expectLater(
        handlers['saveCongregation']!(
          context,
          <String, Object?>{
            'id': _congregationUuid,
            'name': 'Abra Nova',
            'expectedRevision': 2,
            'requestId': 'req-8',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('setCongregationArchived flips active and bumps the revision',
        () async {
      final JsonMap result = await handlers['setCongregationArchived']!(
        context,
        <String, Object?>{
          'id': _congregationUuid,
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-9',
        },
      );

      expect(result, <String, Object?>{
        'id': _congregationUuid,
        'revision': 2,
      });
      final JsonMap? record = await store.read('congregations/$_congregationUuid');
      expect(record?['active'], false);
      expect(record?['revision'], 2);
    });

    test('setCongregationArchived is a no-op in the target state', () async {
      final JsonMap result = await handlers['setCongregationArchived']!(
        context,
        <String, Object?>{
          'id': _congregationUuid,
          'archived': false,
          'expectedRevision': 1,
          'requestId': 'req-10',
        },
      );

      expect(result['revision'], 1);
      final JsonMap? record = await store.read('congregations/$_congregationUuid');
      expect(record?['active'], true);
      expect(record?['revision'], 1);
    });

    test('setCongregationArchived missing record is a notFound failure',
        () async {
      await expectLater(
        handlers['setCongregationArchived']!(
          context,
          <String, Object?>{
            'id': _secondUuid,
            'archived': true,
            'expectedRevision': 1,
            'requestId': 'req-11',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.notFound,
          ),
        ),
      );
    });

    test('writes no reference-counter or uniqueness-index documents',
        () async {
      await handlers['saveCongregation']!(
        context,
        <String, Object?>{
          'id': _secondUuid,
          'name': 'Betânia',
          'requestId': 'req-12',
        },
      );
      await handlers['setCongregationArchived']!(
        context,
        <String, Object?>{
          'id': _congregationUuid,
          'archived': true,
          'expectedRevision': 1,
          'requestId': 'req-13',
        },
      );

      expect(await store.read('congregations/$_congregationUuid/internal/references'),
          isNull);
      final List<JsonMap> nameIndexes = await store.query(
        const StoreQuery(collection: 'congregationNames', group: true),
      );
      expect(nameIndexes, isEmpty);
    });
  });
}