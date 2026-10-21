import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_list.dart';

const congregationId = '33333333-3333-4333-8333-333333333333';
const classAId = '22222222-2222-4222-8222-222222222222';
const classBId = '99999999-9999-4999-8999-999999999997';
const sessionId = '55555555-5555-4555-8555-555555555555';
const otherSessionId = '77777777-7777-4777-8777-777777777777';
const opId = '88888888-8888-4888-8888-888888888888';
const actorId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherCongregationId = '44444444-4444-4444-8444-444444444444';
const attendanceMismatchError =
    'A aula retornada não corresponde ao contexto atual. Atualize os dados e tente novamente.';

DateTime lessonDate(int index) =>
    DateTime.utc(2026, 1, 1).add(Duration(days: index));

String wireDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String lessonId(int index) =>
    '${(index + 1).toString().padLeft(8, '0')}-0000-4000-8000-000000000000';

Map<String, dynamic> lesson(int index) => {
  'id': lessonId(index),
  'class_id': classAId,
  'congregation_id': congregationId,
  'date': wireDate(lessonDate(index)),
  'topic': 'Lição $index',
  'status': 'open',
  'revision': 1,
  'replaces_session_id': null,
  'replacement_session_id': null,
};

typedef Captured = ({String operationId, Map<String, Object?> payload});

class _SessionGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String value) {
    if (value != context) throw const DataFailure('stale');
  }

  final createCalls = <Captured>[];
  final cancelCalls = <Captured>[];
  final sessions = <Map<String, dynamic>>[];
  final readRequests = <Map<String, Object?>>[];
  Completer<Map<String, dynamic>>? delayedCommand;
  String? rejection;
  bool lostResponse = false;
  bool failAttendance = false;
  String? attendanceSessionId;
  String? attendanceClassId;
  String? attendanceCongregationId;
  final failListReads = <int>{};
  int revision = 7;
  int pageReads = 0;
  int listPageSize = 1;
  bool overlapPages = false;
  Completer<void>? delayedAppendRead;

  Map<String, dynamic> session(String id, {String status = 'open'}) => {
    'id': id,
    'class_id': classAId,
    'congregation_id': congregationId,
    'date': '2026-12-20',
    'topic': 'Lição',
    'status': status,
    'revision': revision,
    'replaces_session_id': null,
    'replacement_session_id': null,
  };

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    readRequests.add({'rpc': rpc, ...parameters});
    if (rpc == 'ministry_list_class_sessions') {
      pageReads++;
      if (failListReads.remove(pageReads)) {
        throw const DataFailure('unavailable');
      }
      final cursor = parameters['cursor'];
      if (cursor != null) {
        final delay = delayedAppendRead;
        if (delay != null) {
          delayedAppendRead = null;
          await delay.future;
        }
      }
      final offset = cursor == null ? 0 : int.parse(cursor as String);
      final start = overlapPages && offset > 0 ? offset - 1 : offset;
      final end = offset + listPageSize < sessions.length
          ? offset + listPageSize
          : sessions.length;
      return {
        'items': List<Map<String, dynamic>>.from(sessions.sublist(start, end)),
        'next_cursor': end < sessions.length ? '$end' : null,
      };
    }
    if (rpc == 'ministry_get_session_attendance') {
      if (failAttendance) {
        failAttendance = false;
        throw const DataFailure('unavailable');
      }
      final current = sessions.firstWhere(
        (s) => s['id'] == parameters['session_id'],
        orElse: () => session(sessionId),
      );
      return {
        'session': {
          'id': attendanceSessionId ?? current['id'],
          'congregation_id': attendanceCongregationId ?? congregationId,
          'class_id': attendanceClassId ?? classAId,
          'date': current['date'],
          'topic': current['topic'],
          'status': current['status'],
          'roster_frozen': false,
          'lesson_index': null,
          'lesson_part': null,
          'lesson_finished': false,
          'revision': revision,
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
          'updated_by': actorId,
        },
        'roster': [],
      };
    }
    throw UnimplementedError(rpc);
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String name,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    final call = (
      operationId: operationId,
      payload: Map<String, Object?>.unmodifiable(payload),
    );
    (name == 'create_session' ? createCalls : cancelCalls).add(call);
    final wait = delayedCommand;
    if (wait != null) {
      delayedCommand = null;
      return wait.future;
    }
    if (rejection case final code?) {
      rejection = null;
      if (code == 'stale_revision') revision++;
      throw DataFailure(code);
    }
    if (lostResponse) {
      lostResponse = false;
      throw const DataFailure('unavailable');
    }
    if (name == 'create_session' &&
        sessions.any(
          (s) => s['date'] == payload['date'] && s['status'] != 'canceled',
        )) {
      throw const DataFailure('academic_conflict');
    }
    if (name == 'create_session') {
      sessions.add(session(payload['id']! as String));
    }
    if (name == 'cancel_session') {
      final target = sessions.firstWhere((s) => s['id'] == payload['id']);
      target['status'] = 'canceled';
    }
    return {'id': payload['id'], 'revision': revision + 1};
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => throw UnimplementedError(table);
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError(command);
  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

MinistryClassSummary cls(
  String id, {
  ClassStatus status = ClassStatus.active,
}) => MinistryClassSummary(
  id: id,
  name: id == classAId ? 'Turma A' : 'Turma B',
  status: status,
  startDate: '2026-10-01',
  endDate: null,
  revision: 1,
  teacherContactId: null,
);

Widget _listApp(
  _SessionGateway gateway, {
  MinistryClassSummary? classSummary,
  Future<void> Function(String)? opened,
}) {
  final summary = classSummary ?? cls(classAId);
  return MaterialApp(
    home: SessionListPage(
      key: ValueKey(summary.status),
      repository: MinistryRepository(gateway),
      congregationId: congregationId,
      classSummary: summary,
      onOpenSession: opened ?? (_) async {},
    ),
  );
}

void main() {
  testWidgets('create class-bound dated lesson', (tester) async {
    final gateway = _SessionGateway();
    final opened = <String>[];
    await tester.pumpWidget(
      _listApp(gateway, opened: (id) async => opened.add(id)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(gateway.createCalls.single.payload['class_id'], classAId);
    expect(
      gateway.createCalls.single.payload['congregation_id'],
      congregationId,
    );
    expect(gateway.createCalls.single.payload['date'], '2026-12-20');
    expect(opened, [gateway.createCalls.single.payload['id']]);
  });

  testWidgets('session uses selected class', (tester) async {
    final gateway = _SessionGateway();
    await tester.pumpWidget(_listApp(gateway, classSummary: cls(classBId)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(gateway.createCalls.single.payload['class_id'], classBId);
  });

  testWidgets('future lesson remains listed after reload', (tester) async {
    final gateway = _SessionGateway();
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    expect(find.text('20/12/2026'), findsOneWidget);
  });

  testWidgets('duplicate date is rejected', (tester) async {
    final gateway = _SessionGateway()
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 1,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(gateway.createCalls, isEmpty);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('cancel preserves roster history', (tester) async {
    final gateway = _SessionGateway()
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 7,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Turma A · 20/12/2026 · Lição'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(gateway.cancelCalls, isEmpty);
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar aula'),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.cancelCalls.single.payload['expected_revision'], 7);
    expect(gateway.cancelCalls.single.payload['id'], sessionId);
    expect(find.textContaining('Cancelada'), findsOneWidget);
    expect(gateway.sessions.single['status'], 'canceled');
  });

  testWidgets('ambiguous create retains exact request', (tester) async {
    final gateway = _SessionGateway()..lostResponse = true;
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retry-pending-session-create')));
    await tester.pumpAndSettle();
    expect(
      gateway.createCalls.last.operationId,
      gateway.createCalls.first.operationId,
    );
    expect(gateway.createCalls.last.payload, gateway.createCalls.first.payload);
  });

  testWidgets('ambiguous cancel retains exact request', (tester) async {
    final gateway = _SessionGateway()
      ..lostResponse = true
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 7,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar aula'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-session')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-session')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-date')), findsNothing);
    expect(gateway.createCalls, isEmpty);
    await tester.tap(find.byKey(const Key('retry-pending-session-cancel')));
    await tester.pumpAndSettle();
    expect(
      gateway.cancelCalls.last.operationId,
      gateway.cancelCalls.first.operationId,
    );
    expect(gateway.cancelCalls.last.payload, gateway.cancelCalls.first.payload);
  });

  testWidgets(
    'open and finalized lessons can be canceled in historical classes',
    (tester) async {
      for (final status in [ClassStatus.completed, ClassStatus.archived]) {
        for (final sessionStatus in ['open', 'finalized', 'canceled']) {
          final gateway = _SessionGateway()
            ..sessions.add({
              'id': sessionId,
              'class_id': classAId,
              'congregation_id': congregationId,
              'date': '2026-12-20',
              'topic': 'Lição',
              'status': sessionStatus,
              'revision': 7,
              'replaces_session_id': null,
              'replacement_session_id': null,
            });
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            _listApp(gateway, classSummary: cls(classAId, status: status)),
          );
          await tester.pumpAndSettle();
          expect(find.text('20/12/2026'), findsOneWidget);
          if (sessionStatus == 'canceled') {
            expect(
              find.byKey(const Key('cancel-session-$sessionId')),
              findsNothing,
            );
            expect(gateway.cancelCalls, isEmpty);
            continue;
          }
          await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Cancelar aula'),
            ),
          );
          await tester.pumpAndSettle();
          expect(gateway.cancelCalls.single.payload['expected_revision'], 7);
          expect(gateway.sessions.single['status'], 'canceled');
        }
      }
    },
  );

  testWidgets('first page failure can be retried from the list', (
    tester,
  ) async {
    final gateway = _SessionGateway()
      ..failListReads.add(1)
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 1,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as aulas. Tente novamente.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('refresh-sessions')));
    await tester.pumpAndSettle();
    expect(gateway.readRequests.last['cursor'], isNull);
    expect(find.text('20/12/2026'), findsOneWidget);
  });

  testWidgets(
    'attendance read failure exposes list refresh and cancellation retry',
    (tester) async {
      final gateway = _SessionGateway()
        ..failAttendance = true
        ..sessions.add({
          'id': sessionId,
          'class_id': classAId,
          'congregation_id': congregationId,
          'date': '2026-12-20',
          'topic': 'Lição',
          'status': 'open',
          'revision': 1,
          'replaces_session_id': null,
          'replacement_session_id': null,
        });
      await tester.pumpWidget(_listApp(gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Não foi possível atualizar a aula. Atualize os dados e tente novamente.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('refresh-sessions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancelar aula'),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.cancelCalls, hasLength(1));
    },
  );

  testWidgets('empty class shows an explicit empty state', (tester) async {
    await tester.pumpWidget(_listApp(_SessionGateway()));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma aula registrada nesta turma.'), findsOneWidget);
  });

  testWidgets('detail open failure can recover through list refresh', (
    tester,
  ) async {
    final gateway = _SessionGateway()
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 1,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    var failDetail = true;
    await tester.pumpWidget(
      _listApp(
        gateway,
        opened: (_) async {
          if (failDetail) throw const DataFailure('unavailable');
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('20/12/2026'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível abrir a aula. Atualize e tente novamente.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('refresh-sessions')));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível abrir a aula. Atualize e tente novamente.'),
      findsNothing,
    );
    failDetail = false;
    await tester.tap(find.text('20/12/2026'));
    await tester.pumpAndSettle();
    expect(gateway.pageReads, 3);
  });

  testWidgets('stale cancellation reloads and requires renewed confirmation', (
    tester,
  ) async {
    final gateway = _SessionGateway()
      ..rejection = 'stale_revision'
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 7,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar aula'),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.cancelCalls.single.payload['expected_revision'], 7);
    expect(
      find.text(
        'A aula foi alterada. Atualize e confirme o cancelamento novamente.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('cancel-session-$sessionId')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar aula'),
      ),
    );
    await tester.pumpAndSettle();
    expect(gateway.cancelCalls, hasLength(2));
    expect(gateway.cancelCalls.last.payload['expected_revision'], 8);
    expect(
      gateway.cancelCalls.last.operationId,
      isNot(gateway.cancelCalls.first.operationId),
    );
  });

  testWidgets('session callback completes before list refresh', (tester) async {
    final gateway = _SessionGateway()
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 1,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    final callback = Completer<void>();
    await tester.pumpWidget(_listApp(gateway, opened: (_) => callback.future));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20/12/2026'));
    await tester.pump();
    expect(gateway.pageReads, 1);
    callback.complete();
    await tester.pumpAndSettle();
    expect(gateway.pageReads, 2);
  });

  testWidgets('changed input waits for pending operation resolution', (
    tester,
  ) async {
    final gateway = _SessionGateway()..lostResponse = true;
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '21/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(gateway.createCalls, hasLength(1));
    await tester.tap(find.byKey(const Key('retry-pending-session-create')));
    await tester.pumpAndSettle();
    expect(gateway.createCalls, hasLength(2));
    expect(
      gateway.createCalls.last.operationId,
      gateway.createCalls.first.operationId,
    );
    expect(gateway.createCalls.last.payload, gateway.createCalls.first.payload);
    expect(gateway.createCalls.last.payload['date'], '2026-12-20');
  });

  testWidgets('definite rejection permits corrected input', (tester) async {
    final gateway = _SessionGateway()..rejection = 'invalid';
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-date')), '21/12/2026');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(gateway.createCalls, hasLength(2));
    expect(gateway.createCalls.last.payload['date'], '2026-12-21');
    expect(
      gateway.createCalls.last.operationId,
      isNot(gateway.createCalls.first.operationId),
    );
  });

  testWidgets('historical class list is readable but cannot create', (
    tester,
  ) async {
    for (final status in [ClassStatus.completed, ClassStatus.archived]) {
      final gateway = _SessionGateway()
        ..sessions.add({
          'id': sessionId,
          'class_id': classAId,
          'congregation_id': congregationId,
          'date': '2026-12-20',
          'topic': 'Lição',
          'status': 'finalized',
          'revision': 1,
          'replaces_session_id': null,
          'replacement_session_id': null,
        });
      final opened = <String>[];
      await tester.pumpWidget(
        _listApp(
          gateway,
          classSummary: cls(classAId, status: status),
          opened: (id) async => opened.add(id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nova aula'), findsNothing);
      await tester.tap(find.text('20/12/2026'));
      await tester.pumpAndSettle();
      expect(opened, [sessionId]);
    }
    final gateway = _SessionGateway();
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    expect(find.text('Nova aula'), findsOneWidget);
  });

  testWidgets('pagination appends distinct rows and deduplicates overlaps', (
    tester,
  ) async {
    final gateway = _SessionGateway()
      ..overlapPages = true
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição',
        'status': 'open',
        'revision': 1,
        'replaces_session_id': null,
        'replacement_session_id': null,
      })
      ..sessions.add({
        'id': otherSessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-21',
        'topic': 'Outra lição',
        'status': 'open',
        'revision': 1,
        'replaces_session_id': null,
        'replacement_session_id': null,
      });
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('20/12/2026'), findsOneWidget);
    expect(find.text('21/12/2026'), findsOneWidget);
    expect(find.textContaining('Outra lição'), findsOneWidget);
  });

  testWidgets('open return refreshes through loaded pages and keeps offset', (
    tester,
  ) async {
    final gateway = _SessionGateway()..listPageSize = 50;
    for (var index = 0; index < 60; index++) {
      gateway.sessions.add(lesson(index));
    }
    final opened = <String>[];
    await tester.pumpWidget(
      _listApp(gateway, opened: (id) async => opened.add(id)),
    );
    await tester.pumpAndSettle();
    expect(gateway.pageReads, 1);
    await tester.scrollUntilVisible(
      find.text('Carregar mais'),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(gateway.pageReads, 2);

    final laterDate = displayDate(lessonDate(55));
    await tester.scrollUntilVisible(
      find.text(laterDate),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    final offsetBefore = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(offsetBefore, greaterThan(0));
    final readsBefore = gateway.readRequests
        .where((request) => request['rpc'] == 'ministry_list_class_sessions')
        .length;

    await tester.tap(find.text(laterDate));
    await tester.pumpAndSettle();

    expect(opened, [lessonId(55)]);
    final refreshReads = gateway.readRequests
        .where((request) => request['rpc'] == 'ministry_list_class_sessions')
        .skip(readsBefore)
        .toList();
    expect(refreshReads.map((request) => request['cursor']), [null, '50']);
    expect(find.text(laterDate), findsOneWidget);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      offsetBefore,
    );
  });

  testWidgets(
    'open during pending append restores refresh and pagination controls',
    (tester) async {
      final gateway = _SessionGateway()..listPageSize = 2;
      for (var index = 0; index < 4; index++) {
        gateway.sessions.add(lesson(index));
      }
      final opened = <String>[];
      await tester.pumpWidget(
        _listApp(gateway, opened: (id) async => opened.add(id)),
      );
      await tester.pumpAndSettle();
      expect(gateway.pageReads, 1);

      final appendGate = Completer<void>();
      gateway.delayedAppendRead = appendGate;
      await tester.tap(find.text('Carregar mais'));
      await tester.pump();
      expect(gateway.pageReads, 2);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Carregar mais'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text(displayDate(lessonDate(0))));
      await tester.pumpAndSettle();
      expect(opened, [lessonId(0)]);
      // Refresh re-reads only the rows already loaded.
      expect(gateway.pageReads, 3);

      appendGate.complete();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Atualizar aulas'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Carregar mais'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text(displayDate(lessonDate(3))), findsNothing);

      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();
      expect(gateway.pageReads, 4);
      await tester.scrollUntilVisible(
        find.text(displayDate(lessonDate(3))),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(displayDate(lessonDate(3))), findsOneWidget);
      expect(find.text('Carregar mais'), findsNothing);
    },
  );

  testWidgets('cancellation rejects attendance for another session id', (
    tester,
  ) async {
    final gateway = _SessionGateway()..attendanceSessionId = otherSessionId;
    gateway.sessions.add(gateway.session(sessionId));
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(gateway.cancelCalls, isEmpty);
    expect(find.text(attendanceMismatchError), findsOneWidget);
  });

  testWidgets('cancellation rejects attendance for another class', (
    tester,
  ) async {
    final gateway = _SessionGateway()..attendanceClassId = classBId;
    gateway.sessions.add(gateway.session(sessionId));
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(gateway.cancelCalls, isEmpty);
    expect(find.text(attendanceMismatchError), findsOneWidget);
  });

  testWidgets('cancellation rejects attendance for another congregation', (
    tester,
  ) async {
    final gateway = _SessionGateway()
      ..attendanceCongregationId = otherCongregationId;
    gateway.sessions.add(gateway.session(sessionId));
    await tester.pumpWidget(_listApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-session-$sessionId')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(gateway.cancelCalls, isEmpty);
    expect(find.text(attendanceMismatchError), findsOneWidget);
  });
}
