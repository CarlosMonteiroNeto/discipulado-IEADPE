import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attendance_test_support.dart';

void main() {
  test(
    'a timed-out finalize retries finalize with the same requestId',
    () async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (String operation, JsonMap _) {
          if (operation == 'getSessionAttendance') {
            return attendanceViewJson(
              session: sessionJson(
                id: 'ses1',
                classId: 'cls1',
                date: '2026-01-10',
              ),
              roster: <JsonMap>[
                rosterEntryJson(
                  enrollmentId: 'e1',
                  studentId: 's1',
                  studentName: 'Ana Souza',
                  status: 'present',
                ),
              ],
            );
          }
          if (operation == 'saveAttendance') {
            throw const AppFailure(
              code: AppFailureCode.unavailable,
              message: 'Tempo esgotado.',
            );
          }
          throw StateError('Unexpected operation: $operation');
        };
      stubOwningClass(gateway, status: 'active');
      final AttendanceController controller = attendanceController(
        gateway,
        nowUtc: () => DateTime.utc(2026, 1, 10, 12),
      );
      addTearDown(controller.dispose);

      await controller.load();
      final bool first = await controller.save(finalize: true);

      expect(first, isFalse);
      expect(controller.lastFailedOperation, AttendanceOperation.finalize);
      final String? retained = controller.requestId;
      expect(retained, isNotNull);

      await controller.retry();

      final List<JsonMap> payloads = gateway.invocations
          .where(
            (({String operation, JsonMap payload}) call) =>
                call.operation == 'saveAttendance',
          )
          .map((({String operation, JsonMap payload}) call) => call.payload)
          .toList();
      expect(payloads, hasLength(2));
      expect(payloads.first['finalize'], isTrue);
      expect(payloads.last['finalize'], isTrue);
      expect(payloads.first['requestId'], retained);
      expect(payloads.last['requestId'], retained);
    },
  );

  test(
    'a failed cancel retries cancelSession with the same requestId',
    () async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (String operation, JsonMap _) {
          if (operation == 'getSessionAttendance') {
            return attendanceViewJson(
              session: sessionJson(
                id: 'ses1',
                classId: 'cls1',
                status: 'finalized',
                rosterFrozen: true,
              ),
              roster: <JsonMap>[
                rosterEntryJson(
                  enrollmentId: 'e1',
                  studentId: 's1',
                  studentName: 'Ana Souza',
                  status: 'present',
                ),
              ],
            );
          }
          if (operation == 'cancelSession') {
            throw const AppFailure(
              code: AppFailureCode.unavailable,
              message: 'Tempo esgotado.',
            );
          }
          throw StateError('Unexpected operation: $operation');
        };
      stubOwningClass(gateway, status: 'active');
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      final bool first = await controller.cancelSession();

      expect(first, isFalse);
      expect(controller.lastFailedOperation, AttendanceOperation.cancel);
      final String? retained = controller.requestId;
      expect(retained, isNotNull);

      await controller.retry();

      final List<({String operation, JsonMap payload})> cancels = gateway
          .invocations
          .where(
            (({String operation, JsonMap payload}) call) =>
                call.operation == 'cancelSession',
          )
          .toList();
      expect(cancels, hasLength(2));
      expect(cancels.first.payload['requestId'], retained);
      expect(cancels.last.payload['requestId'], retained);
      expect(
        gateway.invocations.where(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveAttendance',
        ),
        isEmpty,
      );
    },
  );
}
