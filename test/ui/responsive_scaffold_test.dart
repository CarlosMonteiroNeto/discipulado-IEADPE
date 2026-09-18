import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:discipulado_ieadpe/ui/responsive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

const List<AppNavDestination> _destinations = <AppNavDestination>[
  AppNavDestination(
    label: 'Visão geral',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  AppNavDestination(
    label: 'Equipe',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  AppNavDestination(
    label: 'Alunos',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
];

Widget _shell() => const ResponsiveScaffold(
  title: 'Discipulado',
  destinations: _destinations,
  selectedIndex: 0,
  onDestinationSelected: _noop,
  body: Text('conteúdo principal'),
);

void _noop(int index) {}

void main() {
  group('breakpoint classification', () {
    test('maps widths to the S10 navigation modes', () {
      expect(AppLayout.fromWidth(359), AppLayout.compact);
      expect(AppLayout.fromWidth(600), AppLayout.medium);
      expect(AppLayout.fromWidth(768), AppLayout.medium);
      expect(AppLayout.fromWidth(1023), AppLayout.medium);
      expect(AppLayout.fromWidth(1024), AppLayout.expanded);
      expect(AppLayout.fromWidth(1440), AppLayout.expanded);
    });
  });

  testWidgets('expanded widths keep a persistent navigation area', (
    tester,
  ) async {
    await pumpApp(tester, _shell(), width: 1440);

    expect(find.byKey(ResponsiveScaffold.persistentNavKey), findsOneWidget);
    expect(find.byKey(ResponsiveScaffold.compactNavKey), findsNothing);
    expect(find.byKey(ResponsiveScaffold.openDrawerKey), findsNothing);
    expect(find.text('conteúdo principal'), findsOneWidget);
  });

  testWidgets('medium widths use compact navigation without a drawer trigger', (
    tester,
  ) async {
    await pumpApp(tester, _shell(), width: 768);

    expect(find.byKey(ResponsiveScaffold.compactNavKey), findsOneWidget);
    expect(find.byKey(ResponsiveScaffold.persistentNavKey), findsNothing);
    expect(find.byKey(ResponsiveScaffold.openDrawerKey), findsNothing);
  });

  testWidgets('compact widths expose a drawer navigation', (tester) async {
    await pumpApp(tester, _shell(), width: 360);

    expect(find.byKey(ResponsiveScaffold.openDrawerKey), findsOneWidget);
    expect(find.byKey(ResponsiveScaffold.persistentNavKey), findsNothing);
    expect(find.byKey(ResponsiveScaffold.compactNavKey), findsNothing);

    await tester.tap(find.byKey(ResponsiveScaffold.openDrawerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ResponsiveScaffold.drawerKey), findsOneWidget);
    expect(find.text('Equipe'), findsWidgets);
  });

  testWidgets(
    'compact navigation selects a destination and closes the drawer',
    (tester) async {
      var selected = -1;
      await pumpApp(
        tester,
        ResponsiveScaffold(
          title: 'Discipulado',
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: (index) => selected = index,
          body: const Text('conteúdo principal'),
        ),
        width: 360,
      );

      await tester.tap(find.byKey(ResponsiveScaffold.openDrawerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alunos').last);
      await tester.pumpAndSettle();

      expect(selected, 2);
      expect(find.byKey(ResponsiveScaffold.drawerKey), findsNothing);
    },
  );

  testWidgets('shell reflows at 360, 768 and 1440 with 200% text', (
    tester,
  ) async {
    for (final width in <double>[360, 768, 1440]) {
      await pumpApp(
        tester,
        const ResponsiveScaffold(
          title: 'Discipulado',
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: _noop,
          body: _FormBody(),
        ),
        width: width,
        textScale: 2.0,
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'width $width must not overflow',
      );
      expect(
        find.byKey(ResponsiveScaffold.openDrawerKey),
        width < 600 ? findsOneWidget : findsNothing,
      );
      expect(find.byType(AppButton), findsOneWidget);
    }
  });

  testWidgets('public actions render at every breakpoint', (tester) async {
    for (final width in <double>[1440, 768, 360]) {
      await pumpApp(
        tester,
        ResponsiveScaffold(
          title: 'Discipulado',
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: _noop,
          actions: <Widget>[AppButton(label: 'Atualizar', onPressed: () {})],
          body: const Text('conteúdo principal'),
        ),
        width: width,
      );

      expect(
        find.text('Atualizar'),
        findsOneWidget,
        reason: 'shell action must render at width $width',
      );
      expect(
        find.byKey(ResponsiveScaffold.persistentNavKey),
        width >= 1024 ? findsOneWidget : findsNothing,
      );
    }
  });
}

class _FormBody extends StatelessWidget {
  const _FormBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Formulário de contato',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.x4),
        const AppTextField(label: 'Nome completo'),
        const SizedBox(height: AppSpacing.x4),
        const AppTextField(label: 'Telefone'),
        const SizedBox(height: AppSpacing.x6),
        AppButton(label: 'Salvar contato', onPressed: () {}),
      ],
    );
  }
}
