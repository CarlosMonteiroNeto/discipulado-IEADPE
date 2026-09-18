import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';

/// Records every call so tests can prove which resource was requested and
/// whether a mutation was sent.
class FakeStudentGateway implements BackendGateway {
  final List<QueryRequest> queries = <QueryRequest>[];
  final List<RecordLocator> gets = <RecordLocator>[];
  final List<({String operation, JsonMap payload})> invocations =
      <({String operation, JsonMap payload})>[];

  PageResult Function(QueryRequest request)? onQuery;
  JsonMap? Function(RecordLocator locator)? onGet;
  JsonMap Function(String operation, JsonMap payload)? onInvoke;

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

JsonMap studentJson({
  required String id,
  required String name,
  String congregationId = 'c1',
  int revision = 1,
  bool archived = false,
  String? phoneE164,
  String? birthDate,
  Map<String, Object?>? address,
  String? education,
  String? maritalStatus,
  bool? newConvert,
  bool? waterBaptized,
  bool? wantsBaptism,
}) => <String, Object?>{
  'id': id,
  'revision': revision,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
  'name': name,
  'normalizedName': normalizeName(name),
  'congregationId': congregationId,
  'phoneE164': phoneE164,
  'birthDate': birthDate,
  'address': address,
  'education': education,
  'maritalStatus': maritalStatus,
  'newConvert': newConvert,
  'waterBaptized': waterBaptized,
  'wantsBaptism': wantsBaptism,
  'archived': archived,
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

JsonMap progressJson({
  required String enrollmentId,
  String studentId = 's1',
  String classId = 'cls1',
  int present = 0,
  int absent = 0,
  int excused = 0,
  int? percentage,
}) => <String, Object?>{
  'enrollmentId': enrollmentId,
  'studentId': studentId,
  'classId': classId,
  'present': present,
  'absent': absent,
  'excused': excused,
  'total': present + absent,
  'percentage': percentage,
};

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

/// Pumps a student form/page inside a scrollable scaffold so grouped forms do
/// not overflow the test viewport.
Future<void> pumpStudentPage(WidgetTester tester, Widget page) => pumpApp(
  tester,
  page,
  height: 2000,
  wrap: (Widget child) => Scaffold(body: SingleChildScrollView(child: child)),
);

/// Scrolls [key] into view, then taps it. A grouped form is taller than the
/// test viewport, so a bare tap on a footer action would miss the widget.
Future<void> tapVisible(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
