import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attendance_test_support.dart';

JsonMap attendanceView({String sessionStatus = 'open'}) => attendanceViewJson(
  session: sessionJson(
    id: 'ses1',
    classId: 'cls1',
    date: '2026-01-10',
    status: sessionStatus,
  ),
  roster: <JsonMap>[
    rosterEntryJson(
      enrollmentId: 'e1',
      studentId: 's1',
      studentName: 'Ana Souza',
      status: 'unmarked',
    ),
  ],
);

void main() {
  test('an unresolved class read fails safe toward read-only', () async {
    // The authoritative class read resolves to null (record missing).
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    gateway.onInvoke = (_, _) => attendanceView();
    gateway.onGet = (_) => null;
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isReadOnly, isTrue);
    expect(await controller.save(finalize: false), isFalse);
  });

  test('a failed class read fails safe toward read-only', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    gateway.onInvoke = (_, _) => attendanceView();
    gateway.onGet = (_) => throw const AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Indisponível.',
    );
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isReadOnly, isTrue);
  });

  test(
    'reloadAfterConflict refreshes a class that moved to completed',
    () async {
      String classStatus = 'active';
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (String operation, JsonMap _) {
          if (operation == 'getSessionAttendance') {
            return attendanceView();
          }
          if (operation == 'saveAttendance') {
            throw const AppFailure(
              code: AppFailureCode.conflict,
              message: 'A chamada foi alterada por outra pessoa.',
            );
          }
          throw StateError('Unexpected operation: $operation');
        };
      gateway.onGet = (_) =>
          classJson(id: 'cls1', name: 'Discipulado 2026', status: classStatus);
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.isReadOnly, isFalse);

      controller.mark('e1', AttendanceStatus.present);
      expect(await controller.save(finalize: false), isFalse);
      expect(controller.hasConflict, isTrue);

      classStatus = 'completed';
      await controller.reloadAfterConflict();

      expect(controller.isReadOnly, isTrue);
      // The unsaved local choice stays visible for comparison.
      expect(controller.statusOf('e1'), AttendanceStatus.present);
    },
  );

  test('reloadAfterConflict keeps an active-class session editable', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) {
        if (operation == 'getSessionAttendance') {
          return attendanceView();
        }
        if (operation == 'saveAttendance') {
          throw const AppFailure(
            code: AppFailureCode.conflict,
            message: 'A chamada foi alterada por outra pessoa.',
          );
        }
        throw StateError('Unexpected operation: $operation');
      };
    stubOwningClass(gateway, status: 'active');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    controller.mark('e1', AttendanceStatus.present);
    await controller.save(finalize: false);
    await controller.reloadAfterConflict();

    expect(controller.isReadOnly, isFalse);
  });
}
