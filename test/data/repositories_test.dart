import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/domain/models.dart';

const scopeId = '22222222-2222-2222-2222-222222222222';
const operationId = '33333333-3333-3333-3333-333333333333';
String id(int i) => '11111111-1111-1111-1111-${i.toString().padLeft(12, '0')}';
Map<String, Object?> row(int i) => {
  'id': id(i),
  'internal_id': 'legacy-$i',
  'name': 'Pessoa $i',
  'landmark': 'Praça',
  'gender': 'female',
  'conversion_date': '2026-10-01',
  'worship_type': '60 - Discipulado',
  'congregation_id': scopeId,
  'was_visited_once': false,
  'visit_count': 0,
  'is_in_discipleship': false,
  'is_discipleship_completed': false,
  'is_deviated': false,
  'created_at': '2026-10-01T12:00:00Z',
  'updated_at': '2026-10-01T12:00:00Z',
};
Future<void> respond(HttpRequest r, Object value, [int status = 200]) async {
  r.response.statusCode = status;
  r.response.headers.contentType = ContentType.json;
  r.response.write(jsonEncode(value));
  await r.response.close();
}

Future<SupabaseGateway> fixture(
  Future<void> Function(HttpRequest) handler, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final serving = server.listen(handler);
  final client = SupabaseClient(
    'http://127.0.0.1:${server.port}',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(() async {
    await client.dispose();
    await serving.cancel();
    await server.close(force: true);
  });
  return SupabaseGateway(
    client,
    ProtectedDataBoundary(),
    requestTimeout: timeout,
  );
}

void main() {
  test(
    '1205 scoped rows cross bounded 100-row SDK pages exactly once',
    () async {
      var requests = 0;
      final gateway = await fixture((r) async {
        requests++;
        expect(r.uri.path, '/rest/v1/converts');
        expect(r.uri.queryParameters['limit'], '100');
        expect(r.uri.queryParameters['order'], 'id.asc.nullslast');
        expect(r.uri.queryParameters['deleted_at'], 'is.null');
        expect(r.uri.queryParameters['congregation_id'], 'eq.$scopeId');
        expect(r.uri.queryParameters['name'], 'ilike.%Pessoa%');
        final after = r.uri.queryParameters['id'];
        final start = after == null ? 1 : int.parse(after.split('-').last) + 1;
        await respond(r, [
          for (var i = start; i <= 1205 && i < start + 100; i++) row(i),
        ]);
      });
      final repository = ConvertRepository(gateway);
      final ids = <String>[];
      String? cursor;
      do {
        final page = await repository.list(
          const ConvertQuery(congregationId: scopeId, name: 'Pessoa'),
          cursor,
        );
        ids.addAll(page.items.map((r) => r.id));
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(ids, [for (var i = 1; i <= 1205; i++) id(i)]);
      expect(ids.toSet(), hasLength(1205));
      expect(requests, 13);
    },
  );
  test(
    'transient SQL errors retry exactly three times with unchanged envelope',
    () async {
      final bodies = <Object?>[];
      final gateway = await fixture((r) async {
        expect(r.uri.path, '/rest/v1/rpc/ieadpe_transition_convert');
        bodies.add(jsonDecode(await utf8.decoder.bind(r).join()));
        if (bodies.length < 3) {
          await respond(r, {'code': '40001', 'message': 'serialization'}, 409);
        } else {
          await respond(r, {'id': id(1)});
        }
      });
      final result = await gateway.command('transition_convert', operationId, {
        'id': id(1),
        'action': 'visit',
      });
      expect(result.status, MutationStatus.applied);
      expect(result.value, id(1));
      expect(
        bodies,
        List.filled(3, {
          'operation_id': operationId,
          'payload': {'id': id(1), 'action': 'visit'},
        }),
      );
    },
  );
  test(
    'permission failure is rejected once rather than retried or empty',
    () async {
      var count = 0;
      final gateway = await fixture((r) async {
        count++;
        await respond(r, {
          'code': '42501',
          'message': 'private SQL internals',
        }, 403);
      });
      final result = await gateway.command('delete_convert', operationId, {
        'id': id(1),
      });
      expect(result.status, MutationStatus.rejected);
      expect(result.errorCode, 'permission');
      expect(count, 1);
      await expectLater(
        ConvertRepository(gateway).list(const ConvertQuery(), null),
        throwsA(isA<Exception>()),
      );
      expect(count, 2);
    },
  );
  test('scope invalidation discards outstanding read', () async {
    final received = Completer<void>();
    final release = Completer<void>();
    final gateway = await fixture((r) async {
      received.complete();
      await release.future;
      await respond(r, [row(1)]);
    });
    final pending = ConvertRepository(gateway).list(const ConvertQuery(), null);
    final assertion = expectLater(pending, throwsA(isA<Exception>()));
    await received.future;
    gateway.boundary.invalidate();
    release.complete();
    await assertion;
  });
  test(
    'timeout retries retain operation ID and stop after three attempts',
    () async {
      final ids = <String>[];
      final gateway = await fixture((r) async {
        ids.add(
          (jsonDecode(await utf8.decoder.bind(r).join()) as Map)['operation_id']
              as String,
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await respond(r, {'id': id(1)});
      }, timeout: const Duration(milliseconds: 40));
      final result = await gateway.command('delete_convert', operationId, {
        'id': id(1),
      });
      expect(result.status, MutationStatus.rejected);
      expect(result.errorCode, 'unavailable');
      expect(ids, [operationId, operationId, operationId]);
    },
  );
}
