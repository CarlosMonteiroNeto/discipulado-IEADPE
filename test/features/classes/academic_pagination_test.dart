import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_test_support.dart';

void main() {
  test('listSessions follows nextCursor beyond one page', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onQuery = (QueryRequest request) {
        if (request.resource != QueryResource.sessions) {
          return const PageResult(items: <JsonMap>[]);
        }
        if (request.cursor == null) {
          return PageResult(
            items: List<JsonMap>.generate(
              100,
              (int index) => sessionJson(id: 's$index', classId: 'cls1'),
            ),
            nextCursor: 'cursor-2',
          );
        }
        return PageResult(
          items: <JsonMap>[sessionJson(id: 's100', classId: 'cls1')],
        );
      };

    final List<Session> sessions = await newRepository(gateway)
        .listSessions(congregationId: 'c1', classId: 'cls1');

    expect(sessions, hasLength(101));
    final List<QueryRequest> sessionQueries = gateway.queries
        .where(
          (QueryRequest request) => request.resource == QueryResource.sessions,
        )
        .toList();
    expect(sessionQueries, hasLength(2));
    expect(sessionQueries.first.cursor, isNull);
    expect(sessionQueries.last.cursor, 'cursor-2');
  });
}
