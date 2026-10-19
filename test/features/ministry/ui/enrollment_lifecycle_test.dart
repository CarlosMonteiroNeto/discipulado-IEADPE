import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';
import 'package:ieadpe_converts/features/ministry/ui/class_enrollment_panel.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _classId = '22222222-2222-4222-8222-222222222222';
const _personId = '55555555-5555-4555-8555-555555555555';
const _studentId = '66666666-6666-4666-8666-666666666666';
const _enrollmentId = '77777777-7777-4777-8777-777777777777';
const _actor = '88888888-8888-4888-8888-888888888888';

class _EnrollmentGateway implements ReadRpcGateway, MinistryCommandGateway {
  final calls =
      <({String name, String operationId, Map<String, Object?> payload})>[];
  int reads = 0;
  bool enrolled = false;
  bool closed = false;
  bool loseNextEnrollmentResponse = false;
  bool loseNextCloseResponse = false;

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
      return {
        'items': [
          {
            'id': _personId,
            'congregation_id': _scope,
            'name': 'Pessoa Exemplo',
            'normalized_name': 'pessoa exemplo',
            'phone': null,
            'birth_date': null,
            'address': null,
            'person_revision': 1,
          },
        ],
        'next_cursor': null,
      };
    }
    if (rpc == 'ministry_list_class_students') {
      reads++;
      return {
        'items': enrolled && !closed
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
                    'revision': 1,
                    'created_at': '2026-10-19T00:00:00Z',
                    'updated_at': '2026-10-19T00:00:00Z',
                    'updated_by': _actor,
                  },
                },
              ]
            : [],
        'next_cursor': null,
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
    calls.add((name: name, operationId: operationId, payload: Map.of(payload)));
    if (name == 'enroll_student') {
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
}
