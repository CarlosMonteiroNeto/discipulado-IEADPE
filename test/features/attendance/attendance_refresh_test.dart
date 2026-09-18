import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'attendance_test_support.dart';

void main() {
  test(
    'a successful finalize refreshes authoritative status and revision',
    () async {
      bool finalized = false;
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onInvoke = (String operation, JsonMap _) {
          if (operation == 'getSessionAttendance') {
            return attendanceViewJson(
              session: sessionJson(
                id: 'ses1',
                classId: 'cls1',
                date: '2026-01-10',
                status: finalized ? 'finalized' : 'open',
                rosterFrozen: finalized,
                revision: finalized ? 2 : 1,
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
            finalized = true;
            return const <String, Object?>{'id': 'ses1', 'revision': 2};
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
      expect(controller.session?.status, SessionStatus.open);

      final bool saved = await controller.save(finalize: true);

      expect(saved, isTrue);
      expect(controller.session?.status, SessionStatus.finalized);
      expect(controller.expectedRevision, 2);
      // The authoritative session/roster was re-read after the confirmed write.
      expect(
        gateway.invocations.where(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'getSessionAttendance',
        ),
        hasLength(2),
      );
    },
  );

  testWidgets('the header shows Finalizada after a successful finalize', (
    WidgetTester tester,
  ) async {
    bool finalized = false;
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) {
        if (operation == 'getSessionAttendance') {
          return attendanceViewJson(
            session: sessionJson(
              id: 'ses1',
              classId: 'cls1',
              date: '2026-01-10',
              status: finalized ? 'finalized' : 'open',
              rosterFrozen: finalized,
              revision: finalized ? 2 : 1,
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
          finalized = true;
          return const <String, Object?>{'id': 'ses1', 'revision': 2};
        }
        throw StateError('Unexpected operation: $operation');
      };
    stubOwningClass(gateway, status: 'active');
    final AttendanceController controller = attendanceController(
      gateway,
      nowUtc: () => DateTime.utc(2026, 1, 10, 12),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, AttendancePage(controller: controller), height: 2000);
    expect(find.text('Aberta'), findsOneWidget);

    await tester.tap(find.byKey(AttendancePage.finalizeKey));
    await tester.pumpAndSettle();

    expect(find.text('Finalizada'), findsOneWidget);
  });

  test('cancelSession sends the revision confirmed by the last save', () async {
    int revision = 1;
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (String operation, JsonMap _) {
        if (operation == 'getSessionAttendance') {
          return attendanceViewJson(
            session: sessionJson(
              id: 'ses1',
              classId: 'cls1',
              date: '2026-01-11',
              revision: revision,
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
        }
        if (operation == 'saveAttendance') {
          revision = 4;
          return const <String, Object?>{'id': 'ses1', 'revision': 4};
        }
        if (operation == 'cancelSession') {
          return const <String, Object?>{'id': 'ses1', 'revision': 5};
        }
        throw StateError('Unexpected operation: $operation');
      };
    stubOwningClass(gateway, status: 'active');
    final AttendanceController controller = attendanceController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    await controller.save(finalize: false);
    await controller.cancelSession();

    final JsonMap payload = gateway.invocations
        .lastWhere(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'cancelSession',
        )
        .payload;
    expect(payload['expectedRevision'], 4);
  });
}
