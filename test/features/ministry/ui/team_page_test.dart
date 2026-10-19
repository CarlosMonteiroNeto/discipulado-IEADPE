import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_page.dart';

const _scope = '22222222-2222-4222-8222-222222222222';
const _contactId = '11111111-1111-4111-8111-111111111111';

class _TeamGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();
  final reads = <String>[];
  final writes = <(String, Map<String, Object?>)>[];

  @override
  String get context => boundary.generation;

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
    if (rpc == 'ministry_get_teacher_contact') {
      return {
        'contact': {
          'id': _contactId,
          'congregation_id': _scope,
          'name': 'Ana Silva',
          'phone_e164': '+5511999990000',
          'birth_date': '1982-02-03',
          'revision': 4,
        },
      };
    }
    if (rpc == 'ministry_get_contact') {
      return {
        'contact': {
          'id': _contactId,
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'scope': 'congregation',
          'congregation_id': _scope,
          'role_code': 'teacher',
          'phone_e164': '+5511999990000',
          'birth_date': '1982-02-03',
          'email': 'ana@example.test',
          'archived_at': null,
          'revision': 4,
          'user_access_id': null,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
          'updated_by': _contactId,
        },
        'access': null,
      };
    }
    return {
      'items': [
        {
          'id': _contactId,
          'name': 'Ana Silva',
          'normalized_name': 'ana silva',
          'scope': 'congregation',
          'congregation_id': _scope,
          'role_code': 'teacher',
          'phone_e164': '+5511999990000',
          'birth_date': '1982-02-03',
          'email': 'ana@example.test',
          'archived_at': null,
          'revision': 4,
          'user_access_id': null,
        },
      ],
      'next_cursor': null,
    };
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
    writes.add((command, Map<String, Object?>.of(payload)));
    return {'id': payload['id'], 'revision': 5};
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => {};
}

void main() {
  testWidgets('congregation team page offers teacher contact creation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TeamPage(
          repository: MinistryRepository(_TeamGateway()),
          congregationId: _scope,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionar professor'), findsOneWidget);
  });

  testWidgets('teacher edit loads bounded detail before showing the form', (
    tester,
  ) async {
    final gateway = _TeamGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: TeamPage(
          repository: MinistryRepository(gateway),
          congregationId: _scope,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar professor'));
    await tester.pumpAndSettle();

    expect(gateway.reads, contains('ministry_get_teacher_contact'));
    expect(find.text('1982-02-03'), findsOneWidget);
    expect(find.text('Função: Professor'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('teacher-contact-phone')),
      '+5511999990001',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(gateway.reads, contains('ministry_get_contact'));
    final save = gateway.writes.single;
    expect(save.$1, 'save_contact');
    expect(save.$2['phone_e164'], '+5511999990001');
    expect(save.$2['birth_date'], '1982-02-03');
    expect(save.$2['expected_revision'], 4);
    expect(save.$2['email'], 'ana@example.test');
    expect(save.$2['name'], 'Ana Silva');
  });
}
