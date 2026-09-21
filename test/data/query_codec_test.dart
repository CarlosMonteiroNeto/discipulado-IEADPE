import 'package:discipulado_ieadpe/data/query_codec.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const QueryCodec codec = QueryCodec();

  group('plan', () {
    test('resolves a scoped collection with stable ordering and page size', () {
      final QueryPlan plan = codec.plan(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          equalityFilters: <String, Object?>{'archived': false},
        ),
      );
      expect(plan.collection, 'congregations/c1/students');
      expect(plan.orderBy, 'normalizedName');
      expect(plan.limit, defaultPageSize);
      expect(plan.filters.single.field, 'archived');
      expect(plan.callableOperation, isNull);
    });

    test('rejects a scoped resource without a congregation', () {
      expect(
        () => codec.plan(const QueryRequest(resource: QueryResource.students)),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('enforces the explicit page bounds', () {
      expect(
        () => codec.plan(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            limit: 0,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => codec.plan(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            limit: maxPageSize + 1,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('rejects an unsupported filter combination', () {
      expect(
        () => codec.plan(
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c1',
            equalityFilters: <String, Object?>{'unknownField': 'x'},
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => codec.plan(
          const QueryRequest(
            resource: QueryResource.sessions,
            congregationId: 'c1',
            namePrefix: 'jo',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('keeps student-by-class reads on the plain query codec', () {
      final QueryPlan plan = codec.plan(
        const QueryRequest(
          resource: QueryResource.students,
          congregationId: 'c1',
          equalityFilters: <String, Object?>{'classId': 'cl1'},
        ),
      );
      expect(plan.collection, 'congregations/c1/students');
      expect(plan.callableOperation, isNull);
      expect(plan.filters.single.field, 'classId');
    });
  });

  group('cursors', () {
    const QueryRequest studentsC1 = QueryRequest(
      resource: QueryResource.students,
      congregationId: 'c1',
      equalityFilters: <String, Object?>{'archived': false},
    );

    test('round-trips an opaque cursor bound to scope and filters', () {
      final QueryPlan plan = codec.plan(studentsC1);
      final String encoded = codec.encodeCursor(
        QueryCursor(
          resource: QueryResource.students,
          congregationId: 'c1',
          filterFingerprint: plan.filterFingerprint,
          orderBy: plan.orderBy,
          lastSortValue: 'ana',
          lastId: 's1',
        ),
      );
      expect(encoded.contains('congregations'), isFalse);
      final QueryCursor decoded = codec.decodeCursor(encoded);
      expect(decoded.congregationId, 'c1');
      expect(decoded.lastId, 's1');
      expect(decoded.lastSortValue, 'ana');
    });

    test('rejects cursor reuse after a scope change', () {
      final QueryPlan plan = codec.plan(studentsC1);
      final String encoded = codec.encodeCursor(
        QueryCursor(
          resource: QueryResource.students,
          congregationId: 'c1',
          filterFingerprint: plan.filterFingerprint,
          orderBy: plan.orderBy,
          lastSortValue: 'ana',
          lastId: 's1',
        ),
      );
      expect(
        () => codec.verifyCursor(
          encoded,
          const QueryRequest(
            resource: QueryResource.students,
            congregationId: 'c2',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('rejects a malformed cursor', () {
      expect(
        () => codec.decodeCursor('not-a-cursor'),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('record paths', () {
    test('builds an explicit scoped record path', () {
      expect(
        codec.recordPath(
          const RecordLocator(
            resource: QueryResource.students,
            id: 's1',
            congregationId: 'c1',
          ),
        ),
        'congregations/c1/students/s1',
      );
      expect(
        codec.recordPath(
          const RecordLocator(resource: QueryResource.directory, id: 'ct1'),
        ),
        'directory/ct1',
      );
    });

    test('rejects internal collections and path traversal', () {
      expect(() => QueryCodec.validateId('users'), throwsA(isA<AppFailure>()));
      expect(
        () => QueryCodec.validateId('operations'),
        throwsA(isA<AppFailure>()),
      );
      expect(() => QueryCodec.validateId('roster'), throwsA(isA<AppFailure>()));
      expect(() => QueryCodec.validateId('a/b'), throwsA(isA<AppFailure>()));
      expect(() => QueryCodec.validateId(''), throwsA(isA<AppFailure>()));
      expect(
        () => codec.recordPath(
          const RecordLocator(resource: QueryResource.students, id: 's1'),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
