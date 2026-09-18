import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/contact_form.dart';
import 'package:discipulado_ieadpe/features/team/role_replacement_dialog.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'team_test_support.dart';

void main() {
  testWidgets('a save conflict reload refreshes the contact revision', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    int saveAttempts = 0;
    gateway.onInvoke = (String operation, JsonMap payload) {
      if (operation == 'saveContact') {
        saveAttempts++;
        if (saveAttempts == 1) {
          throw const AppFailure(
            code: AppFailureCode.conflict,
            message: 'O registro foi alterado por outra pessoa.',
          );
        }
      }
      return const <String, Object?>{'id': 'ct1', 'revision': 6};
    };
    gateway.onGet = (_) =>
        contactJson(id: 'ct1', name: 'Ana Souza', revision: 5);
    await pumpApp(
      tester,
      Scaffold(
        body: ContactForm(
          repository: TeamRepository(gateway: gateway),
          config: const ContactFormConfig(
            scope: ContactScope.congregation,
            congregationId: 'c1',
            contactId: 'ct1',
            expectedRevision: 3,
            initialName: 'Ana Souza',
            initialRoleCode: RoleCode.teacher,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ContactForm.saveKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ContactForm.conflictKey), findsOneWidget);

    await tester.tap(find.byKey(ContactForm.reloadKey));
    await tester.pumpAndSettle();

    expect(
      gateway.gets.where(
        (RecordLocator locator) => locator.resource == QueryResource.contacts,
      ),
      isNotEmpty,
    );

    await tester.tap(find.byKey(ContactForm.saveKey));
    await tester.pumpAndSettle();

    final List<({String operation, JsonMap payload})> saves = gateway
        .invocations
        .where(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'saveContact',
        )
        .toList(growable: false);
    expect(saves, hasLength(2));
    expect(saves.last.payload['expectedRevision'], 5);
    final EditableText name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ContactForm.nameFieldKey),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.controller.text, 'Ana Souza');
  });

  testWidgets('a replacement conflict reload refreshes both revisions', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    final Map<String, int> revisions = <String, int>{'old': 5, 'ct1': 2};
    int replaceAttempts = 0;
    gateway.onQuery = (_) => const PageResult(
      items: <JsonMap>[
        <String, Object?>{
          'id': 'old',
          'name': 'Carlos Lima',
          'normalizedName': 'carlos lima',
          'scope': 'congregation',
          'roleCode': 'congregationAssistant',
          'congregationId': 'c1',
          'phoneE164': null,
        },
      ],
    );
    gateway.onGet = (RecordLocator locator) {
      if (locator.id == 'old') {
        return contactJson(
          id: 'old',
          name: 'Carlos Lima',
          roleCode: 'congregationAssistant',
          revision: revisions['old']!,
        );
      }
      if (locator.id == 'ct1') {
        return contactJson(
          id: 'ct1',
          name: 'Ana Souza',
          roleCode: 'teacher',
          revision: revisions['ct1']!,
        );
      }
      return null;
    };
    gateway.onInvoke = (String operation, JsonMap payload) {
      if (operation == 'replaceRoleHolder') {
        replaceAttempts++;
        if (replaceAttempts == 1) {
          throw const AppFailure(
            code: AppFailureCode.conflict,
            message: 'O responsável mudou desde o carregamento.',
          );
        }
      }
      return const <String, Object?>{'id': 'ct1', 'revision': 5};
    };
    await pumpApp(
      tester,
      Scaffold(
        body: ContactForm(
          repository: TeamRepository(gateway: gateway),
          config: const ContactFormConfig(
            scope: ContactScope.congregation,
            congregationId: 'c1',
            contactId: 'ct1',
            expectedRevision: 2,
            initialName: 'Ana Souza',
            initialRoleCode: RoleCode.congregationAssistant,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ContactForm.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('Carlos Lima'), findsOneWidget);

    await tester.tap(find.byKey(RoleReplacementDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(find.byKey(RoleReplacementDialog.conflictKey), findsOneWidget);

    revisions['old'] = 7;
    revisions['ct1'] = 4;
    await tester.tap(find.byKey(RoleReplacementDialog.reloadKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RoleReplacementDialog.confirmKey));
    await tester.pumpAndSettle();

    final List<({String operation, JsonMap payload})> replaces = gateway
        .invocations
        .where(
          (({String operation, JsonMap payload}) call) =>
              call.operation == 'replaceRoleHolder',
        )
        .toList(growable: false);
    expect(replaces, hasLength(2));
    expect(replaces.last.payload['previousExpectedRevision'], 7);
    expect(replaces.last.payload['expectedRevision'], 4);
    expect(
      gateway.gets.where((RecordLocator locator) => locator.id == 'old').length,
      greaterThanOrEqualTo(2),
    );
  });
}
