import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/io_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/features/converts/register_page.dart';
import 'package:ieadpe_converts/features/feedback/feedback_dialog.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/convert_handoff_page.dart';

class LoopbackHttp extends HttpOverrides {}

class RootFixture {
  static const scopeId = '33333333-3333-4333-8333-333333333333';
  static const syntheticStudentId = '22222222-2222-4222-8222-222222222222';
  static const classId = '44444444-4444-4444-8444-444444444444';
  static const sessionId = '55555555-5555-4555-8555-555555555555';
  static const enrollmentRecordId = '66666666-6666-4666-8666-666666666666';
  late HttpServer server;
  late SupabaseClient client;
  late HttpClient http;
  late AuthRepository auth;
  bool admin = true, failScope = false;
  Completer<void>? scopeGate;
  final paths = <String>[];
  String? convertId;
  String? studentId;
  String? enrollmentId;
  Map<String, Object?>? convertPayload;
  Map<String, Object?>? promotionPayload;
  Map<String, Object?>? enrollmentPayload;
  Map<String, Object?>? attendancePayload;
  String? rosterStudentId;
  bool attendanceFinalized = false;
  int promotionCount = 0;
  final linkedStudentIds = <String>{};
  int get studentIdentityCount => linkedStudentIds.length;
  Future<void> initialize() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.path);
      final body = await utf8.decoder.bind(request).join();
      final decodedBody = body.isEmpty ? null : jsonDecode(body);
      final params = decodedBody is Map
          ? Map<String, dynamic>.from(decodedBody)
          : <String, dynamic>{};
      final payload = params['payload'] is Map
          ? Map<String, Object?>.from(params['payload'] as Map)
          : <String, Object?>{};
      final rpc = request.uri.path.split('/').last;
      request.response.headers.contentType = ContentType.json;
      Object value = <Object>[];
      if (request.uri.path.endsWith('ieadpe_get_scope')) {
        await scopeGate?.future;
        if (failScope) {
          request.response.statusCode = 403;
          value = {'code': '42501', 'message': 'synthetic'};
        } else {
          value = {
            'is_admin': admin,
            'is_supervision': false,
            'congregation_ids': <String>[],
            'ministry_supervision': false,
            'ministry_congregation_ids': [scopeId],
          };
        }
      }
      if (request.uri.path == '/rest/v1/congregations') {
        value = [
          {'id': scopeId, 'name': 'Congregação Sintética', 'archived_at': null},
        ];
      }
      if (rpc == 'ieadpe_ministry_list_congregations') {
        value = {
          'items': [
            {'id': scopeId, 'name': 'Congregação Sintética'},
          ],
          'next_cursor': null,
        };
      }
      if (rpc == 'ieadpe_create_convert') {
        convertId = '11111111-1111-4111-8111-111111111111';
        convertPayload = payload;
        value = {'id': convertId};
      }
      if (rpc == 'ieadpe_promote_convert_to_student') {
        promotionCount++;
        promotionPayload = payload;
        studentId = syntheticStudentId;
        linkedStudentIds.add(studentId!);
        value = {
          'convert_id': payload['convert_id'],
          'student_id': studentId,
          'congregation_id': payload['congregation_id'],
          'status': 'linked',
        };
      }
      if (rpc == 'ieadpe_ministry_list_convert_referrals') {
        value = {
          'items': convertId == null
              ? <Object>[]
              : [
                  {
                    'convert_id': convertId,
                    'congregation_id': scopeId,
                    'name': convertPayload?['name'],
                    'phone': convertPayload?['phone'],
                    'address': convertPayload?['address'],
                    'conversion_date': convertPayload?['conversion_date'],
                  },
                ],
          'next_cursor': null,
        };
      }
      if (rpc == 'ieadpe_ministry_list_classes') {
        value = {
          'items': [
            {
              'id': classId,
              'name': 'Turma Sintética',
              'status': 'active',
              'start_date': '2026-01-01',
              'end_date': null,
              'revision': 1,
            },
          ],
          'next_cursor': null,
        };
      }
      if (rpc == 'ieadpe_ministry_enroll_student') {
        enrollmentPayload = payload;
        enrollmentId = payload['id'] as String;
        value = {'id': enrollmentId, 'revision': 1};
      }
      if (rpc == 'ieadpe_ministry_list_pending_sessions') {
        value = {
          'items': [
            {
              'id': sessionId,
              'class_id': classId,
              'class_name': 'Turma Sintética',
              'congregation_id': scopeId,
              'date': '2026-10-15',
              'topic': 'Encontro sintético',
              'status': 'open',
            },
          ],
          'next_cursor': null,
        };
      }
      if (rpc == 'ieadpe_ministry_get_session_attendance') {
        rosterStudentId = studentId;
        value = {
          'session': {
            'id': sessionId,
            'congregation_id': scopeId,
            'revision': attendanceFinalized ? 2 : 1,
            'created_at': '2026-10-15T10:00:00Z',
            'updated_at': '2026-10-15T10:00:00Z',
            'updated_by': '11111111-1111-4111-8111-111111111111',
            'class_id': classId,
            'date': '2026-10-15',
            'topic': 'Encontro sintético',
            'status': attendanceFinalized ? 'finalized' : 'open',
            'roster_frozen': true,
            'lesson_index': null,
            'lesson_part': null,
            'lesson_finished': false,
          },
          'roster': [
            {
              'enrollment_id': enrollmentId,
              'session_id': sessionId,
              'student_id': studentId,
              'student_name': convertPayload?['name'],
              'status': attendanceFinalized ? 'present' : 'unmarked',
            },
          ],
        };
      }
      if (rpc == 'ieadpe_ministry_save_attendance') {
        attendancePayload = payload;
        attendanceFinalized = payload['finalize'] == true;
        value = {
          'id': sessionId,
          'revision': 2,
          'status': attendanceFinalized ? 'finalized' : 'open',
          'roster_frozen': true,
          'attendance_count': 1,
        };
      }
      if (request.uri.path.endsWith('ieadpe_weekly_overview')) {
        value = {
          'visible': false,
          'global': admin,
          'week_start': null,
          'rows': <Object>[],
          'next_cursor': null,
        };
      }
      request.response.write(jsonEncode(value));
      await request.response.close();
    });
    http = LoopbackHttp().createHttpClient(null)..idleTimeout = Duration.zero;
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
    scopeGate?.complete();
    scopeGate = null;
    await client.dispose();
    http.close(force: true);
    await server.close(force: true);
  }
}

Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
}

Future<void> settleLoopback(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
  await tester.pump();
}

void main() {
  testWidgets(
    'production root mounts Google login for configured SDK without a session',
    (tester) async {
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ))!;
      final auth = AuthRepository(
        client,
        AuthRedirectPolicy(Uri.parse('http://localhost:3000/auth/callback')),
      );
      await tester.pumpWidget(App(auth: auth));
      await tester.pumpAndSettle();
      expect(find.text('Entrar com Google'), findsOneWidget);
      expect(find.text('Aplicativo em preparação'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(client.dispose);
    },
  );
  testWidgets(
    'registered convert stays one identity through ministry enrollment and finalized attendance',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      await tester.pumpWidget(
        MaterialApp(home: ProtectedApplication(repository: fixture.auth)),
      );
      await drain(tester);
      expect(find.byType(RegisterPage), findsOneWidget);

      // Save through the production registration form. The fixture assigns a
      // synthetic congregation and convert ID, then exposes that exact record
      // through the scoped ministry referral projection.
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Jornada Sintética',
      );
      await tester.enterText(
        find.byKey(const ValueKey('landmark')),
        'Perto da praça',
      );
      await tester.enterText(
        find.byKey(const ValueKey('conversion_date')),
        '2026-10-15',
      );
      final congregationField = find
          .descendant(
            of: find.byType(ConvertForm),
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .first;
      await tester.ensureVisible(congregationField);
      await tester.tap(congregationField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Congregação Sintética').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<Gender>));
      await tester.tap(find.byType(DropdownButtonFormField<Gender>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feminino').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('01 - Oração').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cadastrar').last);
      await tester.tap(find.text('Cadastrar').last);
      await drain(tester);
      expect(
        find.text('Novo convertido cadastrado com sucesso!'),
        findsOneWidget,
      );

      final shell = tester.widget<AppShell>(find.byType(AppShell));
      shell.onNavigate('/ministry/handoff');
      await drain(tester);
      expect(find.text('Jornada Sintética'), findsOneWidget);
      final referral = find.byKey(
        const Key('handoff-referral-11111111-1111-4111-8111-111111111111'),
      );
      tester.widget<ListTile>(referral).onTap!.call();
      await tester.pump();
      expect(tester.widget<ListTile>(referral).selected, isTrue);
      await drain(tester);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Referência do convertido'), findsOneWidget);
      expect(fixture.promotionCount, 0);
      expect(find.text('Revisar aluno existente'), findsOneWidget);
      final handoffPage = tester.widget<ConvertHandoffPage>(
        find.byType(ConvertHandoffPage),
      );
      final promotion = await tester.runAsync(
        () => handoffPage.handoff.promote(
          operationId: '77777777-7777-4777-8777-777777777777',
          convertId: fixture.convertId!,
          congregationId: RootFixture.scopeId,
        ),
      );
      expect(promotion?.convertId, fixture.convertId);
      expect(promotion?.studentId, RootFixture.syntheticStudentId);
      final enrollment = await tester.runAsync(
        () => handoffPage.ministry.command(
          name: 'enroll_student',
          operationId: '88888888-8888-4888-8888-888888888888',
          payload: {
            'id': RootFixture.enrollmentRecordId,
            'congregation_id': RootFixture.scopeId,
            'class_id': RootFixture.classId,
            'student_id': promotion!.studentId,
            'start_date': '2026-10-17',
          },
        ),
      );
      expect(enrollment?.id, RootFixture.enrollmentRecordId);
      expect(fixture.promotionCount, 1);

      await tester.tap(
        find.byKey(const ValueKey('app-shell-ministry-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frequência').last);
      await drain(tester);
      expect(find.text('Turma Sintética'), findsOneWidget);
      await tester.tap(find.text('Turma Sintética').last);
      await drain(tester);
      await tester.tap(find.byType(DropdownButton<AttendanceStatus>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Presente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar e finalizar'));
      await drain(tester);

      expect(fixture.convertId, isNotNull);
      expect(fixture.convertPayload?['congregation_id'], RootFixture.scopeId);
      expect(fixture.promotionPayload?['convert_id'], fixture.convertId);
      expect(fixture.promotionPayload?['student_id'], isNull);
      expect(fixture.studentId, isNotNull);
      expect(fixture.studentId, RootFixture.syntheticStudentId);
      expect(fixture.enrollmentPayload?['student_id'], fixture.studentId);
      expect(fixture.enrollmentPayload?['class_id'], RootFixture.classId);
      expect(fixture.enrollmentPayload?['id'], RootFixture.enrollmentRecordId);
      expect(
        fixture.enrollmentPayload?['congregation_id'],
        RootFixture.scopeId,
      );
      expect(fixture.rosterStudentId, fixture.studentId);
      expect(fixture.attendancePayload?['marks'], {
        fixture.enrollmentPayload!['id'] as String: 'present',
      });
      expect(fixture.attendanceFinalized, isTrue);
      expect(fixture.promotionCount, 1);
      expect(fixture.studentIdentityCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  testWidgets(
    'real SDK root retains picker through resume and destroys explicit equal-scope owners',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      final chosen = Completer<Uint8List?>();
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedApplication(
            repository: fixture.auth,
            pickPhoto: () => chosen.future,
          ),
        ),
      );
      await drain(tester);
      expect(find.byType(RegisterPage), findsOneWidget);
      final owner = tester.state(find.byType(RegisterPage));
      final rootContext = tester.element(find.byType(RegisterPage));
      final router = (rootContext
          .findAncestorWidgetOfExactType<ProtectedApplication>()!);
      expect(router.repository, same(fixture.auth));
      await tester.ensureVisible(find.text('Escolher foto'));
      await tester.tap(find.text('Escolher foto'));
      await tester.pump();
      fixture.scopeGate = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Atualizando acesso…'), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
      chosen.complete(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
        ),
      );
      await tester.pump();
      fixture.scopeGate!.complete();
      fixture.scopeGate = null;
      await drain(tester);
      expect(tester.state(find.byType(RegisterPage)), same(owner));
      expect(find.text('Remover foto'), findsOneWidget);
      // Real UI permission callback must replace the owner despite equal flags.
      await tester.tap(find.byTooltip('Enviar sugestão'));
      await tester.pump();
      final callback = tester
          .widget<FeedbackDialog>(find.byType(FeedbackDialog))
          .onScopeRefresh;
      final refresh = callback();
      await drain(tester);
      await refresh;
      expect(find.text('Remover foto'), findsNothing);
      expect(tester.state(find.byType(RegisterPage)), isNot(same(owner)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  testWidgets(
    'SDK identity switch while chooser is pending discards old form and bytes',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      final chosen = Completer<Uint8List?>();
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedApplication(
            repository: fixture.auth,
            pickPhoto: () => chosen.future,
          ),
        ),
      );
      await drain(tester);
      final owner = tester.state(find.byType(RegisterPage));
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Synthetic private draft',
      );
      await tester.ensureVisible(find.text('Escolher foto'));
      await tester.tap(find.text('Escolher foto'));
      await tester.pump();
      await tester.runAsync(
        () => fixture.identity('22222222-2222-2222-2222-222222222222'),
      );
      await drain(tester);
      chosen.complete(Uint8List.fromList([1, 2, 3]));
      await drain(tester);
      expect(tester.state(find.byType(RegisterPage)), isNot(same(owner)));
      expect(find.text('Synthetic private draft'), findsNothing);
      expect(find.text('Remover foto'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  for (final changed in [false, true]) {
    testWidgets(
      'resume ${changed ? 'changed scope' : 'failure'} discards pending chooser and protected form',
      (tester) async {
        final fixture = RootFixture();
        await tester.runAsync(fixture.initialize);
        final chosen = Completer<Uint8List?>();
        await tester.pumpWidget(
          MaterialApp(
            home: ProtectedApplication(
              repository: fixture.auth,
              pickPhoto: () => chosen.future,
            ),
          ),
        );
        await drain(tester);
        final owner = tester.state(find.byType(RegisterPage));
        await tester.enterText(
          find.byKey(const ValueKey('name')),
          'Synthetic private draft',
        );
        await tester.ensureVisible(find.text('Escolher foto'));
        await tester.tap(find.text('Escolher foto'));
        await tester.pump();
        fixture.admin = false;
        fixture.failScope = !changed;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await drain(tester);
        chosen.complete(Uint8List.fromList([1, 2, 3]));
        await drain(tester);
        expect(find.text('Synthetic private draft'), findsNothing);
        expect(find.text('Remover foto'), findsNothing);
        if (changed) {
          expect(tester.state(find.byType(RegisterPage)), isNot(same(owner)));
        } else {
          expect(find.byType(RegisterPage), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.close);
      },
    );
  }
  testWidgets(
    'actual SDK root connects all five Admin tabs and both feedback owners',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      await tester.pumpWidget(
        MaterialApp(home: ProtectedApplication(repository: fixture.auth)),
      );
      await drain(tester);
      tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/admin');
      await drain(tester);
      for (final label in [
        'Congregações',
        'Acessos',
        'Relatório',
        'Eventos',
        'Backup',
      ]) {
        final choice = find.widgetWithText(ChoiceChip, label);
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await drain(tester);
        expect(find.textContaining('ainda não está disponível'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(fixture.paths, contains('/rest/v1/congregations'));
      expect(fixture.paths, contains('/rest/v1/user_access'));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
}
