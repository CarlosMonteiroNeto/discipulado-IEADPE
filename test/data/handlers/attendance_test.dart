import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/attendance.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:discipulado_ieadpe/features/classes/academic_repository.dart';
import 'package:discipulado_ieadpe/features/students/enrollment_history.dart';
import 'package:flutter_test/flutter_test.dart';

const String _classUuid = 'f3e2d1c0-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _sessionUuid = '22111111-2222-4333-8444-555555555555';
const String _e1 = '11111111-1111-4111-8111-111111111111';
const String _e2 = '22222222-2222-4222-8222-222222222222';
const String _e3 = '33333333-3333-4333-8333-333333333333';
const String _s1 = 'aaaaaaaa-1111-4111-8111-111111111111';
const String _s2 = 'bbbbbbbb-2222-4222-8222-222222222222';

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

JsonMap seededCongregation({String id = 'c1'}) => <String, Object?>{
  'id': id,
  'name': id == 'c1' ? 'Abra' : 'Camboas',
  'normalizedName': id == 'c1' ? 'abra' : 'camboas',
  'active': true,
  'revision': 1,
  'createdAt': '2025-01-01T12:00:00.000Z',
  'updatedAt': '2025-01-01T12:00:00.000Z',
  'updatedBy': 'u0',
};

JsonMap seededClass({String id = _classUuid, String status = 'active'}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'name': 'Turma A',
      'normalizedName': 'turma a',
      'teacherContactId': null,
      'startDate': '2026-03-04',
      'endDate': '2026-12-19',
      'status': status,
      'enrollmentCount': 0,
      'activeEnrollmentCount': 0,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededEnrollment({
  required String id,
  required String studentId,
  String startDate = '2026-03-01',
  String? endDate = '2026-12-31',
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'classId': _classUuid,
      'studentId': studentId,
      'startDate': startDate,
      'endDate': endDate,
      'status': 'active',
      'revision': 1,
      'createdAt': '2026-02-01T12:00:00.000Z',
      'updatedAt': '2026-02-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededStudent({
  required String id,
  required String name,
  String? classId,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'name': name,
      'normalizedName': name.toLowerCase(),
      'phone': null,
      'classId': classId,
      'archived': false,
      'revision': 1,
      'createdAt': '2026-02-01T12:00:00.000Z',
      'updatedAt': '2026-02-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededClassRosterEntry({
  required String enrollmentId,
  required String studentId,
  required String studentName,
}) =>
    <String, Object?>{
      'id': enrollmentId,
      'enrollmentId': enrollmentId,
      'studentId': studentId,
      'studentName': studentName,
      'classId': _classUuid,
      'congregationId': 'c1',
      'revision': 1,
      'createdAt': '2026-02-01T12:00:00.000Z',
      'updatedAt': '2026-02-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededSession({
  String id = _sessionUuid,
  String classId = _classUuid,
  String date = '2026-05-10',
  String status = 'open',
  bool rosterFrozen = false,
  int revision = 1,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'classId': classId,
      'date': date,
      'topic': 'Tema',
      'status': status,
      'rosterFrozen': rosterFrozen,
      'revision': revision,
      'createdAt': '2026-04-01T12:00:00.000Z',
      'updatedAt': '2026-04-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededSessionRosterEntry({
  required String sessionId,
  required String enrollmentId,
  required String studentId,
  String studentName = 'Aluna Congelada',
}) =>
    <String, Object?>{
      'id': enrollmentId,
      'enrollmentId': enrollmentId,
      'studentId': studentId,
      'studentName': studentName,
      'sessionId': sessionId,
      'classId': _classUuid,
      'congregationId': 'c1',
      'revision': 1,
      'createdAt': '2026-04-01T12:00:00.000Z',
      'updatedAt': '2026-04-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededAttendance({
  required String sessionId,
  required String enrollmentId,
  required String status,
  String studentId = _s1,
}) =>
    <String, Object?>{
      'id': enrollmentId,
      'enrollmentId': enrollmentId,
      'studentId': studentId,
      'status': status,
      'sessionId': sessionId,
      'classId': _classUuid,
      'congregationId': 'c1',
      'revision': 1,
      'createdAt': '2026-04-01T12:00:00.000Z',
      'updatedAt': '2026-04-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

String sessionRosterPath(String sessionId) =>
    'congregations/c1/sessions/$sessionId/roster';

JsonMap saveAttendancePayload({
  required int expectedRevision,
  required Map<String, AttendanceStatus> marks,
  bool finalize = false,
  String sessionId = _sessionUuid,
  Object? lessonFinished,
}) =>
    <String, Object?>{
      'congregationId': 'c1',
      'classId': _classUuid,
      'sessionId': sessionId,
      'expectedRevision': expectedRevision,
      'finalize': finalize,
      'attendance': <String, Object?>{
        for (final MapEntry<String, AttendanceStatus> entry in marks.entries)
          entry.key: entry.value.wire,
      },
      'lessonFinished': ?lessonFinished,
      'requestId': 'req-att',
    };

JsonMap getSessionAttendancePayload({
  String sessionId = _sessionUuid,
  String congregationId = 'c1',
  String classId = _classUuid,
}) =>
    <String, Object?>{
      'congregationId': congregationId,
      'classId': classId,
      'sessionId': sessionId,
    };

JsonMap getEnrollmentProgressPayload({
  required String enrollmentId,
  String congregationId = 'c1',
}) =>
    <String, Object?>{
      'congregationId': congregationId,
      'enrollmentId': enrollmentId,
    };

Map<String, JsonMap> progressSessionSeeds() => <String, JsonMap>{
  // Six finalized in-window sessions: 3 present, 1 absent, 2 excused.
  for (int i = 1; i <= 6; i++)
    'congregations/c1/sessions/0000000$i-0000-4000-8000-00000000000$i':
        seededSession(
          id: '0000000$i-0000-4000-8000-00000000000$i',
          date: '2026-05-$i',
          status: 'finalized',
          rosterFrozen: true,
        ),
  // An open session carrying a present mark must not count.
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000001': seededSession(
    id: '22222222-0000-4000-8000-000000000001',
    date: '2026-06-01',
    status: 'open',
    rosterFrozen: true,
  ),
  // A canceled session carrying a mark must not count.
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000002': seededSession(
    id: '22222222-0000-4000-8000-000000000002',
    date: '2026-06-02',
    status: 'canceled',
    rosterFrozen: true,
  ),
  // Out of the enrollment window.
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000003': seededSession(
    id: '22222222-0000-4000-8000-000000000003',
    date: '2027-01-10',
    status: 'finalized',
    rosterFrozen: true,
  ),
  // A session of a different class.
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000004': seededSession(
    id: '22222222-0000-4000-8000-000000000004',
    classId: '99999999-9999-4999-8999-999999999999',
    date: '2026-06-03',
    status: 'finalized',
    rosterFrozen: true,
  ),
  for (int i = 1; i <= 6; i++)
    'congregations/c1/sessions/0000000$i-0000-4000-8000-00000000000$i/roster/$_e1':
        seededSessionRosterEntry(
          sessionId: '0000000$i-0000-4000-8000-00000000000$i',
          enrollmentId: _e1,
          studentId: _s1,
        ),
  for (int i = 1; i <= 6; i++)
    'congregations/c1/sessions/0000000$i-0000-4000-8000-00000000000$i/attendance/$_e1':
        seededAttendance(
          sessionId: '0000000$i-0000-4000-8000-00000000000$i',
          enrollmentId: _e1,
          status: i <= 3
              ? AttendanceStatus.present.wire
              : i == 4
              ? AttendanceStatus.absent.wire
              : AttendanceStatus.excused.wire,
        ),
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000001/roster/$_e1':
      seededSessionRosterEntry(
        sessionId: '22222222-0000-4000-8000-000000000001',
        enrollmentId: _e1,
        studentId: _s1,
      ),
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000001/attendance/$_e1':
      seededAttendance(
        sessionId: '22222222-0000-4000-8000-000000000001',
        enrollmentId: _e1,
        status: AttendanceStatus.present.wire,
      ),
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000002/roster/$_e1':
      seededSessionRosterEntry(
        sessionId: '22222222-0000-4000-8000-000000000002',
        enrollmentId: _e1,
        studentId: _s1,
      ),
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000003/roster/$_e1':
      seededSessionRosterEntry(
        sessionId: '22222222-0000-4000-8000-000000000003',
        enrollmentId: _e1,
        studentId: _s1,
      ),
  'congregations/c1/sessions/22222222-0000-4000-8000-000000000003/attendance/$_e1':
      seededAttendance(
        sessionId: '22222222-0000-4000-8000-000000000003',
        enrollmentId: _e1,
        status: AttendanceStatus.present.wire,
      ),
};

void main() {
  group('attendance handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
        'congregations/c1/classes/$_classUuid/roster/$_e1':
            seededClassRosterEntry(
              enrollmentId: _e1,
              studentId: _s1,
              studentName: 'Aluna Congelada',
            ),
        'congregations/c1/students/$_s1': seededStudent(
          id: _s1,
          name: 'Nome Atual',
          classId: _classUuid,
        ),
      });
      handlers = attendanceHandlers();
    });

    test('registry exposes the attendance and progress operations', () {
      expect(
        handlers.keys,
        containsAll(<String>[
          'saveAttendance',
          'getSessionAttendance',
          'getEnrollmentProgress',
        ]),
      );
    });

    test('first save freezes the eligible roster and writes marks', () async {
      final HandlerContext context = contextWith(store);
      final JsonMap result =
          await handlers['saveAttendance']!(context, saveAttendancePayload(
            expectedRevision: 1,
            marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
          ));

      expect(result, <String, Object?>{'id': _sessionUuid, 'revision': 2});

      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['rosterFrozen'], isTrue);
      expect(session?['status'], isNot(SessionStatus.finalized.wire));

      final List<JsonMap> roster = await store.query(
        StoreQuery(collection: sessionRosterPath(_sessionUuid)),
      );
      expect(roster, hasLength(1));
      final JsonMap entry = roster.single;
      expect(entry['enrollmentId'], _e1);
      expect(entry['studentId'], _s1);
      expect(entry['studentName'], 'Aluna Congelada');
      expect(entry['createdAt'], isNot(isNull));

      final JsonMap? mark = await store.read(
        'congregations/c1/sessions/$_sessionUuid/attendance/$_e1',
      );
      expect(mark?['status'], AttendanceStatus.present.wire);
      expect(mark?['studentId'], _s1);
      expect(mark?['revision'], 1);
    });

    test('freeze keeps only enrollments whose interval includes the date', () async {
      final DirectStore storeWithExtras = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
        'congregations/c1/enrollments/$_e2': seededEnrollment(
          id: _e2,
          studentId: _s2,
          endDate: '2026-04-01',
        ),
        'congregations/c1/enrollments/$_e3': seededEnrollment(
          id: _e3,
          studentId: 'cccccccc-3333-4333-8333-333333333333',
          startDate: '2026-06-01',
        ),
        for (final String id in <String>[_e1, _e2, _e3])
          'congregations/c1/classes/$_classUuid/roster/$id':
              seededClassRosterEntry(
                enrollmentId: id,
                studentId: id == _e1 ? _s1 : 'p-$id',
                studentName: 'Aluna $id',
              ),
        'congregations/c1/students/$_s1': seededStudent(
          id: _s1,
          name: 'Nome Atual',
        ),
      });
      final HandlerContext context = contextWith(storeWithExtras);

      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      ));

      final List<JsonMap> roster = await storeWithExtras.query(
        StoreQuery(collection: sessionRosterPath(_sessionUuid)),
      );
      expect(roster.map((JsonMap entry) => entry['enrollmentId']), [_e1]);
    });

    test('fallback captures the current student name without a snapshot', () async {
      final DirectStore bareStore = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
        'congregations/c1/students/$_s1': seededStudent(
          id: _s1,
          name: 'Nome Atual',
        ),
      });
      final HandlerContext context = contextWith(bareStore);

      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      ));

      final List<JsonMap> roster = await bareStore.query(
        StoreQuery(collection: sessionRosterPath(_sessionUuid)),
      );
      expect(roster.single['studentName'], 'Nome Atual');
    });

    test('frozen names survive a later student rename', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      ));
      await store.write(
        'congregations/c1/students/$_s1',
        seededStudent(id: _s1, name: 'Nome Renomeado', classId: _classUuid),
      );

      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 2,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.absent},
      ));

      final List<JsonMap> roster = await store.query(
        StoreQuery(collection: sessionRosterPath(_sessionUuid)),
      );
      expect(roster.single['studentName'], 'Aluna Congelada');
      final JsonMap? mark = await store.read(
        'congregations/c1/sessions/$_sessionUuid/attendance/$_e1',
      );
      expect(mark?['status'], AttendanceStatus.absent.wire);
      expect(mark?['revision'], 2);
    });

    test('marks must match the frozen roster membership exactly', () async {
      final HandlerContext context = contextWith(store);
      expect(
        () => handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{
            _e1: AttendanceStatus.present,
            _e2: AttendanceStatus.unmarked,
          },
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
      expect(
        () => handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{},
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
    });

    test('a stale expected revision is a conflict', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      ));
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.absent},
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('a canceled session cannot be edited', () async {
      final DirectStore storeWithCanceled = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(
          status: 'canceled',
        ),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
      });
      final HandlerContext context = contextWith(storeWithCanceled);
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('a finalized session requires finalize to correct', () async {
      final DirectStore storeWithFinalized = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(
          status: 'finalized',
          rosterFrozen: true,
        ),
        'congregations/c1/sessions/$_sessionUuid/roster/$_e1':
            seededSessionRosterEntry(
              sessionId: _sessionUuid,
              enrollmentId: _e1,
              studentId: _s1,
            ),
      });
      final HandlerContext context = contextWith(storeWithFinalized);
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
          finalize: false,
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('finalize rejects an empty roster', () async {
      final DirectStore emptyStore = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
      });
      final HandlerContext context = contextWith(emptyStore);
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{},
          finalize: true,
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('finalize requires every member to be marked', () async {
      final HandlerContext context = contextWith(store);
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.unmarked},
          finalize: true,
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
    });

    test('finalize refuses a session dated in the future', () async {
      final HandlerContext earlyContext = contextWith(
        store,
        now: DateTime.utc(2026, 5, 1, 12),
      );
      await expectLater(
        handlers['saveAttendance']!(earlyContext, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
          finalize: true,
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
    });

    test('finalize transitions the session to finalized', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
        finalize: true,
      ));
      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['status'], SessionStatus.finalized.wire);
      expect(session?['rosterFrozen'], isTrue);
      expect(session?['revision'], 2);
    });

    test('finalized correction keeps the status and bumps the revision', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
        finalize: true,
      ));
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 2,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.excused},
        finalize: true,
      ));
      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['status'], SessionStatus.finalized.wire);
      expect(session?['revision'], 3);
      final JsonMap? mark = await store.read(
        'congregations/c1/sessions/$_sessionUuid/attendance/$_e1',
      );
      expect(mark?['status'], AttendanceStatus.excused.wire);
      expect(mark?['revision'], 2);
    });

    test('a late enrollment never joins an already-frozen roster', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      ));
      await store.write(
        'congregations/c1/enrollments/$_e3',
        seededEnrollment(
          id: _e3,
          studentId: 'cccccccc-3333-4333-8333-333333333333',
          startDate: '2026-06-01',
        ),
      );

      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 2,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      ));

      final List<JsonMap> roster = await store.query(
        StoreQuery(collection: sessionRosterPath(_sessionUuid)),
      );
      expect(roster, hasLength(1));
    });

    test('a session is limited to 100 roster members', () async {
      final HandlerContext context = contextWith(store);
      final Map<String, AttendanceStatus> many = <String, AttendanceStatus>{
        for (int i = 0; i < 101; i++) 'id-$i': AttendanceStatus.present,
      };
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: many,
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('an unknown attendance status is rejected', () async {
      final HandlerContext context = contextWith(store);
      final JsonMap payload = saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
      );
      payload['attendance'] = <String, Object?>{_e1: 'faltou'};
      await expectLater(
        handlers['saveAttendance']!(context, payload),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
    });

    test('attendance is refused for a completed class', () async {
      final DirectStore storeWithCompleted = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(
          status: 'completed',
        ),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
      });
      final HandlerContext context = contextWith(storeWithCompleted);
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('saveAttendance persists the concluded flag onto the session', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
        lessonFinished: true,
      ));

      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['lessonFinished'], isTrue);
      expect(session?['lessonIndex'], isNull);
      expect(session?['lessonPart'], isNull);
    });

    test('saveAttendance rejects a non-boolean concluded flag', () async {
      final HandlerContext context = contextWith(store);
      await expectLater(
        handlers['saveAttendance']!(context, saveAttendancePayload(
          expectedRevision: 1,
          marks: <String, AttendanceStatus>{_e1: AttendanceStatus.present},
          lessonFinished: 'sim',
        )),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
    });

    test('reads decode an unmarked roster without marks', () async {
      final DirectStore storeWithRoster = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(
          rosterFrozen: true,
        ),
        'congregations/c1/sessions/$_sessionUuid/roster/$_e1':
            seededSessionRosterEntry(
              sessionId: _sessionUuid,
              enrollmentId: _e1,
              studentId: _s1,
            ),
      });
      final HandlerContext context = contextWith(storeWithRoster);

      final JsonMap raw = await handlers['getSessionAttendance']!(
        context,
        getSessionAttendancePayload(),
      );
      final AttendanceView view = AttendanceView.fromJson(raw);
      expect(view.session.status, SessionStatus.open);
      expect(view.session.rosterFrozen, isTrue);
      expect(view.session.date.toIso8601String(), '2026-05-10');
      expect(view.entries, hasLength(1));
      expect(view.entries.single.enrollmentId, _e1);
      expect(view.entries.single.studentId, _s1);
      expect(view.entries.single.studentName, 'Aluna Congelada');
      expect(view.entries.single.status, AttendanceStatus.unmarked);
    });

    test('an unfrozen session lists the currently eligible students', () async {
      final DirectStore storeWithEnrollment = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
        'congregations/c1/classes/$_classUuid/roster/$_e1':
            seededClassRosterEntry(
              enrollmentId: _e1,
              studentId: _s1,
              studentName: 'Aluna Ativa',
            ),
      });
      final HandlerContext ctx = contextWith(storeWithEnrollment);

      final AttendanceView view = AttendanceView.fromJson(
        await handlers['getSessionAttendance']!(ctx, getSessionAttendancePayload()),
      );

      expect(view.session.rosterFrozen, isFalse);
      expect(view.entries, hasLength(1));
      expect(view.entries.single.enrollmentId, _e1);
      expect(view.entries.single.studentId, _s1);
      expect(view.entries.single.studentName, 'Aluna Ativa');
      expect(view.entries.single.status, AttendanceStatus.unmarked);
    });

    test('an unfrozen session excludes students outside their enrollment window',
        () async {
      final DirectStore storeWithWindows = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        // Starts after the session date.
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
          startDate: '2026-06-01',
        ),
        // Ended before the session date.
        'congregations/c1/enrollments/$_e2': seededEnrollment(
          id: _e2,
          studentId: _s2,
          endDate: '2026-04-30',
        ),
      });
      final HandlerContext ctx = contextWith(storeWithWindows);

      final AttendanceView view = AttendanceView.fromJson(
        await handlers['getSessionAttendance']!(ctx, getSessionAttendancePayload()),
      );

      expect(view.entries, isEmpty);
    });

    test('reading an unfrozen session does not freeze the roster', () async {
      final DirectStore storeWithEnrollment = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/sessions/$_sessionUuid': seededSession(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
      });
      final HandlerContext ctx = contextWith(storeWithEnrollment);

      await handlers['getSessionAttendance']!(ctx, getSessionAttendancePayload());

      final JsonMap? session = await storeWithEnrollment.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['rosterFrozen'], isFalse);
      final List<JsonMap> roster = await storeWithEnrollment.query(
        const StoreQuery(
          collection: 'congregations/c1/sessions/'
              '22111111-2222-4333-8444-555555555555/roster',
        ),
      );
      expect(roster, isEmpty);
    });

    test('reads merge the current marks into the roster', () async {
      final HandlerContext context = contextWith(store);
      await handlers['saveAttendance']!(context, saveAttendancePayload(
        expectedRevision: 1,
        marks: <String, AttendanceStatus>{_e1: AttendanceStatus.excused},
      ));

      final AttendanceView view = AttendanceView.fromJson(
        await handlers['getSessionAttendance']!(context, getSessionAttendancePayload()),
      );
      expect(view.entries.single.status, AttendanceStatus.excused);
      expect(view.entries.single.studentName, 'Aluna Congelada');
    });

    test('session attendance lookup fails for a missing session', () async {
      final HandlerContext context = contextWith(store);
      await expectLater(
        handlers['getSessionAttendance']!(
          context,
          getSessionAttendancePayload(sessionId: 'missing'),
        ),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.notFound)),
      );
    });
  });

  group('progress aggregation', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
          startDate: '2026-03-01',
          endDate: '2026-12-31',
        ),
        ...progressSessionSeeds(),
      });
      handlers = attendanceHandlers();
    });

    test('aggregates finalized in-window sessions into 75 percent', () async {
      final HandlerContext context = contextWith(store);
      final JsonMap raw = await handlers['getEnrollmentProgress']!(
        context,
        getEnrollmentProgressPayload(enrollmentId: _e1),
      );
      final EnrollmentProgressView view = EnrollmentProgressView.fromJson(raw);
      expect(view.enrollmentId, _e1);
      expect(view.classId, _classUuid);
      expect(view.present, 3);
      expect(view.absent, 1);
      expect(view.excused, 2);
      expect(view.percentage, 75);
    });

    test('misses the mark on a session whose roster lacks the enrollment', () async {
      final DirectStore storeWithForeign = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
        'congregations/c1/sessions/$_sessionUuid': seededSession(
          status: 'finalized',
          rosterFrozen: true,
        ),
        'congregations/c1/sessions/$_sessionUuid/attendance/$_e1':
            seededAttendance(
              sessionId: _sessionUuid,
              enrollmentId: _e1,
              status: AttendanceStatus.present.wire,
            ),
      });
      final HandlerContext context = contextWith(storeWithForeign);
      final EnrollmentProgressView view = EnrollmentProgressView.fromJson(
        await handlers['getEnrollmentProgress']!(
          context,
          getEnrollmentProgressPayload(enrollmentId: _e1),
        ),
      );
      expect(view.present, 0);
      expect(view.absent, 0);
      expect(view.percentage, isNull);
    });

    test('a zero denominator yields a null percentage', () async {
      final DirectStore quietStore = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
        'congregations/c1/enrollments/$_e1': seededEnrollment(
          id: _e1,
          studentId: _s1,
        ),
        'congregations/c1/sessions/$_sessionUuid': seededSession(
          status: 'finalized',
          rosterFrozen: true,
        ),
        'congregations/c1/sessions/$_sessionUuid/roster/$_e1':
            seededSessionRosterEntry(
              sessionId: _sessionUuid,
              enrollmentId: _e1,
              studentId: _s1,
            ),
      });
      final HandlerContext context = contextWith(quietStore);
      final EnrollmentProgressView view = EnrollmentProgressView.fromJson(
        await handlers['getEnrollmentProgress']!(
          context,
          getEnrollmentProgressPayload(enrollmentId: _e1),
        ),
      );
      expect(view.present, 0);
      expect(view.absent, 0);
      expect(view.percentage, isNull);
    });

    test('progress lookup fails for a missing enrollment', () async {
      final HandlerContext context = contextWith(store);
      await expectLater(
        handlers['getEnrollmentProgress']!(
          context,
          getEnrollmentProgressPayload(enrollmentId: 'missing'),
        ),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.notFound)),
      );
    });
  });
}