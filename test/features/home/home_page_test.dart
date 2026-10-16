import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/home/home_page.dart';
import 'package:ieadpe_converts/features/home/home_repository.dart';
import 'package:ieadpe_converts/features/weekly/weekly_repository.dart';

import '../weekly/weekly_panel_test.dart' show WeeklyGateway;
import '../converts/list_test.dart' show RowsRepository;

void main() {
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
