import 'package:discipulado_ieadpe/data/direct_store.dart';
import 'package:discipulado_ieadpe/data/handlers/overview.dart';
import 'package:discipulado_ieadpe/data/query_codec.dart';
import 'package:discipulado_ieadpe/data/transport_support.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/domain/validation.dart';
import 'package:discipulado_ieadpe/features/overview/overview_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const String _classUuid = 'f3e2d1c0-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _c1ClassUuid = 'f3e2d1c0-abcd-46ae-9f0e-6c7f1a2b3c4d';
const String _c2ClassUuid = 'cccccccc-abcd-46ae-9f0e-6c7f1a2b3c4d';

DateTime _now() => DateTime.utc(2026, 9, 21, 12);

HandlerContext contextWith(
  DirectStore store, {
  String uid = 'u1',
  DateTime? now,
}) =>
    HandlerContext(
      store: store,
      uid: uid,
      now: now ?? _now(),
    );

JsonMap seededCongregation(String id) => <String, Object?>{
  'id': id,
  'name': id == 'c1' ? 'Abra' : 'Camboas',
  'normalizedName': id == 'c1' ? 'abra' : 'camboas',
  'active': true,
  'revision': 1,
  'createdAt': '2025-01-01T12:00:00.000Z',
  'updatedAt': '2025-01-01T12:00:00.000Z',
  'updatedBy': 'u0',
};

JsonMap seededStudent(String id, String congregationId, {bool archived = false}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'name': 'Aluno $id',
      'normalizedName': 'aluno $id',
      'phone': null,
      'classId': null,
      'archived': archived,
      'revision': 1,
      'createdAt': '2026-02-01T12:00:00.000Z',
      'updatedAt': '2026-02-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededClass({
  required String id,
  required String congregationId,
  String status = 'active',
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'name': 'Turma $id',
      'normalizedName': 'turma $id',
      'teacherContactId': null,
      'startDate': '2026-01-01',
      'endDate': '2026-12-31',
      'status': status,
      'enrollmentCount': 0,
      'activeEnrollmentCount': 0,
      'revision': 1,
      'createdAt': '2026-01-01T12:00:00.000Z',
      'updatedAt': '2026-01-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap seededSession({
  required String id,
  required String congregationId,
  String classId = _classUuid,
  String date = '2026-09-20',
  String status = 'open',
  Object? topic,
}) =>
    <String, Object?>{
      'id': id,
      'congregationId': congregationId,
      'classId': classId,
      'date': date,
      'topic': topic,
      'status': status,
      'rosterFrozen': false,
      'revision': 1,
      'createdAt': '2026-08-01T12:00:00.000Z',
      'updatedAt': '2026-08-01T12:00:00.000Z',
      'updatedBy': 'u0',
    };

JsonMap getOverviewPayload({Object? congregationId = 'c1'}) =>
    <String, Object?>{'congregationId': congregationId};

Map<String, JsonMap> c1CountsSeeds() => <String, JsonMap>{
  'congregations/c1': seededCongregation('c1'),
  'congregations/c1/students/s-1': seededStudent('s-1', 'c1'),
  'congregations/c1/students/s-2': seededStudent('s-2', 'c1'),
  'congregations/c1/students/s-3': seededStudent('s-3', 'c1', archived: true),
  'congregations/c1/classes/$_c1ClassUuid': seededClass(
    id: _c1ClassUuid,
    congregationId: 'c1',
  ),
  'congregations/c1/classes/c2-class': seededClass(
    id: 'c2-class',
    congregationId: 'c1',
    status: 'completed',
  ),
  'congregations/c1/sessions/s-today': seededSession(
    id: 's-today',
    congregationId: 'c1',
    date: '2026-09-21',
  ),
  'congregations/c1/sessions/s-yesterday': seededSession(
    id: 's-yesterday',
    congregationId: 'c1',
    date: '2026-09-20',
  ),
  'congregations/c1/sessions/s-tomorrow': seededSession(
    id: 's-tomorrow',
    congregationId: 'c1',
    date: '2026-09-22',
  ),
  'congregations/c1/sessions/s-finalized': seededSession(
    id: 's-finalized',
    congregationId: 'c1',
    date: '2026-09-01',
    status: 'finalized',
  ),
  'congregations/c1/sessions/s-canceled': seededSession(
    id: 's-canceled',
    congregationId: 'c1',
    date: '2026-09-02',
    status: 'canceled',
  ),
};

Map<String, JsonMap> c2CountsSeeds() => <String, JsonMap>{
  'congregations/c2': seededCongregation('c2'),
  'congregations/c2/students/s-4': seededStudent('s-4', 'c2'),
  'congregations/c2/classes/$_c2ClassUuid': seededClass(
    id: _c2ClassUuid,
    congregationId: 'c2',
  ),
  'congregations/c2/sessions/s-c2': seededSession(
    id: 's-c2',
    congregationId: 'c2',
    date: '2026-09-19',
  ),
};

JsonMap listPendingPayload({
  Object? congregationId = 'c1',
  Object? limit = 50,
  Object? cursor,
}) =>
    <String, Object?>{
      'congregationId': congregationId,
      'limit': limit,
      'cursor': cursor,
    };

Map<String, JsonMap> pendingSeeds() => <String, JsonMap>{
  'congregations/c1': seededCongregation('c1'),
  'congregations/c1/classes/$_c1ClassUuid': seededClass(
    id: _c1ClassUuid,
    congregationId: 'c1',
  ),
  for (final String id in <String>['a', 'b', 'c', 'd', 'e'])
    'congregations/c1/sessions/id-$id': seededSession(
      id: 'id-$id',
      congregationId: 'c1',
      date: '2026-06-0${id.codeUnitAt(0) - 96}',
    ),
  'congregations/c1/sessions/future': seededSession(
    id: 'future',
    congregationId: 'c1',
    date: '2026-12-30',
  ),
  'congregations/c1/sessions/summary-away': seededSession(
    id: 'summary-away',
    congregationId: 'c1',
    date: '2026-06-06',
    status: 'finalized',
  ),
};

String encodedCursor({
  String? congregationId = 'c1',
  String fingerprint = 'status=open;',
  String orderBy = 'date',
  String lastSortValue = '2026-06-02',
  String lastId = 'id-b',
}) =>
    const QueryCodec().encodeCursor(
      QueryCursor(
        resource: QueryResource.sessions,
        congregationId: congregationId,
        filterFingerprint: fingerprint,
        orderBy: orderBy,
        lastId: lastId,
        lastSortValue: lastSortValue,
      ),
    );

void main() {
  group('overview handlers', () {
    late DirectStore store;
    late Map<String, DirectOperationHandler> handlers;

    setUp(() {
      store = InMemoryDirectStore(<String, JsonMap>{
        ...c1CountsSeeds(),
      });
      handlers = overviewHandlers();
    });

    test('registry exposes the overview operations', () {
      expect(
        handlers.keys,
        containsAll(<String>['getOverview', 'listPendingSessions']),
      );
    });

    test('scoped counts are exact through the injected clock', () async {
      final HandlerContext context = contextWith(store);
      final JsonMap raw = await handlers['getOverview']!(
        context,
        getOverviewPayload(),
      );
      final OverviewCounts counts = OverviewCounts.fromJson(raw);
      expect(counts.students, 2);
      expect(counts.classes, 1);
      expect(counts.openSessions, 2);
      expect(
        counts.throughDate,
        recifeToday(_now()),
      );
      expect(counts.throughDate.toIso8601String(), '2026-09-21');
    });

    test('open sessions are bounded by the Recife through date', () async {
      final HandlerContext context = contextWith(store);
      final OverviewCounts counts = OverviewCounts.fromJson(
        await handlers['getOverview']!(context, getOverviewPayload()),
      );
      expect(counts.openSessions, 2);
      final JsonMap? tomorrow = await store.read(
        'congregations/c1/sessions/s-tomorrow',
      );
      expect(tomorrow, isNotNull);
    });

    test('null scope aggregates across congregations', () async {
      final DirectStore allStore = InMemoryDirectStore(<String, JsonMap>{
        ...c1CountsSeeds(),
        ...c2CountsSeeds(),
      });
      final HandlerContext context = contextWith(allStore);
      final OverviewCounts counts = OverviewCounts.fromJson(
        await handlers['getOverview']!(
          context,
          getOverviewPayload(congregationId: null),
        ),
      );
      expect(counts.students, 3);
      expect(counts.classes, 2);
      expect(counts.openSessions, 3);
    });

    test('listPendingSessions pages open sessions by date then id', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final JsonMap raw = await handlers['listPendingSessions']!(
        context,
        listPendingPayload(limit: 3),
      );
      expect(raw['nextCursor'], isA<String>());
      final PendingSessionPage page = PendingSessionPage(
        items: (raw['items']! as List<Object?>)
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) => PendingSessionEntry.fromJson(
                Map<String, Object?>.from(item),
              ),
            )
            .toList(growable: false),
        nextCursor: raw['nextCursor'] as String?,
      );
      expect(
        page.items.map((PendingSessionEntry entry) => entry.id),
        <String>['id-a', 'id-b', 'id-c'],
      );
      expect(
        page.items.map((PendingSessionEntry entry) => entry.className),
        <String?>['Turma $_c1ClassUuid', 'Turma $_c1ClassUuid', 'Turma $_c1ClassUuid'],
      );
      expect(page.nextCursor, isNotNull);
    });

    test('a second page continues after the encoded cursor', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final List<String> ids = <String>[];
      String? cursor;
      while (true) {
        final JsonMap raw = await handlers['listPendingSessions']!(
          context,
          listPendingPayload(limit: 2, cursor: cursor),
        );
        final PendingSessionPage page = PendingSessionPage(
          items: (raw['items']! as List<Object?>)
              .whereType<Map<Object?, Object?>>()
              .map(
                (Map<Object?, Object?> item) => PendingSessionEntry.fromJson(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false),
          nextCursor: raw['nextCursor'] as String?,
        );
        ids.addAll(page.items.map((PendingSessionEntry entry) => entry.id));
        cursor = page.nextCursor;
        if (cursor == null) {
          break;
        }
      }
      expect(
        ids,
        <String>['id-a', 'id-b', 'id-c', 'id-d', 'id-e'],
      );
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('no trailing cursor when the page is fully consumed', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final JsonMap raw = await handlers['listPendingSessions']!(
        context,
        listPendingPayload(limit: 50),
      );
      expect(raw['items'], hasLength(5));
      expect(raw['nextCursor'], isNull);
    });

    test('empty results page cleanly', () async {
      final DirectStore quietStore = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation('c1'),
      });
      final HandlerContext context = contextWith(quietStore);
      final JsonMap raw = await handlers['listPendingSessions']!(
        context,
        listPendingPayload(limit: 5),
      );
      expect(raw['items'], <Object?>[]);
      expect(raw['nextCursor'], isNull);
    });

    test('a date in the future or a non-open status is never pending', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final JsonMap raw = await handlers['listPendingSessions']!(
        context,
        listPendingPayload(limit: 50),
      );
      final List<Object?> items = raw['items']! as List<Object?>;
      expect(items, hasLength(5));
      for (final Object? item in items) {
        final Map<String, Object?> map = Map<String, Object?>.from(
          item! as Map<Object?, Object?>,
        );
        expect(map['status'], 'open');
        expect(
          (map['date']! as String).compareTo('2026-09-21') <= 0,
          isTrue,
        );
      }
    });

    test('a missing class document yields a null className', () async {
      final DirectStore orphanStore = InMemoryDirectStore(<String, JsonMap>{
        'congregations/c1': seededCongregation('c1'),
        'congregations/c1/sessions/id-a': seededSession(
          id: 'id-a',
          congregationId: 'c1',
          classId: 'missing-class',
          date: '2026-09-20',
        ),
      });
      final HandlerContext context = contextWith(orphanStore);
      final JsonMap raw = await handlers['listPendingSessions']!(
        context,
        listPendingPayload(limit: 5),
      );
      final List<Object?> items = raw['items']! as List<Object?>;
      final PendingSessionEntry entry = PendingSessionEntry.fromJson(
        Map<String, Object?>.from(items.single! as Map<Object?, Object?>),
      );
      expect(entry.className, isNull);
    });

    test('a cursor from another scope is rejected', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final String foreignCursor = encodedCursor(congregationId: 'c2');
      await expectLater(
        handlers['listPendingSessions']!(
          context,
          listPendingPayload(limit: 2, cursor: foreignCursor),
        ),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('a cursor for another filter identity is rejected', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final String forgedCursor = encodedCursor(
        fingerprint: 'status=finalized;',
        lastSortValue: '2026-09-25',
      );
      await expectLater(
        handlers['listPendingSessions']!(
          context,
          listPendingPayload(limit: 2, cursor: forgedCursor),
        ),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('a cursor with another order field is rejected', () async {
      final DirectStore pendingStore = InMemoryDirectStore(<String, JsonMap>{
        ...pendingSeeds(),
      });
      final HandlerContext context = contextWith(pendingStore);
      final String misorderedCursor = encodedCursor(
        orderBy: 'id',
        lastId: 'id-x',
      );
      await expectLater(
        handlers['listPendingSessions']!(
          context,
          listPendingPayload(limit: 2, cursor: misorderedCursor),
        ),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.conflict)),
      );
    });

    test('limit must stay within 1 and 100', () async {
      final HandlerContext context = contextWith(store);
      await expectLater(
        handlers['listPendingSessions']!(context, listPendingPayload(limit: 0)),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
      await expectLater(
        handlers['listPendingSessions']!(
          context,
          listPendingPayload(limit: 101),
        ),
        throwsA(isA<AppFailure>()
            .having((AppFailure f) => f.code, 'code', AppFailureCode.validation)),
      );
    });

    test('null scope pending pages across congregations with own class names', () async {
      final DirectStore allStore = InMemoryDirectStore(<String, JsonMap>{
        ...c1CountsSeeds(),
        ...c2CountsSeeds(),
        'congregations/c2/sessions/id-c2': seededSession(
          id: 'id-c2',
          congregationId: 'c2',
          classId: _c2ClassUuid,
          date: '2026-09-18',
        ),
      });
      final HandlerContext context = contextWith(allStore);
      final JsonMap raw = await handlers['listPendingSessions']!(
        context,
        listPendingPayload(congregationId: null, limit: 50),
      );
      final List<Object?> items = raw['items']! as List<Object?>;
      expect(items, hasLength(4));
      final PendingSessionEntry c2Entry = PendingSessionEntry.fromJson(
        Map<String, Object?>.from(items.first! as Map<Object?, Object?>),
      );
      expect(c2Entry.congregationId, 'c2');
      expect(c2Entry.className, 'Turma $_c2ClassUuid');
      expect(c2Entry.date.toIso8601String(), '2026-09-18');
    });
  });
}