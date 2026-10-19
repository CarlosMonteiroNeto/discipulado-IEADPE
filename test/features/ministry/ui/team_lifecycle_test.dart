import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_contact_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_page.dart';

const _congregationId = '22222222-2222-4222-8222-222222222222';
const _contactId = '11111111-1111-4111-8111-111111111111';
const _otherContactId = '33333333-3333-4333-8333-333333333333';
const _assignmentId = '44444444-4444-4444-8444-444444444444';

class _TeamGateway implements ReadRpcGateway, MinistryCommandGateway {
  _TeamGateway({
    this.globalManager = false,
    List<Map<String, Object?>> contacts = const [],
  }) {
    for (final contact in contacts) {
      _contacts[contact['id']! as String] = Map.of(contact);
    }
  }

  final bool globalManager;
  final boundary = ProtectedDataBoundary();
  final _contacts = <String, Map<String, Object?>>{};
  final reads = <(String, Map<String, Object?>)>[];
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
    reads.add((rpc, Map.of(parameters)));
    if (rpc == 'ministry_get_contact') {
      final id = parameters['contact_id']! as String;
      final contact = _contacts[id]!;
      final accessId = globalManager
          ? contact['user_access_id'] as String?
          : null;
      return {
        'contact': {
          ...contact,
          'user_access_id': accessId,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
          'updated_by': _contactId,
        },
        'access': accessId == null
            ? null
            : {
                'id': accessId,
                'user_email': contact['email'],
                'role': contact['scope'] == 'congregation'
                    ? AccessRole.direction.wireValue
                    : AccessRole.supervision.wireValue,
                'congregation_id': contact['congregation_id'],
                'user_id': _assignmentId,
              },
      };
    }
    if (rpc == 'ministry_get_teacher_contact') {
      final id = parameters['contact_id']! as String;
      final contact = _contacts[id]!;
      return {
        'contact': {
          'id': id,
          'congregation_id': contact['congregation_id'],
          'name': contact['name'],
          'phone_e164': contact['phone_e164'],
          'birth_date': contact['birth_date'],
          'revision': contact['revision'],
        },
      };
    }
    final scope = parameters['scope']! as String;
    final congregationId = parameters['congregation_id'];
    final items = _contacts.values
        .where(
          (contact) =>
              contact['scope'] == scope &&
              contact['congregation_id'] == congregationId,
        )
        .map(
          (contact) => {
            'id': contact['id'],
            'name': contact['name'],
            'normalized_name': (contact['name']! as String).toLowerCase(),
            'scope': contact['scope'],
            'congregation_id': contact['congregation_id'],
            'role_code': contact['role_code'],
            'phone_e164': contact['phone_e164'],
            'birth_date': contact['birth_date'],
            'email': contact['email'],
            'archived_at': contact['archived_at'],
            'revision': contact['revision'],
            'user_access_id': globalManager ? contact['user_access_id'] : null,
          },
        )
        .toList();
    return {'items': items, 'next_cursor': null};
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
    final frozen = Map<String, Object?>.of(payload);
    writes.add((command, frozen));
    final id = payload['id']! as String;
    final old = _contacts[id];
    switch (command) {
      case 'save_contact':
        final revision = old == null ? 1 : (old['revision']! as int) + 1;
        _contacts[id] = {
          'id': id,
          'scope': payload['scope'],
          'congregation_id': payload['congregation_id'],
          'name': payload['name'],
          'normalized_name': (payload['name']! as String).toLowerCase(),
          'role_code': payload['role_code'],
          'phone_e164': payload['phone_e164'],
          'birth_date': payload['birth_date'],
          'email': payload['email'],
          'archived_at': old?['archived_at'],
          'revision': revision,
          'user_access_id': old?['user_access_id'],
        };
        return {'id': id, 'revision': revision};
      case 'save_contact_with_access':
        final access = payload['access']! as Map<String, Object?>;
        final accessId = access['id'] as String? ?? _assignmentId;
        final revision = old == null ? 1 : (old['revision']! as int) + 1;
        _contacts[id] = {
          'id': id,
          'scope': payload['scope'],
          'congregation_id': payload['congregation_id'],
          'name': payload['name'],
          'normalized_name': (payload['name']! as String).toLowerCase(),
          'role_code': payload['role_code'],
          'phone_e164': payload['phone_e164'],
          'birth_date': payload['birth_date'],
          'email': payload['email'],
          'archived_at': old?['archived_at'],
          'revision': revision,
          'user_access_id': accessId,
        };
        return {'id': id, 'revision': revision, 'access_id': accessId};
      case 'revoke_contact_access':
        final revision = (old!['revision']! as int) + 1;
        old['user_access_id'] = null;
        old['revision'] = revision;
        return {
          'id': id,
          'revision': revision,
          'revoked_access_id': _assignmentId,
        };
      case 'set_contact_archived':
        final revision = (old!['revision']! as int) + 1;
        old['archived_at'] = payload['archived'] == true
            ? '2026-10-19T00:00:00Z'
            : null;
        old['revision'] = revision;
        return {'id': id, 'revision': revision};
      case 'replace_role_holder':
        final previousId = payload['previous_contact_id']! as String;
        final previous = _contacts[previousId]!;
        final revision = (old!['revision']! as int) + 1;
        previous['revision'] = (previous['revision']! as int) + 1;
        old['revision'] = revision;
        return {
          'id': id,
          'revision': revision,
          'previous_contact_id': previousId,
          'previous_revision': previous['revision'],
        };
    }
    throw StateError('Unexpected command: $command');
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => {};

  Map<String, Object?> contact(String id) => _contacts[id]!;
}

Map<String, Object?> _contact({
  String id = _contactId,
  String name = 'Ana Silva',
  String scope = 'congregation',
  String? congregationId = _congregationId,
  String? roleCode = 'teacher',
  String? email,
  String? userAccessId,
  int revision = 4,
}) => {
  'id': id,
  'name': name,
  'normalized_name': name.toLowerCase(),
  'scope': scope,
  'congregation_id': congregationId,
  'role_code': roleCode,
  'phone_e164': '+5511999990000',
  'birth_date': '1982-02-03',
  'email': email,
  'archived_at': null,
  'revision': revision,
  'user_access_id': userAccessId,
};

Future<void> _pumpTeam(
  WidgetTester tester,
  _TeamGateway gateway, {
  String? congregationId = _congregationId,
  bool supervision = false,
  bool canManageAccess = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TeamPage(
        repository: MinistryRepository(gateway),
        congregationId: congregationId,
        supervision: supervision,
        canManageAccess: canManageAccess,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('directory-only contact has no login', (tester) async {
    final gateway = _TeamGateway(contacts: [_contact(email: null)]);
    await _pumpTeam(tester, gateway);

    expect(find.text('Sem acesso ao aplicativo'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Adicionar contato'));
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-name')),
      'Joana Nunes',
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['email'], isNull);
    expect(gateway.writes.single.$2, isNot(contains('access')));
  });

  testWidgets('authorized detail edit uses the returned contact revision', (
    tester,
  ) async {
    final gateway = _TeamGateway(contacts: [_contact()]);
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    expect(
      gateway.reads.map((read) => read.$1),
      contains('ministry_get_contact'),
    );
    expect(find.byType(TeamContactForm), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-phone')),
      '+5511999990001',
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['expected_revision'], 4);
    expect(gateway.writes.single.$2['birth_date'], '1982-02-03');
  });

  testWidgets('global manager explicitly selects the returned assignment ID', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      globalManager: true,
      contacts: [
        _contact(
          scope: 'supervision',
          congregationId: null,
          roleCode: 'campaignSupervisor',
          email: 'ana@example.test',
          userAccessId: _assignmentId,
        ),
      ],
    );
    await _pumpTeam(
      tester,
      gateway,
      congregationId: null,
      supervision: true,
      canManageAccess: true,
    );

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    expect(find.text('Acesso ao aplicativo'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Atualizar vínculo de acesso'));
    expect(
      find.byKey(const ValueKey('team-access-assignment')),
      findsOneWidget,
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));
    expect(gateway.writes, isEmpty);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-access-assignment')),
    );
    await _tapAndSettle(tester, find.textContaining(_assignmentId));
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact_with_access');
    expect(
      (gateway.writes.single.$2['access']! as Map<String, Object?>)['id'],
      _assignmentId,
    );
  });

  testWidgets('verified access is granted only after an explicit choice', (
    tester,
  ) async {
    final gateway = _TeamGateway(globalManager: true);
    await _pumpTeam(
      tester,
      gateway,
      congregationId: null,
      supervision: true,
      canManageAccess: true,
    );

    await _tapAndSettle(tester, find.text('Adicionar contato'));
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-name')),
      'Marcos Lima',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-email')),
      'marcos@example.test',
    );
    expect(gateway.writes, isEmpty);
    await _tapAndSettle(tester, find.text('Conceder acesso ao aplicativo'));
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact_with_access');
    expect(gateway.writes.single.$2, isNot(contains('access_id')));
    expect(gateway.writes.single.$2['email'], 'marcos@example.test');
    expect(
      (gateway.writes.single.$2['access']! as Map<String, Object?>)['role'],
      AccessRole.supervision.wireValue,
    );
  });

  testWidgets('role replacement keeps the previous contact in the directory', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      contacts: [
        _contact(name: 'Ana Silva'),
        _contact(id: _otherContactId, name: 'Bia Santos', revision: 2),
      ],
    );
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.text('Bia Santos'));
    await _tapAndSettle(tester, find.text('Substituir ocupante atual'));
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-replace-holder')),
    );
    await _tapAndSettle(tester, find.text('Ana Silva').last);
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(
      gateway.writes.map((write) => write.$1),
      contains('replace_role_holder'),
    );
    expect(gateway.contact(_contactId)['archived_at'], isNull);
    expect(gateway.contact(_contactId)['name'], 'Ana Silva');
  });

  testWidgets('archive and access revoke are distinct lifecycle actions', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      globalManager: true,
      contacts: [
        _contact(email: 'ana@example.test', userAccessId: _assignmentId),
      ],
    );
    await _pumpTeam(tester, gateway, canManageAccess: true);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    await _tapAndSettle(tester, find.text('Arquivar contato'));
    expect(find.textContaining('não revoga o acesso'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Confirmar arquivamento'));
    expect(gateway.writes.single.$1, 'set_contact_archived');
    expect(gateway.contact(_contactId)['user_access_id'], _assignmentId);

    final revokeGateway = _TeamGateway(
      globalManager: true,
      contacts: [
        _contact(email: 'ana@example.test', userAccessId: _assignmentId),
      ],
    );
    await _pumpTeam(tester, revokeGateway, canManageAccess: true);
    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    await _tapAndSettle(tester, find.text('Revogar acesso'));
    await _tapAndSettle(tester, find.text('Confirmar revogação'));

    expect(revokeGateway.writes.single.$1, 'revoke_contact_access');
    expect(revokeGateway.contact(_contactId)['archived_at'], isNull);
    expect(revokeGateway.contact(_contactId)['user_access_id'], isNull);
  });

  testWidgets('local user cannot create global access', (tester) async {
    final gateway = _TeamGateway();
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.text('Adicionar contato'));
    expect(find.text('Conceder acesso ao aplicativo'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-name')),
      'Joana Nunes',
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2, isNot(contains('access')));
  });
}
