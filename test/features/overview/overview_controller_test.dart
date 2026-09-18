import 'dart:async';

import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/overview/overview_controller.dart';
import 'package:discipulado_ieadpe/features/overview/overview_repository.dart';
import 'package:discipulado_ieadpe/ui/async_content.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overview_test_support.dart';

List<String?> overviewScopes(FakeOverviewGateway gateway) => gateway.invocations
    .where(
      (({String operation, JsonMap payload}) entry) =>
          entry.operation == 'getOverview',
    )
    .map(
      (({String operation, JsonMap payload}) entry) =>
          entry.payload['congregationId'] as String?,
    )
    .toList(growable: false);

void main() {
  test('staff scope is fixed to the assigned congregation', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.setCongregation('c2');

    expect(controller.congregationId, 'c1');
    expect(overviewScopes(gateway), <String?>['c1']);
  });

  test('supervisor may select one congregation or Todas', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: supervisorProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.congregationId, isNull);

    await controller.setCongregation('c2');
    expect(controller.congregationId, 'c2');

    await controller.setCongregation(null);
    expect(controller.congregationId, isNull);
    expect(overviewScopes(gateway), <String?>[null, 'c2', null]);
  });

  test(
    'a stale result from a previous scope cannot replace the new scope',
    () async {
      final FakeOverviewGateway gateway = FakeOverviewGateway();
      final Map<String, Completer<JsonMap>> completers =
          <String, Completer<JsonMap>>{};
      gateway.onInvoke = (String operation, JsonMap payload) {
        if (operation == 'listPendingSessions') {
          return Future<JsonMap>.value(const <String, Object?>{
            'items': <Object?>[],
            'nextCursor': null,
          });
        }
        final String scope = (payload['congregationId'] as String?) ?? 'todas';
        return (completers[scope] ??= Completer<JsonMap>()).future;
      };
      final OverviewController controller = OverviewController(
        repository: OverviewRepository(gateway: gateway),
        profile: supervisorProfile(),
      );
      addTearDown(controller.dispose);

      final Future<void> first = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      final Future<void> second = controller.setCongregation('c2');
      await Future<void>.delayed(Duration.zero);

      completers['c2']!.complete(
        overviewJson(students: 5, classes: 2, openSessions: 1),
      );
      await second;
      completers['todas']!.complete(
        overviewJson(students: 99, classes: 99, openSessions: 99),
      );
      await first;

      expect(controller.counts.data?.students, 5);
      expect(controller.counts.data?.classes, 2);
    },
  );

  test('failure never fabricates zero counts', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => throw const AppFailure(
        code: AppFailureCode.unavailable,
        message: 'Não foi possível carregar a visão geral.',
      );
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.counts.phase, AsyncPhase.error);
    expect(controller.counts.data, isNull);
  });

  test('Atualizar and mutation invalidation re-fetch the counts', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(overviewScopes(gateway), hasLength(1));

    await controller.refresh();
    expect(overviewScopes(gateway), hasLength(2));

    await controller.invalidate();
    expect(overviewScopes(gateway), hasLength(3));
  });

  test('opening pendentes paginates and a scope switch resets it', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (String operation, JsonMap payload) async {
        if (operation == 'getOverview') {
          return overviewJson();
        }
        final String? cursor = payload['cursor'] as String?;
        if (cursor == null) {
          return <String, Object?>{
            'items': <JsonMap>[pendingSessionJson(id: 'x6')],
            'nextCursor': 'cursor-2',
          };
        }
        return <String, Object?>{
          'items': <JsonMap>[pendingSessionJson(id: 'x5', date: '2026-09-18')],
          'nextCursor': null,
        };
      };
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: supervisorProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.togglePending();

    expect(controller.pendingVisible, isTrue);
    expect(
      controller.pending.data?.map((PendingSessionEntry e) => e.id),
      <String>['x6'],
    );
    expect(controller.hasNextPage, isTrue);

    await controller.nextPendingPage();
    expect(
      controller.pending.data?.map((PendingSessionEntry e) => e.id),
      <String>['x5'],
    );
    expect(controller.hasPreviousPage, isTrue);

    await controller.setCongregation('c2');
    expect(controller.hasPreviousPage, isFalse);
    final List<({String operation, JsonMap payload})> pendingCalls = gateway
        .invocations
        .where(
          (({String operation, JsonMap payload}) entry) =>
              entry.operation == 'listPendingSessions',
        )
        .toList(growable: false);
    expect(pendingCalls.last.payload['congregationId'], 'c2');
    expect(pendingCalls.last.payload['cursor'], isNull);
  });

  test('sign-out clears the selected scope and pending visibility', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: supervisorProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.setCongregation('c2');
    await controller.togglePending();
    expect(controller.pendingVisible, isTrue);

    controller.clearSessionData();

    expect(controller.congregationId, isNull);
    expect(controller.pendingVisible, isFalse);
    expect(controller.counts.data, isNull);
  });

  test('OverviewQuery round-trips congregacao and pendentes route state', () {
    const OverviewQuery query = OverviewQuery(
      congregationId: 'c2',
      pending: true,
    );

    expect(query.toQueryParameters(), <String, String>{
      'congregacao': 'c2',
      'pendentes': 'true',
    });

    final OverviewQuery parsed = OverviewQuery.fromQueryParameters(
      query.toQueryParameters(),
    );
    expect(parsed.congregationId, 'c2');
    expect(parsed.pending, isTrue);

    final OverviewQuery empty = OverviewQuery.fromQueryParameters(
      <String, String>{},
    );
    expect(empty.congregationId, isNull);
    expect(empty.pending, isFalse);
    expect(empty.toQueryParameters(), isEmpty);
  });

  test(
    'the exposed pendentes route state drives the pending section',
    () async {
      final FakeOverviewGateway gateway = FakeOverviewGateway()
        ..onInvoke = (String operation, JsonMap payload) async {
          if (operation == 'getOverview') {
            return overviewJson();
          }
          return <String, Object?>{
            'items': <JsonMap>[
              pendingSessionJson(
                id: 'x6',
                congregationId: (payload['congregationId'] as String?) ?? 'c2',
              ),
            ],
            'nextCursor': null,
          };
        };
      final OverviewController controller = OverviewController(
        repository: OverviewRepository(gateway: gateway),
        profile: supervisorProfile(),
        initialQuery: OverviewQuery.fromQueryParameters(<String, String>{
          'congregacao': 'c2',
          'pendentes': 'true',
        }),
      );
      addTearDown(controller.dispose);

      expect(controller.congregationId, 'c2');
      expect(controller.pendingVisible, isTrue);
      expect(controller.query.pending, isTrue);
      expect(controller.toQueryParameters(), <String, String>{
        'congregacao': 'c2',
        'pendentes': 'true',
      });

      await controller.refresh();
      expect(
        controller.pending.data?.map((PendingSessionEntry e) => e.id),
        <String>['x6'],
      );

      await controller.setPendingVisible(false);
      expect(controller.pendingVisible, isFalse);
      expect(controller.toQueryParameters().containsKey('pendentes'), isFalse);

      await controller.togglePending();
      expect(controller.pendingVisible, isTrue);
      expect(controller.toQueryParameters()['pendentes'], 'true');
    },
  );

  test('a failed forward page leaves no phantom previous-page entry', () async {
    bool failForward = true;
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (String operation, JsonMap payload) async {
        if (operation == 'getOverview') {
          return overviewJson();
        }
        if (payload['cursor'] == null) {
          return <String, Object?>{
            'items': <JsonMap>[pendingSessionJson(id: 'x6')],
            'nextCursor': 'cursor-2',
          };
        }
        if (failForward) {
          throw const AppFailure(
            code: AppFailureCode.unavailable,
            message: 'Não foi possível carregar as chamadas pendentes.',
          );
        }
        return <String, Object?>{
          'items': <JsonMap>[pendingSessionJson(id: 'x5', date: '2026-09-18')],
          'nextCursor': null,
        };
      };
    final OverviewController controller = OverviewController(
      repository: OverviewRepository(gateway: gateway),
      profile: supervisorProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.togglePending();
    expect(controller.hasNextPage, isTrue);

    await controller.nextPendingPage();

    expect(controller.hasPreviousPage, isFalse);
    expect(controller.pending.phase, AsyncPhase.error);
    // The forward cursor is retained so the failed page can be retried.
    expect(controller.hasNextPage, isTrue);

    failForward = false;
    await controller.nextPendingPage();

    expect(controller.hasPreviousPage, isTrue);
    expect(
      controller.pending.data?.map((PendingSessionEntry e) => e.id),
      <String>['x5'],
    );
  });
}
