import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/class_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'class_test_support.dart';

Future<void> pumpDetail(
  WidgetTester tester,
  FakeAcademicGateway gateway, {
  required String classStatus,
  required List<JsonMap> sessions,
}) async {
  gateway.onGet = (_) => classJson(
    id: 'cls1',
    name: 'Discipulado 2026',
    status: classStatus,
    teacherContactId: 't1',
  );
  gateway.onQuery = (QueryRequest request) {
    switch (request.resource) {
      case QueryResource.sessions:
        return PageResult(items: sessions);
      case QueryResource.contacts:
        return PageResult(
          items: <JsonMap>[
            contactJson(id: 't1', name: 'Professor A', roleCode: 'teacher'),
          ],
        );
      default:
        return const PageResult(items: <JsonMap>[]);
    }
  };
  await pumpApp(
    tester,
    ClassDetailPage(
      repository: newRepository(gateway),
      classId: 'cls1',
      congregationId: 'c1',
    ),
    height: 2000,
  );
}

void main() {
  testWidgets('an active class hides Abrir only for canceled sessions', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    await pumpDetail(
      tester,
      gateway,
      classStatus: 'active',
      sessions: <JsonMap>[
        sessionJson(id: 'ses-cancel', classId: 'cls1', status: 'canceled'),
        sessionJson(id: 'ses-open', classId: 'cls1', status: 'open'),
      ],
    );

    expect(
      find.byKey(ClassDetailPage.openSessionKey('ses-cancel')),
      findsNothing,
    );
    expect(
      find.byKey(ClassDetailPage.openSessionKey('ses-open')),
      findsOneWidget,
    );
  });

  testWidgets('a completed class hides Abrir for every session', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    await pumpDetail(
      tester,
      gateway,
      classStatus: 'completed',
      sessions: <JsonMap>[
        sessionJson(
          id: 'ses-final',
          classId: 'cls1',
          status: 'finalized',
          rosterFrozen: true,
        ),
      ],
    );

    expect(
      find.byKey(ClassDetailPage.openSessionKey('ses-final')),
      findsNothing,
    );
    expect(find.text('Chamada'), findsWidgets);
  });
}
