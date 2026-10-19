import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/session_navigation_context.dart';
import 'package:ieadpe_converts/features/ministry/ui/attendance_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_detail_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/classes_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/ministry_home_page.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/session_list.dart';
import 'package:ieadpe_converts/ui/base44_widgets.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';

const congregationId = '33333333-3333-4333-8333-333333333333';
const classAId = '22222222-2222-4222-8222-222222222222';
const classBId = '99999999-9999-4999-8999-999999999997';
const sessionId = '55555555-5555-4555-8555-555555555555';
const enrollmentId = '66666666-6666-4666-8666-666666666666';
const studentId = '77777777-7777-4777-8777-777777777777';
const actorId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherCongregationId = '88888888-8888-4888-8888-888888888888';

class _NavigationGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String value) {
    if (value != context) throw const DataFailure('stale');
  }

  final calls = <({String rpc, Map<String, Object?> payload})>[];
  String detailClassId = classAId;
  String detailCongregationId = congregationId;
  final sessions = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    calls.add((rpc: rpc, payload: Map.of(parameters)));
    if (rpc == 'ministry_list_pending_sessions') {
      return {'items': sessions, 'next_cursor': null};
    }
    if (rpc == 'ministry_get_session_attendance') {
      return {
        'session': {
          'id': parameters['session_id'],
          'congregation_id': detailCongregationId,
          'revision': 1,
          'created_at': '2026-10-15T10:00:00Z',
          'updated_at': '2026-10-15T10:00:00Z',
          'updated_by': actorId,
          'class_id': detailClassId,
          'date': '2026-12-20',
          'topic': 'Tema da turma B protegida',
          'status': 'open',
          'roster_frozen': true,
          'lesson_index': null,
          'lesson_part': null,
          'lesson_finished': false,
        },
        'roster': [
          {
            'enrollment_id': enrollmentId,
            'session_id': parameters['session_id'],
            'student_id': studentId,
            'student_name': 'Pessoa B protegida',
            'status': 'unmarked',
          },
        ],
      };
    }
    throw UnimplementedError(rpc);
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String name,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError(name);

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

Widget _attendance(
  _NavigationGateway gateway, {
  SessionNavigationContext? selected,
}) => MaterialApp(
  home: AttendancePage(
    repository: MinistryRepository(gateway),
    congregationId: congregationId,
    selectedSession: selected,
  ),
);

class _LoopbackHttpOverrides extends HttpOverrides {}

class _RootNavigationFixture {
  late final HttpServer server;
  late final HttpClient http;
  late final SupabaseClient client;
  late final AuthRepository auth;
  final sessionRows = <Map<String, Object?>>[];
  final listCalls = <Map<String, Object?>>[];
  final detailCalls = <Map<String, Object?>>[];
  final commandCalls = <Map<String, Object?>>[];
  int pendingCalls = 0;
  bool blockDetail = false;
  Completer<void>? detailGate;
  Completer<void>? createGate;
  bool mismatchDetail = false;
  bool twoCongregations = false;

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
      Object value = <Object>[];
      if (rpc == 'ieadpe_get_scope') {
        value = {
          'is_admin': true,
          'is_supervision': false,
          'congregation_ids': <String>[],
          'ministry_supervision': false,
          'ministry_congregation_ids': twoCongregations
              ? [congregationId, otherCongregationId]
              : [congregationId],
        };
      } else if (request.uri.path == '/rest/v1/congregations') {
        value = <Object>[];
      } else if (rpc == 'ieadpe_ministry_list_congregations') {
        value = {
          'items': [
            {'id': congregationId, 'name': 'Congregação protegida'},
            if (twoCongregations)
              {'id': otherCongregationId, 'name': 'Outra congregação'},
          ],
          'next_cursor': null,
        };
      } else if (rpc == 'ieadpe_ministry_list_classes') {
        value = {
          'items': [
            {
              'id': classAId,
              'name': 'Turma A protegida',
              'status': 'active',
              'start_date': '2026-10-01',
              'end_date': null,
              'revision': 1,
              'teacher_contact_id': null,
            },
          ],
          'next_cursor': null,
        };
      } else if (rpc == 'ieadpe_ministry_list_class_students') {
        value = {'items': <Object>[], 'next_cursor': null};
      } else if (rpc == 'ieadpe_ministry_list_class_sessions') {
        listCalls.add(Map.of(read));
        value = {
          'items': List<Map<String, Object?>>.from(sessionRows),
          'next_cursor': null,
        };
      } else if (rpc == 'ieadpe_ministry_list_pending_sessions') {
        pendingCalls++;
        value = {'items': <Object>[], 'next_cursor': null};
      } else if (rpc == 'ieadpe_ministry_get_session_attendance') {
        detailCalls.add(Map.of(read));
        if (blockDetail) await detailGate!.future;
        final requestPayload = read;
        final selectedSession = sessionRows
            .where((item) => item['id'] == requestPayload['session_id'])
            .firstOrNull;
        value = {
          'session': {
            'id': requestPayload['session_id'],
            'congregation_id': congregationId,
            'revision': 1,
            'created_at': '2026-10-15T10:00:00Z',
            'updated_at': '2026-10-15T10:00:00Z',
            'updated_by': actorId,
            'class_id': mismatchDetail
                ? classBId
                : selectedSession?['class_id'] ?? classAId,
            'date': selectedSession?['date'] ?? '2026-12-20',
            'topic': selectedSession?['topic'] ?? 'Sessão protegida',
            'status': 'open',
            'roster_frozen': true,
            'lesson_index': null,
            'lesson_part': null,
            'lesson_finished': false,
          },
          'roster': [
            {
              'enrollment_id': enrollmentId,
              'session_id': requestPayload['session_id'],
              'student_id': studentId,
              'student_name': 'Aluno protegido',
              'status': 'unmarked',
            },
          ],
        };
      } else if (rpc == 'ieadpe_ministry_create_session') {
        commandCalls.add(payload);
        if (createGate != null) await createGate!.future;
        sessionRows.add({
          'id': payload['id'],
          'class_id': payload['class_id'],
          'congregation_id': payload['congregation_id'],
          'date': payload['date'],
          'topic': payload['topic'],
          'status': 'open',
          'revision': 1,
        });
        value = {'id': payload['id'], 'revision': 1, 'status': 'open'};
      }
      request.response.write(jsonEncode(value));
      await request.response.close();
    });
    http = _LoopbackHttpOverrides().createHttpClient(null)
      ..idleTimeout = Duration.zero;
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic',
      httpClient: IOClient(http),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    auth = AuthRepository(
      client,
      AuthRedirectPolicy(Uri.parse('http://localhost:3000/auth/callback')),
    );
    await identity('11111111-1111-1111-1111-111111111111');
  }

  Future<void> identity(String id) => client.auth.recoverSession(
    jsonEncode({
      'access_token':
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature',
      'token_type': 'bearer',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'created_at': '2026-10-15T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
      },
    }),
  );

  Future<void> close() async {
    detailGate?.complete();
    detailGate = null;
    createGate?.complete();
    createGate = null;
    await client.dispose();
    http.close(force: true);
    await server.close(force: true);
  }
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 35)),
    );
    await tester.pump();
  }
}

Future<void> _popProtectedRoute(WidgetTester tester) async {
  final returningFromAttendance = find
      .byType(AttendancePage)
      .evaluate()
      .isNotEmpty;
  final returningFromSessionList =
      !returningFromAttendance &&
      find.byType(SessionListPage).evaluate().isNotEmpty;
  final current = returningFromAttendance
      ? find.byType(AttendancePage).evaluate().first
      : returningFromSessionList
      ? find.byType(SessionListPage).evaluate().first
      : find.byType(ClassDetailPage).evaluate().first;
  final target = returningFromAttendance
      ? find.byType(SessionListPage, skipOffstage: false).evaluate().first
      : returningFromSessionList
      ? find.byType(ClassDetailPage, skipOffstage: false).evaluate().first
      : find.byType(ClassesPage, skipOffstage: false).evaluate().first;
  final currentRoute = ModalRoute.of(current)!;
  final targetRoute = ModalRoute.of(target)!;
  expect(identical(currentRoute.navigator, targetRoute.navigator), isTrue);
  currentRoute.navigator!.popUntil((route) => identical(route, targetRoute));
  await tester.pump(const Duration(milliseconds: 500));
  await _drain(tester);
  await tester.pumpAndSettle();
  expect(currentRoute.isCurrent, isFalse);
  expect(targetRoute.isCurrent, isTrue);
}

Future<void> _openClassSessions(WidgetTester tester) async {
  tester
      .widget<AppShell>(find.byType(AppShell))
      .onNavigate('/ministry/classes');
  await _drain(tester);
  expect(tester.takeException(), isNull);
  await tester.tap(find.text('Turma A protegida'));
  await _drain(tester);
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(ClassDetailPage), findsOneWidget);
  await tester.tap(find.text('Ver aulas'));
  await _drain(tester);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpProtectedApp(
  WidgetTester tester,
  _RootNavigationFixture fixture,
) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(home: ProtectedApplication(repository: fixture.auth)),
  );
  await _drain(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _chooseCongregation(WidgetTester tester, String selectedId) async {
  tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/ministry');
  await _drain(tester);
  tester
      .widget<MinistryHomePage>(find.byType(MinistryHomePage))
      .onSelectCongregation!
      .call(selectedId);
  await _drain(tester);
}

void main() {
  testWidgets('class session survives create open back and reload', (
    tester,
  ) async {
    final fixture = _RootNavigationFixture();
    await tester.runAsync(fixture.initialize);
    await _pumpProtectedApp(tester, fixture);
    expect(tester.takeException(), isNull);
    await _openClassSessions(tester);
    expect(find.text('Nenhuma aula registrada nesta turma.'), findsOneWidget);
    expect(
      tester.getRect(find.text('Nova aula')).right,
      lessThanOrEqualTo(1440),
    );
    final readsBeforeCreate = fixture.listCalls.length;

    await tester.tap(find.text('Nova aula'));
    await _drain(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionForm), findsOneWidget);
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.enterText(
      find.byKey(const Key('session-topic')),
      'Lição futura',
    );
    await tester.tap(find.text('Salvar'));
    await _drain(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await _drain(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await _drain(tester);

    expect(fixture.commandCalls, hasLength(1));
    expect(fixture.commandCalls.single['class_id'], classAId);
    expect(fixture.commandCalls.single['congregation_id'], congregationId);
    expect(fixture.commandCalls.single['date'], '2026-12-20');
    expect(fixture.detailCalls, hasLength(1));
    expect(fixture.detailCalls.single['congregation_id'], congregationId);
    expect(
      fixture.detailCalls.single['session_id'],
      fixture.commandCalls.single['id'],
    );
    expect(find.text('Lista congelada · 2026-12-20'), findsOneWidget);
    expect(find.text('Aluno protegido'), findsOneWidget);

    await _popProtectedRoute(tester);
    expect(find.byType(AttendancePage).evaluate().isEmpty, isTrue);
    expect(find.byType(SessionListPage), findsOneWidget);
    expect(find.text('20/12/2026'), findsOneWidget);
    expect(fixture.listCalls, hasLength(readsBeforeCreate + 1));
    expect(fixture.listCalls.last['class_id'], classAId);
    expect(fixture.listCalls.last['congregation_id'], congregationId);

    await _popProtectedRoute(tester);
    expect(find.byType(ClassDetailPage), findsOneWidget);
    await tester.tap(find.text('Ver aulas'));
    await _drain(tester);
    expect(find.text('20/12/2026'), findsOneWidget);
    expect(fixture.listCalls.last['class_id'], classAId);
    expect(fixture.listCalls.last['congregation_id'], congregationId);
    expect(
      fixture.detailCalls.every(
        (call) =>
            call['congregation_id'] == congregationId &&
            call['session_id'] == fixture.commandCalls.single['id'],
      ),
      isTrue,
    );
    expect(fixture.pendingCalls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  });

  testWidgets('mismatched session detail is rejected in the app route', (
    tester,
  ) async {
    final fixture = _RootNavigationFixture()
      ..mismatchDetail = true
      ..sessionRows.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição protegida',
        'status': 'open',
        'revision': 1,
      });
    await tester.runAsync(fixture.initialize);
    await _pumpProtectedApp(tester, fixture);
    await _openClassSessions(tester);
    await tester.tap(find.text('20/12/2026'));
    await _drain(tester);
    expect(fixture.detailCalls.single['congregation_id'], congregationId);
    expect(fixture.detailCalls.single['session_id'], sessionId);
    expect(find.text('Lição protegida'), findsNothing);
    expect(find.text('Aluno protegido'), findsNothing);
    expect(
      find.text('Não foi possível abrir a chamada. Tente novamente.'),
      findsOneWidget,
    );
    expect(fixture.pendingCalls, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  });

  testWidgets('scope loss clears nested routes and late session response', (
    tester,
  ) async {
    final fixture = _RootNavigationFixture()
      ..blockDetail = true
      ..detailGate = Completer<void>()
      ..sessionRows.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição protegida',
        'status': 'open',
        'revision': 1,
      });
    await tester.runAsync(fixture.initialize);
    await _pumpProtectedApp(tester, fixture);
    await _openClassSessions(tester);
    await tester.tap(find.text('20/12/2026'));
    await tester.pump(const Duration(milliseconds: 500));
    await _drain(tester);
    expect(fixture.detailCalls, hasLength(1));
    tester
        .widget<AppShell>(find.byType(AppShell, skipOffstage: false))
        .onSignOut();
    await _drain(tester);
    expect(find.byType(AttendancePage), findsNothing);
    expect(find.byType(SessionForm), findsNothing);
    expect(find.text('Sessão protegida'), findsNothing);
    fixture.detailGate!.complete();
    fixture.detailGate = null;
    await _drain(tester);
    expect(find.byType(AttendancePage), findsNothing);
    expect(find.byType(SessionForm), findsNothing);
    expect(find.text('Aluno protegido'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  });

  testWidgets('congregation switch clears a pending session create route', (
    tester,
  ) async {
    final fixture = _RootNavigationFixture()
      ..twoCongregations = true
      ..createGate = Completer<void>();
    await tester.runAsync(fixture.initialize);
    await _pumpProtectedApp(tester, fixture);
    await _chooseCongregation(tester, congregationId);
    await _openClassSessions(tester);
    await tester.tap(find.text('Nova aula'));
    await _drain(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(const Key('session-date')), '20/12/2026');
    await tester.tap(find.text('Salvar'));
    await _drain(tester);
    expect(fixture.commandCalls, hasLength(1));
    expect(find.byType(SessionForm), findsOneWidget);

    tester
        .widget<AppShell>(find.byType(AppShell, skipOffstage: false))
        .onNavigate('/ministry');
    await tester.pump();
    tester
        .widget<MinistryHomePage>(
          find.byType(MinistryHomePage, skipOffstage: false),
        )
        .onSelectCongregation!
        .call(otherCongregationId);
    await _drain(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await _drain(tester);
    expect(find.byType(SessionForm), findsNothing);
    expect(find.byType(ClassDetailPage), findsNothing);

    fixture.createGate!.complete();
    fixture.createGate = null;
    await _drain(tester);
    expect(find.byType(SessionForm), findsNothing);
    expect(find.byType(AttendancePage), findsNothing);
    expect(find.text('Lição futura'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  });

  testWidgets('identity switch clears selected attendance and late response', (
    tester,
  ) async {
    final fixture = _RootNavigationFixture()
      ..blockDetail = true
      ..detailGate = Completer<void>()
      ..sessionRows.add({
        'id': sessionId,
        'class_id': classAId,
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição protegida',
        'status': 'open',
        'revision': 1,
      });
    await tester.runAsync(fixture.initialize);
    await _pumpProtectedApp(tester, fixture);
    await _openClassSessions(tester);
    await tester.tap(find.text('20/12/2026'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => fixture.identity('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
    );
    await _drain(tester);
    expect(find.byType(AttendancePage), findsNothing);
    expect(find.text('Sessão protegida'), findsNothing);
    fixture.detailGate!.complete();
    fixture.detailGate = null;
    await _drain(tester);
    expect(find.byType(AttendancePage), findsNothing);
    expect(find.text('Aluno protegido'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  });

  testWidgets(
    'selected session uses exact context and rejects foreign detail',
    (tester) async {
      final gateway = _NavigationGateway()..detailClassId = classBId;
      final selected = SessionNavigationContext(
        congregationId: congregationId,
        classId: classAId,
        sessionId: sessionId,
      );

      await tester.pumpWidget(_attendance(gateway, selected: selected));
      await tester.pumpAndSettle();

      final request = gateway.calls.single;
      expect(request.rpc, 'ministry_get_session_attendance');
      expect(request.payload, {
        'congregation_id': congregationId,
        'session_id': sessionId,
      });
      expect(selected.classId, classAId);
      expect(find.text('Tema da turma B protegida'), findsNothing);
      expect(find.text('Pessoa B protegida'), findsNothing);
      expect(
        find.text('Não foi possível abrir a chamada. Tente novamente.'),
        findsOneWidget,
      );
      expect(
        gateway.calls.where(
          (call) => call.rpc == 'ministry_list_pending_sessions',
        ),
        isEmpty,
      );
    },
  );

  testWidgets('pending queue route remains available without session context', (
    tester,
  ) async {
    final gateway = _NavigationGateway()
      ..sessions.add({
        'id': sessionId,
        'class_id': classAId,
        'class_name': 'Turma A',
        'congregation_id': congregationId,
        'date': '2026-12-20',
        'topic': 'Lição futura',
        'status': 'open',
      });
    await tester.pumpWidget(_attendance(gateway));
    await tester.pumpAndSettle();
    expect(
      gateway.calls.where(
        (call) => call.rpc == 'ministry_list_pending_sessions',
      ),
      hasLength(1),
    );
    expect(find.text('Turma A'), findsOneWidget);
  });

  test('session navigation context rejects invalid UUID values', () {
    expect(
      () => SessionNavigationContext(
        congregationId: 'not-a-uuid',
        classId: classAId,
        sessionId: sessionId,
      ),
      throwsArgumentError,
    );
  });
}
