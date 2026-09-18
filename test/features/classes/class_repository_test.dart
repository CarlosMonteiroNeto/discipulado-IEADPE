import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/class_group.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/enrollment.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_test_support.dart';

void main() {
  late FakeAcademicGateway gateway;
  late AcademicRepository repository;

  setUp(() {
    gateway = FakeAcademicGateway();
    repository = newRepository(gateway);
  });

  test(
    'class list applies scope, status filter and normalized prefix',
    () async {
      gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

      await repository.listClasses(
        const ClassQuery(
          search: 'Discipulado',
          status: ClassStatus.active,
          congregationId: 'c1',
        ),
      );

      final QueryRequest request = gateway.queries.single;
      expect(request.resource, QueryResource.classes);
      expect(request.congregationId, 'c1');
      expect(request.equalityFilters?['status'], 'active');
      expect(request.namePrefix, 'Discipulado');
    },
  );

  test('class creation sends the stable ID, teacher and ISO dates', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-id',
      'revision': 1,
    };

    final AcademicMutationResult result = await repository.saveClass(
      draft: ClassDraft(
        name: 'Discipulado 2026',
        teacherContactId: 't1',
        startDate: CalendarDate(2026, 1, 5),
      ),
      congregationId: 'c1',
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'saveClass');
    expect(call.payload['id'], 'new-id');
    expect(call.payload['congregationId'], 'c1');
    expect(call.payload['name'], 'Discipulado 2026');
    expect(call.payload['teacherContactId'], 't1');
    expect(call.payload['startDate'], '2026-01-05');
    expect(call.payload['endDate'], isNull);
    expect(call.payload['requestId'], 'req-1');
    expect(result.id, 'new-id');
    expect(result.revision, 1);
  });

  test('class edit carries the expected revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'cls1',
      'revision': 4,
    };

    await repository.saveClass(
      draft: ClassDraft(
        name: 'Discipulado 2026',
        startDate: CalendarDate(2026, 1, 5),
      ),
      congregationId: 'c1',
      id: 'cls1',
      expectedRevision: 3,
    );

    expect(gateway.invocations.single.payload['expectedRevision'], 3);
  });

  test('eligible teachers are scoped active local teacher contacts', () async {
    gateway.onQuery = (_) => PageResult(
      items: <JsonMap>[
        contactJson(id: 't1', name: 'Professor A', roleCode: 'teacher'),
      ],
    );

    final List<Contact> teachers = await repository.listEligibleTeachers(
      congregationId: 'c1',
    );

    final QueryRequest request = gateway.queries.single;
    expect(request.resource, QueryResource.contacts);
    expect(request.congregationId, 'c1');
    expect(request.equalityFilters?['archived'], false);
    expect(request.equalityFilters?['scope'], 'congregation');
    expect(request.equalityFilters?['roleCode'], 'teacher');
    expect(teachers.single.roleCode, RoleCode.teacher);
  });

  test('eligible students exclude archived records', () async {
    gateway.onQuery = (_) => PageResult(
      items: <JsonMap>[studentOptionJson(id: 's1', name: 'Ana Souza')],
    );

    final List<StudentOption> students = await repository.listEligibleStudents(
      congregationId: 'c1',
    );

    final QueryRequest request = gateway.queries.single;
    expect(request.resource, QueryResource.students);
    expect(request.equalityFilters?['archived'], false);
    expect(students.single.name, 'Ana Souza');
  });

  test(
    'enrollment create sends class, student and explicit start date',
    () async {
      gateway.onInvoke = (_, _) => const <String, Object?>{
        'id': 'new-id',
        'revision': 1,
      };

      await repository.enrollStudent(
        congregationId: 'c1',
        classId: 'cls1',
        studentId: 's1',
        startDate: CalendarDate(2026, 1, 10),
      );

      final ({String operation, JsonMap payload}) call =
          gateway.invocations.single;
      expect(call.operation, 'enrollStudent');
      expect(call.payload['id'], 'new-id');
      expect(call.payload['classId'], 'cls1');
      expect(call.payload['studentId'], 's1');
      expect(call.payload['startDate'], '2026-01-10');
      expect(call.payload['requestId'], 'req-1');
    },
  );

  test('enrollment close records status and explicit end date', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'e1',
      'revision': 3,
    };

    await repository.closeEnrollment(
      congregationId: 'c1',
      classId: 'cls1',
      enrollmentId: 'e1',
      status: EnrollmentStatus.withdrawn,
      endDate: CalendarDate(2026, 6, 30),
      expectedRevision: 2,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'closeEnrollment');
    expect(call.payload['id'], 'e1');
    expect(call.payload['status'], 'withdrawn');
    expect(call.payload['endDate'], '2026-06-30');
    expect(call.payload['expectedRevision'], 2);
  });

  test('session creation sends date and topic with a fresh ID', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-id',
      'revision': 1,
    };

    await repository.createSession(
      congregationId: 'c1',
      classId: 'cls1',
      date: CalendarDate(2026, 2, 3),
      topic: 'Aula 1',
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'createSession');
    expect(call.payload['id'], 'new-id');
    expect(call.payload['classId'], 'cls1');
    expect(call.payload['date'], '2026-02-03');
    expect(call.payload['topic'], 'Aula 1');
  });

  test(
    'attendance save submits the complete roster map and revision',
    () async {
      gateway.onInvoke = (_, _) => const <String, Object?>{
        'id': 'ses1',
        'revision': 2,
      };

      final AcademicMutationResult result = await repository.saveAttendance(
        congregationId: 'c1',
        classId: 'cls1',
        sessionId: 'ses1',
        expectedRevision: 1,
        marks: const <String, AttendanceStatus>{
          'e1': AttendanceStatus.present,
          'e2': AttendanceStatus.absent,
          'e3': AttendanceStatus.excused,
          'e4': AttendanceStatus.unmarked,
        },
        finalize: false,
      );

      final ({String operation, JsonMap payload}) call =
          gateway.invocations.single;
      expect(call.operation, 'saveAttendance');
      expect(call.payload['sessionId'], 'ses1');
      expect(call.payload['expectedRevision'], 1);
      expect(call.payload['finalize'], false);
      expect(call.payload['requestId'], 'req-1');
      expect(call.payload['attendance'], <String, Object?>{
        'e1': 'present',
        'e2': 'absent',
        'e3': 'excused',
        'e4': 'unmarked',
      });
      expect(result.revision, 2);
    },
  );

  test('session attendance keeps the frozen historical student name', () async {
    gateway.onInvoke = (_, _) => attendanceViewJson(
      session: sessionJson(
        id: 'ses1',
        classId: 'cls1',
        status: 'finalized',
        rosterFrozen: true,
        revision: 2,
      ),
      roster: <JsonMap>[
        rosterEntryJson(
          enrollmentId: 'e1',
          studentId: 's1',
          studentName: 'Ana Antiga',
          status: 'present',
        ),
      ],
    );

    final AttendanceView view = await repository.getSessionAttendance(
      congregationId: 'c1',
      classId: 'cls1',
      sessionId: 'ses1',
    );

    expect(view.session.rosterFrozen, isTrue);
    expect(view.entries.single.studentName, 'Ana Antiga');
    expect(view.entries.single.status, AttendanceStatus.present);
  });

  test('session cancellation sends canceled status and the revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'ses1',
      'revision': 2,
    };

    await repository.cancelSession(
      congregationId: 'c1',
      classId: 'cls1',
      sessionId: 'ses1',
      expectedRevision: 1,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'cancelSession');
    expect(call.payload['id'], 'ses1');
    expect(call.payload['status'], 'canceled');
    expect(call.payload['expectedRevision'], 1);
  });
}
