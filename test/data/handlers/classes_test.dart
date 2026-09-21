import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/classes.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

const String _classUuid = 'f3e2d1c0-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _secondClassUuid = 'a1b2c3d4-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _teacherUuid = 'c0ffee11-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _secretaryUuid = '0ddba11a-abcd-46ae-9f0e-6c7f1a2b3c4d';

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

JsonMap classPayload({
  String id = _classUuid,
  String congregationId = 'c1',
  String name = 'Turma A',
  Object? teacherContactId,
  String startDate = '2026-03-04',
  Object? endDate,
  int? expectedRevision,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'name': name,
      'teacherContactId': teacherContactId,
      'startDate': startDate,
      'endDate': endDate,
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

JsonMap seededContact(
  String id, {
  String roleCode = 'teacher',
  bool archived = false,
}) =>
    <String, Object?>{
      'id': id,
      'name': id == _teacherUuid ? 'Teacher One' : 'Secretary One',
      'normalizedName': id == _teacherUuid ? 'teacher one' : 'secretary one',
      'scope': 'congregation',
      'congregationId': 'c1',
      'roleCode': roleCode,
      'phoneE164': null,
      'birthDate': null,
      'archived': archived,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededClass({
  String id = _classUuid,
  String status = 'active',
  String? teacherContactId = _teacherUuid,
  int enrollmentCount = 0,
  int activeEnrollmentCount = 0,
  int revision = 1,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'name': 'Turma A',
      'normalizedName': 'turma a',
      'teacherContactId': teacherContactId,
      'startDate': '2026-03-04',
      'endDate': null,
      'status': status,
      'enrollmentCount': enrollmentCount,
      'activeEnrollmentCount': activeEnrollmentCount,
      'revision': revision,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

void main() {
  group('classes handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;
    late HandlerContext context;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/contacts/$_teacherUuid': seededContact(_teacherUuid),
        'congregations/c1/contacts/$_secretaryUuid': seededContact(
          _secretaryUuid,
          roleCode: 'secretary',
        ),
        'congregations/c1/classes/$_classUuid': seededClass(),
      });
      handlers = classesHandlers();
      context = contextWith(store);
    });

    test('exposes saveClass and setClassStatus', () {
      expect(
        handlers.keys,
        containsAll(<String>['saveClass', 'setClassStatus']),
      );
    });

    test('create writes the record and returns revision 1', () async {
      final JsonMap result = await handlers['saveClass']!(
        context,
        classPayload(
          id: _secondClassUuid,
          teacherContactId: _teacherUuid,
          startDate: '2026-03-04',
          endDate: '2026-12-19',
        ),
      );

      expect(result, <String, Object?>{
        'id': _secondClassUuid,
        'revision': 1,
      });
      final JsonMap? record = await store.read(
        'congregations/c1/classes/$_secondClassUuid',
      );
      expect(record?['name'], 'Turma A');
      expect(record?['normalizedName'], 'turma a');
      expect(record?['teacherContactId'], _teacherUuid);
      expect(record?['startDate'], '2026-03-04');
      expect(record?['endDate'], '2026-12-19');
      expect(record?['status'], 'active');
      expect(record?['enrollmentCount'], 0);
      expect(record?['activeEnrollmentCount'], 0);
      expect(record?['revision'], 1);
      expect(record?['updatedBy'], 'u1');
    });

    test('create accepts a class without a teacher', () async {
      final JsonMap result = await handlers['saveClass']!(
        context,
        classPayload(
          id: _secondClassUuid,
          teacherContactId: null,
        ),
      );

      expect(result['revision'], 1);
      final JsonMap? record = await store.read(
        'congregations/c1/classes/$_secondClassUuid',
      );
      expect(record?['teacherContactId'], isNull);
    });

    test('rejects a non-UUID id on create', () async {
      await expectLater(
        handlers['saveClass']!(context, classPayload(id: 'not-a-uuid')),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a blank or short name', () async {
      await expectLater(
        handlers['saveClass']!(context, classPayload(name: ' ')),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects an end date before the start date', () async {
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(
            id: _secondClassUuid,
            startDate: '2026-06-01',
            endDate: '2026-03-04',
          ),
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

    test('rejects a teacher that is not a local contact', () async {
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(id: _secondClassUuid, teacherContactId: 'unknown-id'),
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

    test('rejects an archived teacher contact', () async {
      store.write(
        'congregations/c1/contacts/$_teacherUuid',
        seededContact(_teacherUuid, archived: true),
      );
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(id: _secondClassUuid, teacherContactId: _teacherUuid),
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

    test('rejects a teacher contact without the teacher role', () async {
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(id: _secondClassUuid, teacherContactId: _secretaryUuid),
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

    test('rename preserves identity and createdAt and bumps revision',
        () async {
      final JsonMap result = await handlers['saveClass']!(
        context,
        classPayload(
          name: 'Turma A (Manhã)',
          teacherContactId: _teacherUuid,
          expectedRevision: 1,
        ),
      );

      expect(result, <String, Object?>{'id': _classUuid, 'revision': 2});
      final JsonMap? record = await store.read(
        'congregations/c1/classes/$_classUuid',
      );
      expect(record?['id'], _classUuid);
      expect(record?['name'], 'Turma A (Manhã)');
      expect(record?['normalizedName'], 'turma a (manha)');
      expect(record?['createdAt'], '2025-01-01T12:00:00.000Z');
      expect(record?['revision'], 2);
      expect(record?['updatedBy'], 'u1');
    });

    test('rejects editing a completed or archived class', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(status: 'completed'),
      );
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(name: 'Turma B', expectedRevision: 1),
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

    test('rejects changing dates once an enrollment exists', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(enrollmentCount: 3),
      );
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(startDate: '2026-03-05', expectedRevision: 1),
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

    test('rejects changing dates once a session exists', () async {
      store.write(
        'congregations/c1/sessions/s1',
        <String, Object?>{
          'id': 's1',
          'congregationId': 'c1',
          'classId': _classUuid,
          'date': '2026-05-10',
          'status': 'open',
          'revision': 1,
        },
      );
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(startDate: '2026-03-05', expectedRevision: 1),
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

    test('rejects a stale expected revision on rename', () async {
      await expectLater(
        handlers['saveClass']!(
          context,
          classPayload(name: 'Turma B', expectedRevision: 9),
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

    test('setClassStatus is a no-op in the target state', () async {
      final JsonMap result = await handlers['setClassStatus']!(
        context,
        <String, Object?>{
          'id': _classUuid,
          'congregationId': 'c1',
          'status': 'active',
          'expectedRevision': 1,
          'requestId': 'req-noop',
        },
      );

      expect(result, <String, Object?>{'id': _classUuid, 'revision': 1});
    });

    test('completes a class only when enrollments and sessions are settled',
        () async {
      final JsonMap result = await handlers['setClassStatus']!(
        context,
        <String, Object?>{
          'id': _classUuid,
          'congregationId': 'c1',
          'status': 'completed',
          'expectedRevision': 1,
          'requestId': 'req-complete',
        },
      );

      expect(result, <String, Object?>{'id': _classUuid, 'revision': 2});
      final JsonMap? record = await store.read(
        'congregations/c1/classes/$_classUuid',
      );
      expect(record?['status'], 'completed');
      expect(record?['revision'], 2);
    });

    test('blocks completion with an active enrollment', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(activeEnrollmentCount: 2),
      );
      await expectLater(
        handlers['setClassStatus']!(
          context,
          <String, Object?>{
            'id': _classUuid,
            'congregationId': 'c1',
            'status': 'completed',
            'expectedRevision': 1,
            'requestId': 'req-block-1',
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

    test('blocks completion with an open session', () async {
      store.write(
        'congregations/c1/sessions/s1',
        <String, Object?>{
          'id': 's1',
          'congregationId': 'c1',
          'classId': _classUuid,
          'date': '2026-05-10',
          'status': 'open',
          'revision': 1,
        },
      );
      await expectLater(
        handlers['setClassStatus']!(
          context,
          <String, Object?>{
            'id': _classUuid,
            'congregationId': 'c1',
            'status': 'completed',
            'expectedRevision': 1,
            'requestId': 'req-block-2',
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

    test('blocks archiving an active class with enrollments or sessions',
        () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(enrollmentCount: 1),
      );
      await expectLater(
        handlers['setClassStatus']!(
          context,
          <String, Object?>{
            'id': _classUuid,
            'congregationId': 'c1',
            'status': 'archived',
            'expectedRevision': 1,
            'requestId': 'req-block-3',
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

    test('archives an empty active class then reactivates it', () async {
      final JsonMap archived = await handlers['setClassStatus']!(
        context,
        <String, Object?>{
          'id': _classUuid,
          'congregationId': 'c1',
          'status': 'archived',
          'expectedRevision': 1,
          'requestId': 'req-arch',
        },
      );
      expect(archived, <String, Object?>{'id': _classUuid, 'revision': 2});

      final JsonMap reactivated = await handlers['setClassStatus']!(
        context,
        <String, Object?>{
          'id': _classUuid,
          'congregationId': 'c1',
          'status': 'active',
          'expectedRevision': 2,
          'requestId': 'req-reactivate',
        },
      );
      expect(reactivated, <String, Object?>{'id': _classUuid, 'revision': 3});
      final JsonMap? record = await store.read(
        'congregations/c1/classes/$_classUuid',
      );
      expect(record?['status'], 'active');
      expect(record?['revision'], 3);
    });

    test('rejects reopening a completed class', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(status: 'completed'),
      );
      await expectLater(
        handlers['setClassStatus']!(
          context,
          <String, Object?>{
            'id': _classUuid,
            'congregationId': 'c1',
            'status': 'active',
            'expectedRevision': 1,
            'requestId': 'req-reopen',
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

    test('re-archiving an archived class is a no-op', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(status: 'archived'),
      );
      final JsonMap result = await handlers['setClassStatus']!(
        context,
        <String, Object?>{
          'id': _classUuid,
          'congregationId': 'c1',
          'status': 'archived',
          'expectedRevision': 1,
          'requestId': 'req-rearch',
        },
      );

      expect(result['revision'], 1);
    });

    test('setClassStatus missing class is a notFound failure', () async {
      await expectLater(
        handlers['setClassStatus']!(
          context,
          <String, Object?>{
            'id': _secondClassUuid,
            'congregationId': 'c1',
            'status': 'completed',
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
      await handlers['saveClass']!(
        context,
        classPayload(id: _secondClassUuid, teacherContactId: _teacherUuid),
      );
      await handlers['setClassStatus']!(
        context,
        <String, Object?>{
          'id': _classUuid,
          'congregationId': 'c1',
          'status': 'archived',
          'expectedRevision': 1,
          'requestId': 'req-ref',
        },
      );

      final List<JsonMap> teacherRefs = await store.query(
        const StoreQuery(collection: 'teacherClassRefs', group: true),
      );
      expect(teacherRefs, isEmpty);
      final JsonMap? congregation = await store.read('congregations/c1');
      expect(congregation?['unarchivedStudents'], isNull);
      expect(congregation?['activeClasses'], isNull);
    });
  });
}