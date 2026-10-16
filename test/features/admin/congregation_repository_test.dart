import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/admin/congregation_repository.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';

import '../../data/repositories_test.dart' show fixture, respond, id;

void main() {
  test(
    'catalog traverses all 205 bounded UUID pages before presentation',
    () async {
      var requests = 0;
      final gateway = await fixture((r) async {
        requests++;
        expect(r.uri.path, '/rest/v1/congregations');
        expect(r.uri.queryParameters['limit'], '100');
        final after = r.uri.queryParameters['id'];
        final start = after == null ? 1 : int.parse(after.split('-').last) + 1;
        await respond(r, [
          for (var n = start; n < start + 100 && n <= 205; n++)
            {
              'id': id(n),
              'name': 'Sede',
              'archived_at': n == 1 ? '2026-10-01T00:00:00Z' : null,
            },
        ]);
      });
      final result = await CongregationRepository(gateway).list();
      expect(result, hasLength(205));
      expect(result.first.archivedAt, isNotNull);
      expect(result.last.id, id(205));
      expect(requests, 3);
    },
  );
  test(
    'catalog rejects malformed dates rather than publishing partial data',
    () async {
      final gateway = await fixture(
        (r) async => respond(r, [
          {'id': id(1), 'name': 'Sede', 'archived_at': 'wrong'},
        ]),
      );
      await expectLater(
        CongregationRepository(gateway).list(),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    },
  );
  test(
    'catalog command snapshots minimal save and archive envelopes',
    () async {
      final paths = <String>[];
      final payloads = <Object?>[];
      final gateway = await fixture((r) async {
        paths.add(r.uri.path);
        final body = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
        expect(body.keys.toSet(), {'operation_id', 'payload'});
        payloads.add(body['payload']);
        await respond(r, {'id': id(1)});
      });
      final repository = CongregationRepository(gateway);
      await repository.save(id(20), '  Renomeada  ', id: id(1));
      await repository.archive(id(21), id(1));
      expect(paths, [
        '/rest/v1/rpc/ieadpe_save_congregation',
        '/rest/v1/rpc/ieadpe_archive_congregation',
      ]);
      expect(payloads, [
        {'id': id(1), 'name': 'Renomeada'},
        {'id': id(1)},
      ]);
    },
  );
}
