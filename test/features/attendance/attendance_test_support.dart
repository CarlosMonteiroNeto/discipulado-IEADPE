import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';

import '../classes/class_test_support.dart';

export '../classes/class_test_support.dart';

AttendanceController attendanceController(
  FakeAcademicGateway gateway, {
  DateTime Function()? nowUtc,
  String congregationId = 'c1',
  String classId = 'cls1',
  String sessionId = 'ses1',
}) {
  // Editing tests must resolve the owning class through the authoritative
  // repository read; default to an active class unless a test stubs another
  // status (or an unresolved read) first.
  gateway.onGet ??= (RecordLocator locator) =>
      locator.resource == QueryResource.classes
      ? classJson(
          id: classId,
          name: 'Discipulado 2026',
          congregationId: congregationId,
          status: 'active',
        )
      : null;
  return AttendanceController(
    repository: newRepository(gateway),
    congregationId: congregationId,
    classId: classId,
    sessionId: sessionId,
    nowUtc: nowUtc,
  );
}

/// Drives the owning class lifecycle status through the authoritative class
/// read (`repository.getClass`), which is the only S08 source for the
/// completed/archived read-only gate. The attendance response never carries a
/// `classStatus` field.
void stubOwningClass(
  FakeAcademicGateway gateway, {
  required String status,
  String id = 'cls1',
  String congregationId = 'c1',
  String? teacherContactId,
}) {
  gateway.onGet = (RecordLocator locator) =>
      locator.resource == QueryResource.classes
      ? classJson(
          id: id,
          name: 'Discipulado 2026',
          congregationId: congregationId,
          status: status,
          teacherContactId: teacherContactId,
        )
      : null;
}
