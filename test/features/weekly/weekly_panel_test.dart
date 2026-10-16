import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/weekly/weekly_panel.dart';
import 'package:ieadpe_converts/features/weekly/weekly_repository.dart';

const congregationId = '72000000-0000-0000-0000-000000000001';

class WeeklyGateway implements ReadRpcGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  bool visible = true, global = false, confirmed = false;
  String? failure;
  String week = '2026-10-05';
  final operations = <String>[];
  Completer<MutationResult<String>>? pendingMutation;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    if (pending != null) return pending!.future;
    if (failure == 'permission') throw const DataFailure('permission');
    return {
      'visible': visible,
      'global': global,
      'week_start': visible ? week : null,
      'rows': visible
          ? [
              {'id': congregationId, 'name': 'Sede', 'confirmed': confirmed},
            ]
          : [],
    };
  }

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    operations.add(operationId);
    if (pendingMutation != null) return pendingMutation!.future;
    if (failure != null) {
      return MutationResult.rejected(
        operationId: operationId,
        errorCode: failure!,
      );
    }
    confirmed = true;
    return MutationResult.applied(
      operationId: operationId,
      value: congregationId,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) => throw UnimplementedError();
}

Future<void> mount(
  WidgetTester t,
  WeeklyGateway gateway, {
  double scale = 1,
  Future<void> Function()? refresh,
}) async {
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyPanel(
              repository: WeeklyRepository(gateway),
              onScopeRefresh: refresh,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'direction confirmation retries keep operation and render success',
    (t) async {
      final gateway = WeeklyGateway()..failure = 'unavailable';
      await mount(t, gateway);
      expect(
        find.text('Não houve conversões em Sede na última semana'),
        findsOneWidget,
      );
      await t.tap(find.text('Confirmar sem conversões'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(find.textContaining('Não foi possível confirmar'), findsOneWidget);
      gateway.failure = null;
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(gateway.operations.length, 2);
      expect(gateway.operations.toSet(), hasLength(1));
      expect(find.text('Relatório confirmado'), findsOneWidget);
    },
  );
  testWidgets(
    'replacing protected owner suppresses an earlier mutation result',
    (t) async {
      final old = WeeklyGateway()..pendingMutation = Completer();
      await mount(t, old);
      await t.tap(find.text('Confirmar sem conversões'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      await mount(t, WeeklyGateway());
      old.pendingMutation!.complete(
        MutationResult.rejected(
          operationId: old.operations.single,
          errorCode: 'unavailable',
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Não foi possível confirmar'), findsNothing);
      expect(find.text('Confirmar sem conversões'), findsOneWidget);
    },
  );
  testWidgets(
    'refresh into a new server week discards the previous logical operation',
    (t) async {
      final gateway = WeeklyGateway()..failure = 'unavailable';
      await mount(t, gateway);
      await t.tap(find.text('Confirmar sem conversões'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      gateway.week = '2026-10-12';
      await t.tap(find.text('Atualizar relatório'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar sem conversões'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(gateway.operations, hasLength(2));
      expect(gateway.operations.toSet(), hasLength(2));
      expect(find.text('12/10/2026 a 18/10/2026'), findsOneWidget);
    },
  );
  testWidgets(
    'replacement during invalid-result reload suppresses old feedback',
    (t) async {
      final gateway = WeeklyGateway()..failure = 'invalid';
      await mount(t, gateway);
      await t.tap(find.text('Confirmar sem conversões'));
      await t.pumpAndSettle();
      gateway.pending = Completer();
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      await mount(t, WeeklyGateway());
      gateway.pending!.complete({
        'visible': true,
        'global': false,
        'week_start': '2026-10-05',
        'rows': [],
      });
      await t.pumpAndSettle();
      expect(
        find.textContaining('O período ou os dados mudaram'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'direction controls support keyboard at 360px and 200 percent text',
    (t) async {
      t.view.physicalSize = const Size(360, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final gateway = WeeklyGateway();
      await mount(t, gateway, scale: 2);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.textContaining('Você confirma'), findsOneWidget);
      await t.ensureVisible(find.text('Cancelar'));
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(gateway.operations, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('hidden Sunday renders no reporting content', (t) async {
    await mount(t, WeeklyGateway()..visible = false);
    expect(find.textContaining('conversões'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });
  testWidgets(
    'global status at 360px 200 percent text remains keyboard accessible',
    (t) async {
      t.view.physicalSize = const Size(360, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await mount(t, WeeklyGateway()..global = true, scale: 2);
      expect(find.text('Aguardando'), findsOneWidget);
      expect(find.text('Confirmar sem conversões'), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('permission removes records and refreshes scope', (t) async {
    final gateway = WeeklyGateway()..failure = 'permission';
    var refreshed = 0;
    await mount(
      t,
      gateway,
      refresh: () async {
        refreshed++;
      },
    );
    expect(find.text('Sede'), findsNothing);
    expect(find.textContaining('Seu acesso mudou'), findsOneWidget);
    expect(refreshed, 1);
  });
  testWidgets('obsolete protected response is never published', (t) async {
    final gateway = WeeklyGateway()..pending = Completer();
    await t.pumpWidget(
      MaterialApp(home: WeeklyPanel(repository: WeeklyRepository(gateway))),
    );
    gateway.boundary.invalidate();
    gateway.pending!.complete({
      'visible': true,
      'global': false,
      'week_start': '2026-10-05',
      'rows': [
        {
          'id': congregationId,
          'name': 'Private old record',
          'confirmed': false,
        },
      ],
    });
    await t.pumpAndSettle();
    expect(find.text('Private old record'), findsNothing);
  });
}
