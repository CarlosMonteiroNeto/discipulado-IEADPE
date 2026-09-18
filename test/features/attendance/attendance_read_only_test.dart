import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_page.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_row.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'attendance_test_support.dart';

JsonMap attendanceView({
  required String sessionStatus,
  String? classStatus,
  String entryStatus = 'present',
}) => attendanceViewJson(
  session: sessionJson(
    id: 'ses1',
    classId: 'cls1',
    status: sessionStatus,
    rosterFrozen: true,
  ),
  roster: <JsonMap>[
    rosterEntryJson(
      enrollmentId: 'e1',
      studentId: 's1',
      studentName: 'Ana Souza',
      status: entryStatus,
    ),
  ],
  classStatus: classStatus,
);

void main() {
  test('a canceled session is read-only and refuses mutations', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) =>
          attendanceView(sessionStatus: 'canceled', classStatus: 'active');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isReadOnly, isTrue);
    expect(await controller.save(finalize: false), isFalse);
    controller.mark('e1', AttendanceStatus.absent);
    expect(controller.statusOf('e1'), AttendanceStatus.present);
    expect(
      gateway.invocations.where(
        (({String operation, JsonMap payload}) call) =>
            call.operation == 'saveAttendance',
      ),
      isEmpty,
    );
  });

  for (final String classStatus in <String>['completed', 'archived']) {
    test('a session in a $classStatus class is read-only', () async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (_, _) => attendanceView(
          sessionStatus: 'finalized',
          classStatus: classStatus,
        );
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isReadOnly, isTrue);
      expect(await controller.save(finalize: false), isFalse);
      expect(await controller.cancelSession(), isFalse);
    });
  }

  testWidgets('a canceled session disables controls but keeps the roster', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) =>
          attendanceView(sessionStatus: 'canceled', classStatus: 'active');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Presente'), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byKey(AttendancePage.saveKey)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<AppButton>(find.byKey(AttendancePage.finalizeKey))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<AppButton>(find.byKey(AttendancePage.markAllKey)).onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(AttendanceRow.choiceKey('e1', AttendanceStatus.absent)),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(controller.statusOf('e1'), AttendanceStatus.present);
  });

  testWidgets('a session in a completed class disables controls', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) =>
          attendanceView(sessionStatus: 'finalized', classStatus: 'completed');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    expect(
      tester.widget<AppButton>(find.byKey(AttendancePage.saveKey)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<AppButton>(find.byKey(AttendancePage.finalizeKey))
          .onPressed,
      isNull,
    );
  });

  testWidgets('an active open session stays fully editable', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => attendanceView(
        sessionStatus: 'open',
        classStatus: 'active',
        entryStatus: 'unmarked',
      );
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);

    expect(controller.isReadOnly, isFalse);
    expect(
      tester.widget<AppButton>(find.byKey(AttendancePage.saveKey)).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<AppButton>(find.byKey(AttendancePage.finalizeKey))
          .onPressed,
      isNotNull,
    );

    await tester.tap(
      find.byKey(AttendanceRow.choiceKey('e1', AttendanceStatus.absent)),
    );
    await tester.pumpAndSettle();
    expect(controller.statusOf('e1'), AttendanceStatus.absent);
  });
}
