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
      t.view.physicalSize = const Size(360, 800);
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
      expect(find.text('Congregações'), findsOneWidget);
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
    'access grants normalize email and require congregation for direction',
    (t) async {
      final gateway = AdminGateway();
      await t.pumpWidget(app(gateway));
      await t.pumpAndSettle();
      await press(t, 'Acessos');
      await press(t, 'Novo acesso');
      await t.enterText(find.byType(TextFormField), ' USER@Example.Test ');
      await press(t, 'Salvar acesso');
      expect(gateway.commands, isEmpty);
      expect(find.text('Selecione uma congregação ativa.'), findsOneWidget);
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Sede').last);
      await t.pumpAndSettle();
      await press(t, 'Salvar acesso');
      expect(gateway.commands, ['save_access']);
      expect(gateway.payloads.single, {
        'user_email': 'user@example.test',
        'role': 'Membro da direção da campanha',
        'congregation_id': catalogId,
      });
    },
  );
  testWidgets(
    'revoking self invalidates before scope refresh and hides grant records',
    (t) async {
      final gateway = AdminGateway()
        ..accesses = [
          {
            'id': '20000000-0000-0000-0000-000000000001',
            'user_email': 'self@example.test',
            'role': 'Membro da supervisão das campanhas',
            'user_id': '00000000-0000-0000-0000-000000000001',
            'congregation_id': null,
          },
        ];
      final token = gateway.context;
      var refreshed = 0;
      await t.pumpWidget(
        app(
          gateway,
          refresh: () async {
            expect(gateway.context, isNot(token));
            refreshed++;
          },
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'Acessos');
      await press(t, 'Remover');
      await t.tap(find.widgetWithText(FilledButton, 'Remover'));
      await t.pumpAndSettle();
      expect(gateway.commands, ['revoke_access']);
      expect(refreshed, 1);
      expect(find.text('self@example.test'), findsNothing);
    },
  );
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
    'duplicate existing grant offers correction before sending command',
    (t) async {
      final gateway = AdminGateway()
        ..accesses = [
          {
            'id': '20000000-0000-0000-0000-000000000001',
            'user_email': 'existing@example.test',
            'role': 'Membro da direção da campanha',
            'congregation_id': catalogId,
            'user_id': null,
          },
        ];
      await t.pumpWidget(app(gateway));
      await t.pumpAndSettle();
      await press(t, 'Acessos');
      await press(t, 'Novo acesso');
      await t.enterText(find.byType(TextFormField), 'EXISTING@example.test');
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Sede').last);
      await t.pumpAndSettle();
      await press(t, 'Salvar acesso');
      expect(gateway.commands, isEmpty);
      expect(
        find.text(
          'Este usuário já possui este acesso. Confira o cargo e a congregação.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'access editor wraps scaled roles and remains usable at 360 pixels',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final gateway = AdminGateway();
      await t.pumpWidget(app(gateway, scale: 2));
      await t.pumpAndSettle();
      await press(t, 'Acessos');
      await press(t, 'Novo acesso');
      await t.enterText(find.byType(TextFormField), 'supervision@example.test');
      await t.ensureVisible(find.byType(DropdownButtonFormField<AccessRole>));
      await t.tap(find.byType(DropdownButtonFormField<AccessRole>));
      await t.pumpAndSettle();
      await t.tap(find.text('Membro da supervisão das campanhas').last);
      await t.pumpAndSettle();
      await press(t, 'Salvar acesso');
      expect(gateway.payloads.single['congregation_id'], isNull);
      expect(t.takeException(), isNull);
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
