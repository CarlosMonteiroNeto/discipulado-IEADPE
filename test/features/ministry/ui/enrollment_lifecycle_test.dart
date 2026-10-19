import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_enrollment_panel.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _otherScope = '99999999-9999-4999-8999-999999999998';
const _classId = '22222222-2222-4222-8222-222222222222';
const _otherClassId = '99999999-9999-4999-8999-999999999997';
const _personId = '55555555-5555-4555-8555-555555555555';
const _otherPersonId = '99999999-9999-4999-8999-999999999996';
const _studentId = '66666666-6666-4666-8666-666666666666';
const _enrollmentId = '77777777-7777-4777-8777-777777777777';
const _actor = '88888888-8888-4888-8888-888888888888';

class _EnrollmentGateway implements ReadRpcGateway, MinistryCommandGateway {
  final calls =
      <({String name, String operationId, Map<String, Object?> payload})>[];
  int reads = 0;
  bool enrolled = false;
  bool closed = false;
  int enrollmentRevision = 1;
  bool loseNextEnrollmentResponse = false;
  bool loseNextCloseResponse = false;
  String? rejectNextEnrollment;
  String? rejectNextClose;
  Completer<Map<String, dynamic>>? delayedPeopleResponse;
  Completer<Map<String, dynamic>>? delayedRosterResponse;

  Map<String, dynamic> _peopleResponse(String scope, String name, String id) =>
      {
        'items': [
          {
            'id': id,
            'congregation_id': scope,
            'name': name,
            'normalized_name': name.toLowerCase(),
            'phone': null,
            'birth_date': null,
            'address': null,
            'person_revision': 1,
          },
        ],
        'next_cursor': null,
      };

  Map<String, dynamic> _rosterResponse({bool includeEnrollment = false}) => {
    'items': includeEnrollment
        ? [
            {
              'student': {
                'id': _studentId,
                'person_id': _personId,
                'person_revision': 1,
                'congregation_id': _scope,
                'name': 'Pessoa Exemplo',
                'normalized_name': 'pessoa exemplo',
                'phone_e164': null,
                'birth_date': null,
                'address': null,
                'education': null,
                'marital_status': null,
                'new_convert': null,
                'water_baptized': null,
                'wants_baptism': null,
                'archived_at': null,
                'revision': 1,
                'created_at': '2026-10-19T00:00:00Z',
                'updated_at': '2026-10-19T00:00:00Z',
                'updated_by': _actor,
              },
              'enrollment': {
                'id': _enrollmentId,
                'congregation_id': _scope,
                'student_id': _studentId,
                'class_id': _classId,
                'start_date': '2026-10-01',
                'end_date': null,
                'status': 'active',
                'revision': enrollmentRevision,
                'created_at': '2026-10-19T00:00:00Z',
                'updated_at': '2026-10-19T00:00:00Z',
                'updated_by': _actor,
              },
            },
          ]
        : [],
    'next_cursor': null,
  };

  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    if (rpc == 'ministry_list_people') {
      final delayed = delayedPeopleResponse;
      if (delayed != null) {
        delayedPeopleResponse = null;
        return delayed.future;
      }
      return parameters['congregation_id'] == _otherScope
          ? _peopleResponse(_otherScope, 'Outra Pessoa', _otherPersonId)
          : parameters['name_prefix'] == 'Outra'
          ? _peopleResponse(_scope, 'Outra Pessoa', _otherPersonId)
          : _peopleResponse(_scope, 'Pessoa Exemplo', _personId);
    }
    if (rpc == 'ministry_list_class_students') {
      reads++;
      final delayed = delayedRosterResponse;
      if (delayed != null) {
        delayedRosterResponse = null;
        return delayed.future;
      }
      return _rosterResponse(includeEnrollment: enrolled && !closed);
    }
    throw UnimplementedError(rpc);
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String name,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    calls.add((name: name, operationId: operationId, payload: Map.of(payload)));
    if (name == 'enroll_student') {
      final rejection = rejectNextEnrollment;
      if (rejection != null) {
        rejectNextEnrollment = null;
        throw DataFailure(rejection);
      }
      enrolled = true;
      if (loseNextEnrollmentResponse) {
        loseNextEnrollmentResponse = false;
        throw const DataFailure('unavailable');
      }
      return {
        'id': payload['id'],
        'student_id': _studentId,
        'person_id': payload['person_id'],
        'revision': 1,
        'student_revision': 1,
      };
    }
    if (name == 'close_enrollment') {
      final rejection = rejectNextClose;
      if (rejection != null) {
        rejectNextClose = null;
        if (rejection == 'stale_revision') enrollmentRevision++;
        throw DataFailure(rejection);
      }
      closed = true;
      if (loseNextCloseResponse) {
        loseNextCloseResponse = false;
        throw const DataFailure('unavailable');
      }
    }
    return {'id': payload['id'], 'revision': 2};
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) => throw UnimplementedError(table);

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) => throw UnimplementedError(command);

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) => throw UnimplementedError();
}

void main() {
  test('typed closure sends the scoped revisioned command payload', () async {
    final gateway = _EnrollmentGateway();
    final result = await MinistryRepository(gateway).closeEnrollment(
      operationId: '99999999-9999-4999-8999-999999999999',
      enrollmentId: _enrollmentId,
      congregationId: _scope,
      status: EnrollmentStatus.completed,
      endDate: CalendarDate(2026, 10, 19),
      startDate: CalendarDate(2026, 10, 1),
      expectedRevision: 1,
    );
    expect(result.revision, 2);
    expect(gateway.calls.single.name, 'close_enrollment');
    expect(
      gateway.calls.single.operationId,
      '99999999-9999-4999-8999-999999999999',
    );
    expect(gateway.calls.single.payload, {
      'id': _enrollmentId,
      'congregation_id': _scope,
      'status': 'completed',
      'end_date': '2026-10-19',
      'expected_revision': 1,
    });
  });

  testWidgets('enrolls the first canonical person into an empty class', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway();
    final repository = MinistryRepository(gateway);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: repository,
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum aluno matriculado nesta turma.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Pessoa',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enrollment-person-search')), findsOneWidget);
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoa Exemplo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();

    expect(gateway.calls.single.name, 'enroll_student');
    expect(gateway.calls.single.payload, containsPair('person_id', _personId));
    expect(gateway.calls.single.payload, isNot(contains('student_id')));
    expect(find.text('Pessoa Exemplo'), findsOneWidget);
  });

  testWidgets('closes an active enrollment while preserving its row history', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()..enrolled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();
    expect(gateway.calls.single.name, 'close_enrollment');
    expect(gateway.calls.single.payload['id'], _enrollmentId);
    expect(gateway.calls.single.payload['expected_revision'], 1);
    expect(gateway.calls.single.payload['status'], 'withdrawn');
    expect(find.text('Nenhum aluno matriculado nesta turma.'), findsOneWidget);
  });

  testWidgets('replays the same enrollment after a lost response', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()..loseNextEnrollmentResponse = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Pessoa',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoa Exemplo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(1));

    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].operationId, gateway.calls[0].operationId);
    expect(gateway.calls[1].payload, gateway.calls[0].payload);
  });

  testWidgets('person changes cannot replace an unresolved enrollment', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()..loseNextEnrollmentResponse = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            key: const ValueKey('enrollment-panel'),
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Pessoa',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoa Exemplo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(1));

    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Outra',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outra Pessoa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(1));
    await tester.tap(find.byKey(const Key('retry-pending-enrollment')));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].operationId, gateway.calls[0].operationId);
    expect(gateway.calls[1].payload, gateway.calls[0].payload);
  });

  testWidgets('definitive enrollment rejection releases the pending command', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()..rejectNextEnrollment = 'invalid';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Pessoa',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoa Exemplo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(1));

    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Outra',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outra Pessoa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enroll-person-button')));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].payload['person_id'], _otherPersonId);
    expect(gateway.calls[1].operationId, isNot(gateway.calls[0].operationId));
  });

  testWidgets('replays the same close command after a lost response', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()
      ..enrolled = true
      ..loseNextCloseResponse = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(1));

    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].operationId, gateway.calls[0].operationId);
    expect(gateway.calls[1].payload, gateway.calls[0].payload);
  });

  testWidgets('status changes cannot replace an unresolved close command', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()
      ..enrolled = true
      ..loseNextCloseResponse = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(1));

    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir participação'));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(1));
    await tester.tap(find.byKey(const Key('retry-pending-close')));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].operationId, gateway.calls[0].operationId);
    expect(gateway.calls[1].payload, gateway.calls[0].payload);
    expect(gateway.calls[1].payload['status'], 'withdrawn');
  });

  testWidgets('close date changes cannot replace an unresolved payload', (
    tester,
  ) async {
    var currentTime = DateTime(2026, 10, 19, 12);
    final gateway = _EnrollmentGateway()
      ..enrolled = true
      ..loseNextCloseResponse = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            now: () => currentTime,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(1));

    currentTime = currentTime.add(const Duration(days: 1));
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(1));
    await tester.tap(find.byKey(const Key('retry-pending-close')));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].operationId, gateway.calls[0].operationId);
    expect(gateway.calls[1].payload, gateway.calls[0].payload);
  });

  testWidgets('stale close revision allows a fresh command after refresh', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway()
      ..enrolled = true
      ..rejectNextClose = 'stale_revision';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassEnrollmentPanel(
            repository: MinistryRepository(gateway),
            congregationId: _scope,
            classId: _classId,
            classStartDate: '2026-10-01',
            classEndDate: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar desistência'));
    await tester.pumpAndSettle();
    expect(gateway.calls.single.payload['expected_revision'], 1);
    expect(
      find.text(
        'A matrícula foi alterada por outra pessoa. Atualize a turma e tente novamente.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-enrollment-$_enrollmentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir participação'));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(2));
    expect(gateway.calls[1].payload['expected_revision'], 2);
    expect(gateway.calls[1].operationId, isNot(gateway.calls[0].operationId));
  });

  testWidgets('old roster response is discarded after scope and class change', (
    tester,
  ) async {
    final oldRoster = Completer<Map<String, dynamic>>();
    final gateway = _EnrollmentGateway()..delayedRosterResponse = oldRoster;
    Widget panel(String scope, String classId) => MaterialApp(
      home: Scaffold(
        body: ClassEnrollmentPanel(
          key: const ValueKey('enrollment-panel'),
          repository: MinistryRepository(gateway),
          congregationId: scope,
          classId: classId,
          classStartDate: '2026-10-01',
          classEndDate: null,
          onChanged: () {},
        ),
      ),
    );

    await tester.pumpWidget(panel(_scope, _classId));
    await tester.pumpWidget(panel(_otherScope, _otherClassId));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('enrollment-search-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Nenhum aluno matriculado nesta turma.'), findsOneWidget);
    oldRoster.complete(gateway._rosterResponse(includeEnrollment: true));
    await tester.pumpAndSettle();
    expect(find.text('Pessoa Exemplo'), findsNothing);
  });

  testWidgets('old people search is discarded and new search can finish', (
    tester,
  ) async {
    final gateway = _EnrollmentGateway();
    Widget panel(String scope, String classId) => MaterialApp(
      home: Scaffold(
        body: ClassEnrollmentPanel(
          key: const ValueKey('enrollment-panel'),
          repository: MinistryRepository(gateway),
          congregationId: scope,
          classId: classId,
          classStartDate: '2026-10-01',
          classEndDate: null,
          onChanged: () {},
        ),
      ),
    );

    await tester.pumpWidget(panel(_scope, _classId));
    await tester.pumpAndSettle();
    final oldPeople = Completer<Map<String, dynamic>>();
    gateway.delayedPeopleResponse = oldPeople;
    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Pessoa',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pump();

    await tester.pumpWidget(panel(_otherScope, _otherClassId));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('enrollment-search-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const Key('enrollment-person-query')),
      'Outra',
    );
    await tester.tap(find.byKey(const Key('enrollment-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enrollment-person-search')), findsOneWidget);
    oldPeople.complete(
      gateway._peopleResponse(_scope, 'Pessoa Exemplo', _personId),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollment-person-search')));
    await tester.pumpAndSettle();
    expect(find.text('Outra Pessoa'), findsWidgets);
    expect(find.text('Pessoa Exemplo'), findsNothing);
  });
}
