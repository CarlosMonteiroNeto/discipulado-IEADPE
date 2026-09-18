import 'package:discipulado_ieadpe/domain/class_group.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/enrollment.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/enrollment_editor.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_test_support.dart';

List<Enrollment> enrollments(int count) => List<Enrollment>.generate(
  count,
  (int index) => Enrollment.fromJson(
    enrollmentJson(
      id: 'e$index',
      studentId: 's$index',
      classId: 'cls1',
      status: 'completed',
    ),
  ),
);

ClassGroup classGroup() =>
    ClassGroup.fromJson(classJson(id: 'cls1', name: 'Discipulado 2026'));

void main() {
  testWidgets('99 enrollment records still allow adding', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();

    await pumpAcademicPage(
      tester,
      EnrollmentEditor(
        repository: newRepository(gateway),
        congregationId: 'c1',
        classGroup: classGroup(),
        enrollments: enrollments(99),
        students: const <StudentOption>[
          StudentOption(id: 's1', name: 'Ana Souza'),
        ],
      ),
    );

    expect(find.byKey(EnrollmentEditor.capacityKey), findsNothing);
    final AppButton add = tester.widget<AppButton>(
      find.byKey(EnrollmentEditor.addKey),
    );
    expect(add.onPressed, isNotNull);
  });

  testWidgets('the 100-record cap blocks enrollment 101 with a message', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();

    await pumpAcademicPage(
      tester,
      EnrollmentEditor(
        repository: newRepository(gateway),
        congregationId: 'c1',
        classGroup: classGroup(),
        enrollments: enrollments(100),
        students: const <StudentOption>[
          StudentOption(id: 's1', name: 'Ana Souza'),
        ],
      ),
    );

    expect(find.text(EnrollmentEditor.capacityMessage), findsOneWidget);
    final AppButton add = tester.widget<AppButton>(
      find.byKey(EnrollmentEditor.addKey),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('active-enrollment conflict names the existing class', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => throw const AppFailure(
        code: AppFailureCode.conflict,
        message: 'Aluno já possui matrícula ativa.',
        fieldErrors: <String, String>{'existingClassName': 'Turma Alfa'},
      );

    await pumpAcademicPage(
      tester,
      EnrollmentEditor(
        repository: newRepository(gateway),
        congregationId: 'c1',
        classGroup: classGroup(),
        enrollments: const <Enrollment>[],
        students: const <StudentOption>[
          StudentOption(id: 's1', name: 'Ana Souza'),
        ],
      ),
    );

    await tester.tap(find.byKey(EnrollmentEditor.studentFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(EnrollmentEditor.startDateFieldKey),
      '10/01/2026',
    );
    await tapVisible(tester, EnrollmentEditor.addKey);

    expect(find.textContaining('Turma Alfa'), findsOneWidget);
    expect(gateway.invocations.single.operation, 'enrollStudent');
  });

  testWidgets('a new enrollment submits the explicit start date', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => const <String, Object?>{
        'id': 'new-id',
        'revision': 1,
      };

    await pumpAcademicPage(
      tester,
      EnrollmentEditor(
        repository: newRepository(gateway),
        congregationId: 'c1',
        classGroup: classGroup(),
        enrollments: const <Enrollment>[],
        students: const <StudentOption>[
          StudentOption(id: 's1', name: 'Ana Souza'),
        ],
      ),
    );

    await tester.tap(find.byKey(EnrollmentEditor.studentFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(EnrollmentEditor.startDateFieldKey),
      '10/01/2026',
    );
    await tapVisible(tester, EnrollmentEditor.addKey);

    final JsonMap payload = gateway.invocations.single.payload;
    expect(payload['classId'], 'cls1');
    expect(payload['studentId'], 's1');
    expect(payload['startDate'], '2026-01-10');
  });
}
