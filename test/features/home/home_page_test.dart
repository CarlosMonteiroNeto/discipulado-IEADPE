import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/home/home_page.dart';
import 'package:ieadpe_converts/features/home/home_repository.dart';
import 'package:ieadpe_converts/features/weekly/weekly_panel.dart';
import 'package:ieadpe_converts/features/weekly/weekly_repository.dart';

import '../weekly/weekly_panel_test.dart' show WeeklyGateway;
import '../converts/list_test.dart' show RowsRepository;

void main() {
  for (final external in [false, true]) {
    final trigger = external ? 'external refreshRevision' : 'Home refresh';
    for (final pending in [false, true]) {
      final scenario = pending ? 'pending' : 'recoverably failed';
      testWidgets(
        '$trigger preserves $scenario weekly confirmation identity and blocks overlap',
        (t) async {
          t.view.physicalSize = const Size(360, 600);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final gateway = WeeklyGateway()..failure = 'unavailable';
          if (pending) gateway.pendingMutation = Completer();
          final repository = HomeRepository(RowsRepository(gateway, []));
          final weekly = WeeklyRepository(gateway);
          Future<void> mount(int revision) async {
            await t.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: HomePage(
                    repository: repository,
                    weekly: weekly,
                    onNavigate: (_) {},
                    refreshRevision: revision,
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
          }

          Future<void> press(String label) async {
            await t.scrollUntilVisible(find.text(label), 150);
            await t.pumpAndSettle();
            await t.ensureVisible(find.text(label));
            await t.pumpAndSettle();
            await t.tap(find.text(label));
            await t.pumpAndSettle();
          }

          await mount(0);
          await press('Confirmar sem conversões');
          await press('Confirmar');
          expect(gateway.operations, hasLength(1));
          final originalOperation = gateway.operations.single;
          if (external) {
            await mount(1);
          } else {
            await t.scrollUntilVisible(
              find.byTooltip('Atualizar início'),
              -150,
            );
            await t.tap(find.byTooltip('Atualizar início'));
            await t.pumpAndSettle();
          }
          await t.scrollUntilVisible(find.byType(WeeklyPanel), 150);
          await t.pumpAndSettle();
          if (pending) {
            // Attempt every enabled path a replacement panel would expose.
            if (find.text('Confirmar sem conversões').evaluate().isNotEmpty) {
              await press('Confirmar sem conversões');
            }
            if (find.text('Confirmar').evaluate().isNotEmpty) {
              await press('Confirmar');
            }
            expect(
              gateway.operations,
              hasLength(1),
              reason:
                  'Home refresh must not permit an overlapping confirmation',
            );
            expect(find.text('Confirmando…'), findsOneWidget);
            final response = gateway.pendingMutation!;
            gateway.pendingMutation = null;
            response.complete(
              MutationResult.rejected(
                operationId: originalOperation,
                errorCode: 'unavailable',
              ),
            );
            await t.pumpAndSettle();
          }
          gateway.failure = null;
          if (find.text('Confirmar sem conversões').evaluate().isNotEmpty) {
            await press('Confirmar sem conversões');
          }
          await press('Confirmar');
          expect(gateway.operations, [originalOperation, originalOperation]);
          expect(find.text('Relatório confirmado'), findsOneWidget);
        },
      );
    }
  }
  testWidgets('Home loads metrics and refreshes hidden weekly owner', (
    t,
  ) async {
    final gateway = WeeklyGateway()..visible = false;
    final converts = RowsRepository(gateway, []);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            repository: HomeRepository(converts),
            weekly: WeeklyRepository(gateway),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Sem Conversões na Última Semana'), findsNothing);
    gateway.visible = true;
    await t.tap(find.byTooltip('Atualizar início'));
    await t.pumpAndSettle();
    expect(find.text('Sem Conversões na Última Semana'), findsOneWidget);
  });
}
