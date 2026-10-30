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
  }) {
    for (final contact in contacts) {
      _contacts[contact['id']! as String] = Map.of(contact);
    }
  }

  final bool globalManager;
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
      throw StateError('manual access candidates are no longer used');
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
        final email = payload['email'];
        _contacts[id] = {
          'id': id,
          'scope': payload['scope'],
          'congregation_id': payload['congregation_id'],
          'name': payload['name'],
          'normalized_name': (payload['name']! as String).toLowerCase(),
          'role_code': payload['role_code'],
          'phone_e164': payload['phone_e164'],
          'birth_date': payload['birth_date'],
          'email': email,
          'archived_at': old?['archived_at'],
          // Access follows the e-mail, exactly like the server-side command.
          'user_access_id': email == null ? null : _assignmentId,
          'revision': revision,
        };
        return _commit(operationId, command, frozen, {
          'id': id,
          'revision': revision,
        });
      case 'set_contact_archived':
        final revision = (old!['revision']! as int) + 1;
        final archived = payload['archived'] == true;
        old['archived_at'] = archived ? '2026-10-19T00:00:00Z' : null;
        old['user_access_id'] = archived || old['email'] == null
            ? null
            : _assignmentId;
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
  List<Congregation> congregations = const [
    Congregation(id: _congregationId, name: 'Congregação Central'),
  ],
  bool canSelectSupervision = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TeamPage(
        repository: MinistryRepository(gateway),
        congregations: congregations,
        canSelectSupervision: canSelectSupervision,
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
        congregations: const [
          Congregation(id: _congregationId, name: 'Congregação Central'),
        ],
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

    expect(find.text('Sem acesso ao app'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Adicionar membro'));
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

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    expect(
      gateway.reads.map((read) => read.$1),
      contains('ministry_get_contact'),
    );
    expect(find.byType(TeamContactForm), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-phone')),
      '(11) 9 9999-0001',
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

    await tester.tap(find.byTooltip('Editar membro'));
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

  testWidgets('editing a linked member exposes no manual access controls', (
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
    await _pumpTeam(tester, gateway, canSelectSupervision: true);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    expect(find.text('Acesso ao aplicativo'), findsNothing);
    expect(find.text('Selecionar vínculo manualmente'), findsNothing);
    expect(find.byKey(const ValueKey('team-access-role')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('team-contact-email')),
          )
          .enabled,
      isTrue,
    );

    await tester.enterText(
      find.byKey(const ValueKey('team-contact-email')),
      'ana.nova@example.test',
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['email'], 'ana.nova@example.test');
    expect(gateway.writes.single.$2, isNot(contains('access')));
  });

  testWidgets('saving an unchanged member synchronizes access', (tester) async {
    final gateway = _TeamGateway(
      contacts: [_contact(email: 'ana@example.test')],
    );
    await _pumpTeam(tester, gateway);
    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    await _tapAndSettle(tester, find.text('Salvar contato'));
    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['email'], 'ana@example.test');
  });

  testWidgets('adding a member with an e-mail grants access in the same save', (
    tester,
  ) async {
    final gateway = _TeamGateway(globalManager: true);
    await _pumpTeam(tester, gateway, canSelectSupervision: true);

    await _tapAndSettle(tester, find.text('Adicionar membro'));
    expect(find.text('Selecionar vínculo manualmente'), findsNothing);
    expect(find.byKey(const ValueKey('team-create-new-access')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-name')),
      'Marcos Lima',
    );
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-email')),
      'marcos@example.test',
    );
    expect(gateway.writes, isEmpty);
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['scope'], 'supervision');
    expect(gateway.writes.single.$2['email'], 'marcos@example.test');
    expect(gateway.writes.single.$2, isNot(contains('access')));
    expect(
      gateway.contact(
        gateway.writes.single.$2['id'] as String,
      )['user_access_id'],
      _assignmentId,
    );
  });

  testWidgets('team scope selector switches between supervision and local', (
    tester,
  ) async {
    final gateway = _TeamGateway(globalManager: true);
    await _pumpTeam(
      tester,
      gateway,
      canSelectSupervision: true,
      congregations: const [
        Congregation(id: _congregationId, name: 'Congregação Central'),
      ],
    );

    expect(find.text('Equipe da supervisão'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('team-scope-selector')), findsOneWidget);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-scope-selector')),
    );
    await _tapAndSettle(
      tester,
      find.textContaining('Congregação Central').last,
    );

    expect(find.text('Equipe local'), findsOneWidget);
    final listing = gateway.reads.last;
    expect(listing.$2['scope'], 'congregation');
    expect(listing.$2['congregation_id'], _congregationId);

    await _tapAndSettle(tester, find.text('Adicionar membro'));
    expect(find.text('Congregação: Congregação Central'), findsOneWidget);
  });

  testWidgets('single-congregation leader goes straight to the local team', (
    tester,
  ) async {
    await _pumpTeam(tester, _TeamGateway());
    expect(find.text('Equipe local'), findsOneWidget);
    expect(find.byKey(const ValueKey('team-scope-selector')), findsNothing);
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
        '(11) 9 9999-0002',
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

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    final phoneField = find.byKey(const ValueKey('team-contact-phone'));
    await tester.enterText(phoneField, '(11) 9 9999-0002');
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('team-contact-save')),
    );

    expect(gateway.contact(_contactId)['revision'], 5);
    expect(
      find.textContaining('Os dados permanecem no formulário'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.descendant(
              of: phoneField,
              matching: find.byType(TextFormField),
            ),
          )
          .enabled,
      isFalse,
    );

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
        '(11) 9 9999-0002',
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('team-contact-save')),
      );

      expect(gateway.contact(_otherContactId)['revision'], 4);
      expect(gateway.contact(_contactId)['revision'], 5);
      final phoneField = find.byKey(const ValueKey('team-contact-phone'));
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: phoneField,
                matching: find.byType(TextFormField),
              ),
            )
            .enabled,
        isFalse,
      );

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

  testWidgets('leader can move a linked member to a new e-mail', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      contacts: [
        _contact(email: 'linked@example.test', userAccessId: _assignmentId),
      ],
    );
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    final emailField = find.byKey(const ValueKey('team-contact-email'));
    expect(tester.widget<TextFormField>(emailField).enabled, isTrue);
    await tester.enterText(emailField, 'novo@example.test');
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['email'], 'novo@example.test');
  });

  testWidgets('clearing the e-mail removes access and keeps the member', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      contacts: [
        _contact(email: 'linked@example.test', userAccessId: _assignmentId),
      ],
    );
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-email')),
      '',
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['email'], isNull);
    expect(gateway.contact(_contactId)['user_access_id'], isNull);
    expect(gateway.contact(_contactId)['archived_at'], isNull);
  });

  testWidgets('inactive member loses access and reactivation restores it', (
    tester,
  ) async {
    final gateway = _TeamGateway(
      globalManager: true,
      contacts: [
        _contact(email: 'ana@example.test', userAccessId: _assignmentId),
      ],
    );
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    await _tapAndSettle(tester, find.text('Marcar como inativo'));
    expect(find.textContaining('perde o acesso ao aplicativo'), findsOneWidget);
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Marcar como inativo'),
    );
    expect(gateway.writes.single.$1, 'set_contact_archived');
    expect(gateway.writes.single.$2['archived'], isTrue);
    expect(gateway.contact(_contactId)['user_access_id'], isNull);
    expect(find.text('Membro inativo'), findsOneWidget);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    await _tapAndSettle(
      tester,
      find.widgetWithText(TextButton, 'Reativar membro'),
    );
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Reativar membro'),
    );

    expect(gateway.writes, hasLength(2));
    expect(gateway.writes.last.$2['archived'], isFalse);
    expect(gateway.contact(_contactId)['user_access_id'], _assignmentId);
    expect(find.text('Membro inativo'), findsNothing);
  });

  testWidgets('inactive member can be reactivated from its detail form', (
    tester,
  ) async {
    final gateway = _TeamGateway(contacts: [_contact()]);
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    await _tapAndSettle(tester, find.text('Marcar como inativo'));
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Marcar como inativo'),
    );

    expect(gateway.writes.single.$1, 'set_contact_archived');
    expect(gateway.writes.single.$2['archived'], isTrue);
    expect(gateway.contact(_contactId)['revision'], 5);
    expect(gateway.contact(_contactId)['archived_at'], isNotNull);
    expect(find.text('Membro inativo'), findsOneWidget);

    await _tapAndSettle(tester, find.byTooltip('Editar membro'));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('team-contact-name')),
          )
          .enabled,
      isFalse,
    );
    expect(
      find.text('Membro inativo · sem acesso ao aplicativo'),
      findsOneWidget,
    );
    final restoreButton = find.widgetWithText(TextButton, 'Reativar membro');
    expect(restoreButton, findsOneWidget);
    expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
    await _tapAndSettle(tester, restoreButton);
    await _tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Reativar membro'),
    );

    expect(gateway.writes, hasLength(2));
    expect(gateway.writes.last.$1, 'set_contact_archived');
    expect(gateway.writes.last.$2['archived'], isFalse);
    expect(gateway.writes.last.$2['expected_revision'], 5);
    expect(gateway.contact(_contactId)['revision'], 6);
    expect(gateway.contact(_contactId)['archived_at'], isNull);
    expect(find.text('Membro inativo'), findsNothing);
  });

  testWidgets('local team uses the same automatic access save', (tester) async {
    final gateway = _TeamGateway();
    await _pumpTeam(tester, gateway);

    await _tapAndSettle(tester, find.text('Adicionar membro'));
    expect(find.text('Selecionar vínculo manualmente'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('team-contact-name')),
      'Joana Nunes',
    );
    await _tapAndSettle(tester, find.text('Salvar contato'));

    expect(gateway.writes.single.$1, 'save_contact');
    expect(gateway.writes.single.$2['scope'], 'congregation');
    expect(gateway.writes.single.$2['congregation_id'], _congregationId);
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
      await _tapAndSettle(tester, find.text('Adicionar membro'));
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
        find.byType(Dialog),
        matchesGoldenFile(_teamGoldenPath(golden)),
      );
      await _tapAndSettle(tester, find.text('Cancelar'));
    }
  });

  testWidgets('Team contact form keeps focused email above the keyboard', (
    tester,
  ) async {
    await _pumpTeamViewport(
      tester,
      _TeamGateway(),
      size: const Size(360, 900),
      textScale: 2,
    );
    await _tapAndSettle(tester, find.text('Adicionar membro'));

    final email = find.byKey(const ValueKey('team-contact-email'));
    await tester.ensureVisible(email);
    await tester.pumpAndSettle();
    await tester.tap(email);
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();

    final usableBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    expect(tester.getBottomRight(email).dy, lessThanOrEqualTo(usableBottom));
    expect(tester.takeException(), isNull);
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
    await _tapAndSettle(tester, find.text('Adicionar membro'));
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
