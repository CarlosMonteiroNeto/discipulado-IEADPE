import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/contact_form.dart';
import 'package:discipulado_ieadpe/features/team/contact_page.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:discipulado_ieadpe/ui/async_content.dart';
import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'team_test_support.dart';

const JsonMap _supervisionEntry = <String, Object?>{
  'id': 'sup1',
  'name': 'Carla Sup',
  'normalizedName': 'carla sup',
  'scope': 'supervision',
  'roleCode': 'campaignSupervisor',
  'congregationId': null,
  'phoneE164': null,
};

JsonMap _supervisionContact({required int revision, bool archived = false}) =>
    contactJson(
      id: 'sup1',
      name: 'Carla Sup',
      scope: 'supervision',
      congregationId: null,
      roleCode: 'campaignSupervisor',
      revision: revision,
      archived: archived,
    );

void main() {
  test(
    'getContact reads a supervision contact without a congregation',
    () async {
      final FakeTeamGateway gateway = FakeTeamGateway()
        ..onGet = (_) => _supervisionContact(revision: 4);
      final TeamRepository repository = TeamRepository(gateway: gateway);

      final Contact? contact = await repository.getContact(
        id: 'sup1',
        scope: ContactScope.supervision,
      );

      expect(contact, isNotNull);
      expect(contact!.revision, 4);
      expect(gateway.gets.single.resource, QueryResource.contacts);
      expect(gateway.gets.single.congregationId, isNull);
    },
  );

  testWidgets('a supervisor archives a supervision contact', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return _supervisionEntry;
      if (locator.resource == QueryResource.contacts) {
        return _supervisionContact(revision: 4);
      }
      return null;
    };
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'sup1',
      'revision': 5,
    };

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: gateway),
        profile: testProfile(role: AccessRole.supervisor, congregationId: null),
        contactId: 'sup1',
      ),
    );

    expect(find.byKey(ContactPage.archiveKey), findsOneWidget);
    await tester.tap(find.byKey(ContactPage.archiveKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'setContactArchived');
    expect(call.payload['scope'], 'supervision');
    expect(call.payload['congregationId'], isNull);
    expect(call.payload['archived'], true);
    expect(call.payload['expectedRevision'], 4);
  });

  testWidgets('a supervisor renames a supervision contact', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return _supervisionEntry;
      if (locator.resource == QueryResource.contacts) {
        return _supervisionContact(revision: 4);
      }
      return null;
    };
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'sup1',
      'revision': 5,
    };

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: gateway),
        profile: testProfile(role: AccessRole.supervisor, congregationId: null),
        contactId: 'sup1',
      ),
    );

    await tester.tap(find.byKey(ContactPage.editKey));
    await tester.pumpAndSettle();
    final Finder nameEditable = find.descendant(
      of: find.byKey(ContactForm.nameFieldKey),
      matching: find.byType(EditableText),
    );
    await tester.enterText(nameEditable, 'Carla Renomeada');
    await tester.tap(find.byKey(ContactForm.saveKey));
    await tester.pumpAndSettle();

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'saveContact');
    expect(call.payload['id'], 'sup1');
    expect(call.payload['scope'], 'supervision');
    expect(call.payload['expectedRevision'], 4);
  });

  testWidgets('a supervisor restores an archived supervision contact', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return null;
      if (locator.resource == QueryResource.contacts) {
        return _supervisionContact(revision: 6, archived: true);
      }
      return null;
    };
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'sup1',
      'revision': 7,
    };

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: gateway),
        profile: testProfile(role: AccessRole.supervisor, congregationId: null),
        contactId: 'sup1',
        scope: ContactScope.supervision,
      ),
    );

    expect(find.byKey(ContactPage.restoreKey), findsOneWidget);
    await tester.tap(find.byKey(ContactPage.restoreKey));
    await tester.pumpAndSettle();

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'setContactArchived');
    expect(call.payload['archived'], false);
    expect(call.payload['expectedRevision'], 6);
  });

  test('a denied supervision read surfaces a safe AppFailure', () async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onGet = (_) => throw const AppFailure(
        code: AppFailureCode.forbidden,
        message: 'Acesso não autorizado',
      );

    await expectLater(
      TeamRepository(gateway: gateway)
          .getContact(id: 'sup1', scope: ContactScope.supervision),
      throwsA(
        isA<AppFailure>().having(
          (AppFailure failure) => failure.code,
          'code',
          AppFailureCode.forbidden,
        ),
      ),
    );
  });

  test('a denied supervision mutation surfaces a safe AppFailure', () async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onInvoke = (_, _) => throw const AppFailure(
        code: AppFailureCode.forbidden,
        message: 'Acesso não autorizado',
      );

    await expectLater(
      TeamRepository(gateway: gateway).setContactArchived(
        id: 'sup1',
        scope: ContactScope.supervision,
        archived: true,
        expectedRevision: 1,
      ),
      throwsA(
        isA<AppFailure>().having(
          (AppFailure failure) => failure.code,
          'code',
          AppFailureCode.forbidden,
        ),
      ),
    );
  });

  testWidgets('a denied read renders the safe forbidden state', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return null;
      throw const AppFailure(
        code: AppFailureCode.forbidden,
        message: 'Acesso não autorizado',
      );
    };

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: gateway),
        profile: testProfile(
          role: AccessRole.congregationStaff,
          congregationId: null,
        ),
        contactId: 'sup1',
        scope: ContactScope.supervision,
      ),
    );

    expect(find.byKey(AsyncContent.forbiddenKey), findsOneWidget);
  });
}
