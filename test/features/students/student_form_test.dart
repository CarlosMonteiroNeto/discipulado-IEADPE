import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/student.dart';
import 'package:discipulado_ieadpe/features/students/student_form_page.dart';
import 'package:discipulado_ieadpe/features/students/student_repository.dart';
import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'student_test_support.dart';

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
  });

  testWidgets('create requires only the name and leaves optional groups null', (
    WidgetTester tester,
  ) async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-student-id',
      'revision': 1,
    };
    StudentMutationResult? saved;

    await pumpStudentPage(
      tester,
      StudentFormPage(
        repository: repository,
        config: const StudentFormConfig(congregationId: 'c1'),
        onSaved: (StudentMutationResult result) => saved = result,
      ),
    );

    await tester.enterText(
      find.byKey(StudentFormPage.nameFieldKey),
      'Ana Souza',
    );
    await tapVisible(tester, StudentFormPage.saveKey);

    final JsonMap payload = gateway.invocations.single.payload;
    expect(payload['name'], 'Ana Souza');
    expect(payload['phone'], isNull);
    expect(payload['birthDate'], isNull);
    expect(payload['address'], isNull);
    expect(payload['education'], isNull);
    expect(payload['maritalStatus'], isNull);
    expect(payload['newConvert'], isNull);
    expect(payload['waterBaptized'], isNull);
    expect(payload['wantsBaptism'], isNull);
    expect(saved?.id, 'new-student-id');
  });

  testWidgets('accepts a real leap day and submits it as yyyy-MM-dd', (
    WidgetTester tester,
  ) async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-student-id',
      'revision': 1,
    };

    await pumpStudentPage(
      tester,
      StudentFormPage(
        repository: repository,
        config: const StudentFormConfig(congregationId: 'c1'),
      ),
    );

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await setFormText(
      tester,
      StudentFormPage.birthDateFieldKey,
      '29/02/2024',
    );
    await tapVisible(tester, StudentFormPage.saveKey);

    expect(gateway.invocations.single.payload['birthDate'], '2024-02-29');
  });

  testWidgets('rejects an impossible leap day and never submits', (
    WidgetTester tester,
  ) async {
    await pumpStudentPage(
      tester,
      StudentFormPage(
        repository: repository,
        config: const StudentFormConfig(congregationId: 'c1'),
      ),
    );

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await setFormText(
      tester,
      StudentFormPage.birthDateFieldKey,
      '29/02/2023',
    );
    await tapVisible(tester, StudentFormPage.saveKey);

    expect(gateway.invocations, isEmpty);
    expect(find.text(StudentFormPage.invalidDateMessage), findsOneWidget);
  });

  testWidgets('stale conflict keeps the values and reloads the revision', (
    WidgetTester tester,
  ) async {
    bool conflict = true;
    gateway.onInvoke = (String operation, JsonMap payload) {
      if (conflict) {
        throw const AppFailure(
          code: AppFailureCode.conflict,
          message: 'O registro foi alterado por outra pessoa.',
        );
      }
      return const <String, Object?>{'id': 's1', 'revision': 4};
    };
    gateway.onGet = (RecordLocator locator) =>
        studentJson(id: 's1', name: 'Ana Souza', revision: 4);
    StudentMutationResult? saved;

    await pumpStudentPage(
      tester,
      StudentFormPage(
        repository: repository,
        config: StudentFormConfig(
          congregationId: 'c1',
          studentId: 's1',
          expectedRevision: 3,
          initial: Student.fromJson(
            studentJson(id: 's1', name: 'Ana Souza', revision: 3),
          ),
        ),
        onSaved: (StudentMutationResult result) => saved = result,
      ),
    );

    await tester.enterText(
      find.byKey(StudentFormPage.nameFieldKey),
      'Ana Editada',
    );
    await tapVisible(tester, StudentFormPage.saveKey);

    expect(
      find.text('O registro foi alterado por outra pessoa.'),
      findsOneWidget,
    );
    expect(saved, isNull);
    expect(find.text('Ana Editada'), findsOneWidget);

    conflict = false;
    await tapVisible(tester, StudentFormPage.reloadKey);
    await tapVisible(tester, StudentFormPage.saveKey);

    expect(gateway.invocations.last.payload['expectedRevision'], 4);
    expect(saved?.revision, 4);
  });

  testWidgets('dirty form warns before leaving and cancel keeps editing', (
    WidgetTester tester,
  ) async {
    bool cancelled = false;

    await pumpStudentPage(
      tester,
      StudentFormPage(
        repository: repository,
        config: const StudentFormConfig(congregationId: 'c1'),
        onCancel: () => cancelled = true,
      ),
    );

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await tapVisible(tester, StudentFormPage.cancelKey);

    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);
    await tester.tap(find.byKey(ConfirmationDialog.cancelKey));
    await tester.pumpAndSettle();

    expect(cancelled, isFalse);
    expect(find.text('Ana'), findsOneWidget);

    await tapVisible(tester, StudentFormPage.cancelKey);
    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(gateway.invocations, isEmpty);
  });

  testWidgets('submits from the keyboard with Ctrl+Enter', (
    WidgetTester tester,
  ) async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-student-id',
      'revision': 1,
    };

    await pumpStudentPage(
      tester,
      StudentFormPage(
        repository: repository,
        config: const StudentFormConfig(congregationId: 'c1'),
      ),
    );

    await tester.enterText(find.byKey(StudentFormPage.nameFieldKey), 'Ana');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(gateway.invocations, hasLength(1));
    expect(gateway.invocations.single.operation, 'saveStudent');
  });
}
