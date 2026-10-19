import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/students_page.dart';

const _scope = '22222222-2222-4222-8222-222222222222';
const _studentId = '11111111-1111-4111-8111-111111111111';
const _personId = '44444444-4444-4444-8444-444444444444';

class _StudentGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  @override
  String get context => boundary.generation;

  final reads = <String>[];
  final commands = <String>[];
  final writes = <(String, Map<String, Object?>)>[];

  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    reads.add(rpc);
    if (rpc == 'ministry_list_students') {
      return {
        'items': [
          {
            'id': _studentId,
            'person_id': _personId,
            'congregation_id': _scope,
            'name': 'Ana Silva',
            'phone': null,
            'birth_date': null,
            'address': null,
            'education': null,
            'marital_status': null,
            'new_convert': false,
            'water_baptized': null,
            'wants_baptism': null,
            'archived_at': null,
            'revision': 2,
            'person_revision': 4,
            'link_state': 'linked',
          },
        ],
        'next_cursor': null,
      };
    }
    if (rpc == 'ministry_get_student') {
      return {
        'student': {
          'id': _studentId,
          'person_id': _personId,
          'congregation_id': _scope,
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'phone_e164': null,
          'birth_date': null,
          'address': null,
          'education': 'Superior',
          'marital_status': null,
          'new_convert': false,
          'water_baptized': null,
          'wants_baptism': null,
          'archived_at': null,
          'revision': 2,
          'person_revision': 4,
          'link_state': 'linked',
          'created_at': '2026-10-18T12:00:00Z',
          'updated_at': '2026-10-18T12:00:00Z',
          'updated_by': '55555555-5555-4555-8555-555555555555',
        },
      };
    }
    if (rpc == 'ministry_get_person') {
      return {
        'person': {
          'id': _personId,
          'congregation_id': _scope,
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'phone': null,
          'birth_date': null,
          'address': null,
          'created_at': '2026-10-18T12:00:00Z',
          'updated_at': '2026-10-18T12:00:00Z',
          'updated_by': null,
        },
        'person_revision': 4,
      };
    }
    throw StateError('Unexpected RPC: $rpc');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => MutationResult.applied(operationId: operationId, value: 'record');

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    commands.add(command);
    writes.add((command, Map<String, Object?>.of(payload)));
    if (command == 'set_student_archived') {
      throw const DataFailure('active_enrollment');
    }
    return {
      'id': payload['id'],
      'revision': (payload['expected_revision'] as int?) == null
          ? 1
          : (payload['expected_revision'] as int) + 1,
    };
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => {};
}

void main() {
  testWidgets('opening a student row loads scoped academic detail', (
    tester,
  ) async {
    final gateway = _StudentGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentsPage(
          repository: MinistryBrowserRepository(gateway),
          congregationId: _scope,
          onOpenHandoff: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ana Silva'));
    await tester.pumpAndSettle();

    expect(gateway.reads, contains('ministry_get_student'));
    expect(gateway.reads, contains('ministry_get_person'));
    final detailScroll = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    final academicSection = find.text('Dados acadêmicos');
    await tester.scrollUntilVisible(
      academicSection,
      300,
      scrollable: detailScroll,
    );
    expect(find.text('Dados acadêmicos'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('student-detail-education')),
      300,
      scrollable: detailScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('student-detail-education')),
      'Superior completo',
    );
    final saveAcademic = find.text('Salvar dados acadêmicos');
    await tester.ensureVisible(saveAcademic);
    await tester.tap(saveAcademic);
    await tester.pumpAndSettle();
    final save = gateway.writes.singleWhere(
      (write) => write.$1 == 'save_student',
    );
    expect(save.$2['education'], 'Superior completo');
    expect(save.$2['expected_revision'], 2);

    final archive = find.text('Arquivar aluno');
    await tester.ensureVisible(archive);
    await tester.tap(archive);
    await tester.pumpAndSettle();
    final archiveError = find.text(
      'Este aluno tem uma matrícula ativa e não pode ser arquivado.',
    );
    await tester.scrollUntilVisible(
      archiveError,
      -300,
      scrollable: detailScroll,
    );
    expect(archiveError, findsOneWidget);
  });
}
