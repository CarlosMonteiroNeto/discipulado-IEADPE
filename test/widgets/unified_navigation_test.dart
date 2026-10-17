import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/routing/router.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';
import 'package:ieadpe_converts/features/ministry/ui/ministry_home_page.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';

void main() {
  testWidgets('campaign grants do not expose ministry navigation', (
    tester,
  ) async {
    final scope = AccessScope(congregationIds: ['campaign']);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildUnifiedTheme(),
        home: AppShell(
          scope: scope,
          currentRoute: '/converts',
          onNavigate: (_) {},
          onSignOut: () {},
          child: const Text('Campaign'),
        ),
      ),
    );
    expect(find.text('Discipulado'), findsNothing);
    expect(routesFor(scope), isNot(contains('/ministry')));
  });

  testWidgets(
    'ministry grant adds ministry navigation within the shared shell',
    (tester) async {
      final scope = AccessScope(ministryCongregationIds: ['ministry']);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildUnifiedTheme(),
          home: AppShell(
            scope: scope,
            currentRoute: '/ministry',
            onNavigate: opened.add,
            onSignOut: () {},
            child: const Text('Área protegida'),
          ),
        ),
      );
      expect(find.text('Discipulado'), findsOneWidget);
      expect(find.text('Alunos'), findsOneWidget);
      await tester.tap(find.text('Alunos').first);
      expect(opened, contains('/ministry/students'));
      expect(find.text('Área protegida'), findsOneWidget);
    },
  );

  test('unified theme retains campaign brand colors and shared surfaces', () {
    final theme = buildUnifiedTheme();
    expect(theme.appBarTheme.backgroundColor, UnifiedColors.brandNavy);
    expect(
      theme.colorScheme.primary,
      ColorScheme.fromSeed(seedColor: UnifiedColors.brandBlue).primary,
    );
    expect(theme.scaffoldBackgroundColor, UnifiedColors.page);
  });

  testWidgets(
    'ministry supervisor must choose one of the server granted scopes',
    (tester) async {
      var selected = '';
      var openedStudents = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MinistryHomePage(
              loadOverview: () async => const {
                'students': 0,
                'classes': 0,
                'open_sessions': 0,
                'through_date': '2026-10-17',
              },
              scopeName: 'Escolha uma congregação',
              availableCongregationIds: const [
                'b2700000-0000-0000-0000-000000000001',
                'b2700000-0000-0000-0000-000000000002',
              ],
              congregationNames: const {
                'b2700000-0000-0000-0000-000000000001': 'Congregação Central',
                'b2700000-0000-0000-0000-000000000002': 'Congregação Norte',
              },
              selectedCongregationId: null,
              onSelectCongregation: (value) => selected = value!,
              scopedActionsEnabled: false,
              onOpenStudents: () => openedStudents = true,
              onOpenClasses: () {},
              onOpenAttendance: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Escolha uma congregação'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Alunos'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Congregação Central').last);
      expect(selected, 'b2700000-0000-0000-0000-000000000001');
      expect(find.text('Congregação Central'), findsOneWidget);
      expect(find.text('b2700000-0000-0000-0000-000000000001'), findsNothing);
      expect(openedStudents, isFalse);
    },
  );

  testWidgets('directory failures expose a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MinistryHomePage(
            loadOverview: () async => const {},
            scopeName: 'Selecione uma congregação',
            scopeError: 'Falha ao carregar o diretório autorizado.',
            onRetryScope: () => retried = true,
            scopedActionsEnabled: false,
            onOpenStudents: null,
            onOpenClasses: null,
            onOpenAttendance: null,
          ),
        ),
      ),
    );
    expect(
      find.text('Falha ao carregar o diretório autorizado.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar carregar novamente'));
    expect(retried, isTrue);
  });
}
