import 'dart:convert';
import 'dart:async';

import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/weekly/weekly_repository.dart';

import '../../data/repositories_test.dart' show fixture, respond, id;

void main() {
  test(
    'server overview crosses 1205 bounded pages and orders Matriz first',
    () async {
      var requests = 0;
      final gateway = await fixture((r) async {
        expect(r.uri.path, '/rest/v1/rpc/ieadpe_weekly_overview');
        final body = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
        final after = body['after_id'] as String?;
        final start = after == null ? 1 : int.parse(after.split('-').last) + 1;
        expect(body['expected_week'], requests == 0 ? null : '2026-10-05');
        requests++;
        await respond(r, {
          'visible': true,
          'global': true,
          'week_start': '2026-10-05',
          'rows': [
            for (var i = start; i <= 1205 && i < start + 100; i++)
              {
                'id': id(i),
                'name': i == 1205
                    ? 'Matriz'
                    : 'Congregação ${i.toString().padLeft(4, '0')}',
                'confirmed': i.isEven,
              },
          ],
        });
      });
      final overview = await WeeklyRepository(
        gateway,
        sortNames: (names) async => names..sort(),
      ).overview();
      expect(overview.entries, hasLength(1205));
      expect(overview.entries.first.name, 'Matriz');
      expect(overview.isGlobal, isTrue);
      expect(requests, 13);
    },
  );
  test(
    'read RPC retries transient failures with identical bounded parameters',
    () async {
      final bodies = <Object?>[];
      final gateway = await fixture((r) async {
        bodies.add(jsonDecode(await utf8.decoder.bind(r).join()));
        if (bodies.length < 3) {
          await respond(r, {'code': '503', 'message': 'synthetic'}, 503);
          return;
        }
        await respond(r, {
          'visible': false,
          'global': true,
          'week_start': null,
          'rows': [],
        });
      });
      final result = await WeeklyRepository(gateway).overview();
      expect(result.visible, isFalse);
      expect(bodies, hasLength(3));
      for (final body in bodies) {
        expect(body, {'after_id': null, 'expected_week': null});
      }
    },
  );
  test('invalidation suppresses a pending actual SDK read', () async {
    final received = Completer<void>(), release = Completer<void>();
    final gateway = await fixture((r) async {
      received.complete();
      await release.future;
      await respond(r, {
        'visible': true,
        'global': true,
        'week_start': '2026-10-05',
        'rows': [],
      });
    });
    final pending = WeeklyRepository(gateway).overview();
    final assertion = expectLater(
      pending,
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
    );
    await received.future;
    gateway.boundary.invalidate();
    release.complete();
    await assertion;
  });
  test('malformed duplicate or oversized overview pages fail without fabricated rows', () async {
    for (final rows in [
      [
        {'id': id(1), 'name': 'Sede', 'confirmed': false},
        {'id': id(1), 'name': 'Sede', 'confirmed': true},
      ],
      [
        for (var i = 1; i <= 101; i++)
          {'id': id(i), 'name': 'Sede', 'confirmed': false},
      ],
      [
        {'id': id(1), 'name': 'Sede', 'confirmed': 'false'},
      ],
    ]) {
      final gateway = await fixture(
        (r) async => respond(r, {
          'visible': true,
          'global': true,
          'week_start': '2026-10-05',
          'rows': rows,
        }),
      );
      await expectLater(
        WeeklyRepository(gateway).overview(),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    }
  });
  test('server rejects changed scope or week across traversal', () async {
    var calls = 0;
    final gateway = await fixture((r) async {
      calls++;
      await respond(r, {
        'visible': true,
        'global': true,
        'week_start': calls == 1 ? '2026-10-05' : '2026-10-12',
        'rows': calls == 1
            ? [
                for (var i = 1; i <= 100; i++)
                  {'id': id(i), 'name': 'Sede', 'confirmed': false},
              ]
            : [],
      });
    });
    await expectLater(
      WeeklyRepository(gateway).overview(),
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'invalid')),
    );
  });
}
