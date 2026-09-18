import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/validation.dart';
import 'package:discipulado_ieadpe/features/classes/academic_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';

export 'package:discipulado_ieadpe/features/classes/academic_repository.dart';

/// Records every call so tests can prove which resource was requested and
/// whether a mutation was sent. [onInvokeAsync] allows a test to hold a
/// mutation open and prove that a duplicate submission is prevented.
class FakeAcademicGateway implements BackendGateway {
  final List<QueryRequest> queries = <QueryRequest>[];
  final List<RecordLocator> gets = <RecordLocator>[];
  final List<({String operation, JsonMap payload})> invocations =
      <({String operation, JsonMap payload})>[];

  PageResult Function(QueryRequest request)? onQuery;
  JsonMap? Function(RecordLocator locator)? onGet;
  JsonMap Function(String operation, JsonMap payload)? onInvoke;
  Future<JsonMap> Function(String operation, JsonMap payload)? onInvokeAsync;

  @override
  Future<PageResult> query(QueryRequest request) async {
    queries.add(request);
    return onQuery?.call(request) ?? const PageResult(items: <JsonMap>[]);
  }

  @override
  Future<JsonMap?> get(RecordLocator locator) async {
    gets.add(locator);
    return onGet?.call(locator);
  }

  @override
  Future<JsonMap> invoke(String operation, JsonMap payload) async {
    invocations.add((operation: operation, payload: payload));
    final Future<JsonMap> Function(String, JsonMap)? asyncHandler =
        onInvokeAsync;
    if (asyncHandler != null) {
      return asyncHandler(operation, payload);
    }
    return onInvoke?.call(operation, payload) ??
        const <String, Object?>{'id': 'generated', 'revision': 1};
  }
}

AccessProfile staffProfile({String congregationId = 'c1'}) => AccessProfile(
  accessRole: AccessRole.congregationStaff,
  congregationId: congregationId,
  active: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 1, 1),
);

AccessProfile supervisorProfile() => AccessProfile(
  accessRole: AccessRole.supervisor,
  congregationId: null,
  active: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 1, 1),
);

JsonMap classJson({
  required String id,
  required String name,
  String congregationId = 'c1',
  String status = 'active',
  String startDate = '2026-01-01',
  String? endDate,
  String? teacherContactId,
  int revision = 1,
}) => <String, Object?>{
  'id': id,
  'revision': revision,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
  'congregationId': congregationId,
  'name': name,
  'normalizedName': normalizeName(name),
  'teacherContactId': teacherContactId,
  'startDate': startDate,
  'endDate': endDate,
  'status': status,
};

JsonMap enrollmentJson({
  required String id,
  required String studentId,
  required String classId,
  String congregationId = 'c1',
  String startDate = '2026-01-10',
  String? endDate,
  String status = 'active',
  int revision = 1,
}) => <String, Object?>{
  'id': id,
  'revision': revision,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
  'studentId': studentId,
  'classId': classId,
  'congregationId': congregationId,
  'startDate': startDate,
  'endDate': endDate,
  'status': status,
};

JsonMap sessionJson({
  required String id,
  required String classId,
  String congregationId = 'c1',
  String date = '2026-01-10',
  String? topic,
  String status = 'open',
  bool rosterFrozen = false,
  int revision = 1,
}) => <String, Object?>{
  'id': id,
  'revision': revision,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
  'classId': classId,
  'congregationId': congregationId,
  'date': date,
  'topic': topic,
  'status': status,
  'rosterFrozen': rosterFrozen,
};

JsonMap contactJson({
  required String id,
  required String name,
  String scope = 'congregation',
  String? roleCode,
  String congregationId = 'c1',
  bool archived = false,
  int revision = 1,
}) => <String, Object?>{
  'id': id,
  'revision': revision,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
  'name': name,
  'normalizedName': normalizeName(name),
  'scope': scope,
  'congregationId': scope == 'supervision' ? null : congregationId,
  'roleCode': roleCode,
  'phoneE164': null,
  'birthDate': null,
  'archived': archived,
};

JsonMap studentOptionJson({required String id, required String name}) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'normalizedName': normalizeName(name),
      'congregationId': 'c1',
      'archived': false,
      'revision': 1,
    };

JsonMap rosterEntryJson({
  required String enrollmentId,
  required String studentId,
  required String studentName,
  String status = 'unmarked',
}) => <String, Object?>{
  'enrollmentId': enrollmentId,
  'studentId': studentId,
  'studentName': studentName,
  'status': status,
};

/// The authoritative `getSessionAttendance` response shape: session + roster
/// only. The owning class lifecycle status is never a wire field here; it is
/// resolved through the repository class read (S08).
JsonMap attendanceViewJson({
  required JsonMap session,
  required List<JsonMap> roster,
}) => <String, Object?>{'session': session, 'roster': roster};

JsonMap congregationJson({
  required String id,
  required String name,
  bool active = true,
}) => <String, Object?>{
  'id': id,
  'revision': 1,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
  'name': name,
  'normalizedName': normalizeName(name),
  'active': active,
};

/// Pumps a class/attendance widget inside a scrollable scaffold so grouped
/// forms do not overflow the test viewport.
Future<void> pumpAcademicPage(
  WidgetTester tester,
  Widget page, {
  double width = 1280,
  double height = 2000,
  double textScale = 1.0,
}) => pumpApp(
  tester,
  page,
  width: width,
  height: height,
  textScale: textScale,
  wrap: (Widget child) => Scaffold(body: SingleChildScrollView(child: child)),
);

/// Scrolls [key] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

AcademicRepository newRepository(
  FakeAcademicGateway gateway, {
  String requestId = 'req-1',
  String recordId = 'new-id',
}) => AcademicRepository(
  gateway: gateway,
  requestIdFactory: () => requestId,
  recordIdFactory: () => recordId,
);
