import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/student.dart';
import 'package:discipulado_ieadpe/features/students/enrollment_history.dart';
import 'package:discipulado_ieadpe/features/students/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'student_test_support.dart';

void main() {
  late FakeStudentGateway gateway;
  late StudentRepository repository;

  setUp(() {
    gateway = FakeStudentGateway();
    repository = StudentRepository(
      gateway: gateway,
      recordIdFactory: () => 'new-student-id',
      requestIdFactory: () => 'request-1',
    );
  });

  test('class filter reads through the scoped class-student query', () async {
    gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

    await repository.listStudents(
      const StudentQuery(
        congregationId: 'c1',
        classId: 'cls1',
        search: 'ana',
        cursor: 'cursor-1',
      ),
    );

    final QueryRequest request = gateway.queries.single;
    expect(request.resource, QueryResource.students);
    expect(request.congregationId, 'c1');
    expect(request.namePrefix, 'ana');
    expect(request.cursor, 'cursor-1');
    expect(request.equalityFilters, <String, Object?>{
      'archived': false,
      'classId': 'cls1',
    });
    expect(request.limit, 50);
  });

  test('without a class filter only the archived flag is scoped', () async {
    gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

    await repository.listStudents(
      const StudentQuery(congregationId: 'c1', archived: true),
    );

    final QueryRequest request = gateway.queries.single;
    expect(request.equalityFilters, <String, Object?>{'archived': true});
    expect(request.namePrefix, isNull);
  });

  test('create sends only the name and keeps unanswered fields null', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-student-id',
      'revision': 1,
    };

    final StudentMutationResult result = await repository.saveStudent(
      draft: const StudentDraft(name: 'Ana Souza'),
      congregationId: 'c1',
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'saveStudent');
    expect(call.payload['id'], 'new-student-id');
    expect(call.payload.containsKey('expectedRevision'), isFalse);
    expect(call.payload['name'], 'Ana Souza');
    expect(call.payload['congregationId'], 'c1');
    expect(call.payload['phone'], isNull);
    expect(call.payload['birthDate'], isNull);
    expect(call.payload['address'], isNull);
    expect(call.payload['education'], isNull);
    expect(call.payload['maritalStatus'], isNull);
    expect(call.payload['newConvert'], isNull);
    expect(call.payload['waterBaptized'], isNull);
    expect(call.payload['wantsBaptism'], isNull);
    expect(call.payload['requestId'], 'request-1');
    expect(result.id, 'new-student-id');
    expect(result.revision, 1);
  });

  test(
    'edit keeps the stable ID and carries the leap-day birth date',
    () async {
      gateway.onInvoke = (_, _) => const <String, Object?>{
        'id': 's1',
        'revision': 4,
      };

      await repository.saveStudent(
        draft: StudentDraft(
          name: 'Ana Souza',
          birthDate: CalendarDate(2024, 2, 29),
        ),
        congregationId: 'c1',
        id: 's1',
        expectedRevision: 3,
      );

      final ({String operation, JsonMap payload}) call =
          gateway.invocations.single;
      expect(call.payload['id'], 's1');
      expect(call.payload['expectedRevision'], 3);
      expect(call.payload['birthDate'], '2024-02-29');
    },
  );

  test('archive sends the existing ID, scope and revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 's1',
      'revision': 5,
    };

    await repository.setStudentArchived(
      id: 's1',
      congregationId: 'c1',
      archived: true,
      expectedRevision: 4,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'setStudentArchived');
    expect(call.payload['id'], 's1');
    expect(call.payload['congregationId'], 'c1');
    expect(call.payload['archived'], isTrue);
    expect(call.payload['expectedRevision'], 4);
  });

  test(
    'enrollment history resolves class name and authoritative progress',
    () async {
      gateway.onQuery = (QueryRequest request) {
        if (request.resource == QueryResource.enrollments) {
          return PageResult(
            items: <JsonMap>[
              enrollmentJson(id: 'e1', studentId: 's1', classId: 'cls1'),
            ],
          );
        }
        return const PageResult(items: <JsonMap>[]);
      };
      gateway.onGet = (RecordLocator locator) =>
          locator.resource == QueryResource.classes
          ? classJson(id: 'cls1', name: 'Adultos')
          : null;
      gateway.onInvoke = (String operation, JsonMap payload) =>
          operation == 'getEnrollmentProgress'
          ? progressJson(
              enrollmentId: 'e1',
              present: 3,
              absent: 1,
              excused: 2,
              percentage: 75,
            )
          : const <String, Object?>{'id': 'e1', 'revision': 1};

      final List<EnrollmentHistoryEntry> history = await repository
          .enrollmentHistory(studentId: 's1', congregationId: 'c1');

      expect(history, hasLength(1));
      expect(history.single.enrollment.id, 'e1');
      expect(history.single.className, 'Adultos');
      expect(history.single.progress?.present, 3);
      expect(history.single.progress?.absent, 1);
      expect(history.single.progress?.excused, 2);
      expect(history.single.progress?.percentage, 75);
      expect(gateway.invocations.single.operation, 'getEnrollmentProgress');
    },
  );

  test('an out-of-scope student ID resolves to null without data', () async {
    gateway.onGet = (_) => null;

    final Student? student = await repository.getStudent(
      id: 'missing',
      congregationId: 'c1',
    );

    expect(student, isNull);
    expect(gateway.gets.single.resource, QueryResource.students);
    expect(gateway.gets.single.congregationId, 'c1');
  });
}
