import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/features/intake/public_intake_repository.dart';
import 'package:ieadpe_converts/features/intake/turnstile_challenge.dart';

const _apiUrl = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _runId = String.fromEnvironment('JOURNEY_RUN_ID');
const _congregationAId = String.fromEnvironment('JOURNEY_CONGREGATION_A_ID');
const _congregationAName = String.fromEnvironment(
  'JOURNEY_CONGREGATION_A_NAME',
);
const _outOfScopeEmail = String.fromEnvironment('JOURNEY_OUT_OF_SCOPE_EMAIL');
const _outOfScopePassword = String.fromEnvironment(
  'JOURNEY_OUT_OF_SCOPE_PASSWORD',
);
const _supervisorEmail = String.fromEnvironment('JOURNEY_SUPERVISOR_EMAIL');
const _supervisorPassword = String.fromEnvironment(
  'JOURNEY_SUPERVISOR_PASSWORD',
);
const _publicConvertName = String.fromEnvironment(
  'JOURNEY_PUBLIC_CONVERT_NAME',
);
const _allowedOrigin = String.fromEnvironment('JOURNEY_ALLOWED_ORIGIN');
const _intakeTestEndpoint = String.fromEnvironment(
  'JOURNEY_INTAKE_TEST_ENDPOINT',
);

void registerPublicIntakeJourneyTests() {
  testWidgets(
    'anonymous public intake remains pending until a scoped reviewer approves it',
    (tester) async {
      final api = Uri.tryParse(_apiUrl);
      final testEndpoint = Uri.tryParse(_intakeTestEndpoint);
      expect(api, isNotNull);
      expect(
        api!.scheme == 'http' &&
            const {'localhost', '127.0.0.1', '::1'}.contains(api.host),
        isTrue,
        reason: 'The journey refuses non-loopback Supabase endpoints.',
      );
      expect(_anonKey, isNotEmpty);
      expect(_runId, isNotEmpty);
      expect(_congregationAId, isNotEmpty);
      expect(_congregationAName, isNotEmpty);
      expect(_publicConvertName, isNotEmpty);
      expect(_outOfScopeEmail, isNotEmpty);
      expect(_outOfScopePassword, isNotEmpty);
      expect(_supervisorEmail, isNotEmpty);
      expect(_supervisorPassword, isNotEmpty);
      expect(_allowedOrigin, 'http://127.0.0.1:7357');
      expect(testEndpoint, isNotNull);
      expect(
        testEndpoint!.scheme == 'http' &&
            testEndpoint.host == '127.0.0.1' &&
            testEndpoint.path == '/functions/v1/public-intake' &&
            !testEndpoint.hasQuery &&
            !testEndpoint.hasFragment &&
            testEndpoint.userInfo.isEmpty,
        isTrue,
        reason: 'The deterministic function seam must be loopback-only.',
      );

      final supabase = SupabaseClient(
        _apiUrl,
        _anonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final auth = AuthRepository(
        supabase,
        AuthRedirectPolicy(Uri.parse('$_allowedOrigin/auth/callback')),
      );
      final intakeHttp = _LoopbackFunctionRewriteClient(
        supabaseUrl: api,
        functionEndpoint: testEndpoint,
      );
      final publicIntake = PublicIntakeRepository(
        supabaseUrl: api,
        publishableKey: _anonKey,
        client: intakeHttp,
        requestTimeout: const Duration(seconds: 20),
      );
      final challengeSequence = _JourneyTokenSequence(_runId);

      try {
        await tester.pumpWidget(
          App(
            key: const ValueKey('public-intake-journey'),
            auth: auth,
            publicIntakeRepository: publicIntake,
            turnstileChallengeFactory: () =>
                _JourneyTurnstileChallenge(challengeSequence),
            initialPath: '/register',
          ),
        );
        await _waitFor(
          tester,
          () => find.text('Congregação *').evaluate().isNotEmpty,
          'active congregation picker',
        );
        await _fillAnonymousForm(tester, _publicConvertName);
        await _tapText(tester, 'Cadastrar');

        await _waitFor(
          tester,
          () => find
              .text(
                'Não foi possível confirmar o envio. Seus dados estão mantidos para uma nova tentativa.',
              )
              .evaluate()
              .isNotEmpty,
          'recoverable unknown outcome after the accepted response is dropped',
        );
        expect(
          _editable(tester, 'person-name').evaluate().isNotEmpty,
          isTrue,
          reason: 'The anonymous draft must remain available for safe retry.',
        );
        await _tapText(tester, 'Tentar envio novamente');
        await _waitFor(
          tester,
          () => find
              .text('Cadastro enviado para análise da congregação.')
              .evaluate()
              .isNotEmpty,
          'generic anonymous acceptance',
        );
        expect(intakeHttp.submissions, hasLength(2));
        final first = intakeHttp.submissions.first;
        final retry = intakeHttp.submissions.last;
        expect(retry['submission_id'], first['submission_id']);
        expect(retry['draft'], first['draft']);
        expect(retry['turnstile_token'], isNot(first['turnstile_token']));
        expect(intakeHttp.publicResponses, hasLength(2));
        for (final response in intakeHttp.publicResponses) {
          expect(response, {'status': 'received'});
        }
        expect(
          find.textContaining(_publicConvertName),
          findsNothing,
          reason: 'The public success surface must not reveal submitted data.',
        );

        await _expectForbidden(
          () => supabase.rpc(
            'ieadpe_list_pending_intake',
            params: {
              'request': {
                'congregation_id': _congregationAId,
                'limit': 50,
                'cursor': null,
              },
            },
          ),
        );
        await _expectForbidden(
          () => supabase.rpc(
            'ieadpe_receive_public_intake',
            params: {'request': <String, Object?>{}},
          ),
        );
        await _expectForbidden(
          () => supabase.rpc(
            'ieadpe_create_convert',
            params: {
              'operation_id': '00000000-0000-4000-8000-000000000001',
              'payload': <String, Object?>{},
            },
          ),
        );
        await _expectUnsignedStorageUploadDenied(supabase);

        await supabase.auth.signInWithPassword(
          email: _supervisorEmail,
          password: _supervisorPassword,
        );
        final supervisorId = supabase.auth.currentUser!.id;
        expect(
          await _officialRecords(supabase, _publicConvertName),
          isEmpty,
          reason: 'An accepted pending draft must not enter official lists.',
        );
        expect(
          await _officialReportRecords(supabase, _publicConvertName),
          isEmpty,
          reason: 'An accepted pending draft must not appear in reports.',
        );

        final submissionId = first['submission_id'] as String;
        final wrongReviewer = SupabaseClient(
          _apiUrl,
          _anonKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        try {
          await wrongReviewer.auth.signInWithPassword(
            email: _outOfScopeEmail,
            password: _outOfScopePassword,
          );
          await _expectForbidden(
            () => wrongReviewer.rpc(
              'ieadpe_get_pending_intake',
              params: {
                'request': {'id': submissionId},
              },
            ),
          );
          await _expectForbidden(
            () => wrongReviewer.rpc(
              'ieadpe_review_pending_intake',
              params: {
                'operation_id': '00000000-0000-4000-8000-000000000002',
                'payload': {
                  'id': submissionId,
                  'expected_revision': 1,
                  'decision': 'reject',
                },
              },
            ),
          );
        } finally {
          await wrongReviewer.dispose();
        }

        await tester.pumpWidget(
          App(
            key: const ValueKey('reviewer-intake-journey'),
            auth: auth,
            publicIntakeRepository: publicIntake,
            turnstileChallengeFactory: () =>
                _JourneyTurnstileChallenge(challengeSequence),
            initialPath: '/pending',
          ),
        );
        await _waitFor(
          tester,
          () => find.text(_publicConvertName).evaluate().isNotEmpty,
          'scoped reviewer pending queue',
        );
        await _tapText(tester, _publicConvertName);
        await _waitFor(
          tester,
          () => find.text('Aprovar cadastro').evaluate().isNotEmpty,
          'review detail and approval action',
        );
        final landmark = _editable(tester, 'landmark');
        await tester.ensureVisible(landmark);
        await tester.enterText(landmark, 'Ponto corrigido pelo revisor');
        final approve = find.text('Aprovar cadastro');
        await tester.ensureVisible(approve);
        await tester.tap(approve);
        await tester.pump();
        await _waitFor(
          tester,
          () => find.text(_publicConvertName).evaluate().isEmpty,
          'approved item leaving the actionable pending queue',
        );

        final approvedItems = await _officialRecords(
          supabase,
          _publicConvertName,
        );
        expect(approvedItems, hasLength(1));
        final approved = approvedItems.single;
        final approvedConvert = Map<String, dynamic>.from(
          approved['convert'] as Map,
        );
        expect(approvedConvert['created_by'], supervisorId);
        expect(approvedConvert['landmark'], 'Ponto corrigido pelo revisor');
        expect(
          await _officialReportRecords(supabase, _publicConvertName),
          hasLength(1),
          reason: 'Approval must add exactly one official report source row.',
        );
        await _expectMissingPending(supabase, submissionId);

        final signOut = find.byTooltip('Sair');
        await _waitFor(tester, () => signOut.evaluate().isNotEmpty, 'sign-out');
        await tester.tap(signOut);
        await _waitFor(
          tester,
          () => find
              .text('Entre com sua conta Google para continuar.')
              .evaluate()
              .isNotEmpty,
          'signed-out public registration screen',
        );
        expect(supabase.auth.currentSession, isNull);
        expect(find.text(_publicConvertName), findsNothing);
        expect(find.text('Pendentes'), findsNothing);
        // ignore: avoid_print
        print('PUBLIC_INTAKE_JOURNEY=PASS');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await supabase.auth.signOut();
        intakeHttp.close();
        await supabase.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _JourneyTokenSequence {
  _JourneyTokenSequence(this.runId);
  final String runId;
  int _counter = 0;

  String next() => 'journey-test:$runId:${++_counter}';
}

class _JourneyTurnstileChallenge implements TurnstileChallenge {
  _JourneyTurnstileChallenge(this.sequence);
  final _JourneyTokenSequence sequence;

  @override
  Widget get view => const SizedBox.shrink();

  @override
  bool get isSupported => true;

  @override
  Future<String> acquireToken() async => sequence.next();

  @override
  void reset() {}

  @override
  void dispose() {}
}

class _LoopbackFunctionRewriteClient extends http.BaseClient {
  _LoopbackFunctionRewriteClient({
    required Uri supabaseUrl,
    required Uri functionEndpoint,
  }) : _supabaseUrl = supabaseUrl,
       _functionEndpoint = functionEndpoint {
    if (supabaseUrl.scheme != 'http' ||
        !const {'localhost', '127.0.0.1', '::1'}.contains(supabaseUrl.host) ||
        functionEndpoint.scheme != 'http' ||
        functionEndpoint.host != '127.0.0.1' ||
        functionEndpoint.path != '/functions/v1/public-intake' ||
        functionEndpoint.hasQuery ||
        functionEndpoint.hasFragment ||
        functionEndpoint.userInfo.isNotEmpty) {
      throw ArgumentError('The local intake test endpoint must be loopback.');
    }
  }

  final Uri _supabaseUrl;
  final Uri _functionEndpoint;
  final http.Client _inner = http.Client();
  final submissions = <Map<String, dynamic>>[];
  final publicResponses = <Map<String, dynamic>>[];
  bool _dropFirstAcceptedResponse = true;
  bool _cleanupIdReported = false;

  Uri get _submissionUri =>
      _supabaseUrl.replace(path: '/functions/v1/public-intake');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url != _submissionUri) return _inner.send(request);
    if (request.method != 'POST' || request.url.hasQuery) {
      throw http.ClientException(
        'Unexpected public intake request.',
        request.url,
      );
    }
    final bytes = await request.finalize().toBytes();
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bytes)) as Map,
    );
    submissions.add(body);
    final submissionId = body['submission_id'];
    if (!_cleanupIdReported &&
        submissionId is String &&
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(submissionId)) {
      _cleanupIdReported = true;
      // ignore: avoid_print
      print('PUBLIC_INTAKE_CLEANUP_ID=$submissionId');
    }
    final forwarded = http.Request('POST', _functionEndpoint)
      ..headers.addAll(request.headers)
      ..bodyBytes = bytes;
    final response = await _inner.send(forwarded);
    final responseBytes = await response.stream.toBytes();
    if (response.statusCode == 202) {
      publicResponses.add(
        Map<String, dynamic>.from(
          jsonDecode(utf8.decode(responseBytes)) as Map,
        ),
      );
    }
    if (_dropFirstAcceptedResponse && response.statusCode == 202) {
      _dropFirstAcceptedResponse = false;
      return http.StreamedResponse(
        Stream<List<int>>.error(
          http.ClientException('Synthetic accepted-response loss.'),
        ),
        response.statusCode,
        request: forwarded,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(responseBytes),
      response.statusCode,
      request: forwarded,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

Future<void> _fillAnonymousForm(WidgetTester tester, String name) async {
  await _tapText(tester, 'Congregação *');
  await tester.pumpAndSettle();
  await _tapText(tester, _congregationAName);

  final personName = _editable(tester, 'person-name');
  await tester.ensureVisible(personName);
  await tester.enterText(personName, name);
  final landmark = _editable(tester, 'landmark');
  await tester.ensureVisible(landmark);
  await tester.enterText(landmark, 'Ponto público');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await _tap(tester, find.byKey(const ValueKey('convert-gender')));
  await tester.pumpAndSettle();
  await _tapText(tester, 'Feminino');
  final date = DateTime.now().toIso8601String().substring(0, 10);
  final dateField = find.byKey(const ValueKey('conversion_date'));
  await tester.ensureVisible(dateField);
  await tester.enterText(dateField, date);
  await _tap(tester, find.byKey(const ValueKey('convert-worship')));
  await tester.pumpAndSettle();
  await _tapText(tester, worshipTypes.first);
}

Finder _editable(WidgetTester tester, String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EditableText),
);

Future<List<Map<String, dynamic>>> _officialRecords(
  SupabaseClient client,
  String name,
) async {
  final raw = await client.rpc(
    'ieadpe_ministry_list_converts',
    params: {
      'request': {
        'congregation_id': _congregationAId,
        'name_prefix': name,
        'limit': 100,
        'cursor': null,
      },
    },
  );
  final items = Map<String, dynamic>.from(raw as Map)['items'] as List;
  return items.map((item) => Map<String, dynamic>.from(item as Map)).where((
    item,
  ) {
    final person = item['person'];
    return person is Map && person['name'] == name;
  }).toList();
}

Future<List<Map<String, dynamic>>> _officialReportRecords(
  SupabaseClient client,
  String name,
) async {
  final rows = await client
      .from('converts')
      .select('id, name')
      .eq('name', name)
      .eq('congregation_id', _congregationAId);
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
}

Future<void> _expectForbidden(Future<dynamic> Function() operation) async {
  try {
    await operation();
    fail('An unauthorized public intake bypass unexpectedly succeeded.');
  } on PostgrestException catch (error) {
    expect(error.code, '42501');
  }
}

Future<void> _expectUnsignedStorageUploadDenied(SupabaseClient client) async {
  final objectPath = 'journey-test/$_runId/unsigned.jpg';
  try {
    await client.storage
        .from('convert-photos')
        .uploadBinary(
          objectPath,
          Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    fail('An anonymous client unexpectedly uploaded to private photo Storage.');
  } on StorageException catch (error) {
    expect({'400', '401', '403', '404'}, contains(error.statusCode));
  }
}

Future<void> _expectMissingPending(
  SupabaseClient client,
  String submissionId,
) async {
  try {
    await client.rpc(
      'ieadpe_get_pending_intake',
      params: {
        'request': {'id': submissionId},
      },
    );
    fail('An approved item remained actionable in the pending RPC.');
  } on PostgrestException catch (error) {
    expect(error.code, '22023');
    expect(error.message, contains('pending_not_found'));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _waitFor(tester, () => target.evaluate().isNotEmpty, 'tap target');
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String label) async =>
    _tap(tester, find.text(label).last);
