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
Map<String, Object?> convertProjectionRow(int i) => {
  'id': id(i),
  'internal_id': 'legacy-$i',
  'person_id': null,
  'congregation_id': scopeId,
  'landmark': 'Praça',
  'gender': 'female',
  'conversion_date': '2026-10-01',
  'worship_type': '60 - Discipulado',
  'photo_url': null,
  'photo_asset_id': null,
  'age': null,
  'last_visit_date': null,
  'was_visited_once': false,
  'visit_count': 0,
  'is_in_discipleship': false,
  'discipleship_start_date': null,
  'is_discipleship_completed': false,
  'is_deviated': false,
  'created_by': null,
  'created_at': '2026-10-01T12:00:00Z',
  'updated_at': '2026-10-01T12:00:00Z',
  'deleted_at': null,
  'revision': 1,
};
Map<String, Object?> convertProjection(
  int i, {
  Map<String, Object?> convertChanges = const {},
}) => {
  'convert': {...convertProjectionRow(i), ...convertChanges},
  'person': null,
  'person_revision': null,
  'legacy_identity': {'name': 'Pessoa $i', 'phone': null, 'address': null},
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
  test('literal search sends asterisk and regex metacharacters without wildcard aliases', () async {
    final gateway = await fixture((r) async {
      expect(r.uri.queryParameters['name'], r'imatch.A\*%_\\\.\[\]');
      await respond(r, <Object>[]);
    });
    await gateway.read('converts', context: gateway.context, name: r'A*%_\.[]');
  });
  test(
    '1205 scoped rows cross thirteen bounded server pages exactly once',
    () async {
      final requestBodies = <Map<String, dynamic>>[];
      final gateway = await fixture((r) async {
        expect(r.method, 'POST');
        expect(r.uri.path, '/rest/v1/rpc/ieadpe_ministry_list_converts');
        final body = Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(r).join()) as Map,
        );
        requestBodies.add(body);
        final pageNumber = requestBodies.length;
        final expectedCursor = pageNumber == 1
            ? null
            : 'opaque-server-cursor-${pageNumber - 1}';
        expect(body, {
          'request': {
            'congregation_id': scopeId,
            'name_prefix': 'Pessoa',
            'limit': 100,
            'cursor': expectedCursor,
          },
        });
        final start = (pageNumber - 1) * 100 + 1;
        final end = pageNumber == 13 ? 1205 : pageNumber * 100;
        await respond(r, {
          'items': [for (var i = start; i <= end; i++) convertProjection(i)],
          'next_cursor': pageNumber == 13
              ? null
              : 'opaque-server-cursor-$pageNumber',
        });
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
      expect(requestBodies, hasLength(13));
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
      await respond(r, {
        'items': [convertProjection(1)],
        'next_cursor': null,
      });
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
