import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/role_replacement_dialog.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'team_test_support.dart';

const RoleReplacementRequest _request = RoleReplacementRequest(
  scope: ContactScope.congregation,
  congregationId: 'c1',
  roleCode: RoleCode.congregationAssistant,
  previousContactId: 'old',
  previousExpectedRevision: 5,
  targetContactId: 'target',
  targetExpectedRevision: 2,
);

Future<void> _openDialog(
  WidgetTester tester,
  FakeTeamGateway gateway, {
  Future<void> Function()? onReload,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (BuildContext context) => AppButton(
          label: 'Substituir',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (BuildContext _) => RoleReplacementDialog(
              repository: TeamRepository(gateway: gateway),
              request: _request,
              roleLabel: RoleCode.congregationAssistant.label,
              holderName: 'Carlos Lima',
              onReload: onReload,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Substituir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the existing holder and cancels without a mutation', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    await _openDialog(tester, gateway);

    expect(find.text('Carlos Lima'), findsOneWidget);
    expect(find.text(RoleCode.congregationAssistant.label), findsOneWidget);

    await tester.tap(find.byKey(RoleReplacementDialog.cancelKey));
    await tester.pumpAndSettle();

    expect(gateway.invocations, isEmpty);
  });

  testWidgets('a conflict preserves the selection and offers reload', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onInvoke = (String operation, JsonMap payload) {
        throw const AppFailure(
          code: AppFailureCode.conflict,
          message: 'O responsável mudou desde o carregamento.',
        );
      };
    bool reloaded = false;
    await _openDialog(tester, gateway, onReload: () async => reloaded = true);

    await tester.tap(find.byKey(RoleReplacementDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(RoleReplacementDialog.conflictKey), findsOneWidget);
    expect(find.byKey(RoleReplacementDialog.reloadKey), findsOneWidget);
    expect(find.text('Carlos Lima'), findsOneWidget);
    expect(gateway.invocations, hasLength(1));
    expect(gateway.invocations.single.operation, 'replaceRoleHolder');

    await tester.tap(find.byKey(RoleReplacementDialog.reloadKey));
    await tester.pumpAndSettle();
    expect(reloaded, isTrue);
  });

  testWidgets('a confirmed replacement sends only replaceRoleHolder', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onInvoke = (String operation, JsonMap payload) =>
          const <String, Object?>{
            'id': 'target',
            'revision': 3,
            'previousContactId': 'old',
            'previousRevision': 6,
          };
    await _openDialog(tester, gateway);

    await tester.tap(find.byKey(RoleReplacementDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(gateway.invocations, hasLength(1));
    expect(gateway.invocations.single.operation, 'replaceRoleHolder');
    expect(gateway.invocations.single.payload['previousContactId'], 'old');
    expect(find.byKey(RoleReplacementDialog.conflictKey), findsNothing);
  });
}
