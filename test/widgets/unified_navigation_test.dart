import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/routing/router.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';
import 'package:ieadpe_converts/features/ministry/ui/ministry_home_page.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';

void main() {
  testWidgets('AccessScope without ministry fields hides ministry navigation', (
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
    expect(
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      findsNothing,
    );
    expect(routesFor(scope), isNot(contains('/ministry')));
  });

  testWidgets(
    'direction server scope adds ministry navigation within the shared shell',
    (tester) async {
      final scope = AccessScope(
        congregationIds: ['direction-a'],
        ministryCongregationIds: ['direction-a'],
      );
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
      expect(find.text('Discipulado'), findsNWidgets(2));
      expect(routesFor(scope), contains('/ministry/students'));
      expect(routesFor(scope), isNot(contains('/admin')));
      expect(
        find.byKey(const ValueKey('app-shell-ministry-selector')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('app-shell-ministry-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alunos').last);
      expect(opened, contains('/ministry/students'));
      expect(find.text('Área protegida'), findsOneWidget);
    },
  );

  testWidgets('global server scope keeps the Discipulado selector visible', (
    tester,
  ) async {
    final scope = AccessScope(isAdmin: true, isMinistrySupervision: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildUnifiedTheme(),
        home: AppShell(
          scope: scope,
          currentRoute: '/ministry',
          onNavigate: (_) {},
          onSignOut: () {},
          child: const Text('Área global'),
        ),
      ),
    );

    expect(find.text('Discipulado'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('app-shell-ministry-selector')),
      findsOneWidget,
    );
    expect(routesFor(scope), contains('/admin'));
    expect(routesFor(scope), contains('/ministry/students'));
  });

  test(
    'unified theme uses the readable campaign palette and shared surfaces',
    () {
      final theme = buildUnifiedTheme();
      expect(theme.appBarTheme.backgroundColor, UnifiedColors.brandNavy);
      expect(theme.colorScheme.primary, UnifiedColors.brandNavy);
      expect(theme.colorScheme.secondary, UnifiedColors.brandBlue);
      expect(theme.colorScheme.onSurface, UnifiedColors.text);
      expect(theme.inputDecorationTheme.fillColor, Colors.white);
      expect(theme.scaffoldBackgroundColor, UnifiedColors.page);
    },
  );

  testWidgets('ministry supervision chooses from the server supplied scopes', (
    tester,
  ) async {
    var selected = '';
    String? selectedId;
    var openedStudents = false;
    var requestedNextPage = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: MinistryHomePage(
              loadOverview: () async => const {
                'students': 0,
                'classes': 0,
                'open_sessions': 0,
                'through_date': '2026-10-17',
              },
              scopeName: selectedId == null
                  ? 'Escolha uma congregação'
                  : 'Congregação Central',
              availableCongregationIds: const [
                'b2700000-0000-0000-0000-000000000001',
                'b2700000-0000-0000-0000-000000000002',
              ],
              congregationNames: const {
                'b2700000-0000-0000-0000-000000000001': 'Congregação Central',
                'b2700000-0000-0000-0000-000000000002': 'Congregação Norte',
              },
              selectedCongregationId: selectedId,
              hasNextCongregationPage: true,
              congregationPageNumber: 1,
              onNextCongregationPage: () => requestedNextPage = true,
              onSelectCongregation: (value) => setState(() {
                selected = value!;
                selectedId = value;
              }),
              scopedActionsEnabled: false,
              onOpenStudents: () => openedStudents = true,
              onOpenClasses: () {},
              onOpenAttendance: () {},
            ),
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
    await tester.tap(
      find.byKey(const ValueKey('ministry-congregation-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Congregação Central').last);
    await tester.pumpAndSettle();
    expect(selected, 'b2700000-0000-0000-0000-000000000001');
    expect(find.text('Congregação Central'), findsAtLeastNWidgets(1));
    expect(find.text('b2700000-0000-0000-0000-000000000001'), findsNothing);
    expect(openedStudents, isFalse);
    expect(find.text('Página 1'), findsOneWidget);
    final nextButton = find.widgetWithText(OutlinedButton, 'Próxima');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    expect(requestedNextPage, isTrue);
  });

  testWidgets(
    'ministry congregation selector opens choices and enables both scoped lists',
    (tester) async {
      const centralId = 'b2700000-0000-0000-0000-000000000001';
      const northId = 'b2700000-0000-0000-0000-000000000002';
      String? selectedId;
      var openedStudents = false;
      var openedClasses = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: MinistryHomePage(
                loadOverview: () async => const {},
                scopeName: selectedId == null
                    ? 'Selecione uma congregação'
                    : 'Congregação Central',
                availableCongregationIds: const [centralId, northId],
                congregationNames: const {
                  centralId: 'Congregação Central',
                  northId: 'Congregação Norte',
                },
                selectedCongregationId: selectedId,
                onSelectCongregation: (value) =>
                    setState(() => selectedId = value),
                scopedActionsEnabled: selectedId != null,
                onOpenStudents: () => openedStudents = true,
                onOpenClasses: () => openedClasses = true,
                onOpenAttendance: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Alunos'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Turmas'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('ministry-congregation-selector')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Congregação Norte'), findsOneWidget);

      await tester.tap(find.text('Congregação Central').last);
      await tester.pumpAndSettle();
      expect(selectedId, centralId);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Alunos'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Turmas'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Alunos'))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Turmas'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Alunos'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Turmas'));
      expect(openedStudents, isTrue);
      expect(openedClasses, isTrue);
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
    expect(
      find.text(
        'Nenhuma congregação autorizada está disponível para esta sessão.',
      ),
      findsNothing,
    );
    await tester.tap(find.text('Tentar carregar novamente'));
    expect(retried, isTrue);
  });

  testWidgets('an empty authorized directory explains the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MinistryHomePage(
            loadOverview: () async => const {},
            scopeName: 'Selecione uma congregação',
            scopedActionsEnabled: false,
            onOpenStudents: null,
            onOpenClasses: null,
            onOpenAttendance: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Nenhuma congregação autorizada está disponível para esta sessão.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('paging keeps the selected congregation visible', (tester) async {
    const selectedId = 'b2700000-0000-0000-0000-000000000001';
    const pageTwoId = 'b2700000-0000-0000-0000-000000000002';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MinistryHomePage(
            loadOverview: () async => const {},
            scopeName: 'Congregação Central',
            selectedCongregationId: selectedId,
            availableCongregationIds: const [selectedId, pageTwoId],
            congregationNames: const {
              selectedId: 'Congregação Central',
              pageTwoId: 'Congregação Norte',
            },
            congregationPageNumber: 2,
            hasPreviousCongregationPage: true,
            scopedActionsEnabled: true,
            onSelectCongregation: (_) {},
            onOpenStudents: () {},
            onOpenClasses: () {},
            onOpenAttendance: () {},
          ),
        ),
      ),
    );

    expect(find.text('Congregação Central'), findsAtLeastNWidgets(1));
    expect(find.text('Página 2'), findsOneWidget);
    final selector = find.byKey(
      const ValueKey('ministry-congregation-selector'),
    );
    expect(selector, findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('ministry-congregation-option:$selectedId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('ministry-congregation-option:$pageTwoId')),
      findsOneWidget,
    );
    expect(find.text('Congregação Central'), findsAtLeastNWidgets(1));
  });
}
