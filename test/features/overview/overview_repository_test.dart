import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/features/overview/overview_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overview_test_support.dart';

void main() {
  test(
    'getOverview routes to the aggregate callable with the requested scope',
    () async {
      final FakeOverviewGateway gateway = FakeOverviewGateway()
        ..onInvoke = (String operation, JsonMap payload) async {
          expect(operation, 'getOverview');
          return overviewJson(students: 4, classes: 2, openSessions: 1);
        };
      final OverviewRepository repository = OverviewRepository(
        gateway: gateway,
      );

      final OverviewCounts counts = await repository.getOverview(
        congregationId: 'c1',
      );

      expect(counts.students, 4);
      expect(counts.classes, 2);
      expect(counts.openSessions, 1);
      expect(counts.throughDate.toIso8601String(), '2026-09-18');
      expect(gateway.lastPayload('getOverview')['congregationId'], 'c1');
      // The browser never queries Firestore for counts.
      expect(gateway.queries, isEmpty);
    },
  );

  test('getOverview sends a null scope for Todas', () async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewRepository repository = OverviewRepository(gateway: gateway);

    await repository.getOverview();

    expect(gateway.lastPayload('getOverview')['congregationId'], isNull);
  });

  test(
    'listPendingSessions forwards scope, limit and cursor and decodes links',
    () async {
      final FakeOverviewGateway gateway = FakeOverviewGateway()
        ..onInvoke = (String operation, JsonMap payload) async {
          expect(operation, 'listPendingSessions');
          return <String, Object?>{
            'items': <JsonMap>[
              pendingSessionJson(
                id: 'x1',
                classId: 'k1',
                className: 'Turma Central',
                congregationId: 'c1',
                date: '2026-09-17',
                topic: 'Batismo',
              ),
              pendingSessionJson(
                id: 'x6',
                classId: 'k4',
                className: 'Turma Norte',
                congregationId: 'c2',
                date: '2026-09-16',
              ),
            ],
            'nextCursor': 'cursor-2',
          };
        };
      final OverviewRepository repository = OverviewRepository(
        gateway: gateway,
      );

      final PendingSessionPage page = await repository.listPendingSessions(
        congregationId: 'c1',
        limit: 20,
        cursor: 'cursor-1',
      );

      expect(page.items, hasLength(2));
      expect(page.items.first.id, 'x1');
      expect(page.items.first.classId, 'k1');
      expect(page.items.first.className, 'Turma Central');
      expect(page.items.first.congregationId, 'c1');
      expect(page.items.first.date.toIso8601String(), '2026-09-17');
      expect(page.items.last.congregationId, 'c2');
      expect(page.nextCursor, 'cursor-2');

      final JsonMap payload = gateway.lastPayload('listPendingSessions');
      expect(payload['congregationId'], 'c1');
      expect(payload['limit'], 20);
      expect(payload['cursor'], 'cursor-1');
    },
  );
}
