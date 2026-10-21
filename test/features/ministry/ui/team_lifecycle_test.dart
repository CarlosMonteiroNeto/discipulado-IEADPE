import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_contact_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_page.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';

import '../../../support/sdk_fonts.dart';

const _congregationId = '22222222-2222-4222-8222-222222222222';
const _contactId = '11111111-1111-4111-8111-111111111111';
const _otherContactId = '33333333-3333-4333-8333-333333333333';
const _assignmentId = '44444444-4444-4444-8444-444444444444';
const _teamGoldenFontFamily = 'TeamGoldenRoboto';

class _TeamGateway implements ReadRpcGateway, MinistryCommandGateway {
  _TeamGateway({
    this.globalManager = false,
    List<Map<String, Object?>> contacts = const [],
    this.accessCandidates = const [],
  }) {
    for (final contact in contacts) {
      _contacts[contact['id']! as String] = Map.of(contact);
    }
  }

  final bool globalManager;
  final List<Map<String, Object?>> accessCandidates;
  @override
  final boundary = ProtectedDataBoundary();
  final _contacts = <String, Map<String, Object?>>{};
  final reads = <(String, Map<String, Object?>)>[];
  final writes = <(String, Map<String, Object?>)>[];
  final operationIds = <String>[];
  final _receipts = <String, _TeamReceipt>{};
  String? failBeforeCommandOnce;
  String? dropResponseAfterCommitOnce;
  Completer<void>? detailGate;

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
      final gate = detailGate;
      if (gate != null) await gate.future;
      final id = parameters['contact_id']! as String;
      final contact = _contacts[id]!;
      final accessId = globalManager
          ? contact['user_access_id'] as String?
          : null;
      return {
        'contact': {
          ...contact,
          'user_access_id': accessId,
          'access_linked': contact['user_access_id'] != null,
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
    if (rpc == 'ministry_list_access_candidates') {
      if (!globalManager) throw const DataFailure('permission');
      final scope = parameters['scope'];
      final congregationId = parameters['congregation_id'];
      final role = parameters['role'];
      return {
        'items': accessCandidates
            .where(
              (candidate) =>
                  candidate['scope'] == scope &&
                  candidate['congregation_id'] == congregationId &&
                  candidate['role'] == role,
            )
            .toList(growable: false),
        'next_cursor': null,
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
    operationIds.add(operationId);
    final receipt = _receipts[operationId];
    if (receipt != null) {
      if (receipt.command != command ||
          jsonEncode(receipt.payload) != jsonEncode(frozen)) {
        throw const DataFailure('operation_conflict');
      }
      return Map<String, dynamic>.of(receipt.result);
    }
    if (failBeforeCommandOnce == command) {
      failBeforeCommandOnce = null;
      throw const DataFailure('unavailable');
    }
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
        return _commit(operationId, command, frozen, {
          'id': id,
          'revision': revision,
        });
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
        return _commit(operationId, command, frozen, {
          'id': id,
          'revision': revision,
          'access_id': accessId,
        });
      case 'revoke_contact_access':
        final revision = (old!['revision']! as int) + 1;
        old['user_access_id'] = null;
        old['revision'] = revision;
        return _commit(operationId, command, frozen, {
          'id': id,
          'revision': revision,
          'revoked_access_id': _assignmentId,
        });
      case 'set_contact_archived':
        final revision = (old!['revision']! as int) + 1;
        old['archived_at'] = payload['archived'] == true
            ? '2026-10-19T00:00:00Z'
            : null;
        old['revision'] = revision;
        return _commit(operationId, command, frozen, {
          'id': id,
          'revision': revision,
        });
      case 'replace_role_holder':
        final previousId = payload['previous_contact_id']! as String;
        final previous = _contacts[previousId]!;
        final revision = (old!['revision']! as int) + 1;
        previous['revision'] = (previous['revision']! as int) + 1;
        old['revision'] = revision;
        return _commit(operationId, command, frozen, {
          'id': id,
          'revision': revision,
          'previous_contact_id': previousId,
          'previous_revision': previous['revision'],
        });
    }
    throw StateError('Unexpected command: $command');
  }

  Map<String, dynamic> _commit(
    String operationId,
    String command,
    Map<String, Object?> payload,
    Map<String, dynamic> result,
  ) {
    _receipts[operationId] = _TeamReceipt(
      command: command,
      payload: Map.of(payload),
      result: Map.of(result),
    );
    if (dropResponseAfterCommitOnce == command) {
      dropResponseAfterCommitOnce = null;
      throw const DataFailure('unavailable');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => {};

  Map<String, Object?> contact(String id) => _contacts[id]!;
}

class _TeamReceipt {
  const _TeamReceipt({
    required this.command,
    required this.payload,
    required this.result,
  });

  final String command;
  final Map<String, Object?> payload;
  final Map<String, dynamic> result;
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

Future<void> _pumpTeamViewport(
  WidgetTester tester,
  _TeamGateway gateway, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = buildUnifiedTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: _teamGoldenFontFamily),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: TeamPage(
        repository: MinistryRepository(gateway),
        congregationId: _congregationId,
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
  setUpAll(() async {
    await loadSdkFont(_teamGoldenFontFamily, const [
      'Roboto-Regular.ttf',
      'roboto-regular.ttf',
    ]);
    await loadSdkFont('MaterialIcons', const [
      'MaterialIcons-Regular.otf',
      'materialicons-regular.otf',
    ]);
  });

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

  testWidgets('pending contact detail cannot open after page disposal', (
    tester,
  ) async {
    final gateway = _TeamGateway(contacts: [_contact()]);
    gateway.detailGate = Completer<void>();
    await _pumpTeam(tester, gateway);

    await tester.tap(find.byTooltip('Editar contato'));
    await tester.pump();
    expect(
      gateway.reads.map((read) => read.$1),
      contains('ministry_get_contact'),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gateway.detailGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(TeamContactForm), findsNothing);
    expect(tester.takeException(), isNull);
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
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-create-new-access')),
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact_with_access');
    expect(gateway.writes.single.$2, isNot(contains('access_id')));
    expect(gateway.writes.single.$2['email'], 'marcos@example.test');
    expect(
      (gateway.writes.single.$2['access']! as Map<String, Object?>)['role'],
      AccessRole.supervision.wireValue,
    );
  });

  testWidgets(
    'existing unlinked assignment requires explicit exact ID choice',
    (tester) async {
      final gateway = _TeamGateway(
        globalManager: true,
        accessCandidates: [
          {
            'id': _assignmentId,
            'email': 'marcos@example.test',
            'role': AccessRole.supervision.wireValue,
            'scope': 'supervision',
            'congregation_id': null,
          },
        ],
      );
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
      await _tapAndSettle(tester, find.text('Conceder acesso ao aplicativo'));

      final candidateDropdown = find.byKey(
        const ValueKey('team-access-candidate'),
      );
      expect(candidateDropdown, findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(candidateDropdown)
            .initialValue,
        isNull,
      );
      expect(
        gateway.reads.map((read) => read.$1),
        contains('ministry_list_access_candidates'),
      );
      final candidateRead = gateway.reads.singleWhere(
        (read) => read.$1 == 'ministry_list_access_candidates',
      );
      expect(candidateRead.$2['role'], AccessRole.supervision.wireValue);
      expect(candidateRead.$2['scope'], 'supervision');
      expect(candidateRead.$2['congregation_id'], isNull);

      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('team-contact-save')),
      );
      expect(gateway.writes, isEmpty);

      await _tapAndSettle(tester, candidateDropdown);
      expect(find.textContaining(_assignmentId), findsOneWidget);
      await _tapAndSettle(tester, find.textContaining(_assignmentId));
      await _tapAndSettle(tester, find.text('Salvar contato'));

      expect(gateway.writes.single.$1, 'save_contact_with_access');
      expect(
        (gateway.writes.single.$2['access']! as Map<String, Object?>)['id'],
        _assignmentId,
      );
    },
  );

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
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-contact-save')),
    );

    expect(
      gateway.writes.map((write) => write.$1),
      contains('replace_role_holder'),
    );
    expect(gateway.contact(_contactId)['archived_at'], isNull);
    expect(gateway.contact(_contactId)['name'], 'Ana Silva');
  });

  testWidgets(
    'role replacement retry resumes from the committed contact revision',
    (tester) async {
      final gateway = _TeamGateway(
        contacts: [
          _contact(name: 'Ana Silva'),
          _contact(id: _otherContactId, name: 'Bia Santos', revision: 2),
        ],
      )..failBeforeCommandOnce = 'replace_role_holder';
      await _pumpTeam(tester, gateway);

      await _tapAndSettle(tester, find.text('Bia Santos'));
      await _tapAndSettle(tester, find.text('Substituir ocupante atual'));
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('team-replace-holder')),
      );
      await _tapAndSettle(tester, find.text('Ana Silva').last);
      await tester.enterText(
        find.byKey(const ValueKey('team-contact-phone')),
        '+5511999990002',
      );

      await _tapAndSettle(tester, find.text('Salvar contato'));
      expect(gateway.contact(_otherContactId)['revision'], 3);
      expect(
        gateway.writes.where((write) => write.$1 == 'save_contact'),
        hasLength(1),
      );

      await _tapAndSettle(tester, find.text('Tentar novamente'));

      final replacementWrites = gateway.writes
          .where((write) => write.$1 == 'replace_role_holder')
          .toList();
      expect(replacementWrites, hasLength(2));
      expect(gateway.operationIds[0], isNot(gateway.operationIds[1]));
      expect(gateway.operationIds[1], gateway.operationIds[2]);
      expect(replacementWrites.last.$2['expected_revision'], 3);
      expect(replacementWrites.last.$2['previous_expected_revision'], 4);
      expect(
        gateway.writes.where((write) => write.$1 == 'save_contact'),
        hasLength(1),
      );
      expect(gateway.contact(_contactId)['name'], 'Ana Silva');
    },
  );

  testWidgets('ambiguous save retry reuses the frozen payload and operation', (
    tester,
  ) async {
    final gateway = _TeamGateway(contacts: [_contact()])
      ..dropResponseAfterCommitOnce = 'save_contact';
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    final phoneField = find.byKey(const ValueKey('team-contact-phone'));
    await tester.enterText(phoneField, '+5511999990002');
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-contact-save')),
    );

    expect(gateway.contact(_contactId)['revision'], 5);
    expect(
      find.textContaining('Os dados permanecem no formulário'),
      findsOneWidget,
    );
    expect(tester.widget<TextFormField>(phoneField).enabled, isFalse);

    await _tapAndSettle(tester, find.text('Tentar novamente'));

    expect(gateway.writes, hasLength(2));
    expect(gateway.writes[0].$1, gateway.writes[1].$1);
    expect(jsonEncode(gateway.writes[0].$2), jsonEncode(gateway.writes[1].$2));
    expect(gateway.operationIds[0], gateway.operationIds[1]);
    expect(gateway.contact(_contactId)['revision'], 5);
  });

  testWidgets(
    'ambiguous replacement retry replays without changing its first-stage save',
    (tester) async {
      final gateway = _TeamGateway(
        contacts: [
          _contact(name: 'Ana Silva'),
          _contact(id: _otherContactId, name: 'Bia Santos', revision: 2),
        ],
      )..dropResponseAfterCommitOnce = 'replace_role_holder';
      await _pumpTeam(tester, gateway);

      await _tapAndSettle(tester, find.text('Bia Santos'));
      await _tapAndSettle(tester, find.text('Substituir ocupante atual'));
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('team-replace-holder')),
      );
      await _tapAndSettle(tester, find.text('Ana Silva').last);
      await tester.enterText(
        find.byKey(const ValueKey('team-contact-phone')),
        '+5511999990002',
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('team-contact-save')),
      );

      expect(gateway.contact(_otherContactId)['revision'], 4);
      expect(gateway.contact(_contactId)['revision'], 5);
      final phoneField = find.byKey(const ValueKey('team-contact-phone'));
      expect(tester.widget<TextFormField>(phoneField).enabled, isFalse);

      await _tapAndSettle(tester, find.text('Tentar novamente'));

      expect(gateway.writes.map((write) => write.$1), [
        'save_contact',
        'replace_role_holder',
        'replace_role_holder',
      ]);
      expect(gateway.operationIds[1], gateway.operationIds[2]);
      expect(
        jsonEncode(gateway.writes[1].$2),
        jsonEncode(gateway.writes[2].$2),
      );
      expect(gateway.contact(_otherContactId)['revision'], 4);
      expect(gateway.contact(_contactId)['revision'], 5);
    },
  );

  testWidgets('local user can edit email only for an unlinked contact', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      contacts: [_contact(email: 'old@example.test')],
    );
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    final emailField = find.byKey(const ValueKey('team-contact-email'));
    expect(tester.widget<TextFormField>(emailField).enabled, isTrue);
    await tester.enterText(emailField, 'new@example.test');
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['email'], 'new@example.test');
  });

  testWidgets('local user cannot edit email for a linked contact', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      contacts: [
        _contact(email: 'linked@example.test', userAccessId: _assignmentId),
      ],
    );
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('team-contact-email')),
          )
          .enabled,
      isFalse,
    );
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

  testWidgets('archived contact can be restored from its detail form', (
    tester,
  ) async {
    final gateway = _TeamGateway(contacts: [_contact()]);
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    await _tapAndSettle(tester, find.text('Arquivar contato'));
    await _tapAndSettle(tester, find.text('Confirmar arquivamento'));

    expect(gateway.writes.single.$1, 'set_contact_archived');
    expect(gateway.writes.single.$2['archived'], isTrue);
    expect(gateway.contact(_contactId)['revision'], 5);
    expect(gateway.contact(_contactId)['archived_at'], isNotNull);
    expect(find.text('Contato arquivado'), findsOneWidget);

    await _tapAndSettle(tester, find.byTooltip('Editar contato'));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('team-contact-name')),
          )
          .enabled,
      isFalse,
    );
    final restoreButton = find.widgetWithText(TextButton, 'Restaurar contato');
    expect(restoreButton, findsOneWidget);
    expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
    await _tapAndSettle(tester, restoreButton);
    await _tapAndSettle(tester, find.text('Restaurar contato').last);

    expect(gateway.writes, hasLength(2));
    expect(gateway.writes.last.$1, 'set_contact_archived');
    expect(gateway.writes.last.$2['archived'], isFalse);
    expect(gateway.writes.last.$2['expected_revision'], 5);
    expect(gateway.contact(_contactId)['revision'], 6);
    expect(gateway.contact(_contactId)['archived_at'], isNull);
    expect(find.text('Contato arquivado'), findsNothing);
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

  testWidgets('Team contact form renders at planned responsive viewports', (
    tester,
  ) async {
    for (final (size, textScale, golden) in [
      (const Size(360, 900), 1.0, 'team_lifecycle_360.png'),
      (const Size(768, 900), 1.0, 'team_lifecycle_768.png'),
      (const Size(1440, 900), 1.0, 'team_lifecycle_1440.png'),
      (const Size(360, 900), 2.0, 'team_lifecycle_360_text_200.png'),
    ]) {
      final gateway = _TeamGateway(
        contacts: [
          _contact(name: 'Ana Silva'),
          _contact(id: _otherContactId, name: 'Bia Santos'),
        ],
      );
      await _pumpTeamViewport(
        tester,
        gateway,
        size: size,
        textScale: textScale,
      );
      await _tapAndSettle(tester, find.text('Adicionar contato'));
      expect(find.byType(TeamContactForm), findsOneWidget);
      final saveButton = find.byKey(const ValueKey('team-contact-save'));
      expect(saveButton.hitTestable(), findsOneWidget);
      if (textScale == 2) {
        final selectedRoleLabel = find.descendant(
          of: find.byKey(const ValueKey('team-contact-role')),
          matching: find.text('Sem função'),
        );
        expect(selectedRoleLabel, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile(_teamGoldenPath(golden)),
      );
      await _tapAndSettle(tester, find.text('Cancelar'));
    }
  });

  testWidgets('Team contact form scrolls email above the keyboard', (
    tester,
  ) async {
    await _pumpTeamViewport(
      tester,
      _TeamGateway(),
      size: const Size(360, 900),
      textScale: 2,
    );
    await _tapAndSettle(tester, find.text('Adicionar contato'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final email = find.byKey(const ValueKey('team-contact-email'));
    await tester.ensureVisible(email);
    await tester.showKeyboard(email);
    await tester.pumpAndSettle();

    final usableBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    expect(tester.getBottomRight(email).dy, lessThanOrEqualTo(usableBottom));
    expect(
      find.byKey(const ValueKey('team-contact-save')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

String _teamGoldenPath(String fileName) {
  final captureRoot = Platform.environment['MINISTRY_GOLDEN_CAPTURE_ROOT']
      ?.trim();
  if (captureRoot == null || captureRoot.isEmpty) {
    return 'goldens/$fileName';
  }
  return <String>[captureRoot, 'team', fileName].join(Platform.pathSeparator);
}
