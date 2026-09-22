import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_page.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_row.dart';
import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'attendance_test_support.dart';

JsonMap singleView({
  String studentName = 'Ana Souza',
  String status = 'unmarked',
  String date = '2026-01-10',
  int revision = 1,
}) => attendanceViewJson(
  session: sessionJson(
    id: 'ses1',
    classId: 'cls1',
    date: date,
    revision: revision,
  ),
  roster: <JsonMap>[
    rosterEntryJson(
      enrollmentId: 'e1',
      studentId: 's1',
      studentName: studentName,
      status: status,
    ),
  ],
);

void main() {
  test('attendance route is deep-linkable with class and session IDs', () {
    expect(
      AttendancePage.routePath('cls1', 'ses1'),
      '/turmas/cls1/chamadas/ses1',
    );
  });

  testWidgets('every row exposes the four statuses as text', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => singleView();
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    expect(find.text('Presente'), findsOneWidget);
    expect(find.text('Ausente'), findsOneWidget);
    expect(find.text('Justificado'), findsOneWidget);
    expect(find.text('Não marcado'), findsOneWidget);
  });

  testWidgets('marks a row by keyboard without a pointer', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => singleView();
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.statusOf('e1'), AttendanceStatus.present);
  });

  testWidgets('Marcar todos presentes then Salvar chamada submits present', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) =>
          operation == 'saveAttendance'
          ? const <String, Object?>{'id': 'ses1', 'revision': 2}
          : singleView();
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    await tester.tap(find.byKey(AttendancePage.markAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AttendancePage.saveKey));
    await tester.pumpAndSettle();

    final JsonMap payload = gateway.invocations
        .lastWhere(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        )
        .payload;
    expect(payload['attendance'], <String, Object?>{'e1': 'present'});
  });

  testWidgets(
    'finalization with an unmarked member explains and does not send',
    (WidgetTester tester) async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (_, _) => singleView();
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        AttendancePage(controller: controller),
        height: 2000,
      );

      await tester.tap(find.byKey(AttendancePage.finalizeKey));
      await tester.pumpAndSettle();

      expect(find.byKey(AttendancePage.validationKey), findsOneWidget);
      expect(
        gateway.invocations.where(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        ),
        isEmpty,
      );
    },
  );

  testWidgets('conflict offers reload with a visible comparison copy', (
    WidgetTester tester,
  ) async {
    bool conflict = true;
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) {
        if (operation == 'getSessionAttendance') {
          return singleView(status: conflict ? 'unmarked' : 'absent');
        }
        throw const AppFailure(
          code: AppFailureCode.conflict,
          message: 'A chamada foi alterada por outra pessoa.',
        );
      };
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    await tester.tap(
      find.byKey(AttendanceRow.choiceKey('e1', AttendanceStatus.present)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AttendancePage.saveKey));
    await tester.pumpAndSettle();

    expect(find.byKey(AttendancePage.conflictKey), findsOneWidget);

    conflict = false;
    await tester.tap(find.byKey(AttendancePage.reloadKey));
    await tester.pumpAndSettle();

    expect(find.byKey(AttendancePage.comparisonKey), findsOneWidget);
  });

  testWidgets('cancellation requires confirmation', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) => operation == 'cancelSession'
          ? const <String, Object?>{'id': 'ses1', 'revision': 2}
          : singleView();
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    await tester.tap(find.byKey(AttendancePage.cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.cancelKey));
    await tester.pumpAndSettle();

    expect(
      gateway.invocations.where(
        (({String operation, JsonMap payload}) call) =>
            call.operation == 'cancelSession',
      ),
      isEmpty,
    );

    await tester.tap(find.byKey(AttendancePage.cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(
      gateway.invocations.where(
        (({String operation, JsonMap payload}) call) =>
            call.operation == 'cancelSession',
      ),
      hasLength(1),
    );
  });

  testWidgets('the concluded checkbox toggles and submits its value', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) =>
          operation == 'saveAttendance'
          ? const <String, Object?>{'id': 'ses1', 'revision': 2}
          : singleView(status: 'present');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    expect(controller.lessonFinished, isFalse);

    await tester.tap(find.byKey(AttendancePage.concludedKey));
    await tester.pumpAndSettle();

    expect(controller.lessonFinished, isTrue);

    await tester.tap(find.byKey(AttendancePage.saveKey));
    await tester.pumpAndSettle();

    final JsonMap payload = gateway.invocations
        .lastWhere(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        )
        .payload;
    expect(payload['lessonFinished'], isTrue);
  });

  testWidgets('renders the frozen historical student name', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => singleView(studentName: 'Ana Antiga');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    expect(find.text('Ana Antiga'), findsOneWidget);
  });

  testWidgets('narrow viewport at 200% text does not overflow', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => singleView();
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      AttendancePage(controller: controller),
      width: 360,
      height: 800,
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(AttendancePage.saveKey), findsOneWidget);
  });
}
