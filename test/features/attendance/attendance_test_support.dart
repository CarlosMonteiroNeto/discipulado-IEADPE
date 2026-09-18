import 'package:discipulado_ieadpe/features/attendance/attendance_controller.dart';

import '../classes/class_test_support.dart';

export '../classes/class_test_support.dart';

AttendanceController attendanceController(
  FakeAcademicGateway gateway, {
  DateTime Function()? nowUtc,
  String congregationId = 'c1',
  String classId = 'cls1',
  String sessionId = 'ses1',
}) => AttendanceController(
  repository: newRepository(gateway),
  congregationId: congregationId,
  classId: classId,
  sessionId: sessionId,
  nowUtc: nowUtc,
);
