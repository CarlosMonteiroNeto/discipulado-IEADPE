import 'package:discipulado_ieadpe/data/query_codec.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, Object?> _c1Filters = <String, Object?>{
  'scope': 'congregation',
  'roleCode': 'congregationAssistant',
  'congregationId': 'c1',
};

const Map<String, Object?> _c2Filters = <String, Object?>{
  'scope': 'congregation',
  'roleCode': 'congregationAssistant',
  'congregationId': 'c2',
};

void main() {
  const QueryCodec codec = QueryCodec();

  test('the directory plan accepts the congregationId equality filter', () {
    final QueryPlan plan = codec.plan(
      const QueryRequest(
        resource: QueryResource.directory,
        equalityFilters: _c1Filters,
      ),
    );

    expect(
      plan.filters.map((QueryFilter filter) => filter.field).toSet(),
      <String>{'scope', 'roleCode', 'congregationId'},
    );
    expect(
      plan.filters
          .firstWhere((QueryFilter filter) => filter.field == 'congregationId')
          .value,
      'c1',
    );
    expect(plan.filterFingerprint, contains('congregationId=c1;'));
  });

  test('a cursor minted for one congregation is rejected for another', () {
    final QueryPlan plan = codec.plan(
      const QueryRequest(
        resource: QueryResource.directory,
        equalityFilters: _c1Filters,
      ),
    );
    final String cursor = codec.encodeCursor(
      QueryCursor(
        resource: QueryResource.directory,
        filterFingerprint: plan.filterFingerprint,
        orderBy: plan.orderBy,
        lastId: 'ct1',
        lastSortValue: 'ana',
      ),
    );

    codec.verifyCursor(
      cursor,
      const QueryRequest(
        resource: QueryResource.directory,
        equalityFilters: _c1Filters,
      ),
    );
    expect(
      () => codec.verifyCursor(
        cursor,
        const QueryRequest(
          resource: QueryResource.directory,
          equalityFilters: _c2Filters,
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('supervision contacts resolve to supervisionContacts/{id}', () {
    expect(
      codec.recordPath(
        const RecordLocator(resource: QueryResource.contacts, id: 'ct1'),
      ),
      'supervisionContacts/ct1',
    );
    expect(
      codec.recordPath(
        const RecordLocator(
          resource: QueryResource.contacts,
          id: 'ct1',
          congregationId: 'c1',
        ),
      ),
      'congregations/c1/contacts/ct1',
    );
  });

  test('the supervision record path still rejects internal collections', () {
    expect(
      () => codec.recordPath(
        const RecordLocator(resource: QueryResource.contacts, id: 'users'),
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}
