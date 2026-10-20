import 'package:ieadpe_converts/features/backup/backup_repository.dart';
import 'package:ieadpe_converts/features/backup/backup_codec.dart';

import 'import_test.dart' show MemoryProgress;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';

import '../../data/repositories_test.dart'
    show fixture, respond, id, convertProjection, scopeId;

void main() {
  test('actual export traverses records and preserves archived congregation labels', () async {
    var calls = 0;
    final gateway = await fixture((request) async {
      if (request.uri.path.endsWith('/congregations')) {
        await respond(request, [
          {
            'id': scopeId,
            'name': 'Archived synthetic',
            'archived_at': '2020-01-01T00:00:00Z',
          },
        ]);
        return;
      }
      calls++;
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(body['request'] as Map);
      final cursor = payload['cursor'] as String?;
      await respond(request, {
        'items': cursor == null
            ? [for (var i = 1; i <= 100; i++) convertProjection(i)]
            : [convertProjection(101)],
        'next_cursor': cursor == null ? 'opaque-cursor-1' : null,
      });
    });
    final bytes = await BackupRepository(
      gateway,
      MemoryProgress(),
    ).exportBytes();
    final preview = BackupCodec().decode(bytes);
    expect(preview.rows, hasLength(101));
    expect(calls, 2);
    expect(preview.rows.first.congregationName, 'Archived synthetic');
  });

  test(
    'actual SDK retries import with unchanged operation and historical payload',
    () async {
      final envelopes = <Object>[];
      final gateway = await fixture((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_import_convert');
        envelopes.add(
          jsonDecode(await utf8.decoder.bind(request).join()) as Object,
        );
        if (envelopes.length == 1) {
          await respond(request, {
            'code': '40001',
            'message': 'synthetic',
          }, 409);
        } else {
          await respond(request, {
            'id': id(1),
            'status': 'created',
            'warning': null,
          });
        }
      });
      final result = await gateway.importRow(id(2), {
        'internal_id': 'legacy',
        'visit_count': 4,
        'discipleship_start_date': null,
      });
      expect(result['status'], 'created');
      expect(envelopes.length, 2);
      expect(envelopes.first, envelopes.last);
    },
  );
  test(
    'import blocks actor and server identity overrides before transport',
    () async {
      var calls = 0;
      final gateway = await fixture((request) async {
        calls++;
        await respond(request, {'id': id(1), 'status': 'created'});
      });
      await expectLater(
        gateway.importRow(id(2), {
          'internal_id': 'legacy',
          'created_by': id(3),
        }),
        throwsA(isA<DataFailure>()),
      );
      expect(calls, 0);
    },
  );
  test(
    'invalidation suppresses committed import response and further retry',
    () async {
      late SupabaseGateway gateway;
      gateway = await fixture((request) async {
        gateway.boundary.invalidate();
        await respond(request, {'id': id(1), 'status': 'created'});
      });
      await expectLater(
        gateway.importRow(id(2), {'internal_id': 'legacy'}),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
      );
    },
  );
}
