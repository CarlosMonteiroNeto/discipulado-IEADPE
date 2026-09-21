import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/enrollments.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/academic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const String _enrollmentUuid = '11111111-2222-4333-8444-555555555555';
const String _secondEnrollmentUuid = 'aaaaaaaa-1111-4222-8333-555555555555';
const String _classUuid = 'f3e2d1c0-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _secondClassUuid = 'a1b2c3d4-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _studentUuid = '0f0f0f0f-1111-4222-8333-444444444444';
const String _secondStudentUuid = '0e0e0e0e-1111-4222-8333-444444444444';
const String _archivedStudentUuid = '0d0d0d0d-1111-4222-8333-444444444444';

HandlerContext contextWith(
  DirectStore store, {
  String uid = 'u1',
  DateTime? now,
}) =>
    HandlerContext(
      store: store,
      uid: uid,
      now: now ?? DateTime.utc(2026, 9, 21, 12),
    );

JsonMap enrollmentPayload({
  String id = _enrollmentUuid,
  String congregationId = 'c1',
  String classId = _classUuid,
  String studentId = _studentUuid,
  String startDate = '2026-04-01',
  int? expectedRevision,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'classId': classId,
      'studentId': studentId,
      'startDate': startDate,
      'requestId': 'req-x',
      'expectedRevision': ?expectedRevision,
    };

JsonMap seededCongregation({String id = 'c1', bool active = true}) =>
    <String, Object?>{
      'id': id,
      'name': id == 'c1' ? 'Abra' : 'Camboas',
      'normalizedName': id == 'c1' ? 'abra' : 'camboas',
      'active': active,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededClass({
  String id = _classUuid,
  String status = 'active',
  int enrollmentCount = 0,
  int activeEnrollmentCount = 0,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'name': 'Turma A',
      'normalizedName': 'turma a',
      'teacherContactId': null,
      'startDate': '2026-03-04',
      'endDate': '2026-12-19',
      'status': status,
      'enrollmentCount': enrollmentCount,
      'activeEnrollmentCount': activeEnrollmentCount,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededStudent(
  String id, {
  String name = 'Ana Oliveira',
  String congregationId = 'c1',
  bool archived = false,
}) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'normalizedName': name.toLowerCase(),
      'congregationId': congregationId,
      'phoneE164': null,
      'birthDate': null,
      'address': null,
      'education': null,
      'maritalStatus': null,
      'newConvert': null,
      'waterBaptized': null,
      'wantsBaptism': null,
      'archived': archived,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededEnrollment({
  String id = _enrollmentUuid,
  String classId = _classUuid,
  String studentId = _studentUuid,
  String status = 'active',
  String startDate = '2026-04-01',
  Object? endDate,
  int revision = 1,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'classId': classId,
      'studentId': studentId,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'revision': revision,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

void main() {
  group('enrollment handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;
    late HandlerContext context;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c2': seededCongregation(id: 'c2'),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/classes/$_secondClassUuid': seededClass(
          id: _secondClassUuid,
        ),
        'congregations/c1/students/$_studentUuid': seededStudent(_studentUuid),
        'congregations/c1/students/$_secondStudentUuid': seededStudent(
          _secondStudentUuid,
          name: 'Bruno Souza',
        ),
        'congregations/c1/students/$_archivedStudentUuid': seededStudent(
          _archivedStudentUuid,
          archived: true,
        ),
      });
      handlers = enrollmentsHandlers();
      context = contextWith(store);
    });

    test('exposes enrollStudent and closeEnrollment', () {
      expect(
        handlers.keys,
        containsAll(<String>['enrollStudent', 'closeEnrollment']),
      );
    });

    test(
        'enrollStudent writes the enrollment, roster entry and student classId backfill',
        () async {
      final JsonMap result = await handlers['enrollStudent']!(
        context,
        enrollmentPayload(id: _enrollmentUuid),
      );

      expect(result, <String, Object?>{'id': _enrollmentUuid, 'revision': 1});

      final JsonMap? enrollment = await store.read(
        'congregations/c1/enrollments/$_enrollmentUuid',
      );
      expect(enrollment?['id'], _enrollmentUuid);
      expect(enrollment?['congregationId'], 'c1');
      expect(enrollment?['classId'], _classUuid);
      expect(enrollment?['studentId'], _studentUuid);
      expect(enrollment?['startDate'], '2026-04-01');
      expect(enrollment?['endDate'], isNull);
      expect(enrollment?['status'], 'active');
      expect(enrollment?['revision'], 1);
      expect(enrollment?['updatedBy'], 'u1');

      final JsonMap? reference = await store.read(
        'congregations/c1/activeEnrollmentRefs/$_studentUuid',
      );
      expect(reference?['enrollmentId'], _enrollmentUuid);
      expect(reference?['classId'], _classUuid);

      final JsonMap? rosterEntry = await store.read(
        'congregations/c1/classes/$_classUuid/roster/$_enrollmentUuid',
      );
      expect(rosterEntry?['enrollmentId'], _enrollmentUuid);
      expect(rosterEntry?['studentId'], _studentUuid);
      expect(rosterEntry?['studentName'], 'Ana Oliveira');
      expect(rosterEntry?['classId'], _classUuid);
      expect(rosterEntry?['revision'], 1);

      final JsonMap? student = await store.read(
        'congregations/c1/students/$_studentUuid',
      );
      expect(student?['classId'], _classUuid);

      final JsonMap? classDocument = await store.read(
        'congregations/c1/classes/$_classUuid',
      );
      expect(classDocument?['enrollmentCount'], 1);
      expect(classDocument?['activeEnrollmentCount'], 1);
    });

    test('the enrollStudent result decodes as AcademicMutationResult',
        () async {
      final JsonMap result = await handlers['enrollStudent']!(
        context,
        enrollmentPayload(),
      );

      final AcademicMutationResult decoded =
          AcademicMutationResult.fromJson(result);
      expect(decoded.id, _enrollmentUuid);
      expect(decoded.revision, 1);
    });

    test('rejects a non-UUID id on create', () async {
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(id: 'not-a-uuid'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects enrolling into a missing class', () async {
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(classId: '01234567-89ab-4cde-8f01-23456789abcd'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.notFound,
          ),
        ),
      );
    });

    test('rejects enrolling into a class that is not active', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(status: 'completed'),
      );
      await expectLater(
        handlers['enrollStudent']!(context, enrollmentPayload()),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects enrolling a missing student', () async {
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(studentId: '01234567-89ab-4cde-8f01-23456789abcd'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.notFound,
          ),
        ),
      );
    });

    test('rejects enrolling an archived student', () async {
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(studentId: _archivedStudentUuid),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects a student that already has an active enrollment', () async {
      store.write(
        'congregations/c1/activeEnrollmentRefs/$_studentUuid',
        <String, Object?>{
          'studentId': _studentUuid,
          'congregationId': 'c1',
          'enrollmentId': _enrollmentUuid,
          'classId': _classUuid,
          'revision': 1,
          'createdAt': '2026-01-01T12:00:00.000Z',
          'updatedAt': '2026-01-01T12:00:00.000Z',
          'updatedBy': 'u0',
        },
      );
      await expectLater(
        handlers['enrollStudent']!(context, enrollmentPayload()),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects a start date outside the class period', () async {
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(startDate: '2027-01-02'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('enforces the enrollment cap as a best-effort length check',
        () async {
      store.write(
        'congregations/c1/classes/$_secondClassUuid',
        seededClass(id: _secondClassUuid, enrollmentCount: 100),
      );
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(
            classId: _secondClassUuid,
            id: _secondEnrollmentUuid,
          ),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('allows enrollment when the class is one below capacity', () async {
      store.write(
        'congregations/c1/classes/$_secondClassUuid',
        seededClass(id: _secondClassUuid, enrollmentCount: 99),
      );
      store.write(
        'congregations/c1/students/$_secondStudentUuid',
        seededStudent(_secondStudentUuid, name: 'Bruno Souza'),
      );

      final JsonMap result = await handlers['enrollStudent']!(
        context,
        enrollmentPayload(
          classId: _secondClassUuid,
          id: _secondEnrollmentUuid,
          studentId: _secondStudentUuid,
        ),
      );

      expect(result, <String, Object?>{
        'id': _secondEnrollmentUuid,
        'revision': 1,
      });
      final JsonMap? classDocument = await store.read(
        'congregations/c1/classes/$_secondClassUuid',
      );
      expect(classDocument?['enrollmentCount'], 100);
    });

    test('an active enrollment edit changes startDate and bumps the revision',
        () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      store.write(
        'congregations/c1/activeEnrollmentRefs/$_studentUuid',
        <String, Object?>{
          'studentId': _studentUuid,
          'congregationId': 'c1',
          'enrollmentId': _enrollmentUuid,
          'classId': _classUuid,
          'revision': 1,
          'createdAt': '2026-01-01T12:00:00.000Z',
          'updatedAt': '2026-01-01T12:00:00.000Z',
          'updatedBy': 'u0',
        },
      );

      final JsonMap result = await handlers['enrollStudent']!(
        context,
        enrollmentPayload(startDate: '2026-05-01', expectedRevision: 1),
      );

      expect(result, <String, Object?>{'id': _enrollmentUuid, 'revision': 2});
      final JsonMap? enrollment = await store.read(
        'congregations/c1/enrollments/$_enrollmentUuid',
      );
      expect(enrollment?['startDate'], '2026-05-01');
      expect(enrollment?['status'], 'active');
      expect(enrollment?['revision'], 2);
      expect(enrollment?['updatedBy'], 'u1');
    });

    test('an active enrollment edit cannot change its student', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(studentId: _secondStudentUuid, expectedRevision: 1),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('an active enrollment edit cannot change its class', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      await expectLater(
        handlers['enrollStudent']!(
          context,
          enrollmentPayload(classId: _secondClassUuid, expectedRevision: 1),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('closeEnrollment completes an active enrollment', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      store.write(
        'congregations/c1/activeEnrollmentRefs/$_studentUuid',
        <String, Object?>{
          'studentId': _studentUuid,
          'congregationId': 'c1',
          'enrollmentId': _enrollmentUuid,
          'classId': _classUuid,
          'revision': 1,
          'createdAt': '2026-01-01T12:00:00.000Z',
          'updatedAt': '2026-01-01T12:00:00.000Z',
          'updatedBy': 'u0',
        },
      );
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(enrollmentCount: 1, activeEnrollmentCount: 1),
      );
      store.write(
        'congregations/c1/students/$_studentUuid',
        <String, Object?>{...seededStudent(_studentUuid), 'classId': _classUuid},
      );

      final JsonMap result = await handlers['closeEnrollment']!(
        context,
        <String, Object?>{
          'id': _enrollmentUuid,
          'congregationId': 'c1',
          'classId': _classUuid,
          'status': 'completed',
          'endDate': '2026-08-01',
          'expectedRevision': 1,
          'requestId': 'req-close',
        },
      );

      expect(result, <String, Object?>{'id': _enrollmentUuid, 'revision': 2});
      final JsonMap? enrollment = await store.read(
        'congregations/c1/enrollments/$_enrollmentUuid',
      );
      expect(enrollment?['status'], 'completed');
      expect(enrollment?['endDate'], '2026-08-01');
      expect(enrollment?['revision'], 2);
      expect(enrollment?['updatedBy'], 'u1');

      final JsonMap? reference = await store.read(
        'congregations/c1/activeEnrollmentRefs/$_studentUuid',
      );
      expect(reference, isNull);

      final JsonMap? classDocument = await store.read(
        'congregations/c1/classes/$_classUuid',
      );
      expect(classDocument?['enrollmentCount'], 1);
      expect(classDocument?['activeEnrollmentCount'], 0);

      final JsonMap? student = await store.read(
        'congregations/c1/students/$_studentUuid',
      );
      expect(student?['classId'], isNull);
    });

    test('closeEnrollment withdraws an active enrollment', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(enrollmentCount: 1, activeEnrollmentCount: 1),
      );

      final JsonMap result = await handlers['closeEnrollment']!(
        context,
        <String, Object?>{
          'id': _enrollmentUuid,
          'congregationId': 'c1',
          'classId': _classUuid,
          'status': 'withdrawn',
          'endDate': '2026-06-15',
          'expectedRevision': 1,
          'requestId': 'req-withdraw',
        },
      );

      expect(result['revision'], 2);
      final JsonMap? enrollment = await store.read(
        'congregations/c1/enrollments/$_enrollmentUuid',
      );
      expect(enrollment?['status'], 'withdrawn');
      expect(enrollment?['endDate'], '2026-06-15');
    });

    test('closeEnrollment rejects active as the target status', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _enrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'active',
            'endDate': '2026-06-15',
            'expectedRevision': 1,
            'requestId': 'req-active',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('closeEnrollment rejects an unknown status', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _enrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'paused',
            'endDate': '2026-06-15',
            'expectedRevision': 1,
            'requestId': 'req-unknown',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('closeEnrollment rejects an end date before the start date',
        () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _enrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'completed',
            'endDate': '2026-03-02',
            'expectedRevision': 1,
            'requestId': 'req-before',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('closeEnrollment rejects an end date outside the class period',
        () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(),
      );
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _enrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'completed',
            'endDate': '2027-01-02',
            'expectedRevision': 1,
            'requestId': 'req-after',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('closeEnrollment rejects a closed enrollment as immutable',
        () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(
          status: 'completed',
          endDate: '2026-08-01',
          revision: 2,
        ),
      );
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _enrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'withdrawn',
            'endDate': '2026-08-01',
            'expectedRevision': 2,
            'requestId': 'req-immutable',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('closeEnrollment rejects a stale expected revision', () async {
      store.write(
        'congregations/c1/enrollments/$_enrollmentUuid',
        seededEnrollment(revision: 2),
      );
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _enrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'completed',
            'endDate': '2026-08-01',
            'expectedRevision': 1,
            'requestId': 'req-stale',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('closeEnrollment missing enrollment is a notFound failure', () async {
      await expectLater(
        handlers['closeEnrollment']!(
          context,
          <String, Object?>{
            'id': _secondEnrollmentUuid,
            'congregationId': 'c1',
            'classId': _classUuid,
            'status': 'completed',
            'endDate': '2026-08-01',
            'expectedRevision': 1,
            'requestId': 'req-missing',
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.notFound,
          ),
        ),
      );
    });

    test('writes no reference-counter documents', () async {
      await handlers['enrollStudent']!(context, enrollmentPayload());

      final JsonMap? congregation = await store.read('congregations/c1');
      expect(congregation?['unarchivedStudents'], isNull);
      expect(congregation?['activeEnrollments'], isNull);
      expect(congregation?['totalEnrollments'], isNull);
    });
  });
}