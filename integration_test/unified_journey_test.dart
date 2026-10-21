import 'dart:convert';

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
import 'package:ieadpe_converts/widgets/app_shell.dart';

const _apiUrl = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _runId = String.fromEnvironment('JOURNEY_RUN_ID');
const _congregationAId = String.fromEnvironment('JOURNEY_CONGREGATION_A_ID');
const _congregationBId = String.fromEnvironment('JOURNEY_CONGREGATION_B_ID');
const _classId = String.fromEnvironment('JOURNEY_CLASS_ID');
const _sessionId = String.fromEnvironment('JOURNEY_SESSION_ID');
const _journeyStudentId = String.fromEnvironment('JOURNEY_STUDENT_ID');
const _journeyPersonId = String.fromEnvironment('JOURNEY_PERSON_ID');
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
    expect(_journeyStudentId, isNotEmpty);
    expect(_journeyPersonId, isNotEmpty);
    expect(_attackEnrollmentId, isNotEmpty);
    expect(_convertName, isNotEmpty);
    expect(_allowedOrigin, 'http://127.0.0.1:7357');
    expect(_controlUrl, startsWith('http://127.0.0.1:'));
    expect(_controlCapability.length, greaterThanOrEqualTo(40));
    var activeSessionId = _sessionId;

    final observedHttp = JourneyHttpObserver(
      http.Client(),
      excludedStudentIds: {_journeyStudentId},
    );
    final client = SupabaseClient(_apiUrl, _anonKey, httpClient: observedHttp);
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
    await _expectForbidden(
      () => client.rpc(
        'ieadpe_ministry_list_classes',
        params: {
          'request': {
            'congregation_id': _congregationAId,
            'status': 'active',
            'limit': 50,
            'cursor': null,
          },
        },
      ),
    );
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
    // The registrar chooses the authorized congregation at creation time;
    // this is the persisted scope, not a later transfer by a supervisor.
    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<String>).first,
      _congregationAName,
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

    // A campaign supervisor sees the already-scoped convert and records a
    // visit in the production converts widgets.
    await _signIn(tester, client, _supervisorEmail, _supervisorPassword);
    await _tap(tester, find.byKey(const ValueKey('app-shell-nav-/converts')));
    await _waitFor(
      tester,
      () => find.text(_convertName).evaluate().isNotEmpty,
      'registered convert in supervisor list',
    );
    await _waitFor(
      tester,
      () => find.text(_congregationAName).evaluate().isNotEmpty,
      'creation-time congregation on convert card',
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
    final convertRow = await _convertByName(
      client,
      _congregationAId,
      _convertName,
    );
    final convertId = convertRow['id'] as String;
    expect(convertRow['congregation_id'], _congregationAId);
    expect(convertRow['visit_count'], 1);
    expect(convertRow['was_visited_once'], isTrue);

    // A direction grant for congregation B cannot read congregation A's
    // projection or forge an enrollment into A through authenticated HTTP.
    final attackStudentId = _uuid.v4();
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
            'student_id': attackStudentId,
            'start_date': DateTime.now().toIso8601String().substring(0, 10),
          },
        },
      ),
    );
    await _expectForbidden(
      () => client.rpc(
        'ieadpe_ministry_register_student',
        params: {
          'operation_id': _uuid.v4(),
          'payload': {
            'id': _journeyStudentId,
            'person_id': _journeyPersonId,
            'congregation_id': _congregationAId,
            'person': {
              'name': 'Journey denied student',
              'phone': null,
              'birth_date': null,
              'address': null,
            },
            'academic': {
              'education': null,
              'marital_status': null,
              'new_convert': false,
              'water_baptized': null,
              'wants_baptism': null,
            },
          },
        },
      ),
    );
    expect(
      observedHttp.ownedIdentityReported,
      isFalse,
      reason: 'the denied fixture registration must never become a cleanup ID',
    );

    // The direction user sees only the scoped referral projection, then
    // explicitly links a student and explicitly enrolls that student.
    await _signIn(tester, client, _directionEmail, _directionPassword);
    final classStudentsAfterDeniedEnrollment = await _classStudents(
      client,
      _congregationAId,
      _classId,
    );
    expect(
      classStudentsAfterDeniedEnrollment.any(
        (row) => (row['student'] as Map)['id'] == attackStudentId,
      ),
      isFalse,
    );
    // Exercise the separate non-convert registration through the real
    // protected students route. The observer records only the generated UUIDs
    // needed by the host-held bounded cleanup, never the person payload.
    await _tap(tester, find.byKey(const ValueKey('app-shell-nav-/ministry')));
    await _waitFor(
      tester,
      () => find
          .byKey(ValueKey('ministry-congregation-scope:1:$_congregationAId'))
          .evaluate()
          .isNotEmpty,
      'authorized ministry scope before non-convert registration',
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Alunos',
    );
    await _tap(tester, find.text('Registrar aluno').last);
    await _waitFor(
      tester,
      () =>
          find.byKey(const ValueKey('student-education')).evaluate().isNotEmpty,
      'non-convert student form',
    );
    const registeredStudentName = 'T11 aluno não convertido';
    await tester.enterText(
      find.byKey(const ValueKey('person-name')),
      registeredStudentName,
    );
    await tester.enterText(
      find.byKey(const ValueKey('student-education')),
      'Ensino médio',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-phone')),
      '+15551234567',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Cadastrar aluno'));
    await _waitFor(
      tester,
      () => observedHttp.ownedIdentityReported,
      'exact UI-created student/person cleanup IDs',
    );
    final registeredStudentPayload = observedHttp.registeredStudentPayload!;
    expect(
      (registeredStudentPayload['person'] as Map)['phone'],
      '+15551234567',
      reason:
          'the later null canonical edit starts from a known non-null value',
    );
    expect(observedHttp.reportedStudentId, isNot(_journeyStudentId));
    expect(observedHttp.reportedStudentId, matches(_uuidPattern));
    expect(observedHttp.reportedPersonId, matches(_uuidPattern));
    final registeredStudentAcademic =
        registeredStudentPayload['academic'] as Map<String, dynamic>;
    expect(registeredStudentAcademic['new_convert'], isFalse);
    expect(registeredStudentPayload.containsKey('convert_id'), isFalse);
    expect(registeredStudentPayload.containsKey('conversion_date'), isFalse);
    expect(registeredStudentPayload.containsKey('event_type'), isFalse);
    await _waitFor(
      tester,
      () => find.text(registeredStudentName).evaluate().isNotEmpty,
      'registered non-convert student in protected list',
    );
    await _tapText(tester, registeredStudentName);
    await _waitFor(
      tester,
      () => find.text('Identidade canônica').evaluate().isNotEmpty,
      'canonical identity editor',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-name')),
      '$registeredStudentName atualizado',
    );
    await tester.enterText(find.byKey(const ValueKey('person-phone')), '');
    await _tapText(tester, 'Salvar identidade');
    await _waitFor(
      tester,
      () =>
          find.text('$registeredStudentName atualizado').evaluate().isNotEmpty,
      'updated canonical identity',
    );
    final nonConvertStudentCandidates = await client.rpc(
      'ieadpe_ministry_list_convert_student_candidates',
      params: {
        'request': {
          'congregation_id': _congregationAId,
          'name_prefix': '$registeredStudentName atualizado',
          'limit': 50,
          'cursor': null,
        },
      },
    );
    final candidatePage = Map<String, dynamic>.from(
      nonConvertStudentCandidates as Map,
    );
    final canonicalCandidates = (candidatePage['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => item['student_id'] == observedHttp.reportedStudentId)
        .toList();
    expect(canonicalCandidates, hasLength(1));
    expect(
      canonicalCandidates.single['name'],
      '$registeredStudentName atualizado',
    );
    expect(
      canonicalCandidates.single['phone'],
      isNull,
      reason:
          'a null canonical phone must not fall back to duplicated legacy data',
    );
    final convertCandidatesForNonConvert = await _rpcItems(
      client,
      'ieadpe_ministry_list_converts',
      {
        'congregation_id': _congregationAId,
        'name_prefix': '$registeredStudentName atualizado',
        'limit': 100,
        'cursor': null,
      },
    );
    expect(
      convertCandidatesForNonConvert.any(
        (row) =>
            row['person'] is Map &&
            (row['person'] as Map)['id'] == observedHttp.reportedPersonId,
      ),
      isFalse,
      reason:
          'non-convert registration must not create a conversion obligation',
    );
    // Return to the scoped ministry shell before exercising convert handoff.
    await tester.pageBack();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('app-shell-nav-/ministry')));
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('app-shell-ministry-selector'))
          .evaluate()
          .isNotEmpty,
      'ministry shell after identity edit',
    );
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
    final studentRows = await _rpcItems(
      client,
      'ieadpe_ministry_list_students',
      {
        'congregation_id': _congregationAId,
        'name_prefix': _convertName,
        'limit': 100,
        'cursor': null,
      },
    );
    final linkedStudents = studentRows
        .where((row) => row['person_id'] == convertRow['person_id'])
        .toList();
    expect(linkedStudents, hasLength(1));
    final studentId = linkedStudents.single['id'] as String;
    var studentName = linkedStudents.single['name'] as String;
    expect(studentName, _convertName);
    expect(
      await _studentEnrollments(client, _congregationAId, studentId),
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
    final enrollmentRows = await _studentEnrollments(
      client,
      _congregationAId,
      studentId,
    );
    final enrollmentMatches = enrollmentRows
        .where((row) => row['class_id'] == _classId)
        .toList();
    expect(enrollmentMatches, hasLength(1));
    final enrollmentId = enrollmentMatches.single['id'] as String;
    expect(enrollmentMatches.single['status'], 'active');
    final convertWithActiveEnrollment = await _convertById(
      client,
      _congregationAId,
      convertId,
    );
    expect(convertWithActiveEnrollment['effective_is_in_discipleship'], isTrue);
    expect(
      convertWithActiveEnrollment['latest_qualifying_lesson_date'],
      isNull,
      reason:
          'an active handoff alone does not fabricate a lesson contribution',
    );
    expect(
      convertWithActiveEnrollment['effective_follow_up_date'],
      convertRow['last_visit_date'],
      reason:
          'before lessons, the independent projection remains manual history',
    );

    // The student's protected summary is visible on the production students
    // route before the journey later verifies revocation removes it.
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Alunos',
    );
    await _waitFor(
      tester,
      () => find.text(studentName).evaluate().isNotEmpty,
      'linked student in students route',
    );
    await _tapText(tester, studentName);
    await _waitFor(
      tester,
      () => find.text('Histórico de matrículas').evaluate().isNotEmpty,
      'student enrollment history before attendance evaluation',
    );
    const preFreezeStudentName = 'T11 aluno canônico antes do congelamento';
    await _waitFor(
      tester,
      () => find.text('Identidade canônica').evaluate().isNotEmpty,
      'canonical identity editor before first roster freeze',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-name')),
      preFreezeStudentName,
    );
    await _tapText(tester, 'Salvar identidade');
    await _waitFor(
      tester,
      () => find.text(preFreezeStudentName).evaluate().isNotEmpty,
      'pre-freeze canonical rename',
    );
    studentName = preFreezeStudentName;
    final renamedStudentRows = await _rpcItems(
      client,
      'ieadpe_ministry_list_students',
      {
        'congregation_id': _congregationAId,
        'name_prefix': preFreezeStudentName,
        'limit': 100,
        'cursor': null,
      },
    );
    expect(
      renamedStudentRows.single['name'],
      preFreezeStudentName,
      reason: 'canonical name is current before the first roster freeze',
    );
    final progressToggle = find.byKey(Key('enrollment-progress-$enrollmentId'));
    await tester.ensureVisible(progressToggle);
    await tester.tap(progressToggle);
    await _waitFor(
      tester,
      () => find.text('Sem aulas avaliadas').evaluate().isNotEmpty,
      'zero-denominator persisted progress before attendance finalization',
    );
    tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/ministry');
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('app-shell-ministry-selector'))
          .evaluate()
          .isNotEmpty,
      'ministry shell after zero progress read',
    );

    // The runner seeded only an empty, run-owned placeholder session (no roster
    // or attendance rows). Cancel it through the session-list UI, then create
    // the eligible lesson as a linked same-date replacement through production
    // UI. Its first attendance read must be the authorized SQL preview, not a
    // privileged fixture roster.
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Turmas',
    );
    await _waitFor(
      tester,
      () => find.text(_className).evaluate().isNotEmpty,
      'run-owned class before UI session creation',
    );
    await _tapText(tester, _className);
    await _tapText(tester, 'Ver aulas');
    final cancelSeedSession = find.byKey(Key('cancel-session-$_sessionId'));
    await _waitFor(
      tester,
      () => cancelSeedSession.evaluate().isNotEmpty,
      'seeded placeholder cancellation action',
    );
    await _tap(tester, cancelSeedSession);
    final seedCancelDialog = find.byType(AlertDialog);
    await _waitFor(
      tester,
      () => seedCancelDialog.evaluate().isNotEmpty,
      'seeded placeholder cancellation confirmation',
    );
    await _tap(
      tester,
      find.descendant(
        of: seedCancelDialog,
        matching: find.text('Cancelar aula'),
      ),
    );
    final createSessionFromSeed = find.byKey(
      Key('replace-session-$_sessionId'),
    );
    await _waitFor(
      tester,
      () => createSessionFromSeed.evaluate().isNotEmpty,
      'same-date lesson creation action',
    );
    await _tap(tester, createSessionFromSeed);
    await _waitFor(
      tester,
      () => find.text('Substituir aula cancelada').evaluate().isNotEmpty,
      'production same-date lesson form',
    );
    final lessonDateField = tester.widget<TextField>(
      find.byKey(const ValueKey('session-date')),
    );
    expect(lessonDateField.readOnly, isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('session-topic')),
      'T11 eligible lesson draft',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Salvar'));
    await _waitFor(
      tester,
      () => find.textContaining('Lista prevista').evaluate().isNotEmpty,
      'UI-created lesson attendance route',
    );
    final classSessionRows = await _classSessions(
      client,
      _congregationAId,
      _classId,
    );
    final firstUiSessions = classSessionRows
        .where((row) => row['replaces_session_id'] == _sessionId)
        .toList();
    expect(firstUiSessions, hasLength(1));
    final firstUiSession = firstUiSessions.single;
    activeSessionId = firstUiSession['id'] as String;
    final canceledSeedSession = classSessionRows.singleWhere(
      (row) => row['id'] == _sessionId,
    );
    expect(firstUiSession['class_id'], _classId);
    expect(firstUiSession['date'], canceledSeedSession['date']);
    expect(canceledSeedSession['status'], 'canceled');
    expect(firstUiSession['status'], 'open');
    expect(firstUiSession['replaces_session_id'], _sessionId);
    final uiSessionBeforeDraft = await _sessionAttendance(
      client,
      _congregationAId,
      activeSessionId,
    );
    final previewSession = _sessionOf(uiSessionBeforeDraft);
    final previewRoster = _rosterOf(uiSessionBeforeDraft);
    expect(previewSession['status'], 'open');
    expect(previewSession['roster_frozen'], isFalse);
    expect(previewRoster, hasLength(1));
    expect(previewRoster.single['enrollment_id'], enrollmentId);
    expect(previewRoster.single['student_id'], studentId);
    expect(previewRoster.single['student_name'], preFreezeStudentName);
    expect(previewRoster.single['status'], 'unmarked');
    expect(
      find.text('A lista será congelada no primeiro salvamento.').evaluate(),
      isNotEmpty,
    );
    final eligibleClassStudents = await _classStudents(
      client,
      _congregationAId,
      _classId,
    );
    expect(
      eligibleClassStudents.any((row) {
        final student = Map<String, dynamic>.from(row['student'] as Map);
        final enrollment = Map<String, dynamic>.from(row['enrollment'] as Map);
        return student['id'] == studentId &&
            student['name'] == preFreezeStudentName &&
            enrollment['id'] == enrollmentId;
      }),
      isTrue,
      reason: 'the eligible canonical student exists before first freeze',
    );
    expect(
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      findsOneWidget,
      reason: 'production attendance UI must present eligible rows so the first draft can freeze them',
    );
    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      'Presente',
    );
    expect(find.bySemanticsLabel('Carregando frequência').evaluate(), isEmpty);
    await _tapText(tester, 'Salvar chamada');
    await _waitFor(
      tester,
      () => find
          .text('Chamada salva e confirmada pelo servidor.')
          .evaluate()
          .isNotEmpty,
      'attendance draft acknowledged before finalization',
    );
    final attendanceAfterDraft = await _sessionAttendance(
      client,
      _congregationAId,
      activeSessionId,
    );
    final sessionAfterDraft = _sessionOf(attendanceAfterDraft);
    expect(sessionAfterDraft['status'], 'open');
    expect(sessionAfterDraft['roster_frozen'], isTrue);
    final draftRoster = _rosterOf(attendanceAfterDraft);
    expect(draftRoster, hasLength(1));
    expect(draftRoster.single['student_name'], preFreezeStudentName);
    expect(draftRoster.single['status'], 'present');
    await _tapText(tester, 'Salvar e finalizar');
    final firstFinalizationDialog = find.byType(AlertDialog);
    await _waitFor(
      tester,
      () => firstFinalizationDialog.evaluate().isNotEmpty,
      'initial attendance finalization confirmation',
    );
    await _tap(
      tester,
      find.descendant(
        of: firstFinalizationDialog,
        matching: find.text('Finalizar chamada'),
      ),
    );
    await _waitFor(
      tester,
      () =>
          find.text('Lista congelada').evaluate().isNotEmpty &&
          find.text(preFreezeStudentName).evaluate().isNotEmpty,
      'immediately refreshed finalized roster',
    );
    expect(
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      findsNothing,
    );
    expect(
      find.text('Chamada finalizada. As marcações são somente leitura.'),
      findsOneWidget,
    );
    expect(find.text('Salvar e finalizar'), findsNothing);

    final independentProgressClient = SupabaseClient(
      _apiUrl,
      _anonKey,
      headers: {
        'Authorization': 'Bearer ${client.auth.currentSession!.accessToken}',
      },
    );
    final freshMinistry = MinistryRepository(
      SupabaseGateway(independentProgressClient, ProtectedDataBoundary()),
    );
    final progress = await freshMinistry.getEnrollmentProgress(
      congregationId: _congregationAId,
      enrollmentId: enrollmentId,
    );
    expect(progress.present, 1);
    expect(progress.absent, 0);
    expect(progress.denominator, 1);
    final convertAfterFirstFinalization = await _convertById(
      independentProgressClient,
      _congregationAId,
      convertId,
    );
    expect(
      convertAfterFirstFinalization['effective_is_in_discipleship'],
      isTrue,
    );
    final firstFinalizedSession = (await _classSessions(
      independentProgressClient,
      _congregationAId,
      _classId,
    )).singleWhere((row) => row['id'] == activeSessionId);
    expect(
      convertAfterFirstFinalization['latest_qualifying_lesson_date'],
      firstFinalizedSession['date'],
    );
    expect(
      convertAfterFirstFinalization['effective_follow_up_date'],
      firstFinalizedSession['date'],
    );
    expect(
      convertAfterFirstFinalization['visit_count'],
      convertRow['visit_count'],
    );

    final persistedBeforeRejections = await _sessionAttendance(
      independentProgressClient,
      _congregationAId,
      activeSessionId,
    );
    final sessionBefore = _sessionOf(persistedBeforeRejections);
    expect(sessionBefore['status'], 'finalized');
    expect(sessionBefore['roster_frozen'], isTrue);
    final attendanceBefore = _rosterOf(persistedBeforeRejections)
        .where((row) => row['enrollment_id'] == enrollmentId)
        .toList();
    expect(attendanceBefore, hasLength(1));
    expect(attendanceBefore.single['status'], 'present');
    final rosterBefore = _rosterOf(persistedBeforeRejections);
    expect(rosterBefore.single['student_name'], preFreezeStudentName);
    final eventsBefore = await independentProgressClient
        .from('convert_events')
        .select('id, event_type, event_date, created_at')
        .eq('convert_id', convertId)
        .order('id');
    expect(observedHttp.attendanceOperationId, isNotNull);
    expect(observedHttp.attendancePayload, isNotNull);
    expect(observedHttp.attendanceReceipt, isNotNull);
    final exactReplay = await client.rpc(
      'ieadpe_ministry_save_attendance',
      params: {
        'operation_id': observedHttp.attendanceOperationId,
        'payload': observedHttp.attendancePayload,
      },
    );
    expect(exactReplay, observedHttp.attendanceReceipt);

    for (final finalize in [false, true]) {
      await _expectSessionRejection(
        () => client.rpc(
          'ieadpe_ministry_save_attendance',
          params: {
            'operation_id': _uuid.v4(),
            'payload': {
              'congregation_id': _congregationAId,
              'session_id': activeSessionId,
              'expected_revision': sessionBefore['revision'],
              'marks': {enrollmentId: 'absent'},
              'finalize': finalize,
            },
          },
        ),
        'session_finalized',
      );
    }
    final persistedAfterRejections = await _sessionAttendance(
      independentProgressClient,
      _congregationAId,
      activeSessionId,
    );
    final sessionAfter = _sessionOf(persistedAfterRejections);
    final rosterAfter = _rosterOf(persistedAfterRejections);
    final attendanceAfter = rosterAfter
        .where((row) => row['enrollment_id'] == enrollmentId)
        .toList();
    expect(sessionAfter['status'], 'finalized');
    expect(sessionAfter['revision'], sessionBefore['revision']);
    expect(attendanceAfter, attendanceBefore);
    expect(rosterAfter, rosterBefore);
    expect(
      await independentProgressClient
          .from('convert_events')
          .select('id, event_type, event_date, created_at')
          .eq('convert_id', convertId)
          .order('id'),
      eventsBefore,
    );
    final progressAfterRejections = await freshMinistry.getEnrollmentProgress(
      congregationId: _congregationAId,
      enrollmentId: enrollmentId,
    );
    expect(progressAfterRejections.present, progress.present);
    expect(progressAfterRejections.absent, progress.absent);
    expect(progressAfterRejections.denominator, progress.denominator);

    // Reopen the finalized original through the production class/session
    // widgets before cancellation and verify its frozen marks remain visible.
    await _tap(tester, find.byKey(const ValueKey('app-shell-nav-/ministry')));
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('app-shell-ministry-selector'))
          .evaluate()
          .isNotEmpty,
      'ministry navigation before session replacement',
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Turmas',
    );
    await _waitFor(
      tester,
      () => find.text(_className).evaluate().isNotEmpty,
      'run-owned class before session replacement',
    );
    await _tapText(tester, _className);
    await _tapText(tester, 'Ver aulas');
    final replaceOriginal = find.byKey(Key('replace-session-$activeSessionId'));
    await _tap(
      tester,
      find.textContaining('Finalizada · T11 eligible lesson draft'),
    );
    await _waitFor(
      tester,
      () => find
          .text('Chamada finalizada. As marcações são somente leitura.')
          .evaluate()
          .isNotEmpty,
      'finalized lesson reopened from production session list',
    );
    expect(
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      findsNothing,
    );
    expect(find.text(preFreezeStudentName), findsOneWidget);
    final reopenedAttendance = _rosterOf(
      await _sessionAttendance(
        independentProgressClient,
        _congregationAId,
        activeSessionId,
      ),
    ).where((row) => row['enrollment_id'] == enrollmentId).toList();
    expect(reopenedAttendance, attendanceBefore);
    tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/ministry');
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('app-shell-ministry-selector'))
          .evaluate()
          .isNotEmpty,
      'ministry shell before post-freeze canonical edit',
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Alunos',
    );
    await _waitFor(
      tester,
      () => find.text(studentName).evaluate().isNotEmpty,
      'linked student after finalized session reopen',
    );
    await _tapText(tester, studentName);
    await _waitFor(
      tester,
      () => find.text('Identidade canônica').evaluate().isNotEmpty,
      'canonical identity after roster freeze',
    );
    const postFreezeStudentName = 'T11 aluno renomeado após congelamento';
    await tester.enterText(
      find.byKey(const ValueKey('person-name')),
      postFreezeStudentName,
    );
    await _tapText(tester, 'Salvar identidade');
    await _waitFor(
      tester,
      () => find.text(postFreezeStudentName).evaluate().isNotEmpty,
      'canonical identity rename after freeze',
    );
    expect(
      _rosterOf(
        await _sessionAttendance(
          independentProgressClient,
          _congregationAId,
          activeSessionId,
        ),
      ),
      rosterBefore,
      reason: 'a later canonical edit must not rewrite the frozen snapshot',
    );

    tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/ministry');
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('app-shell-ministry-selector'))
          .evaluate()
          .isNotEmpty,
      'ministry shell before session cancellation',
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Turmas',
    );
    await _waitFor(
      tester,
      () => find.text(_className).evaluate().isNotEmpty,
      'class route after canonical rename',
    );
    await _tapText(tester, _className);
    await _tapText(tester, 'Ver aulas');
    await _waitFor(
      tester,
      () => find
          .byKey(Key('cancel-session-$activeSessionId'))
          .evaluate()
          .isNotEmpty,
      'original session cancellation action after reopening',
    );
    await _tap(tester, find.byKey(Key('cancel-session-$activeSessionId')));
    final cancelConfirmation = find.byType(AlertDialog);
    await _waitFor(
      tester,
      () => cancelConfirmation.evaluate().isNotEmpty,
      'original session cancellation confirmation',
    );
    await _tap(
      tester,
      find
          .descendant(
            of: cancelConfirmation,
            matching: find.text('Cancelar aula'),
          )
          .last,
    );
    await _waitFor(
      tester,
      () => replaceOriginal.evaluate().isNotEmpty,
      'same-date replacement action after confirmed cancellation',
    );

    final originalAfterCancel = _sessionOf(
      await _sessionAttendance(
        independentProgressClient,
        _congregationAId,
        activeSessionId,
      ),
    );
    expect(originalAfterCancel['status'], 'canceled');
    expect(originalAfterCancel['roster_frozen'], isTrue);
    final canceledOriginalSnapshot = await _sessionAttendance(
      independentProgressClient,
      _congregationAId,
      activeSessionId,
    );
    final originalRosterAfterCancel = _rosterOf(canceledOriginalSnapshot);
    final originalAttendanceAfterCancel = originalRosterAfterCancel
        .where((row) => row['enrollment_id'] == enrollmentId)
        .toList();
    expect(originalAttendanceAfterCancel, attendanceBefore);
    expect(originalRosterAfterCancel, rosterBefore);
    await _expectSessionRejection(
      () => client.rpc(
        'ieadpe_ministry_save_attendance',
        params: {
          'operation_id': _uuid.v4(),
          'payload': {
            'congregation_id': _congregationAId,
            'session_id': activeSessionId,
            'expected_revision': originalAfterCancel['revision'],
            'marks': {enrollmentId: 'absent'},
            'finalize': false,
          },
        },
      ),
      'session_canceled',
    );
    final afterCanceledSaveAttempt = _sessionOf(
      await _sessionAttendance(
        independentProgressClient,
        _congregationAId,
        activeSessionId,
      ),
    );
    expect(
      afterCanceledSaveAttempt['revision'],
      originalAfterCancel['revision'],
    );
    final afterCanceledRoster = _rosterOf(
      await _sessionAttendance(
        independentProgressClient,
        _congregationAId,
        activeSessionId,
      ),
    );
    expect(
      afterCanceledRoster
          .where((row) => row['enrollment_id'] == enrollmentId)
          .toList(),
      attendanceBefore,
    );
    final canceledProgress = await freshMinistry.getEnrollmentProgress(
      congregationId: _congregationAId,
      enrollmentId: enrollmentId,
    );
    expect(canceledProgress.present, 0);
    expect(canceledProgress.absent, 0);
    expect(canceledProgress.denominator, 0);
    final convertAfterCancellation = await _convertById(
      independentProgressClient,
      _congregationAId,
      convertId,
    );
    expect(convertAfterCancellation['effective_is_in_discipleship'], isTrue);
    expect(convertAfterCancellation['latest_qualifying_lesson_date'], isNull);
    expect(
      convertAfterCancellation['effective_follow_up_date'],
      convertRow['last_visit_date'],
    );
    expect(convertAfterCancellation['visit_count'], convertRow['visit_count']);

    await _tap(tester, replaceOriginal);
    await _waitFor(
      tester,
      () => find.text('Substituir aula cancelada').evaluate().isNotEmpty,
      'replacement session form',
    );
    final replacementDate = tester.widget<TextField>(
      find.byKey(const ValueKey('session-date')),
    );
    final originalDate = (originalAfterCancel['date'] as String).split('-');
    expect(replacementDate.readOnly, isTrue);
    expect(
      replacementDate.controller!.text,
      '${originalDate[2]}/${originalDate[1]}/${originalDate[0]}',
    );
    await tester.enterText(
      find.byKey(const ValueKey('session-topic')),
      'T11 replacement lesson',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Salvar'));
    await _waitFor(
      tester,
      () => find.textContaining('Lista prevista').evaluate().isNotEmpty,
      'replacement attendance preview opened by production session flow',
    );
    final linkedSessions = await _classSessions(
      independentProgressClient,
      _congregationAId,
      _classId,
    );
    final replacementMatches = linkedSessions
        .where((row) => row['replaces_session_id'] == activeSessionId)
        .toList();
    expect(replacementMatches, hasLength(1));
    final replacementRow = replacementMatches.single;
    final replacementId = replacementRow['id'] as String;
    expect(replacementRow['class_id'], _classId);
    expect(replacementRow['date'], originalAfterCancel['date']);
    expect(replacementRow['status'], 'open');
    expect(replacementRow['replaces_session_id'], activeSessionId);
    final replacementBeforeFinalization = await _sessionAttendance(
      independentProgressClient,
      _congregationAId,
      replacementId,
    );
    final replacementPreviewSession = _sessionOf(replacementBeforeFinalization);
    final replacementPreviewRoster = _rosterOf(replacementBeforeFinalization);
    expect(replacementPreviewSession['status'], 'open');
    expect(replacementPreviewSession['roster_frozen'], isFalse);
    expect(replacementPreviewRoster, hasLength(1));
    expect(replacementPreviewRoster.single['enrollment_id'], enrollmentId);
    expect(replacementPreviewRoster.single['student_id'], studentId);
    expect(
      replacementPreviewRoster.single['student_name'],
      postFreezeStudentName,
      reason: 'preview uses the current canonical identity before replacement freeze',
    );
    expect(replacementPreviewRoster.single['status'], 'unmarked');
    expect(
      find.text('A lista será congelada no primeiro salvamento.').evaluate(),
      isNotEmpty,
    );

    await _selectDropdown(
      tester,
      find.byType(DropdownButtonFormField<AttendanceStatus>),
      'Presente',
    );
    await _tapText(tester, 'Salvar e finalizar');
    await _waitFor(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
      'replacement attendance finalization confirmation',
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Finalizar chamada'),
      ),
    );
    await _waitFor(
      tester,
      () => find
          .text('Chamada finalizada. As marcações são somente leitura.')
          .evaluate()
          .isNotEmpty,
      'replacement finalized through the production attendance UI',
    );
    final sessionsAfterReplacement = await _classSessions(
      independentProgressClient,
      _congregationAId,
      _classId,
    );
    final originalAfterReplacement = sessionsAfterReplacement.singleWhere(
      (row) => row['id'] == activeSessionId,
    );
    final linkedReplacement = sessionsAfterReplacement.singleWhere(
      (row) => row['id'] == replacementId,
    );
    expect(
      sessionsAfterReplacement
          .where((row) => row['replaces_session_id'] == activeSessionId)
          .toList(),
      [linkedReplacement],
    );
    expect(linkedReplacement['id'], replacementId);
    expect(linkedReplacement['replaces_session_id'], activeSessionId);
    expect(originalAfterReplacement['status'], 'canceled');
    final replacementLineageAfterFinalization = sessionsAfterReplacement
        .singleWhere((row) => row['id'] == replacementId);
    expect(
      replacementLineageAfterFinalization['replaces_session_id'],
      activeSessionId,
    );
    expect(replacementLineageAfterFinalization['status'], 'finalized');
    final originalAfterReplacementAttendance = await _sessionAttendance(
      independentProgressClient,
      _congregationAId,
      activeSessionId,
    );
    final rosterAfterCanceledSaveAttempt = _rosterOf(
      originalAfterReplacementAttendance,
    );
    expect(rosterAfterCanceledSaveAttempt, originalRosterAfterCancel);
    expect(
      rosterAfterCanceledSaveAttempt
          .where((row) => row['enrollment_id'] == enrollmentId)
          .toList(),
      attendanceBefore,
    );
    final replacementProgress = await freshMinistry.getEnrollmentProgress(
      congregationId: _congregationAId,
      enrollmentId: enrollmentId,
    );
    expect(replacementProgress.present, 1);
    expect(replacementProgress.absent, 0);
    expect(replacementProgress.denominator, 1);
    final convertAfterReplacement = await _convertById(
      independentProgressClient,
      _congregationAId,
      convertId,
    );
    expect(convertAfterReplacement['visit_count'], convertRow['visit_count']);
    expect(
      convertAfterReplacement['was_visited_once'],
      convertRow['was_visited_once'],
    );
    expect(convertAfterReplacement['effective_is_in_discipleship'], isTrue);
    expect(
      convertAfterReplacement['latest_qualifying_lesson_date'],
      replacementLineageAfterFinalization['date'],
    );
    expect(
      convertAfterReplacement['effective_follow_up_date'],
      replacementLineageAfterFinalization['date'],
    );

    tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/ministry');
    await _waitFor(
      tester,
      () => find
          .byKey(const ValueKey('app-shell-ministry-selector'))
          .evaluate()
          .isNotEmpty,
      'ministry shell before persisted progress UI read',
    );
    await _selectDropdown(
      tester,
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      'Alunos',
    );
    await _waitFor(
      tester,
      () => find.text(postFreezeStudentName).evaluate().isNotEmpty,
      'linked student after replacement finalization',
    );
    await _tapText(tester, postFreezeStudentName);
    await _waitFor(
      tester,
      () => find.text('Histórico de matrículas').evaluate().isNotEmpty,
      'student history after replacement finalization',
    );
    final replacementProgressToggle = find.byKey(
      Key('enrollment-progress-$enrollmentId'),
    );
    await tester.ensureVisible(replacementProgressToggle);
    await tester.tap(replacementProgressToggle);
    await _waitFor(
      tester,
      () =>
          find.text('Aulas avaliadas: 1').evaluate().isNotEmpty &&
          find.text('Presenças: 1').evaluate().isNotEmpty,
      'student UI reads persisted progress after replacement finalization',
    );
    expect(find.text('Aproveitamento: 100%'), findsOneWidget);
    expect(find.text(postFreezeStudentName), findsOneWidget);

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

    // Keep the same root and Auth session mounted. Production SessionRouter
    // revalidates the changed scope when the app resumes.
    expect(client.auth.currentSession, isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _waitFor(
      tester,
      () => find.text('Cadastrar Novo Convertido').evaluate().isNotEmpty,
      'authorized registration route after grant revocation',
    );
    expect(client.auth.currentSession, isNotNull);
    expect(find.text(postFreezeStudentName), findsNothing);
    expect(find.text(_convertName), findsNothing);
    expect(find.textContaining('Lista congelada'), findsNothing);
    expect(find.byKey(const ValueKey('app-shell-nav-/ministry')), findsNothing);
    expect(
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('app-shell-nav-/register')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    observedHttp.close();
    await independentProgressClient.dispose();
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// Captures only the generated student/person UUID pair from the production
/// registration RPC so the runner can clean a partial browser journey safely.
class JourneyHttpObserver extends http.BaseClient {
  JourneyHttpObserver(this._inner, {this.excludedStudentIds = const {}});

  final http.Client _inner;
  final Set<String> excludedStudentIds;
  bool ownedIdentityReported = false;
  String? reportedStudentId;
  String? reportedPersonId;
  Map<String, dynamic>? registeredStudentPayload;
  String? attendanceOperationId;
  Map<String, dynamic>? attendancePayload;
  Object? attendanceReceipt;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!ownedIdentityReported &&
        request is http.Request &&
        request.url.path.endsWith('/rpc/ieadpe_ministry_register_student')) {
      final registrationRequest = request;
      final body = jsonDecode(registrationRequest.body) as Map<String, dynamic>;
      final payload = body['payload'] as Map<String, dynamic>;
      final studentId = payload['id'] as String;
      final personId = payload['person_id'] as String;
      if (_uuidPattern.hasMatch(studentId) &&
          _uuidPattern.hasMatch(personId) &&
          !excludedStudentIds.contains(studentId)) {
        // Emit before awaiting the response so the host can clean an exact
        // UI-generated ID pair if the browser loses the RPC response. A failed
        // RPC is atomic; the runner's ID-scoped deletion is harmless then.
        // ignore: avoid_print
        print('T11_CLEANUP_IDS=$studentId,$personId');
        final response = await _inner.send(registrationRequest);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          ownedIdentityReported = true;
          reportedStudentId = studentId;
          reportedPersonId = personId;
          registeredStudentPayload = Map<String, dynamic>.from(payload);
        }
        return response;
      }
    }
    final attendanceRequest =
        request is http.Request &&
        request.url.path.endsWith('/rpc/ieadpe_ministry_save_attendance');
    if (attendanceRequest && attendanceOperationId == null) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(body['payload'] as Map);
      if (payload['finalize'] == true) {
        final response = await _inner.send(request);
        final bytes = await response.stream.toBytes();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          attendanceOperationId = body['operation_id'] as String;
          attendancePayload = payload;
          attendanceReceipt = jsonDecode(utf8.decode(bytes));
        }
        return http.StreamedResponse(
          http.ByteStream.fromBytes(bytes),
          response.statusCode,
          headers: response.headers,
          request: response.request,
          reasonPhrase: response.reasonPhrase,
        );
      }
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

Future<void> _expectSessionRejection(
  Future<dynamic> Function() action,
  String reason,
) async {
  try {
    await action();
    fail('A new attendance operation unexpectedly succeeded.');
  } on PostgrestException catch (error) {
    expect(error.code, '23514');
    expect(error.message, contains(reason));
  }
}

Future<List<Map<String, dynamic>>> _rpcItems(
  SupabaseClient client,
  String rpc,
  Map<String, Object?> request,
) async {
  final raw = await client.rpc(rpc, params: {'request': request});
  final page = Map<String, dynamic>.from(raw as Map);
  return (page['items'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

Future<Map<String, dynamic>> _sessionAttendance(
  SupabaseClient client,
  String congregationId,
  String sessionId,
) async {
  final raw = await client.rpc(
    'ieadpe_ministry_get_session_attendance',
    params: {
      'request': {'congregation_id': congregationId, 'session_id': sessionId},
    },
  );
  return Map<String, dynamic>.from(raw as Map);
}

Map<String, dynamic> _sessionOf(Map<String, dynamic> attendance) =>
    Map<String, dynamic>.from(attendance['session'] as Map);

List<Map<String, dynamic>> _rosterOf(Map<String, dynamic> attendance) =>
    (attendance['roster'] as List)
        .map((mark) => Map<String, dynamic>.from(mark as Map))
        .toList();

Future<List<Map<String, dynamic>>> _classSessions(
  SupabaseClient client,
  String congregationId,
  String classId,
) => _rpcItems(client, 'ieadpe_ministry_list_class_sessions', {
  'congregation_id': congregationId,
  'class_id': classId,
  'limit': 100,
  'cursor': null,
});

Future<List<Map<String, dynamic>>> _studentEnrollments(
  SupabaseClient client,
  String congregationId,
  String studentId,
) => _rpcItems(client, 'ieadpe_ministry_list_student_enrollments', {
  'congregation_id': congregationId,
  'student_id': studentId,
  'limit': 100,
  'cursor': null,
});

Future<List<Map<String, dynamic>>> _classStudents(
  SupabaseClient client,
  String congregationId,
  String classId,
) => _rpcItems(client, 'ieadpe_ministry_list_class_students', {
  'congregation_id': congregationId,
  'class_id': classId,
  'limit': 100,
  'cursor': null,
});

Future<Map<String, dynamic>> _convertProjection(
  SupabaseClient client,
  String congregationId, {
  String? convertId,
  String? namePrefix,
}) async {
  final items = await _rpcItems(client, 'ieadpe_ministry_list_converts', {
    'congregation_id': congregationId,
    'name_prefix': namePrefix,
    'limit': 100,
    'cursor': null,
  });
  final matches = items.where((item) {
    final convert = Map<String, dynamic>.from(item['convert'] as Map);
    final person = item['person'];
    return (convertId == null
            ? (person is Map && person['name'] == namePrefix)
            : convert['id'] == convertId) &&
        convert['congregation_id'] == congregationId;
  }).toList();
  expect(matches, hasLength(1));
  return Map<String, dynamic>.from(matches.single['convert'] as Map);
}

Future<Map<String, dynamic>> _convertByName(
  SupabaseClient client,
  String congregationId,
  String name,
) => _convertProjection(client, congregationId, namePrefix: name);

Future<Map<String, dynamic>> _convertById(
  SupabaseClient client,
  String congregationId,
  String id,
) => _convertProjection(client, congregationId, convertId: id);

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

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
