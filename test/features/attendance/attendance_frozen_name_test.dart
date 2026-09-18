import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'attendance_test_support.dart';

void main() {
  testWidgets(
    'renders the frozen name from the authoritative attendance record',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FakeAcademicGateway gateway = FakeAcademicGateway();
      gateway.onQuery = (QueryRequest request) =>
          const PageResult(items: <JsonMap>[]);
      gateway.onInvoke = (String operation, JsonMap _) =>
          operation == 'getSessionAttendance'
          ? attendanceViewJson(
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
                  studentName: 'Ana Antiga',
                  status: 'present',
                ),
              ],
              classStatus: 'completed',
            )
          : const <String, Object?>{};
      final AttendanceController controller = attendanceController(gateway);
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        AttendancePage(controller: controller),
        height: 2000,
      );

      // The rendered label comes from the authoritative attendance roster, not
      // from a student lookup or a name round-trip through another fixture.
      expect(controller.roster.single.studentName, 'Ana Antiga');
      expect(find.text('Ana Antiga'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Ana Antiga')), findsOneWidget);
      expect(
        gateway.queries.where(
          (QueryRequest request) => request.resource == QueryResource.students,
        ),
        isEmpty,
      );
      semantics.dispose();
    },
  );
}
