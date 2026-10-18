import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

const _apiUrl = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _runId = String.fromEnvironment('JOURNEY_RUN_ID');
const _congregationAId = String.fromEnvironment('JOURNEY_CONGREGATION_A_ID');
const _congregationBId = String.fromEnvironment('JOURNEY_CONGREGATION_B_ID');
const _classId = String.fromEnvironment('JOURNEY_CLASS_ID');
const _sessionId = String.fromEnvironment('JOURNEY_SESSION_ID');
const _attackEnrollmentId = String.fromEnvironment(
  'JOURNEY_ATTACK_ENROLLMENT_ID',
);
const _registrarEmail = String.fromEnvironment('JOURNEY_REGISTRAR_EMAIL');
const _registrarPassword = String.fromEnvironment('JOURNEY_REGISTRAR_PASSWORD');
const _supervisorEmail = String.fromEnvironment('JOURNEY_SUPERVISOR_EMAIL');
const _supervisorPassword = String.fromEnvironment(
  'JOURNEY_SUPERVISOR_PASSWORD',
);
const _directionEmail = String.fromEnvironment('JOURNEY_DIRECTION_EMAIL');
const _directionPassword = String.fromEnvironment('JOURNEY_DIRECTION_PASSWORD');
const _outsideEmail = String.fromEnvironment('JOURNEY_OUT_OF_SCOPE_EMAIL');
const _outsidePassword = String.fromEnvironment(
  'JOURNEY_OUT_OF_SCOPE_PASSWORD',
);
const _directionAssignmentId = String.fromEnvironment(
  'JOURNEY_DIRECTION_ASSIGNMENT_ID',
);
const _convertName = String.fromEnvironment('JOURNEY_CONVERT_NAME');
const _allowedOrigin = String.fromEnvironment('JOURNEY_ALLOWED_ORIGIN');
const _controlUrl = String.fromEnvironment('JOURNEY_CONTROL_URL');
const _controlCapability = String.fromEnvironment('JOURNEY_CONTROL_CAPABILITY');
const _uuid = Uuid();

String get _runSlug => _runId.replaceAll('-', '');
String get _congregationAName => 'Journey $_runSlug A';
String get _className => 'Journey Class $_runSlug';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local authenticated app completes the unified ministry journey', (
    tester,
  ) async {
    final api = Uri.tryParse(_apiUrl);
    expect(api, isNotNull, reason: 'The runner must supply a local API URL.');
    expect(
      api!.scheme == 'http' &&
          const {'localhost', '127.0.0.1', '::1'}.contains(api.host),
      isTrue,
      reason: 'The browser test refuses non-loopback Supabase targets.',
    );
    expect(_anonKey, isNotEmpty);
    expect(_runId, isNotEmpty);
    expect(_congregationAId, isNotEmpty);
    expect(_congregationBId, isNotEmpty);
    expect(_classId, isNotEmpty);
    expect(_sessionId, isNotEmpty);
    expect(_attackEnrollmentId, isNotEmpty);
    expect(_convertName, isNotEmpty);
    expect(_allowedOrigin, 'http://127.0.0.1:7357');
    expect(_controlUrl, startsWith('http://127.0.0.1:'));
    expect(_controlCapability.length, greaterThanOrEqualTo(40));

    final client = SupabaseClient(_apiUrl, _anonKey);
    final auth = AuthRepository(
      client,
      AuthRedirectPolicy(Uri.parse('$_allowedOrigin/auth/callback')),
    );
    await tester.pumpWidget(App(auth: auth));

    // The registrar has no access rows. Registration remains an authenticated
    // app workflow and does not need a congregation assignment.
    await _signIn(tester, client, _registrarEmail, _registrarPassword);
    final registrarScope = await client.rpc('ieadpe_get_scope');
    final registrarScopeMap = Map<String, dynamic>.from(registrarScope as Map);
    expect(registrarScopeMap['is_admin'], isFalse);
    expect(registrarScopeMap['is_supervision'], isFalse);
    expect(registrarScopeMap['congregation_ids'], isEmpty);
    expect(registrarScopeMap['ministry_supervision'], isFalse);
    expect(registrarScopeMap['ministry_congregation_ids'], isEmpty);
    await _waitFor(
      tester,
      () => find.text('Cadastrar Novo Convertido').evaluate().isNotEmpty,
      'registrar form',
    );
    await tester.enterText(find.byKey(const ValueKey('name')), _convertName);
    await tester.enterText(
      find.byKey(const ValueKey('address')),
      'Rua Local da Jornada, 1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('landmark')),
      'Próximo ao mercado da jornada',
    );
    await tester.enterText(find.byKey(const ValueKey('phone')), '81999999999');
    await tester.enterText(find.byKey(const ValueKey('age')), '24');
    final conversionDate = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    await tester.enterText(
      find.byKey(const ValueKey('conversion_date')),
      conversionDate,
    );
    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<Gender>),
      'Feminino',
    );
    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<String>).last,
      '14 - Culto Evangelístico',
    );
    await _tapText(tester, 'Cadastrar');
    await _waitFor(
      tester,
      () => find
          .text('Novo convertido cadastrado com sucesso!')
          .evaluate()
          .isNotEmpty,
      'successful registration',
    );

    // A campaign supervisor assigns the new convert and records a visit in
    // the production converts widgets.
    await _signIn(tester, client, _supervisorEmail, _supervisorPassword);
    await _tap(tester, find.byKey(const ValueKey('app-shell-nav-/converts')));
    await _waitFor(
      tester,
      () => find.text(_convertName).evaluate().isNotEmpty,
      'registered convert in supervisor list',
    );
    await _tapText(tester, 'Editar');
    await _waitFor(
      tester,
      () => find.byKey(const ValueKey('name')).evaluate().isNotEmpty,
      'convert edit form',
    );
    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<String>).first,
      _congregationAName,
    );
    await _tapText(tester, 'Atualizar');
    await _waitFor(
      tester,
      () => find.text(_congregationAName).evaluate().isNotEmpty,
      'assigned congregation on convert card',
    );
    await _tapText(tester, 'Visita realizada/entramos em contato');
    await _waitFor(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
      'visit confirmation dialog',
    );
    await _tapText(tester, 'Confirmar');
    await _waitFor(
      tester,
      () => find.text('1 visitas').evaluate().isNotEmpty,
      'recorded follow-up visit',
    );
    final convertRow = await client
        .from('converts')
        .select('id, congregation_id, visit_count, was_visited_once')
        .eq('name', _convertName)
        .single();
    final convertId = convertRow['id'] as String;
    expect(convertRow['congregation_id'], _congregationAId);
    expect(convertRow['visit_count'], 1);
    expect(convertRow['was_visited_once'], isTrue);

    // A direction grant for congregation B cannot read congregation A's
    // projection or forge an enrollment into A through authenticated HTTP.
    await _signIn(tester, client, _outsideEmail, _outsidePassword);
    await _expectForbidden(
      () => client.rpc(
        'ieadpe_ministry_list_convert_referrals',
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
      () => client.rpc(
        'ieadpe_ministry_enroll_student',
        params: {
          'operation_id': _uuid.v4(),
          'payload': {
            'id': _attackEnrollmentId,
            'congregation_id': _congregationAId,
            'class_id': _classId,
            'student_id': _uuid.v4(),
            'start_date': DateTime.now().toIso8601String().substring(0, 10),
          },
        },
      ),
    );

    // The direction user sees only the scoped referral projection, then
    // explicitly links a student and explicitly enrolls that student.
    await _signIn(tester, client, _directionEmail, _directionPassword);
    final referralResponse = await client.rpc(
      'ieadpe_ministry_list_convert_referrals',
      params: {
        'request': {
          'congregation_id': _congregationAId,
          'limit': 50,
          'cursor': null,
        },
      },
    );
    final referralPage = Map<String, dynamic>.from(referralResponse as Map);
    final referrals = (referralPage['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => item['convert_id'] == convertId)
        .toList();
    expect(referrals, hasLength(1));
    expect(referrals.single.keys.toSet(), {
      'convert_id',
      'congregation_id',
      'name',
      'phone',
      'address',
      'conversion_date',
    });
    expect(referrals.single['name'], _convertName);
    expect(
      await client
          .from('ministry_enrollments')
          .select('id')
          .eq('id', _attackEnrollmentId),
      isEmpty,
    );

    await _tap(tester, find.byKey(const ValueKey('app-shell-nav-/ministry')));
    await _waitFor(
      tester,
      () => find
          .byKey(ValueKey('ministry-congregation-scope:1:$_congregationAId'))
          .evaluate()
          .isNotEmpty,
      'selected authorized congregation',
    );
    await _waitFor(
      tester,
      () => find.text(_congregationAName).evaluate().isNotEmpty,
      'authorized congregation label',
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Novos convertidos',
    );
    final referralFinder = find.byKey(Key('handoff-referral-$convertId'));
    await _waitFor(
      tester,
      () => referralFinder.evaluate().isNotEmpty,
      'production referral widget',
    );
    await _tap(tester, referralFinder);
    await _waitFor(
      tester,
      () => find
          .text('Criar aluno a partir desta referência')
          .evaluate()
          .isNotEmpty,
      'explicit student link action',
    );
    await _tapText(tester, 'Criar aluno a partir desta referência');
    await _waitFor(
      tester,
      () => find.text('Matrícula separada').evaluate().isNotEmpty,
      'linked student without automatic enrollment',
    );
    final studentRow = await client
        .from('ministry_students')
        .select('id, convert_id')
        .eq('convert_id', convertId)
        .single();
    final studentId = studentRow['id'] as String;
    expect(studentRow['convert_id'], convertId);
    expect(
      await client
          .from('ministry_enrollments')
          .select('id')
          .eq('student_id', studentId)
          .eq('class_id', _classId),
      isEmpty,
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('handoff-class-select')),
      _className,
    );
    await _tapText(tester, 'Matricular aluno');
    await _waitFor(
      tester,
      () => find
          .text('Aluno vinculado e matriculado na turma selecionada.')
          .evaluate()
          .isNotEmpty,
      'explicit class enrollment',
    );
    final enrollmentRow = await client
        .from('ministry_enrollments')
        .select('id, student_id, class_id, status')
        .eq('student_id', studentId)
        .eq('class_id', _classId)
        .single();
    final enrollmentId = enrollmentRow['id'] as String;
    expect(enrollmentRow['status'], 'active');
    expect(enrollmentRow['student_id'], studentId);

    // The attendance route finalizes through its existing production UI. Its
    // save path immediately calls _open() again and renders the frozen roster.
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Frequência',
    );
    await _waitFor(
      tester,
      () => find.text(_className).evaluate().isNotEmpty,
      'pending attendance session',
    );
    await _tapText(tester, _className);
    await _waitFor(
      tester,
      () =>
          find.text('Lista congelada').evaluate().isNotEmpty &&
          find.text(_convertName).evaluate().isNotEmpty,
      'attendance roster',
    );
    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      'Presente',
    );
    expect(find.bySemanticsLabel('Carregando frequência').evaluate(), isEmpty);
    await _tapText(tester, 'Salvar e finalizar');
    await _waitFor(
      tester,
      () =>
          find.text('Lista congelada').evaluate().isNotEmpty &&
          find.text(_convertName).evaluate().isNotEmpty,
      'immediately refreshed finalized roster',
    );
    final attendanceField = tester
        .widget<DropdownButtonFormField<AttendanceStatus>>(
          find.byType(DropdownButtonFormField<AttendanceStatus>),
        );
    expect(attendanceField.initialValue, AttendanceStatus.present);

    // Construct a new production repository over the same authenticated
    // Supabase HTTP client to verify progress persisted across repository state.
    final freshMinistry = MinistryRepository(
      SupabaseGateway(client, ProtectedDataBoundary()),
    );
    final progress = await freshMinistry.getEnrollmentProgress(
      congregationId: _congregationAId,
      enrollmentId: enrollmentId,
    );
    expect(progress.present, 1);
    expect(progress.absent, 0);
    expect(progress.denominator, 1);

    final sessionBefore = await client
        .from('ministry_sessions')
        .select('revision, status, roster_frozen')
        .eq('id', _sessionId)
        .single();
    expect(sessionBefore['status'], 'finalized');
    expect(sessionBefore['roster_frozen'], isTrue);
    final attendanceBefore = await client
        .from('ministry_attendance')
        .select('status')
        .eq('session_id', _sessionId)
        .eq('enrollment_id', enrollmentId)
        .single();
    expect(attendanceBefore['status'], 'present');
    Object? editError;
    try {
      await freshMinistry.command(
        name: 'save_attendance',
        operationId: _uuid.v4(),
        payload: {
          'congregation_id': _congregationAId,
          'session_id': _sessionId,
          'expected_revision': sessionBefore['revision'],
          'marks': {enrollmentId: 'absent'},
          'finalize': false,
        },
      );
    } catch (error) {
      editError = error;
    }
    expect(editError, isA<DataFailure>());
    expect((editError! as DataFailure).code, 'invalid');
    final sessionAfter = await client
        .from('ministry_sessions')
        .select('revision, status, roster_frozen')
        .eq('id', _sessionId)
        .single();
    final attendanceAfter = await client
        .from('ministry_attendance')
        .select('status')
        .eq('session_id', _sessionId)
        .eq('enrollment_id', enrollmentId)
        .single();
    expect(sessionAfter['status'], 'finalized');
    expect(sessionAfter['revision'], sessionBefore['revision']);
    expect(attendanceAfter['status'], 'present');

    // The browser supplies Origin; only the runner-held, unpredictable
    // capability is added by this test for the fixed assignment endpoint.
    final revokeResponse = await http.post(
      Uri.parse('$_controlUrl/revoke/$_directionAssignmentId'),
      headers: {'X-Run-Capability': _controlCapability},
    );
    expect(revokeResponse.statusCode, 200);
    await _expectForbidden(
      () => client.rpc(
        'ieadpe_ministry_list_convert_referrals',
        params: {
          'request': {
            'congregation_id': _congregationAId,
            'limit': 50,
            'cursor': null,
          },
        },
      ),
    );

    // Rebuild the real app root with the still-active Auth token. Scope is
    // reloaded over HTTP and the protected ministry routes are removed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(App(auth: auth));
    await _waitFor(
      tester,
      () => find.text('Cadastrar Novo Convertido').evaluate().isNotEmpty,
      'reloaded route after grant revocation',
    );
    expect(find.byKey(const ValueKey('app-shell-nav-/ministry')), findsNothing);
    expect(find.byKey(const ValueKey('app-shell-nav-/converts')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Future<void> _signIn(
  WidgetTester tester,
  SupabaseClient client,
  String email,
  String password,
) async {
  if (client.auth.currentSession != null) {
    await client.auth.signOut();
    await _waitFor(
      tester,
      () => find
          .text('Entre com sua conta Google para continuar.')
          .evaluate()
          .isNotEmpty,
      'signed-out login screen',
    );
  }
  await client.auth.signInWithPassword(email: email, password: password);
  await _waitFor(
    tester,
    () => find
        .byKey(const ValueKey('app-shell-nav-/register'))
        .evaluate()
        .isNotEmpty,
    'authenticated protected app shell',
  );
}

Future<void> _expectForbidden(Future<dynamic> Function() operation) async {
  try {
    await operation();
    fail('The out-of-scope HTTP request unexpectedly succeeded.');
  } on PostgrestException catch (error) {
    expect(error.code, '42501');
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
    _tap(tester, find.text(label).first);

Future<void> _selectDropdown(
  WidgetTester tester,
  Finder field,
  String option,
) async {
  await _tap(tester, field);
  final optionFinder = find.text(option).last;
  await _waitFor(
    tester,
    () => optionFinder.evaluate().isNotEmpty,
    'dropdown option $option',
  );
  await tester.tap(optionFinder);
  await tester.pump();
}
