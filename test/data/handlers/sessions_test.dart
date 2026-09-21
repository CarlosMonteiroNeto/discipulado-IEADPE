import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/sessions.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/academic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const String _sessionUuid = '22111111-2222-4333-8444-555555555555';
const String _secondSessionUuid = '22aaaaaa-1111-4222-8333-555555555555';
const String _classUuid = 'f3e2d1c0-abcd-46ae-9f0e-6c7f1a2b3c4d';

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

JsonMap createSessionPayload({
  String id = _sessionUuid,
  String congregationId = 'c1',
  String classId = _classUuid,
  String date = '2026-05-10',
  Object? topic,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'classId': classId,
      'date': date,
      'topic': topic,
      'requestId': 'req-x',
    };

JsonMap cancelSessionPayload({
  String id = _sessionUuid,
  String congregationId = 'c1',
  String classId = _classUuid,
  String status = 'canceled',
  int expectedRevision = 1,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'classId': classId,
      'status': status,
      'expectedRevision': expectedRevision,
      'requestId': 'req-cancel',
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
      'enrollmentCount': 0,
      'activeEnrollmentCount': 0,
      'revision': 1,
      'createdAt': '2025-01-01T12:00:00.000Z',
      'updatedAt': '2025-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededSession({
  String id = _sessionUuid,
  String status = 'open',
  int revision = 1,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': 'c1',
      'classId': _classUuid,
      'date': '2026-05-10',
      'topic': 'Tema',
      'status': status,
      'rosterFrozen': false,
      'revision': revision,
      'createdAt': '2026-04-01T12:00:00.000Z',
      'updatedAt': '2026-04-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

void main() {
  group('session handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;
    late HandlerContext context;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation(),
        'congregations/c1/classes/$_classUuid': seededClass(),
      });
      handlers = sessionsHandlers();
      context = contextWith(store);
    });

    test('exposes createSession and cancelSession', () {
      expect(
        handlers.keys,
        containsAll(<String>['createSession', 'cancelSession']),
      );
    });

    test('creates an open session and returns revision 1', () async {
      final JsonMap result = await handlers['createSession']!(
        context,
        createSessionPayload(topic: 'Secção 1'),
      );

      expect(result, <String, Object?>{'id': _sessionUuid, 'revision': 1});
      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['id'], _sessionUuid);
      expect(session?['congregationId'], 'c1');
      expect(session?['classId'], _classUuid);
      expect(session?['date'], '2026-05-10');
      expect(session?['topic'], 'Secção 1');
      expect(session?['status'], 'open');
      expect(session?['rosterFrozen'], false);
      expect(session?['revision'], 1);
      expect(session?['updatedBy'], 'u1');
    });

    test('trims an empty topic to null', () async {
      final JsonMap result = await handlers['createSession']!(
        context,
        createSessionPayload(topic: '   '),
      );

      expect(result['revision'], 1);
      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['topic'], isNull);
    });

    test('the createSession result decodes as AcademicMutationResult',
        () async {
      final JsonMap result =
          await handlers['createSession']!(context, createSessionPayload());

      final AcademicMutationResult decoded =
          AcademicMutationResult.fromJson(result);
      expect(decoded.id, _sessionUuid);
      expect(decoded.revision, 1);
    });

    test('rejects a non-UUID id', () async {
      await expectLater(
        handlers['createSession']!(context, createSessionPayload(id: 'x')),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.validation,
          ),
        ),
      );
    });

    test('rejects a missing class', () async {
      await expectLater(
        handlers['createSession']!(
          context,
          createSessionPayload(classId: '01234567-89ab-4cde-8f01-23456789abcd'),
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

    test('rejects a class that is not active', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(status: 'completed'),
      );
      await expectLater(
        handlers['createSession']!(context, createSessionPayload()),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects a date outside the class period', () async {
      await expectLater(
        handlers['createSession']!(
          context,
          createSessionPayload(date: '2027-02-01'),
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

    test('rejects an over-long topic', () async {
      await expectLater(
        handlers['createSession']!(
          context,
          createSessionPayload(topic: 'x' * 201),
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

    test('rejects a duplicate noncanceled session for class and date',
        () async {
      store.write(
        'congregations/c1/sessions/$_secondSessionUuid',
        seededSession(id: _secondSessionUuid),
      );
      await expectLater(
        handlers['createSession']!(context, createSessionPayload()),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('allows a new session in place of a canceled one', () async {
      store.write(
        'congregations/c1/sessions/$_secondSessionUuid',
        seededSession(id: _secondSessionUuid, status: 'canceled'),
      );

      final JsonMap result =
          await handlers['createSession']!(context, createSessionPayload());
      expect(result['revision'], 1);
    });

    test('creates no date-lock, index or receipt documents', () async {
      await handlers['createSession']!(context, createSessionPayload());

      final JsonMap? dateLock = await store.read(
        'congregations/c1/classes/$_classUuid/internal/sessionDates/2026-05-10',
      );
      expect(dateLock, isNull);
      final JsonMap? sessionIndex = await store.read(
        'congregations/c1/classes/$_classUuid/internal/sessionIndex',
      );
      expect(sessionIndex, isNull);
      final List<JsonMap> receipts = await store.query(
        const StoreQuery(collection: 'operations', group: true),
      );
      expect(receipts, isEmpty);
    });

    test('cancelSession cancels and keeps the roster and attendance',
        () async {
      store.write(
        'congregations/c1/sessions/$_sessionUuid',
        seededSession(),
      );
      store.write(
        'congregations/c1/sessions/$_sessionUuid/roster/e1',
        <String, Object?>{
          'id': 'e1',
          'enrollmentId': 'e1',
          'studentId': 's1',
          'studentName': 'Aluno',
          'revision': 1,
        },
      );
      store.write(
        'congregations/c1/sessions/$_sessionUuid/attendance/e1',
        <String, Object?>{
          'id': 'e1',
          'enrollmentId': 'e1',
          'studentId': 's1',
          'status': 'present',
          'revision': 1,
        },
      );

      final JsonMap result = await handlers['cancelSession']!(
        context,
        cancelSessionPayload(),
      );

      expect(result, <String, Object?>{'id': _sessionUuid, 'revision': 2});
      final JsonMap? session = await store.read(
        'congregations/c1/sessions/$_sessionUuid',
      );
      expect(session?['status'], 'canceled');
      expect(session?['rosterFrozen'], false);
      expect(session?['revision'], 2);
      expect(session?['updatedBy'], 'u1');
      final JsonMap? rosterEntry = await store.read(
        'congregations/c1/sessions/$_sessionUuid/roster/e1',
      );
      expect(rosterEntry?['enrollmentId'], 'e1');
      final JsonMap? attendanceEntry = await store.read(
        'congregations/c1/sessions/$_sessionUuid/attendance/e1',
      );
      expect(attendanceEntry?['status'], 'present');
    });

    test('cancelSession is a no-op for an already-canceled session', () async {
      store.write(
        'congregations/c1/sessions/$_sessionUuid',
        seededSession(status: 'canceled', revision: 2),
      );
      final JsonMap result = await handlers['cancelSession']!(
        context,
        cancelSessionPayload(expectedRevision: 2),
      );

      expect(result, <String, Object?>{'id': _sessionUuid, 'revision': 2});
    });

    test('cancelSession rejects a stale expected revision', () async {
      store.write(
        'congregations/c1/sessions/$_sessionUuid',
        seededSession(revision: 2),
      );
      await expectLater(
        handlers['cancelSession']!(context, cancelSessionPayload()),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });

    test('cancelSession missing session is a notFound failure', () async {
      await expectLater(
        handlers['cancelSession']!(
          context,
          cancelSessionPayload(id: _secondSessionUuid),
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

    test('cancelSession refuses sessions of a completed class', () async {
      store.write(
        'congregations/c1/classes/$_classUuid',
        seededClass(status: 'completed'),
      );
      store.write(
        'congregations/c1/sessions/$_sessionUuid',
        seededSession(),
      );
      await expectLater(
        handlers['cancelSession']!(context, cancelSessionPayload()),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            AppFailureCode.conflict,
          ),
        ),
      );
    });
  });
}