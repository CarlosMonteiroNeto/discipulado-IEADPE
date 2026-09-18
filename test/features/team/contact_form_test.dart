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
  testWidgets('an existing contact loads its role preselection', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
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

    expect(find.text('Professor(a) do discipulado'), findsOneWidget);
    final EditableText name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ContactForm.nameFieldKey),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.controller.text, 'Ana Souza');
  });

  testWidgets('submit focuses the first invalid field for keyboard users', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    await pumpApp(
      tester,
      Scaffold(
        body: ContactForm(
          repository: TeamRepository(gateway: gateway),
          config: const ContactFormConfig(
            scope: ContactScope.congregation,
            congregationId: 'c1',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ContactForm.saveKey));
    await tester.pump();

    final EditableText name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ContactForm.nameFieldKey),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.focusNode.hasFocus, isTrue);
    expect(gateway.invocations, isEmpty);
  });

  testWidgets('a conflict preserves inputs and offers a reload', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onInvoke = (String operation, JsonMap payload) {
        throw const AppFailure(
          code: AppFailureCode.conflict,
          message: 'O registro foi alterado por outra pessoa.',
        );
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
            expectedRevision: 3,
            initialName: 'Ana Souza',
            initialRoleCode: RoleCode.teacher,
          ),
        ),
      ),
    );

    final Finder nameEditable = find.descendant(
      of: find.byKey(ContactForm.nameFieldKey),
      matching: find.byType(EditableText),
    );
    await tester.enterText(nameEditable, 'Ana Maria');
    await tester.tap(find.byKey(ContactForm.saveKey));
    await tester.pumpAndSettle();

    final EditableText name = tester.widget<EditableText>(nameEditable);
    expect(name.controller.text, 'Ana Maria');
    expect(find.byKey(ContactForm.conflictKey), findsOneWidget);
    expect(find.byKey(ContactForm.reloadKey), findsOneWidget);
    expect(gateway.invocations, hasLength(1));
  });

  testWidgets(
    'an occupied administrative role shows the holder and cancel sends nothing',
    (WidgetTester tester) async {
      final FakeTeamGateway gateway = FakeTeamGateway();
      gateway.onQuery = (_) => PageResult(
        items: <JsonMap>[
          directoryJson(
            id: 'old',
            name: 'Carlos Lima',
            roleCode: 'congregationAssistant',
          ),
        ],
      );
      gateway.onGet = (_) => contactJson(
        id: 'old',
        name: 'Carlos Lima',
        roleCode: 'congregationAssistant',
        revision: 5,
      );
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
              initialRoleCode: RoleCode.congregationAssistant,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(ContactForm.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('Carlos Lima'), findsOneWidget);
      await tester.tap(find.byKey(RoleReplacementDialog.cancelKey));
      await tester.pumpAndSettle();

      expect(gateway.invocations, isEmpty);
    },
  );
}
