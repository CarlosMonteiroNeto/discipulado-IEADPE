import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/data/access_repository.dart';
import 'package:ieadpe_converts/domain/models.dart';

import 'repositories_test.dart' as fixture;

void main() {
  test('invalid calendar timestamps and missing state are rejected rather than defaulted', () async {
    for (final change in <Map<String, Object?>>[
      {'created_at': '2026-02-30T00:00:00Z'},
      {'was_visited_once': null},
      {'visit_count': 1.0},
      {'age': 151},
      {'gender': 'unknown'},
      {'conversion_date': '2026-02-30'},
      {'congregation_id': 'legacy-id'},
    ]) {
      final gateway = await fixture.fixture(
        (r) => fixture.respond(r, {
          'items': [fixture.convertProjection(1, convertChanges: change)],
          'next_cursor': null,
        }),
      );
      await expectLater(
        ConvertRepository(gateway).list(const ConvertQuery(), null),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    }
  });
  test(
    'convert cursors are forwarded unchanged and rejected by the server',
    () async {
      const serverCursor = 'opaque/server-issued.cursor:v1?signature=hidden';
      final requests = <Map<String, dynamic>>[];
      final gateway = await fixture.fixture((r) async {
        expect(r.uri.path, '/rest/v1/rpc/ieadpe_ministry_list_converts');
        final body = Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(r).join()) as Map,
        );
        requests.add(body);
        if (requests.length == 1) {
          await fixture.respond(r, {
            'items': [fixture.convertProjection(1)],
            'next_cursor': serverCursor,
          });
        } else {
          await fixture.respond(r, {
            'code': '22023',
            'message': 'invalid_cursor',
          }, 400);
        }
      });
      final repository = ConvertRepository(gateway);
      final page = await repository.list(const ConvertQuery(), null);
      expect(page.nextCursor, serverCursor);
      await expectLater(
        repository.list(const ConvertQuery(name: 'changed'), page.nextCursor),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'invalid')),
      );
      expect(requests, [
        {
          'request': {
            'congregation_id': null,
            'name_prefix': null,
            'limit': 100,
            'cursor': null,
          },
        },
        {
          'request': {
            'congregation_id': null,
            'name_prefix': 'changed',
            'limit': 100,
            'cursor': serverCursor,
          },
        },
      ]);
    },
  );
  test(
    'duplicate or unordered page fails instead of skipping records',
    () async {
      for (final items in <List<Map<String, Object?>>>[
        [fixture.convertProjection(2), fixture.convertProjection(1)],
        [fixture.convertProjection(1), fixture.convertProjection(1)],
      ]) {
        final gateway = await fixture.fixture(
          (r) => fixture.respond(r, {'items': items, 'next_cursor': null}),
        );
        await expectLater(
          ConvertRepository(gateway).list(const ConvertQuery(), null),
          throwsA(
            isA<DataFailure>().having(
              (e) => e.code,
              'code',
              'invalid_response',
            ),
          ),
        );
      }
    },
  );
  test('empty authorized RPC page is successful', () async {
    final gateway = await fixture.fixture(
      (r) => fixture.respond(r, {'items': [], 'next_cursor': null}),
    );
    final page = await ConvertRepository(gateway)
        .list(const ConvertQuery(), null);
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });
  test(
    'invalidation during transient response prevents retry under new scope',
    () async {
      var calls = 0;
      final arrived = Completer<void>();
      final release = Completer<void>();
      final gateway = await fixture.fixture((r) async {
        calls++;
        arrived.complete();
        await release.future;
        await fixture.respond(r, {
          'code': '40001',
          'message': 'serialization',
        }, 409);
      });
      final pending = gateway.command('delete_convert', fixture.operationId, {
        'id': fixture.id(1),
      });
      await arrived.future;
      gateway.boundary.invalidate();
      release.complete();
      final result = await pending;
      expect(result.errorCode, 'stale');
      expect(calls, 1);
    },
  );
  test(
    'access save sends editable fields only and decodes scoped access rows',
    () async {
      var calls = 0;
      final gateway = await fixture.fixture((r) async {
        calls++;
        if (r.method == 'POST') {
          final body = jsonDecode(await utf8.decoder.bind(r).join());
          expect(r.uri.path, '/rest/v1/rpc/ieadpe_save_access');
          expect(body, {
            'operation_id': fixture.operationId,
            'payload': {
              'user_email': 'synthetic@example.test',
              'role': 'Membro da direção da campanha',
              'congregation_id': fixture.scopeId,
            },
          });
          await fixture.respond(r, {'id': fixture.id(1)});
        } else {
          expect(r.uri.path, '/rest/v1/user_access');
          await fixture.respond(r, [
            {
              'id': fixture.id(1),
              'user_email': 'synthetic@example.test',
              'role': 'Membro da direção da campanha',
              'congregation_id': fixture.scopeId,
              'user_id': null,
            },
          ]);
        }
      });
      final repo = AccessRepository(gateway);
      expect(
        (await repo.save(
          fixture.operationId,
          email: ' Synthetic@example.test ',
          role: AccessRole.direction,
          congregationId: fixture.scopeId,
        )).value,
        fixture.id(1),
      );
      expect((await repo.list()).items.single.congregationId, fixture.scopeId);
      expect(calls, 2);
    },
  );
  test('read DTO cannot be sent as editable mutation payload', () async {
    var calls = 0;
    final gateway = await fixture.fixture((r) {
      calls++;
      return fixture.respond(r, {'id': fixture.id(1)});
    });
    await expectLater(
      gateway.command('edit_convert', fixture.operationId, fixture.row(1)),
      throwsA(isA<DataFailure>()),
    );
    expect(calls, 0);
  });
  test('SDK user switch discards outstanding response even before root refresh', () async {
    final received = Completer<void>();
    final release = Completer<void>();
    final gateway = await fixture.fixture((r) async {
      received.complete();
      await release.future;
      await fixture.respond(r, {
        'items': [fixture.convertProjection(1)],
        'next_cursor': null,
      });
    });
    final pending = ConvertRepository(gateway).list(const ConvertQuery(), null);
    final checked = expectLater(
      pending,
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
    );
    await received.future;
    await gateway.client.auth.recoverSession(
      jsonEncode({
        'access_token':
            'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature',
        'token_type': 'bearer',
        'user': {
          'id': fixture.id(99),
          'aud': 'authenticated',
          'created_at': '2026-10-15T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        },
      }),
    );
    release.complete();
    await checked;
  });
  test('malformed minimal mutation result cannot fabricate success', () async {
    for (final response in <Object>[
      {},
      {'id': fixture.id(1), 'name': 'private record'},
      {'id': 'legacy-id'},
      [],
    ]) {
      final gateway = await fixture.fixture(
        (r) => fixture.respond(r, response),
      );
      final result = await gateway.command(
        'delete_convert',
        fixture.operationId,
        {'id': fixture.id(1)},
      );
      expect(result.status, MutationStatus.rejected);
      expect(result.errorCode, 'invalid_response');
    }
  });
  test('invalid access role/scope combination fails strict decoding', () async {
    final gateway = await fixture.fixture(
      (r) => fixture.respond(r, [
        {
          'id': fixture.id(1),
          'user_email': 'synthetic@example.test',
          'role': 'Membro da supervisão das campanhas',
          'congregation_id': fixture.scopeId,
        },
      ]),
    );
    await expectLater(
      AccessRepository(gateway).list(),
      throwsA(
        isA<DataFailure>().having((e) => e.code, 'code', 'invalid_response'),
      ),
    );
  });
}
