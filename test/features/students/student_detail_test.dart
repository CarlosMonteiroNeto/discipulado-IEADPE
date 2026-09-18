import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/students/student_detail_page.dart';
import 'package:discipulado_ieadpe/features/students/student_repository.dart';
import 'package:discipulado_ieadpe/ui/async_content.dart';
import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'student_test_support.dart';

void main() {
  late FakeStudentGateway gateway;
  late StudentRepository repository;

  setUp(() {
    gateway = FakeStudentGateway();
    repository = StudentRepository(gateway: gateway);
  });

  testWidgets(
    'renders enrollment counts, percentage and zero-denominator copy',
    (WidgetTester tester) async {
      gateway.onGet = (RecordLocator locator) {
        if (locator.resource == QueryResource.students) {
          return studentJson(id: 's1', name: 'Ana Souza');
        }
        if (locator.resource == QueryResource.classes) {
          return classJson(id: 'cls1', name: 'Adultos');
        }
        return null;
      };
      gateway.onQuery = (QueryRequest request) =>
          request.resource == QueryResource.enrollments
          ? PageResult(
              items: <JsonMap>[
                enrollmentJson(id: 'e1', studentId: 's1', classId: 'cls1'),
                enrollmentJson(
                  id: 'e2',
                  studentId: 's1',
                  classId: 'cls1',
                  status: 'completed',
                  endDate: '2026-03-01',
                ),
              ],
            )
          : const PageResult(items: <JsonMap>[]);
      gateway.onInvoke = (String operation, JsonMap payload) {
        if (operation != 'getEnrollmentProgress') {
          return const <String, Object?>{'id': 's1', 'revision': 1};
        }
        return payload['enrollmentId'] == 'e1'
            ? progressJson(
                enrollmentId: 'e1',
                present: 3,
                absent: 1,
                excused: 2,
                percentage: 75,
              )
            : progressJson(enrollmentId: 'e2', percentage: null);
      };

      await pumpApp(
        tester,
        StudentDetailPage(
          repository: repository,
          studentId: 's1',
          congregationId: 'c1',
        ),
      );

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Sem aulas contabilizadas'), findsOneWidget);
      expect(
        find.text('3 presenças · 1 falta · 2 justificadas'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'archive denial explains the active enrollment must close first',
    (WidgetTester tester) async {
      gateway.onGet = (RecordLocator locator) =>
          locator.resource == QueryResource.students
          ? studentJson(id: 's1', name: 'Ana Souza')
          : null;
      gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);
      gateway.onInvoke = (String operation, JsonMap payload) {
        if (operation == 'setStudentArchived') {
          throw const AppFailure(
            code: AppFailureCode.conflict,
            message: 'Student has an active enrollment and cannot be archived.',
          );
        }
        return const <String, Object?>{'id': 's1', 'revision': 2};
      };

      await pumpApp(
        tester,
        StudentDetailPage(
          repository: repository,
          studentId: 's1',
          congregationId: 'c1',
        ),
      );

      await tester.tap(find.byKey(StudentDetailPage.archiveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);
      await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('matrícula'), findsWidgets);
      expect(find.textContaining('Encerre'), findsWidgets);
    },
  );

  testWidgets('an out-of-scope student shows a scoped not-found view', (
    WidgetTester tester,
  ) async {
    gateway.onGet = (_) => null;
    gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

    await pumpApp(
      tester,
      StudentDetailPage(
        repository: repository,
        studentId: 'missing',
        congregationId: 'c1',
      ),
    );

    expect(find.byKey(AsyncContent.notFoundKey), findsOneWidget);
  });
}
