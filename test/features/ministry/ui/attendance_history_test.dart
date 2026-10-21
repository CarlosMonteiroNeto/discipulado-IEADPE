import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/domain/session_navigation_context.dart';
import 'package:ieadpe_converts/features/ministry/ui/attendance_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_list.dart';

const congregationId = '33333333-3333-4333-8333-333333333333';
const classId = '22222222-2222-4222-8222-222222222222';
const parentId = '55555555-5555-4555-8555-555555555555';
const childId = '55555555-5555-4555-8555-555555555556';
const externalChildId = '55555555-5555-4555-8555-555555555557';
const enrollmentA = '66666666-6666-4666-8666-666666666661';
const enrollmentB = '66666666-6666-4666-8666-666666666662';
const studentA = '77777777-7777-4777-8777-777777777771';
const studentB = '77777777-7777-4777-8777-777777777772';
const actorId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

typedef _CommandCall = ({
  String name,
  String operationId,
  Map<String, Object?> payload,
});

Map<String, Object?> _snapshot(Object? value) {
  final map = value is Map ? value : const <Object?, Object?>{};
  return <String, Object?>{
    for (final entry in map.entries)
      entry.key.toString(): entry.value is Map
          ? _snapshot(entry.value)
          : entry.value,
  };
}

Map<String, Object?> _sessionRow(
  String id, {
  required String date,
  required String? topic,
  String status = 'open',
  int revision = 1,
  bool rosterFrozen = true,
  List<Map<String, Object?>>? previewRoster,
  List<Map<String, Object?>>? storedRoster,
  String? replacesSessionId,
  String? replacementSessionId,
}) => <String, Object?>{
  'id': id,
  'class_id': classId,
  'congregation_id': congregationId,
  'date': date,
  'topic': topic,
  'status': status,
  'revision': revision,
  'roster_frozen': rosterFrozen,
  'preview_roster': ?previewRoster,
  'stored_roster': ?storedRoster,
  'replaces_session_id': replacesSessionId,
  'replacement_session_id': replacementSessionId,
};

Map<String, Object?> _sessionListProjection(Map<String, Object?> row) => {
  for (final key in const [
    'id',
    'class_id',
    'congregation_id',
    'date',
    'topic',
    'status',
    'revision',
    'replaces_session_id',
    'replacement_session_id',
  ])
    if (row.containsKey(key)) key: row[key],
};

class _HistoryGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String value) {
    if (value != context) throw const DataFailure('stale');
  }

  final sessions = <Map<String, Object?>>[];
  final commandCalls = <_CommandCall>[];
  final detailReads = <String>[];
  final saveOutcomes = <String>[];
  Completer<void>? saveGate;
  Completer<void>? cancelGate;
  Completer<void>? detailReadGate;
  String? delayedDetailSessionId;
  bool conflictOnCreate = false;
  String? ambiguousCreateOnce;
  int pageSize = 50;

  List<_CommandCall> get saveCalls =>
      commandCalls.where((call) => call.name == 'save_attendance').toList();
  List<_CommandCall> get createCalls =>
      commandCalls.where((call) => call.name == 'create_session').toList();
  List<_CommandCall> get cancelCalls =>
      commandCalls.where((call) => call.name == 'cancel_session').toList();

  Map<String, Object?> _find(String id) =>
      sessions.firstWhere((session) => session['id'] == id);

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    if (rpc == 'ministry_list_class_sessions') {
      final offset = parameters['cursor'] == null
          ? 0
          : int.parse(parameters['cursor']! as String);
      final end = offset + pageSize < sessions.length
          ? offset + pageSize
          : sessions.length;
      return <String, dynamic>{
        'items': <Map<String, Object?>>[
          for (final session in sessions.sublist(offset, end))
            _sessionListProjection(session),
        ],
        'next_cursor': end < sessions.length ? '$end' : null,
      };
    }
    if (rpc == 'ministry_get_session_attendance') {
      final sessionId = parameters['session_id']! as String;
      detailReads.add(sessionId);
      if (sessionId == delayedDetailSessionId) {
        await detailReadGate!.future;
      }
      final row = _find(sessionId);
      return <String, dynamic>{
        'session': <String, Object?>{
          'id': row['id'],
          'congregation_id': row['congregation_id'],
          'class_id': row['class_id'],
          'date': row['date'],
          'topic': row['topic'],
          'status': row['status'],
          'roster_frozen': row['roster_frozen'] ?? true,
          'lesson_index': null,
          'lesson_part': null,
          'lesson_finished': false,
          'revision': row['revision'],
          'replaces_session_id': row['replaces_session_id'],
          'replacement_session_id': row['replacement_session_id'],
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
          'updated_by': actorId,
        },
        'roster':
            (row['roster_frozen'] == false && row['status'] == 'open'
                    ? row['preview_roster'] as List<Map<String, Object?>>? ??
                          const <Map<String, Object?>>[]
                    : row['stored_roster'] as List<Map<String, Object?>>? ??
                          <Map<String, Object?>>[
                            <String, Object?>{
                              'enrollment_id': enrollmentA,
                              'student_id': studentA,
                              'student_name': 'Ana da Silva',
                              'status': 'present',
                            },
                            <String, Object?>{
                              'enrollment_id': enrollmentB,
                              'student_id': studentB,
                              'student_name': 'Bento Souza',
                              'status': 'absent',
                            },
                          ])
                .map(
                  (mark) => <String, Object?>{
                    'enrollment_id': mark['enrollment_id'],
                    'student_id': mark['student_id'],
                    'student_name': mark['student_name'],
                    'status': mark['status'],
                  },
                )
                .toList(),
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
    commandCalls.add((
      name: name,
      operationId: operationId,
      payload: _snapshot(payload),
    ));
    if (name == 'save_attendance') {
      final outcome = saveOutcomes.isEmpty
          ? 'success'
          : saveOutcomes.removeAt(0);
      final gate = saveGate;
      saveGate = null;
      if (gate != null) await gate.future;
      final row = _find(payload['session_id']! as String);
      if (outcome == 'unknown') throw const DataFailure('unavailable');
      if (outcome == 'stale') {
        row['revision'] = (row['revision']! as int) + 1;
        throw const DataFailure('stale_revision');
      }
      if (row['roster_frozen'] == false) {
        final preview =
            row['preview_roster'] as List<Map<String, Object?>>? ??
            const <Map<String, Object?>>[];
        final marks = payload['marks'] as Map<String, Object?>;
        row['stored_roster'] = <Map<String, Object?>>[
          for (final mark in preview)
            <String, Object?>{
              ...mark,
              'status': marks[mark['enrollment_id']] ?? mark['status'],
            },
        ];
        row['roster_frozen'] = true;
      }
      if (payload['finalize'] == true) row['status'] = 'finalized';
      row['revision'] = (row['revision']! as int) + 1;
      return <String, dynamic>{
        'id': row['id'],
        'revision': row['revision'],
        'status': row['status'],
      };
    }
    if (name == 'cancel_session') {
      final gate = cancelGate;
      cancelGate = null;
      if (gate != null) await gate.future;
      _find(payload['id']! as String)['status'] = 'canceled';
      return <String, dynamic>{'id': payload['id'], 'revision': 2};
    }
    if (name == 'create_session') {
      if (ambiguousCreateOnce case final code?) {
        ambiguousCreateOnce = null;
        throw DataFailure(code);
      }
      if (conflictOnCreate) {
        conflictOnCreate = false;
        final parent = _find(payload['replaces_session_id']! as String);
        parent['replacement_session_id'] = externalChildId;
        sessions.add(
          _sessionRow(
            externalChildId,
            date: payload['date']! as String,
            topic: 'Substituta registrada por outra pessoa',
            replacesSessionId: parent['id']! as String,
          ),
        );
        throw const DataFailure('academic_conflict');
      }
      final parentId = payload['replaces_session_id'] as String?;
      if (parentId != null) {
        _find(parentId)['replacement_session_id'] = payload['id'];
      }
      sessions.add(
        _sessionRow(
          payload['id']! as String,
          date: payload['date']! as String,
          topic: payload['topic'] as String?,
          replacesSessionId: parentId,
        ),
      );
      return <String, dynamic>{'id': payload['id'], 'revision': 1};
    }
    throw UnimplementedError(name);
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();

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
}

class _LoopbackHttpOverrides extends HttpOverrides {}

class _ReplacementLoopback {
  _ReplacementLoopback({required this.sqlState, required this.message});

  final String sqlState;
  final String message;
  late final HttpServer server;
  late final HttpClient http;
  late final SupabaseClient client;
  late final SupabaseGateway gateway;
  final listCalls = <Map<String, Object?>>[];
  final createCalls = <Map<String, Object?>>[];

  Future<void> initialize() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final decoded = body.isEmpty ? null : jsonDecode(body);
      final params = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      final read = params['request'] is Map
          ? Map<String, Object?>.from(params['request'] as Map)
          : Map<String, Object?>.from(params);
      final payload = params['payload'] is Map
          ? Map<String, Object?>.from(params['payload'] as Map)
          : <String, Object?>{};
      final rpc = request.uri.path.split('/').last;
      request.response.headers.contentType = ContentType.json;
      Object value;
      var status = 200;
      if (rpc == 'ieadpe_ministry_list_class_sessions') {
        listCalls.add(Map.of(read));
        final hasChild = listCalls.length > 1;
        value = <String, Object?>{
          'items': <Map<String, Object?>>[
            _sessionListProjection(
              _sessionRow(
                parentId,
                date: '2026-12-20',
                topic: 'Lição original',
                status: 'canceled',
                revision: 2,
                replacementSessionId: hasChild ? externalChildId : null,
              ),
            ),
            if (hasChild)
              _sessionListProjection(
                _sessionRow(
                  externalChildId,
                  date: '2026-12-20',
                  topic: 'Substituta externa',
                  revision: 1,
                  replacesSessionId: parentId,
                ),
              ),
          ],
          'next_cursor': null,
        };
      } else if (rpc == 'ieadpe_ministry_create_session') {
        createCalls.add(<String, Object?>{
          'operation_id': params['operation_id'],
          ...payload,
        });
        status = sqlState == '23505' ? 409 : 400;
        value = <String, Object?>{'code': sqlState, 'message': message};
      } else {
        status = 500;
        value = <String, Object?>{'message': 'unexpected RPC $rpc'};
      }
      request.response.statusCode = status;
      request.response.write(jsonEncode(value));
      await request.response.close();
    });
    http = _LoopbackHttpOverrides().createHttpClient(null)
      ..idleTimeout = Duration.zero;
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
      httpClient: IOClient(http),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    gateway = SupabaseGateway(
      client,
      ProtectedDataBoundary(),
      requestTimeout: const Duration(seconds: 3),
    );
  }

  Future<void> close() async {
    await client.dispose();
    await server.close(force: true);
  }
}

Future<void> _drainLoopback(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 35)),
    );
    await tester.pump();
  }
}

SessionNavigationContext _selected(String sessionId) =>
    SessionNavigationContext(
      congregationId: congregationId,
      classId: classId,
      sessionId: sessionId,
    );

MinistryClassSummary _classSummary({ClassStatus status = ClassStatus.active}) =>
    MinistryClassSummary(
      id: classId,
      name: 'Turma A',
      status: status,
      startDate: '2026-10-01',
      endDate: null,
      revision: 1,
      teacherContactId: null,
    );

Widget _attendance(_HistoryGateway gateway, String sessionId) => MaterialApp(
  home: AttendancePage(
    repository: MinistryRepository(gateway),
    congregationId: congregationId,
    selectedSession: _selected(sessionId),
  ),
);

Widget _list(
  _HistoryGateway gateway, {
  ClassStatus status = ClassStatus.active,
  Future<void> Function(String sessionId)? opened,
}) => MaterialApp(
  home: SessionListPage(
    repository: MinistryRepository(gateway),
    congregationId: congregationId,
    classSummary: _classSummary(status: status),
    onOpenSession: opened ?? (_) async {},
  ),
);

Future<void> _openReplacement(WidgetTester tester) async {
  final replacement = find.text('Registrar substituta');
  await tester.ensureVisible(replacement);
  await tester.pumpAndSettle();
  await tester.tap(replacement);
  await tester.pumpAndSettle();
}

Future<void> _confirmCancel(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancelar aula'),
    ),
  );
  await tester.pump();
}

Future<void> _confirmFinalize(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Finalizar chamada'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unfrozen eligible preview saves the full roster and reloads frozen marks after acknowledgement',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Primeira chamada',
            rosterFrozen: false,
            previewRoster: [
              {
                'enrollment_id': enrollmentA,
                'student_id': studentA,
                'student_name': 'Ana da Silva',
                'status': 'unmarked',
              },
              {
                'enrollment_id': enrollmentB,
                'student_id': studentB,
                'student_name': 'Bento Souza',
                'status': 'unmarked',
              },
            ],
          ),
        );
      final saveGate = Completer<void>();
      gateway.saveGate = saveGate;
      await tester.pumpWidget(_attendance(gateway, parentId));
      await tester.pumpAndSettle();

      expect(find.text('Lista prevista · 2026-12-20'), findsOneWidget);
      expect(
        find.text('A lista será congelada no primeiro salvamento.'),
        findsOneWidget,
      );
      expect(find.text('Lista congelada · 2026-12-20'), findsNothing);
      expect(find.text('Ana da Silva'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<AttendanceStatus>),
        findsNWidgets(2),
      );

      await tester.tap(
        find.byType(DropdownButtonFormField<AttendanceStatus>).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ausente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar chamada'));
      await tester.pump();

      expect(gateway.saveCalls, hasLength(1));
      expect(gateway.saveCalls.single.payload['finalize'], isFalse);
      expect(gateway.saveCalls.single.payload['marks'], {
        enrollmentA: 'absent',
        enrollmentB: 'unmarked',
      });
      expect(find.text('Lista prevista · 2026-12-20'), findsOneWidget);
      expect(find.text('Lista congelada · 2026-12-20'), findsNothing);
      expect(find.textContaining('confirmada pelo servidor'), findsNothing);

      saveGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Lista congelada · 2026-12-20'), findsOneWidget);
      expect(find.text('Lista prevista · 2026-12-20'), findsNothing);
      expect(
        find.text('A lista será congelada no primeiro salvamento.'),
        findsNothing,
      );
      expect(
        find.text('Chamada salva e confirmada pelo servidor.'),
        findsOneWidget,
      );
      expect(find.text('Ausente'), findsOneWidget);
      expect(find.text('Sem marcação'), findsOneWidget);
    },
  );

  testWidgets('empty eligible preview cannot be finalized', (tester) async {
    final gateway = _HistoryGateway()
      ..sessions.add(
        _sessionRow(
          parentId,
          date: '2026-12-20',
          topic: 'Aula sem alunos elegíveis',
          rosterFrozen: false,
          previewRoster: const [],
        ),
      );
    await tester.pumpWidget(_attendance(gateway, parentId));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum aluno elegível para a data desta aula.'),
      findsOneWidget,
    );
    expect(find.text('Lista prevista · 2026-12-20'), findsOneWidget);
    expect(
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Salvar e finalizar'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Salvar chamada'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Salvar chamada'));
    await tester.pumpAndSettle();
    expect(gateway.saveCalls, hasLength(1));
    expect(gateway.saveCalls.single.payload['marks'], isEmpty);
    expect(gateway.saveCalls.single.payload['finalize'], isFalse);
    expect(find.text('Lista congelada · 2026-12-20'), findsOneWidget);
    expect(find.text('Lista prevista · 2026-12-20'), findsNothing);
    expect(
      find.text('Chamada salva e confirmada pelo servidor.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Salvar e finalizar'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('frozen empty roster is not synthesized into a preview', (
    tester,
  ) async {
    final gateway = _HistoryGateway()
      ..sessions.add(
        _sessionRow(
          parentId,
          date: '2026-12-20',
          topic: 'Chamada congelada vazia',
          rosterFrozen: true,
          storedRoster: const [],
        ),
      );
    await tester.pumpWidget(_attendance(gateway, parentId));
    await tester.pumpAndSettle();

    expect(find.text('Lista congelada · 2026-12-20'), findsOneWidget);
    expect(find.text('Lista prevista · 2026-12-20'), findsNothing);
    expect(
      find.text('Nenhum aluno elegível para a data desta aula.'),
      findsNothing,
    );
    expect(
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Salvar e finalizar'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('terminal unfrozen reads do not become eligible previews', (
    tester,
  ) async {
    final gateway = _HistoryGateway()
      ..sessions.add(
        _sessionRow(
          parentId,
          date: '2026-12-20',
          topic: 'Aula cancelada sem congelamento',
          status: 'canceled',
          rosterFrozen: false,
          previewRoster: [
            {
              'enrollment_id': enrollmentA,
              'student_id': studentA,
              'student_name': 'Ana da Silva',
              'status': 'unmarked',
            },
          ],
          storedRoster: const [],
        ),
      );
    await tester.pumpWidget(_attendance(gateway, parentId));
    await tester.pumpAndSettle();

    expect(find.text('Lista prevista · 2026-12-20'), findsNothing);
    expect(
      find.text('Nenhum aluno elegível para a data desta aula.'),
      findsNothing,
    );
    expect(find.text('Ana da Silva'), findsNothing);
    expect(
      find.text('Chamada cancelada. As marcações são somente leitura.'),
      findsOneWidget,
    );
    expect(
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      findsNothing,
    );
    expect(find.text('Salvar chamada'), findsNothing);
    expect(find.text('Salvar e finalizar'), findsNothing);
  });

  testWidgets(
    'finalized and canceled attendance render labeled read-only marks',
    (tester) async {
      for (final status in ['finalized', 'canceled']) {
        final gateway = _HistoryGateway()
          ..sessions.add(
            _sessionRow(
              parentId,
              date: '2026-12-20',
              topic: 'Lição encerrada',
              status: status,
              revision: 3,
            ),
          );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_attendance(gateway, parentId));
        await tester.pumpAndSettle();

        expect(
          find.text(status == 'finalized' ? 'Finalizada' : 'Cancelada'),
          findsOneWidget,
        );
        expect(find.textContaining('somente leitura'), findsOneWidget);
        expect(find.text('Ana da Silva'), findsOneWidget);
        expect(find.text('Presente'), findsWidgets);
        expect(find.text('Ausente'), findsWidgets);
        expect(
          find.byType(DropdownButtonFormField<AttendanceStatus>),
          findsNothing,
        );
        expect(find.text('Salvar chamada'), findsNothing);
        expect(find.text('Salvar e finalizar'), findsNothing);
      }

      final openGateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(parentId, date: '2026-12-20', topic: 'Lição aberta'),
        );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_attendance(openGateway, parentId));
      await tester.pumpAndSettle();
      expect(find.text('Aberta'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<AttendanceStatus>),
        findsNWidgets(2),
      );
      expect(find.text('Salvar chamada'), findsOneWidget);
      expect(find.text('Salvar e finalizar'), findsOneWidget);
    },
  );

  testWidgets(
    'finalization explains immutability and confirms only after ack',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(parentId, date: '2026-12-20', topic: 'Lição aberta'),
        );
      final saveGate = Completer<void>();
      gateway.saveGate = saveGate;
      await tester.pumpWidget(_attendance(gateway, parentId));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar e finalizar'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Após finalizar, a chamada não poderá ser editada. '
          'Para corrigir, cancele e registre uma substituta.',
        ),
        findsOneWidget,
      );
      await _confirmFinalize(tester);

      expect(gateway.saveCalls, hasLength(1));
      expect(gateway.saveCalls.single.payload['finalize'], isTrue);
      expect(find.textContaining('confirmada pelo servidor'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar e finalizar'),
            )
            .onPressed,
        isNull,
      );

      saveGate.complete();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Chamada finalizada e confirmada'),
        findsOneWidget,
      );
      expect(find.text('Finalizada'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<AttendanceStatus>),
        findsNothing,
      );
    },
  );

  testWidgets(
    'unknown finalization disables changes and retries exact action',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(parentId, date: '2026-12-20', topic: 'Lição aberta'),
        )
        ..saveOutcomes.add('unknown');
      await tester.pumpWidget(_attendance(gateway, parentId));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar e finalizar'));
      await tester.pumpAndSettle();
      await _confirmFinalize(tester);

      expect(gateway.saveCalls, hasLength(1));
      expect(find.textContaining('pode ter sido concluída'), findsOneWidget);
      expect(find.byKey(const Key('retry-attendance-save')), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<AttendanceStatus>>(
              find.byType(DropdownButtonFormField<AttendanceStatus>).first,
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Salvar chamada'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar e finalizar'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('retry-attendance-save')));
      await tester.pumpAndSettle();

      expect(gateway.saveCalls, hasLength(2));
      expect(
        gateway.saveCalls.last.operationId,
        gateway.saveCalls.first.operationId,
      );
      expect(gateway.saveCalls.last.payload, gateway.saveCalls.first.payload);
      expect(gateway.saveCalls.last.payload['finalize'], isTrue);
      expect(
        find.textContaining('Chamada finalizada e confirmada'),
        findsOneWidget,
      );
      expect(find.text('Finalizada'), findsOneWidget);
    },
  );

  testWidgets(
    'stale rejection needs an explicit authoritative refresh before new intent',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(parentId, date: '2026-12-20', topic: 'Lição aberta'),
        )
        ..saveOutcomes.add('stale');
      await tester.pumpWidget(_attendance(gateway, parentId));
      await tester.pumpAndSettle();
      expect(gateway.detailReads, hasLength(1));

      await tester.tap(find.text('Salvar chamada'));
      await tester.pumpAndSettle();

      expect(gateway.saveCalls, hasLength(1));
      expect(gateway.detailReads, hasLength(1));
      expect(find.textContaining('alterada por outra pessoa'), findsOneWidget);
      expect(find.text('Atualizar e revisar'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Salvar chamada'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Atualizar e revisar'));
      await tester.pumpAndSettle();

      expect(gateway.detailReads, hasLength(2));
      expect(find.textContaining('Revise as marcações'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Salvar chamada'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Salvar chamada'));
      await tester.pumpAndSettle();

      expect(gateway.saveCalls, hasLength(2));
      expect(
        gateway.saveCalls.last.operationId,
        isNot(gateway.saveCalls.first.operationId),
      );
      expect(gateway.saveCalls.last.payload['expected_revision'], 2);
      expect(gateway.saveCalls.last.payload['finalize'], isFalse);
    },
  );

  testWidgets(
    'leaving unknown warns and returning performs a fresh read without resend',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(parentId, date: '2026-12-20', topic: 'Lição aberta'),
        )
        ..saveOutcomes.add('unknown');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-attendance'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AttendancePage(
                        repository: MinistryRepository(gateway),
                        congregationId: congregationId,
                        selectedSession: _selected(parentId),
                      ),
                    ),
                  ),
                  child: const Text('Abrir chamada'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-attendance')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar e finalizar'));
      await tester.pumpAndSettle();
      await _confirmFinalize(tester);
      expect(gateway.saveCalls, hasLength(1));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Sair da chamada?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('pode ter sido concluída'),
        ),
        findsOneWidget,
      );
      expect(gateway.detailReads, hasLength(1));

      await tester.tap(find.text('Sair mesmo assim'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendancePage), findsNothing);
      expect(gateway.saveCalls, hasLength(1));

      await tester.tap(find.byKey(const Key('open-attendance')));
      await tester.pumpAndSettle();
      expect(find.byType(AttendancePage), findsOneWidget);
      expect(gateway.detailReads, hasLength(2));
      expect(gateway.saveCalls, hasLength(1));
    },
  );

  testWidgets(
    'owner context switch disposes pending save and ignores late replies',
    (tester) async {
      for (final outcome in ['success', 'unknown']) {
        final gateway = _HistoryGateway()
          ..sessions.add(
            _sessionRow(parentId, date: '2026-12-20', topic: 'Lição A'),
          )
          ..sessions.add(
            _sessionRow(childId, date: '2026-12-21', topic: 'Lição B'),
          )
          ..saveOutcomes.add(outcome);
        final saveGate = Completer<void>();
        gateway.saveGate = saveGate;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_attendance(gateway, parentId));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Salvar e finalizar'));
        await tester.pumpAndSettle();
        await _confirmFinalize(tester);
        expect(gateway.saveCalls, hasLength(1));

        await tester.pumpWidget(_attendance(gateway, childId));
        await tester.pumpAndSettle();
        expect(find.text('Lista congelada · 2026-12-21'), findsOneWidget);

        saveGate.complete();
        await tester.pumpAndSettle();

        expect(gateway.saveCalls, hasLength(1));
        expect(find.textContaining('confirmada pelo servidor'), findsNothing);
        expect(find.text('Aberta'), findsOneWidget);
        expect(find.text('Lista congelada · 2026-12-21'), findsOneWidget);
        expect(find.text('Lista congelada · 2026-12-20'), findsNothing);
      }
    },
  );

  testWidgets(
    'late roster preview is discarded after selected session changes',
    (tester) async {
      final readGate = Completer<void>();
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Lição A',
            rosterFrozen: false,
            previewRoster: const [
              {
                'enrollment_id': 'enrollment-parent',
                'student_id': 'student-parent',
                'student_name': 'Aluno anterior',
                'status': 'unmarked',
              },
            ],
          ),
        )
        ..sessions.add(
          _sessionRow(childId, date: '2026-12-21', topic: 'Lição B'),
        )
        ..delayedDetailSessionId = parentId
        ..detailReadGate = readGate;

      await tester.pumpWidget(_attendance(gateway, parentId));
      await tester.pump();
      expect(gateway.detailReads, [parentId]);

      await tester.pumpWidget(_attendance(gateway, childId));
      await tester.pumpAndSettle();
      expect(find.text('Lista congelada · 2026-12-21'), findsOneWidget);

      readGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Lista prevista · 2026-12-20'), findsNothing);
      expect(find.text('Aluno anterior'), findsNothing);
      expect(find.text('Lista congelada · 2026-12-21'), findsOneWidget);
    },
  );

  testWidgets(
    'canceled row offers replacement with fixed class and date and links history',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Lição original',
            status: 'canceled',
            revision: 2,
          ),
        );
      await tester.pumpWidget(_list(gateway));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cancelada ·'), findsOneWidget);
      await _openReplacement(tester);

      expect(find.text('Substituir aula cancelada'), findsOneWidget);
      expect(
        find.textContaining('A substituta mantém a turma e a data'),
        findsOneWidget,
      );
      final dateField = tester.widget<TextField>(
        find.byKey(const Key('session-date')),
      );
      expect(dateField.controller!.text, '20/12/2026');
      expect(dateField.readOnly, isTrue);

      await tester.enterText(
        find.byKey(const Key('session-topic')),
        'Lição substituta',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(gateway.createCalls, hasLength(1));
      expect(gateway.createCalls.single.payload['class_id'], classId);
      expect(gateway.createCalls.single.payload['date'], '2026-12-20');
      expect(
        gateway.createCalls.single.payload['replaces_session_id'],
        parentId,
      );
      expect(
        find.textContaining('Substituída pela aula de 20/12/2026'),
        findsOneWidget,
      );
      expect(find.textContaining('Substituta de 20/12/2026'), findsOneWidget);
      expect(find.text('Registrar substituta'), findsNothing);
      expect(find.textContaining('Lição original'), findsOneWidget);
      expect(find.textContaining('Lição substituta'), findsOneWidget);
    },
  );

  testWidgets(
    'pagination-separated child hides replacement on its canceled parent',
    (tester) async {
      final gateway = _HistoryGateway()
        ..pageSize = 1
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Lição original',
            status: 'canceled',
            revision: 2,
            replacementSessionId: childId,
          ),
        )
        ..sessions.add(
          _sessionRow(
            childId,
            date: '2026-12-20',
            topic: 'Lição substituta',
            replacesSessionId: parentId,
          ),
        );
      await tester.pumpWidget(_list(gateway));
      await tester.pumpAndSettle();

      expect(find.textContaining('Substituição já registrada'), findsOneWidget);
      expect(find.text('Registrar substituta'), findsNothing);

      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Substituta de 20/12/2026'), findsOneWidget);
      expect(find.text('Registrar substituta'), findsNothing);
      expect(gateway.createCalls, isEmpty);
    },
  );

  testWidgets(
    'stale eligible replacement surfaces a conflict and refreshes the link',
    (tester) async {
      final gateway = _HistoryGateway()
        ..conflictOnCreate = true
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Lição original',
            status: 'canceled',
            revision: 2,
          ),
        );
      await tester.pumpWidget(_list(gateway));
      await tester.pumpAndSettle();
      await _openReplacement(tester);
      await tester.enterText(
        find.byKey(const Key('session-topic')),
        'Minha substituta',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(gateway.createCalls, hasLength(1));
      expect(
        gateway.createCalls.single.payload['replaces_session_id'],
        parentId,
      );
      expect(
        find.textContaining('Outra pessoa registrou uma substituta'),
        findsOneWidget,
      );
      expect(find.byType(SessionForm), findsNothing);
      expect(
        find.textContaining('Substituída pela aula de 20/12/2026'),
        findsOneWidget,
      );
      expect(find.text('Registrar substituta'), findsNothing);
      expect(gateway.createCalls, hasLength(1));
    },
  );

  testWidgets(
    'real gateway academic replacement SQLSTATEs refresh without reparenting',
    (tester) async {
      for (final scenario in [
        (sqlState: '23505', message: 'academic_conflict'),
        (sqlState: '22023', message: 'academic_invalid'),
      ]) {
        final fixture = _ReplacementLoopback(
          sqlState: scenario.sqlState,
          message: scenario.message,
        );
        await tester.runAsync(fixture.initialize);
        addTearDown(fixture.close);

        await tester.pumpWidget(
          MaterialApp(
            home: SessionListPage(
              repository: MinistryRepository(fixture.gateway),
              congregationId: congregationId,
              classSummary: _classSummary(),
              onOpenSession: (_) async {},
            ),
          ),
        );
        await _drainLoopback(tester);
        expect(find.text('Registrar substituta'), findsOneWidget);

        await _openReplacement(tester);
        expect(find.text('Substituir aula cancelada'), findsOneWidget);
        expect(find.textContaining('20/12/2026'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
        await _drainLoopback(tester);
        await tester.pumpAndSettle();

        expect(fixture.createCalls, hasLength(1));
        expect(fixture.createCalls.single['replaces_session_id'], parentId);
        expect(fixture.createCalls.single['operation_id'], isA<String>());
        expect(fixture.listCalls, hasLength(2));
        expect(
          find.textContaining('Outra pessoa registrou uma substituta'),
          findsOneWidget,
        );
        expect(find.byType(SessionForm), findsNothing);
        expect(find.textContaining('Lição original'), findsOneWidget);
        expect(find.textContaining('Substituta externa'), findsOneWidget);
        expect(
          find.textContaining('Substituída pela aula de 20/12/2026'),
          findsOneWidget,
        );
        expect(find.textContaining('Substituta de 20/12/2026'), findsOneWidget);
        expect(find.text('Registrar substituta'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'ambiguous replacement keeps one operation id and exact payload on retry',
    (tester) async {
      final gateway = _HistoryGateway()
        ..ambiguousCreateOnce = 'invalid'
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Lição original',
            status: 'canceled',
            revision: 2,
          ),
        );
      await tester.pumpWidget(_list(gateway));
      await tester.pumpAndSettle();
      await _openReplacement(tester);
      await tester.enterText(
        find.byKey(const Key('session-topic')),
        'Substituta ambígua',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionForm), findsOneWidget);
      expect(find.textContaining('Não foi possível confirmar'), findsOneWidget);
      expect(gateway.createCalls, hasLength(1));
      await tester.tap(find.byKey(const Key('retry-pending-session-create')));
      await tester.pumpAndSettle();

      expect(gateway.createCalls, hasLength(2));
      expect(
        gateway.createCalls.last.operationId,
        gateway.createCalls.first.operationId,
      );
      expect(
        gateway.createCalls.last.payload,
        gateway.createCalls.first.payload,
      );
      expect(gateway.createCalls.last.payload['replaces_session_id'], parentId);
      expect(find.byType(SessionForm), findsNothing);
    },
  );

  testWidgets(
    'historical class explains why a replacement cannot be registered',
    (tester) async {
      final gateway = _HistoryGateway()
        ..sessions.add(
          _sessionRow(
            parentId,
            date: '2026-12-20',
            topic: 'Lição histórica',
            status: 'canceled',
            revision: 2,
          ),
        );
      await tester.pumpWidget(_list(gateway, status: ClassStatus.archived));
      await tester.pumpAndSettle();
      expect(
        find.text('Substituição indisponível: a turma não está ativa.'),
        findsOneWidget,
      );
      expect(find.text('Registrar substituta'), findsNothing);
    },
  );

  testWidgets('confirmed cancellation shows identity and enables replacement', (
    tester,
  ) async {
    final gateway = _HistoryGateway()
      ..sessions.add(
        _sessionRow(parentId, date: '2026-12-20', topic: 'Lição original'),
      );
    final cancelGate = Completer<void>();
    gateway.cancelGate = cancelGate;
    await tester.pumpWidget(_list(gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancel-session-$parentId')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Turma A · 20/12/2026 · Lição original'),
      findsOneWidget,
    );
    await _confirmCancel(tester);

    expect(gateway.cancelCalls, hasLength(1));
    expect(find.text('Registrar substituta'), findsNothing);

    cancelGate.complete();
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Aula cancelada: Turma A · 20/12/2026 · Lição original',
      ),
      findsOneWidget,
    );
    expect(find.text('Registrar substituta'), findsOneWidget);
  });

  testWidgets('replacing a canceled child forms the next chain link', (
    tester,
  ) async {
    final gateway = _HistoryGateway()
      ..sessions.add(
        _sessionRow(
          parentId,
          date: '2026-12-20',
          topic: 'Lição original',
          status: 'canceled',
          revision: 2,
          replacementSessionId: childId,
        ),
      )
      ..sessions.add(
        _sessionRow(
          childId,
          date: '2026-12-20',
          topic: 'Primeira substituta',
          status: 'canceled',
          revision: 2,
          replacesSessionId: parentId,
        ),
      );
    await tester.pumpWidget(_list(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Registrar substituta'), findsOneWidget);
    await _openReplacement(tester);
    await tester.enterText(
      find.byKey(const Key('session-topic')),
      'Segunda substituta',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(gateway.createCalls, hasLength(1));
    expect(gateway.createCalls.single.payload['replaces_session_id'], childId);
    expect(
      gateway.createCalls.single.payload['replaces_session_id'],
      isNot(parentId),
    );
    expect(
      gateway.sessions.firstWhere(
        (row) => row['id'] == parentId,
      )['replacement_session_id'],
      childId,
    );
    expect(find.text('Registrar substituta'), findsNothing);
    expect(find.textContaining('Segunda substituta'), findsOneWidget);
  });
}
