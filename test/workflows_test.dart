import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_codec.dart';
import 'package:ieadpe_converts/features/ministry/ui/students_page.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/ministry/ui/convert_handoff_page.dart';
import 'package:ieadpe_converts/features/home/home_page.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';

import '../integration_test/unified_journey_test.dart' as journey;
import 'support/date_picker.dart';

class LoopbackHttp extends HttpOverrides {}

class _CapturedZoneHttpClient extends http.BaseClient {
  _CapturedZoneHttpClient(this.inner, this.zone);

  final http.BaseClient inner;
  final Zone zone;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await zone.run(() => inner.send(request));
    late final StreamSubscription<List<int>> subscription;
    late final StreamController<List<int>> body;
    body = StreamController<List<int>>(
      onListen: () {
        zone.run(() {
          subscription = response.stream.listen(
            body.add,
            onError: body.addError,
            onDone: body.close,
          );
        });
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () => subscription.cancel(),
    );
    return http.StreamedResponse(
      body.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => inner.close();
}

http.Request _studentRegistrationRequest(Map<String, String> ids) {
  return http.Request(
    'POST',
    Uri.parse('http://127.0.0.1/rest/v1/rpc/ieadpe_ministry_register_student'),
  )..body = jsonEncode({'payload': ids});
}

class RootFixture {
  static const scopeId = '33333333-3333-4333-8333-333333333333';
  static const syntheticStudentId = '22222222-2222-4222-8222-222222222222';
  static const syntheticPersonId = '77777777-7777-4777-8777-777777777777';
  static const classId = '44444444-4444-4444-8444-444444444444';
  static const sessionId = '55555555-5555-4555-8555-555555555555';
  static const enrollmentRecordId = '66666666-6666-4666-8666-666666666666';
  late HttpServer server;
  late SupabaseClient client;
  late HttpClient http;
  late AuthRepository auth;
  bool admin = true, failScope = false, ministrySupervision = false;
  String? displayName;
  Completer<void>? scopeGate;
  Zone? _transportZone;
  Duration requestDrainTimeout = const Duration(seconds: 5);
  final pendingRequestHandlers = <Future<void>>{};
  final requestHandlerErrors = <AsyncError>[];
  final requestStages = <HttpRequest, String>{};
  final paths = <String>[];
  final convertListScopes = <Object?>[];
  String? convertId;
  String? studentId;
  String? enrollmentId;
  Map<String, Object?>? convertPayload;
  Map<String, Object?>? promotionPayload;
  Map<String, Object?>? enrollmentPayload;
  Map<String, Object?>? attendancePayload;
  Map<String, Object?>? studentRegistrationPayload;
  String? rosterStudentId;
  bool attendanceFinalized = false;
  int promotionCount = 0;
  final linkedStudentIds = <String>{};
  int get studentIdentityCount => linkedStudentIds.length;
  Future<void> initialize() async {
    _transportZone = Zone.current;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Future<void> handleRequest(HttpRequest request) async {
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
            'congregation_ids': admin ? <String>[] : [scopeId],
            'ministry_supervision': ministrySupervision,
            'ministry_congregation_ids': [scopeId],
          };
        }
      }
      if (request.uri.path == '/rest/v1/congregations') {
        value = [
          {'id': scopeId, 'name': 'Congregação Sintética', 'archived_at': null},
        ];
      }
      if (rpc == 'ieadpe_ministry_list_converts') {
        final requestValue = params['request'] as Map?;
        final scope = requestValue?['congregation_id'];
        convertListScopes.add(scope);
        if (!admin && scope == null) {
          request.response.statusCode = 403;
          value = {'code': '42501', 'message': 'forbidden'};
        } else {
          value = {'items': <Object>[], 'next_cursor': null};
        }
      }
      if (rpc == 'ieadpe_convert_dashboard_page') {
        final requestValue = params['request'] as Map?;
        final scope = requestValue?['congregation_id'];
        convertListScopes.add(scope);
        if (!admin && scope != scopeId) {
          request.response.statusCode = 403;
          value = {'code': '42501', 'message': 'forbidden'};
        } else {
          value = {'items': <Object>[], 'next_cursor': null};
        }
      }
      if (rpc == 'ieadpe_convert_dashboard_counts') {
        final ids = (params['request'] as Map)['congregation_ids'] as List;
        value = {
          'counts': [
            for (final id in ids) {'congregation_id': id, 'red_count': 0},
          ],
        };
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
        value = {
          'id': convertId,
          'person_id': syntheticPersonId,
          'revision': 1,
          'person_revision': 1,
        };
      }
      if (rpc == 'ieadpe_promote_convert_to_student') {
        promotionCount++;
        promotionPayload = payload;
        studentId = syntheticStudentId;
        linkedStudentIds.add(studentId!);
        value = {
          'convert_id': payload['convert_id'],
          'student_id': studentId,
          'person_id': syntheticPersonId,
          'congregation_id': payload['congregation_id'],
          'status': 'linked',
        };
      }
      if (rpc == 'ieadpe_ministry_register_student') {
        studentRegistrationPayload = payload;
        value = {
          'id': payload['id'],
          'person_id': payload['person_id'],
          'revision': 1,
          'person_revision': 1,
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
                    'name': (convertPayload?['person'] as Map?)?['name'],
                    'phone': (convertPayload?['person'] as Map?)?['phone'],
                    'address':
                        (convertPayload?['person'] as Map?)?['address'] is Map
                        ? ((convertPayload?['person'] as Map)['address']
                              as Map)['street']
                        : null,
                    'conversion_date':
                        (convertPayload?['convert']
                            as Map?)?['conversion_date'],
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
        value = {
          'id': enrollmentId,
          'student_id': studentId,
          'person_id': payload['person_id'],
          'revision': 1,
          'student_revision': 1,
        };
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
              'student_name': (convertPayload?['person'] as Map?)?['name'],
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
    }

    server.listen((request) {
      late final Future<void> handler;
      requestStages[request] = 'reading request body for ${request.uri.path}';
      handler = handleRequest(request)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              requestHandlerErrors.add(AsyncError(error, stackTrace));
            },
          )
          .whenComplete(() {
            pendingRequestHandlers.remove(handler);
            requestStages.remove(request);
          });
      pendingRequestHandlers.add(handler);
    });
    http = LoopbackHttp().createHttpClient(null)..idleTimeout = Duration.zero;
    final baseHttpClient = IOClient(http);
    final transportClient = _CapturedZoneHttpClient(
      baseHttpClient,
      _transportZone!,
    );
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic',
      httpClient: transportClient,
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
        'user_metadata': <String, Object>{'full_name': ?displayName},
      },
    }),
  );
  Future<void> close() async {
    scopeGate?.complete();
    scopeGate = null;
    var drainTimedOut = false;
    try {
      final deadline = DateTime.now().add(requestDrainTimeout);
      while (pendingRequestHandlers.isNotEmpty) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException(
            'Timed out waiting for ${pendingRequestHandlers.length} accepted HTTP request handler(s) to finish: ${requestStages.values.join('; ')}',
            requestDrainTimeout,
          );
        }
        await Future.wait(pendingRequestHandlers.toList()).timeout(
          remaining,
          onTimeout: () => throw TimeoutException(
            'Timed out waiting for ${pendingRequestHandlers.length} accepted HTTP request handler(s) to finish: ${requestStages.values.join('; ')}',
            requestDrainTimeout,
          ),
        );
      }
      if (requestHandlerErrors.isNotEmpty) {
        final failure = requestHandlerErrors.first;
        Error.throwWithStackTrace(
          StateError(
            'RootFixture HTTP request handler failed: ${failure.error}',
          ),
          failure.stackTrace,
        );
      }
    } on TimeoutException {
      drainTimedOut = true;
      rethrow;
    } finally {
      await client.dispose();
      http.close(force: true);
      final serverClosed = server.close(force: true);
      if (drainTimedOut) {
        unawaited(
          serverClosed.then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              requestHandlerErrors.add(AsyncError(error, stackTrace));
            },
          ),
        );
      } else {
        await serverClosed;
      }
    }
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

Future<void> selectSyntheticCongregation(WidgetTester tester) async {
  final field = find.byKey(const ValueKey('convert-congregation'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Congregação Sintética').last);
  await tester.pumpAndSettle();
}

Future<void> settleLoopback(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
  await tester.pump();
}

class DelayedScopeStudentsRepository extends MinistryBrowserRepository {
  DelayedScopeStudentsRepository(super.gateway);

  final oldScopeRequestStarted = Completer<void>();
  final oldScopeResponse = Completer<MinistryPage<MinistryStudentSummary>>();

  @override
  Future<MinistryPage<MinistryStudentSummary>> listStudents({
    required String congregationId,
    String? namePrefix,
    int limit = 50,
    String? cursor,
  }) {
    if (congregationId == RootFixture.scopeId) {
      if (!oldScopeRequestStarted.isCompleted) {
        oldScopeRequestStarted.complete();
      }
      return oldScopeResponse.future;
    }
    return Future.value(
      MinistryPage(
        items: [
          const MinistryStudentSummary(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            personId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            congregationId: '99999999-9999-4999-8999-999999999999',
            name: 'Student from current scope',
            phone: null,
            birthDate: null,
            address: null,
            education: null,
            maritalStatus: null,
            newConvert: false,
            waterBaptized: null,
            wantsBaptism: null,
            archivedAt: null,
            revision: 1,
            personRevision: 1,
            linkState: PersonLinkState.linked,
          ),
        ],
        nextCursor: null,
      ),
    );
  }
}

void main() {
  testWidgets(
    'students page discards a late list response after congregation scope changes',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      final repository = DelayedScopeStudentsRepository(
        SupabaseGateway(fixture.client, ProtectedDataBoundary()),
      );
      var selectedScope = RootFixture.scopeId;

      Widget page() => MaterialApp(
        home: StudentsPage(
          repository: repository,
          congregationId: selectedScope,
          onOpenHandoff: () {},
        ),
      );

      await tester.pumpWidget(page());
      await repository.oldScopeRequestStarted.future;
      selectedScope = '99999999-9999-4999-8999-999999999999';
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('Student from current scope'), findsOneWidget);

      repository.oldScopeResponse.complete(
        MinistryPage(
          items: [
            const MinistryStudentSummary(
              id: RootFixture.syntheticStudentId,
              personId: RootFixture.syntheticPersonId,
              congregationId: RootFixture.scopeId,
              name: 'Stale student from previous scope',
              phone: null,
              birthDate: null,
              address: null,
              education: null,
              maritalStatus: null,
              newConvert: false,
              waterBaptized: null,
              wantsBaptism: null,
              archivedAt: null,
              revision: 1,
              personRevision: 1,
              linkState: PersonLinkState.linked,
            ),
          ],
          nextCursor: null,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Student from current scope'), findsOneWidget);
      expect(find.text('Stale student from previous scope'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  test(
    'journey observer ignores denied fixture identity and reports UI identity',
    () async {
      final observer = journey.JourneyHttpObserver(
        MockClient((_) async => http.Response('{}', 200)),
        excludedStudentIds: {RootFixture.syntheticStudentId},
      );
      final deniedFixtureIds = {
        'id': RootFixture.syntheticStudentId,
        'person_id': RootFixture.syntheticPersonId,
      };
      await observer.send(_studentRegistrationRequest(deniedFixtureIds));
      expect(observer.ownedIdentityReported, isFalse);

      final rejectedObserver = journey.JourneyHttpObserver(
        MockClient((_) async => http.Response('{}', 403)),
      );
      await rejectedObserver.send(
        _studentRegistrationRequest({
          'id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'person_id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        }),
      );
      expect(rejectedObserver.ownedIdentityReported, isFalse);
      expect(rejectedObserver.reportedStudentId, isNull);
      rejectedObserver.close();

      const uiStudentId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const uiPersonId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      await observer.send(
        _studentRegistrationRequest({
          'id': uiStudentId,
          'person_id': uiPersonId,
        }),
      );
      expect(observer.ownedIdentityReported, isTrue);
      expect(observer.reportedStudentId, uiStudentId);
      expect(observer.reportedPersonId, uiPersonId);
      observer.close();
    },
  );
  test('journey observer records the successful finalize receipt after a draft', () async {
    final observer = journey.JourneyHttpObserver(
      MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final finalize = (payload['payload'] as Map)['finalize'] as bool;
        return http.Response(
          jsonEncode({'status': finalize ? 'finalized' : 'open'}),
          200,
        );
      }),
    );
    final sessionId = RootFixture.sessionId;
    final enrollmentId = RootFixture.enrollmentRecordId;

    Future<void> saveAttendance({required bool finalize}) async {
      final request =
          http.Request(
              'POST',
              Uri.parse(
                'http://127.0.0.1/rest/v1/rpc/ieadpe_ministry_save_attendance',
              ),
            )
            ..body = jsonEncode({
              'operation_id': finalize
                  ? '88888888-8888-4888-8888-888888888888'
                  : '99999999-9999-4999-8999-999999999999',
              'payload': {
                'congregation_id': RootFixture.scopeId,
                'session_id': sessionId,
                'expected_revision': finalize ? 2 : 1,
                'marks': {enrollmentId: 'present'},
                'finalize': finalize,
              },
            });
      await observer.send(request);
    }

    await saveAttendance(finalize: false);
    expect(observer.attendanceOperationId, isNull);
    expect(observer.attendancePayload, isNull);
    expect(observer.attendanceReceipt, isNull);
    await saveAttendance(finalize: true);
    expect(
      observer.attendanceOperationId,
      '88888888-8888-4888-8888-888888888888',
    );
    expect(observer.attendancePayload?['finalize'], isTrue);
    expect(observer.attendanceReceipt, {'status': 'finalized'});
    observer.close();
  });

  testWidgets(
    'production root opens public registration for a session-less SDK',
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
      expect(find.text('Cadastro público'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Entrar com Google'), findsNothing);
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
        find.byKey(const ValueKey('person-name')),
        'Jornada Sintética',
      );
      await tester.enterText(
        find.byKey(const ValueKey('landmark')),
        'Perto da praça',
      );
      await pickDate(
        tester,
        const ValueKey('conversion_date'),
        DateTime(2026, 10, 15),
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
      expect(promotion?.personId, RootFixture.syntheticPersonId);
      final enrollment = await tester.runAsync(
        () => handoffPage.ministry.command(
          name: 'enroll_student',
          operationId: '88888888-8888-4888-8888-888888888888',
          payload: {
            'id': RootFixture.enrollmentRecordId,
            'congregation_id': RootFixture.scopeId,
            'class_id': RootFixture.classId,
            'person_id': promotion!.personId,
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
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Finalizar chamada'),
        ),
      );
      await drain(tester);

      expect(fixture.convertId, isNotNull);
      expect(fixture.convertPayload?['congregation_id'], RootFixture.scopeId);
      expect(fixture.promotionPayload?['convert_id'], fixture.convertId);
      expect(fixture.promotionPayload?['student_id'], isNull);
      expect(fixture.studentId, isNotNull);
      expect(fixture.studentId, RootFixture.syntheticStudentId);
      expect(
        fixture.enrollmentPayload?['person_id'],
        RootFixture.syntheticPersonId,
      );
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

      // The protected production registration route creates a canonical
      // person plus an independent non-convert student record.
      tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/ministry');
      await drain(tester);
      await tester.tap(
        find.byKey(const ValueKey('app-shell-ministry-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alunos').last);
      await drain(tester);
      await tester.tap(find.text('Registrar aluno').last);
      await drain(tester);
      expect(find.byKey(const ValueKey('student-education')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('person-name')),
        'Cadastro sem conversão',
      );
      await tester.enterText(
        find.byKey(const ValueKey('student-education')),
        'Ensino médio',
      );
      final registerStudentSubmit = find.widgetWithText(
        FilledButton,
        'Cadastrar aluno',
      );
      await tester.ensureVisible(registerStudentSubmit);
      await tester.pumpAndSettle();
      await tester.tap(registerStudentSubmit);
      await drain(tester);
      expect(fixture.studentRegistrationPayload, isNotNull);
      final registration = fixture.studentRegistrationPayload!;
      expect(registration['congregation_id'], RootFixture.scopeId);
      expect((registration['person'] as Map)['name'], 'Cadastro sem conversão');
      expect((registration['academic'] as Map)['new_convert'], isFalse);
      expect(registration.containsKey('convert_id'), isFalse);
      expect(registration.containsKey('conversion_date'), isFalse);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  testWidgets('local home loads without repeated access refresh', (
    tester,
  ) async {
    final fixture = RootFixture()..admin = false;
    await tester.runAsync(fixture.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: ProtectedApplication(
          repository: fixture.auth,
          intendedRoute: '/home',
        ),
      ),
    );
    await drain(tester);
    tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/home');
    await drain(tester);
    await settleLoopback(tester);
    await drain(tester);
    expect(fixture.convertListScopes, [RootFixture.scopeId]);
    expect(find.text('Atualizando acesso…'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  });
  testWidgets(
    'supervision chooses a congregation from team and uses it across ministry',
    (tester) async {
      final fixture = RootFixture()..ministrySupervision = true;
      await tester.runAsync(fixture.initialize);
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedApplication(
            repository: fixture.auth,
            intendedRoute: '/ministry/team',
          ),
        ),
      );
      await drain(tester);
      expect(
        find.byKey(const ValueKey('ministry-workspace-congregation')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('ministry-workspace-congregation')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Congregação Sintética').last);
      await drain(tester);
      expect(find.text('Diretório da congregação'), findsOneWidget);
      await tester.tap(find.text('Adicionar contato'));
      await tester.pumpAndSettle();
      expect(find.text('Congregação: Congregação Sintética'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      for (final section in ['Alunos', 'Turmas']) {
        await tester.tap(
          find.byKey(const ValueKey('app-shell-ministry-selector')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(section).last);
        await drain(tester);
        expect(
          find.byKey(const ValueKey('ministry-workspace-congregation')),
          findsOneWidget,
        );
        expect(find.text('Congregação Sintética'), findsOneWidget);
        await tester.tap(
          find
              .text(section == 'Alunos' ? 'Registrar aluno' : 'Nova turma')
              .last,
        );
        await drain(tester);
        expect(find.text('Congregação: Congregação Sintética'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancelar').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar').last);
        await drain(tester);
      }
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
      await selectSyntheticCongregation(tester);
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
      await selectSyntheticCongregation(tester);
      await tester.enterText(
        find.byKey(const ValueKey('person-name')),
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
        await selectSyntheticCongregation(tester);
        await tester.enterText(
          find.byKey(const ValueKey('person-name')),
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
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  testWidgets(
    'SDK root renders session greeting without framework exceptions and clears old home state on identity switch',
    (tester) async {
      final fixture = RootFixture()..displayName = ' Maria Silva ';
      await tester.runAsync(fixture.initialize);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildUnifiedTheme(),
          home: ProtectedApplication(repository: fixture.auth),
        ),
      );
      await drain(tester);
      tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/home');
      await drain(tester);
      expect(find.text('Olá, Maria Silva!'), findsOneWidget);
      final oldHomeState = tester.state(find.byType(HomePage));
      expect(
        tester.takeException(),
        isNull,
        reason:
            'the production themed Home root must not emit Flutter exceptions',
      );

      fixture.displayName = 'Ana Souza';
      await tester.runAsync(
        () => fixture.identity('22222222-2222-2222-2222-222222222222'),
      );
      await drain(tester);
      expect(find.text('Olá, Ana Souza!'), findsOneWidget);
      expect(find.text('Olá, Maria Silva!'), findsNothing);
      expect(tester.state(find.byType(HomePage)), isNot(same(oldHomeState)));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
}
