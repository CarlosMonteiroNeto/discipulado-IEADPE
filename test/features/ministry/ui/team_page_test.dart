import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_contact_form.dart';
import 'package:ieadpe_converts/features/ministry/ui/team_page.dart';

const _scope = '22222222-2222-4222-8222-222222222222';
const _contactId = '11111111-1111-4111-8111-111111111111';

class _TeamGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();
  final reads = <(String, Map<String, Object?>)>[];
  final writes = <(String, Map<String, Object?>)>[];
  Completer<void>? delayContactDetail;

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
    final supervision = parameters['scope'] == 'supervision';
    final contact = {
      'id': _contactId,
      'name': 'Ana Silva',
      'normalized_name': 'ana silva',
      'scope': supervision ? 'supervision' : 'congregation',
      'congregation_id': supervision ? null : _scope,
      'role_code': supervision ? 'campaignSupervisor' : 'teacher',
      'phone_e164': '+5511999990000',
      'birth_date': '1982-02-03',
      'email': 'ana@example.test',
      'archived_at': null,
      'revision': 4,
      'user_access_id': null,
    };
    if (rpc == 'ministry_get_contact') {
      await delayContactDetail?.future;
      return {
        'contact': {
          ...contact,
          'access_linked': contact['user_access_id'] != null,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
          'updated_by': _contactId,
        },
        'access': null,
      };
    }
    return {
      'items': [contact],
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
  testWidgets('congregation team page offers contact creation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TeamPage(
          repository: MinistryRepository(_TeamGateway()),
          congregationId: _scope,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionar contato'), findsOneWidget);
    expect(find.byTooltip('Abrir WhatsApp'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Abrir WhatsApp'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'contact edit loads scoped detail and preserves returned fields',
    (tester) async {
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

      await tester.tap(find.byTooltip('Editar contato'));
      await tester.pumpAndSettle();

      expect(
        gateway.reads.map((read) => read.$1),
        contains('ministry_get_contact'),
      );
      expect(find.text('03/02/1982'), findsOneWidget);
      expect(find.text('Professor(a) do discipulado'), findsNWidgets(2));

      await tester.enterText(
        find.byKey(const ValueKey('team-contact-phone')),
        '(11) 9 9999-0001',
      );
      await tester.tap(find.text('Salvar contato'));
      await tester.pumpAndSettle();

      expect(gateway.writes, hasLength(1));
      final save = gateway.writes.single;
      expect(save.$1, 'save_contact');
      expect(save.$2['phone_e164'], '+5511999990001');
      expect(save.$2['birth_date'], '1982-02-03');
      expect(save.$2['expected_revision'], 4);
      expect(save.$2['email'], 'ana@example.test');
      expect(save.$2['name'], 'Ana Silva');
    },
  );

  testWidgets('late supervision detail does not open after scope changes', (
    tester,
  ) async {
    final gateway = _TeamGateway()..delayContactDetail = Completer<void>();
    final repository = MinistryRepository(gateway);
    await tester.pumpWidget(
      MaterialApp(home: TeamPage(repository: repository, supervision: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar contato'));
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: TeamPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    gateway.delayContactDetail!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(TeamContactForm), findsNothing);
    expect(
      find.text('Selecione uma congregação autorizada para abrir a equipe.'),
      findsOneWidget,
    );
  });
}
