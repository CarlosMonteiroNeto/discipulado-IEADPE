import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/features/students/student_form_page.dart';
import 'package:discipulado_ieadpe/features/students/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'student_test_support.dart';

/// Task 23: a lowercase/mixed-case UF must be normalized to uppercase in the
/// outgoing payload, while an empty UF stays null and an unknown code is still
/// rejected locally with `UF inválida.`.
void main() {
  late FakeStudentGateway gateway;
  late StudentRepository repository;

  setUp(() {
    gateway = FakeStudentGateway();
    repository = StudentRepository(
      gateway: gateway,
      recordIdFactory: () => 'new-student-id',
      requestIdFactory: () => 'request-1',
    );
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-student-id',
      'revision': 1,
    };
  });

  Future<void> pumpForm(WidgetTester tester) => pumpStudentPage(
    tester,
    StudentFormPage(
      repository: repository,
      config: const StudentFormConfig(congregationId: 'c1'),
    ),
  );

  testWidgets('submits a lowercase state code normalized to uppercase', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await tester.enterText(find.byKey(StudentFormPage.stateCodeFieldKey), 'pe');
    await tapVisible(tester, StudentFormPage.saveKey);

    final JsonMap address =
        gateway.invocations.single.payload['address']! as JsonMap;
    expect(address['stateCode'], 'PE');
  });

  testWidgets('submits an empty state code as null, never an empty string', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await tester.enterText(find.byKey(StudentFormPage.streetFieldKey), 'Rua A');
    await tapVisible(tester, StudentFormPage.saveKey);

    final JsonMap address =
        gateway.invocations.single.payload['address']! as JsonMap;
    expect(address['stateCode'], isNull);
  });

  testWidgets('an unknown state code still fails local validation', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await tester.enterText(find.byKey(StudentFormPage.stateCodeFieldKey), 'ZZ');
    await tapVisible(tester, StudentFormPage.saveKey);

    expect(gateway.invocations, isEmpty);
    expect(find.text('UF inválida.'), findsOneWidget);
  });
}
