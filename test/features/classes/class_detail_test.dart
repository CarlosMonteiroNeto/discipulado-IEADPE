import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:discipulado_ieadpe/features/classes/class_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'class_test_support.dart';

void main() {
  testWidgets('renders teacher, roster and sessions and opens a session', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onQuery = (QueryRequest request) {
        switch (request.resource) {
          case QueryResource.enrollments:
            return PageResult(
              items: <JsonMap>[
                enrollmentJson(id: 'e1', studentId: 's1', classId: 'cls1'),
              ],
            );
          case QueryResource.sessions:
            return PageResult(
              items: <JsonMap>[
                sessionJson(id: 'ses1', classId: 'cls1', topic: 'Aula 1'),
              ],
            );
          case QueryResource.contacts:
            return PageResult(
              items: <JsonMap>[
                contactJson(id: 't1', name: 'Professor A', roleCode: 'teacher'),
              ],
            );
          case QueryResource.students:
            return PageResult(
              items: <JsonMap>[studentOptionJson(id: 's1', name: 'Ana Souza')],
            );
          default:
            return const PageResult(items: <JsonMap>[]);
        }
      }
      ..onGet = (_) => classJson(
        id: 'cls1',
        name: 'Discipulado 2026',
        teacherContactId: 't1',
        startDate: '2026-01-01',
      );
    String? openedSession;
    String? openedClass;

    await pumpApp(
      tester,
      ClassDetailPage(
        repository: newRepository(gateway),
        classId: 'cls1',
        congregationId: 'c1',
        onOpenSession: (_, Session session) {
          openedSession = session.id;
          openedClass = session.classId;
        },
      ),
    );

    expect(find.text('Discipulado 2026'), findsOneWidget);
    expect(find.text('Professor A'), findsWidgets);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Aula 1'), findsOneWidget);

    await tester.tap(find.byKey(ClassDetailPage.openSessionKey('ses1')));
    await tester.pumpAndSettle();

    expect(openedSession, 'ses1');
    expect(openedClass, 'cls1');
  });
}
