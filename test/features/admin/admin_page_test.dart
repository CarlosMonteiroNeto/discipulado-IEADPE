import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/admin/admin_page.dart';

import 'admin_gateway.dart';

Widget app(
  AdminGateway gateway, {
  Future<void> Function()? refresh,
  AccessScope? scope,
  double scale = 1,
  VoidCallback? openTeam,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: AdminPage(
        scope: scope ?? AccessScope(isSupervision: true),
        gateway: gateway,
        onScopeRefresh: refresh ?? () async {},
        onOpenTeam: openTeam ?? () {},
        reportBuilder: (_) => const Text('Relatório real'),
        eventsBuilder: (_) => const Text('Eventos reais'),
        backupBuilder: (_) => const Text('Backup real'),
      ),
    ),
  ),
);
Future<void> press(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label));
  await t.pumpAndSettle();
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'manager can navigate five injected panels and feedback at 200 percent on narrow screen',
    (t) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final gateway = AdminGateway();
      var feedback = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: AdminPage(
                scope: AccessScope(isSupervision: true),
                gateway: gateway,
                onScopeRefresh: () async {},
                onOpenTeam: () {},
                reportBuilder: (_) => const Text('Relatório real'),
                eventsBuilder: (_) => const Text('Eventos reais'),
                backupBuilder: (_) => const Text('Backup real'),
                onFeedback: () => feedback++,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Congregações'), findsAtLeastNWidgets(1));
      await press(t, 'Relatório');
      expect(find.text('Relatório real'), findsOneWidget);
      await press(t, 'Eventos');
      expect(find.text('Eventos reais'), findsOneWidget);
      await press(t, 'Backup');
      expect(find.text('Backup real'), findsOneWidget);
      await t.tap(find.byTooltip('Gerenciar mensagens'));
      await t.pumpAndSettle();
      expect(feedback, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'uncertain congregation save freezes snapshot and retry reuses operation before scope invalidation',
    (t) async {
      final gateway = AdminGateway()..failure = 'unavailable';
      final initial = gateway.context;
      var refreshed = 0;
      await t.pumpWidget(
        app(
          gateway,
          refresh: () async {
            expect(gateway.context, isNot(initial));
            refreshed++;
          },
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'Nova congregação');
      await t.enterText(find.byType(TextFormField), '  Nova  ');
      await press(t, 'Salvar congregação');
      expect(gateway.operations, hasLength(1));
      expect(gateway.payloads.single, {'name': 'Nova'});
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      gateway.failure = null;
      await press(t, 'Tentar a mesma alteração novamente');
      expect(gateway.operations, [
        gateway.operations.first,
        gateway.operations.first,
      ]);
      expect(refreshed, 1);
      expect(find.text('Nova congregação'), findsNothing);
    },
  );
  testWidgets('archive needs confirmation and preserves canceled operation', (
    t,
  ) async {
    final gateway = AdminGateway();
    await t.pumpWidget(app(gateway));
    await t.pumpAndSettle();
    await press(t, 'Arquivar');
    await press(t, 'Cancelar');
    expect(gateway.commands, isEmpty);
    await press(t, 'Arquivar');
    await t.tap(find.widgetWithText(FilledButton, 'Arquivar'));
    await t.pumpAndSettle();
    expect(gateway.commands, ['archive_congregation']);
    expect(gateway.payloads.single, {'id': catalogId});
  });
  testWidgets(
    'admin without Ministry scope stays in Admin and can refresh access',
    (t) async {
      final gateway = AdminGateway();
      var refreshed = 0;
      var opened = 0;
      await t.pumpWidget(
        app(
          gateway,
          scope: AccessScope(isAdmin: true),
          refresh: () async => refreshed++,
          openTeam: () => opened++,
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'Acessos');
      expect(
        find.text(
          'O servidor não confirmou acesso à equipe. Atualize seu acesso para tentar novamente.',
        ),
        findsOneWidget,
      );
      expect(find.text('Atualizar acesso'), findsOneWidget);
      await press(t, 'Atualizar acesso');
      expect(refreshed, 1);
      expect(opened, 0);
    },
  );
  testWidgets('Admin access tab opens the unified Team workflow', (t) async {
    final gateway = AdminGateway();
    var opened = 0;
    await t.pumpWidget(
      app(
        gateway,
        scope: AccessScope(isSupervision: true, isMinistrySupervision: true),
        openTeam: () => opened++,
      ),
    );
    await t.pumpAndSettle();
    await press(t, 'Acessos');
    expect(find.text('Abrir equipe'), findsOneWidget);
    expect(find.text('Novo acesso'), findsNothing);
    await press(t, 'Abrir equipe');
    expect(opened, 1);
    expect(gateway.commands, isEmpty);
  });
  testWidgets('stale protected read cannot publish former user catalog', (
    t,
  ) async {
    final gateway = AdminGateway()..pendingRead = Completer();
    await t.pumpWidget(app(gateway));
    await t.pump();
    gateway.boundary.invalidate();
    gateway.pendingRead!.complete([
      {'id': catalogId, 'name': 'Private old catalog'},
    ]);
    await t.pumpAndSettle();
    expect(find.text('Private old catalog'), findsNothing);
    expect(find.text('Nova congregação'), findsNothing);
  });
  testWidgets('registrar cannot load or mutate Admin', (t) async {
    final gateway = AdminGateway();
    await t.pumpWidget(app(gateway, scope: AccessScope()));
    await t.pumpAndSettle();
    expect(find.text('Nova congregação'), findsNothing);
    expect(find.text('Novo acesso'), findsNothing);
    expect(gateway.commands, isEmpty);
  });
  testWidgets('confirmation cannot survive protected scope replacement', (
    t,
  ) async {
    final gateway = AdminGateway();
    await t.pumpWidget(app(gateway));
    await t.pumpAndSettle();
    await press(t, 'Arquivar');
    await t.pumpWidget(app(gateway, scope: AccessScope()));
    await t.pumpAndSettle();
    expect(find.text('Arquivar congregação?'), findsNothing);
  });

  testWidgets(
    'equivalent scope rebuild preserves uncertain operation identity',
    (t) async {
      final gateway = AdminGateway()..failure = 'unavailable';
      await t.pumpWidget(app(gateway));
      await t.pumpAndSettle();
      await press(t, 'Nova congregação');
      await t.enterText(find.byType(TextFormField), 'Nova');
      await press(t, 'Salvar congregação');
      final operation = gateway.operations.single;
      await t.pumpWidget(app(gateway));
      await t.pumpAndSettle();
      expect(find.text('Tentar a mesma alteração novamente'), findsOneWidget);
      gateway.failure = null;
      await press(t, 'Tentar a mesma alteração novamente');
      expect(gateway.operations, [operation, operation]);
    },
  );

  testWidgets(
    'late mutation after owner replacement cannot refresh the next user',
    (t) async {
      final gateway = AdminGateway()..pendingMutation = Completer();
      var refreshes = 0;
      await t.pumpWidget(
        app(
          gateway,
          refresh: () async {
            refreshes++;
          },
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'Nova congregação');
      await t.enterText(find.byType(TextFormField), 'Nova');
      await press(t, 'Salvar congregação');
      final replacement = AdminGateway();
      await t.pumpWidget(app(replacement));
      await t.pumpAndSettle();
      gateway.pendingMutation!.complete(
        MutationResult.applied(
          operationId: gateway.operations.single,
          value: catalogId,
        ),
      );
      await t.pumpAndSettle();
      expect(refreshes, 0);
      expect(find.text('Atualizando seu acesso…'), findsNothing);
      expect(find.text('Nova congregação'), findsOneWidget);
    },
  );
  testWidgets(
    'changed scope suppresses a pending write even when caller keeps the gateway',
    (t) async {
      final gateway = AdminGateway()..pendingMutation = Completer();
      var refreshes = 0;
      await t.pumpWidget(
        app(
          gateway,
          refresh: () async {
            refreshes++;
          },
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'Nova congregação');
      await t.enterText(find.byType(TextFormField), 'Nova');
      await press(t, 'Salvar congregação');
      await t.pumpWidget(
        app(
          gateway,
          scope: AccessScope(isAdmin: true),
          refresh: () async {
            refreshes++;
          },
        ),
      );
      await t.pumpAndSettle();
      gateway.pendingMutation!.complete(
        MutationResult.applied(
          operationId: gateway.operations.single,
          value: catalogId,
        ),
      );
      await t.pumpAndSettle();
      expect(refreshes, 0);
      expect(find.text('Nova congregação'), findsOneWidget);
    },
  );
}
