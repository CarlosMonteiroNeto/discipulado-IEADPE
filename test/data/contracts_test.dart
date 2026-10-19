import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/data/access_repository.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

import 'repositories_test.dart' as fixture;

const _accessOperationId = '33333333-3333-4333-8333-333333333333';
const _contactId = '11111111-1111-4111-8111-111111111111';
const _accessScopeId = '22222222-2222-4222-8222-222222222222';
const _assignmentId = '44444444-4444-4444-8444-444444444444';

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
  test('access grant uses the atomic contact and assignment command', () async {
    var calls = 0;
    final gateway = await fixture.fixture((r) async {
      calls++;
      expect(
        r.uri.path,
        '/rest/v1/rpc/ieadpe_ministry_save_contact_with_access',
      );
      expect(jsonDecode(await utf8.decoder.bind(r).join()), {
        'operation_id': _accessOperationId,
        'payload': {
          'id': _contactId,
          'scope': 'congregation',
          'congregation_id': _accessScopeId,
          'name': 'Teacher One',
          'role_code': 'teacher',
          'phone_e164': null,
          'birth_date': null,
          'email': 'synthetic@example.test',
          'access': {
            'user_email': 'synthetic@example.test',
            'role': AccessRole.direction.wireValue,
            'congregation_id': _accessScopeId,
          },
        },
      });
      await fixture.respond(r, {
        'id': _contactId,
        'revision': 1,
        'access_id': _assignmentId,
      });
    });
    final repo = AccessRepository(gateway);
    final result = await repo.saveContactWithAccess(
      operationId: _accessOperationId,
      id: _contactId,
      scope: ContactScope.congregation,
      congregationId: _accessScopeId,
      name: 'Teacher One',
      roleCode: RoleCode.teacher,
      phoneE164: null,
      birthDate: null,
      email: 'synthetic@example.test',
      accessRole: AccessRole.direction,
      accessCongregationId: _accessScopeId,
    );
    expect(result.accessId, _assignmentId);
    expect(calls, 1);
  });
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
  test(
    'access facade rejects a role outside the contact scope before network',
    () async {
      var calls = 0;
      final gateway = await fixture.fixture((r) {
        calls++;
        return fixture.respond(r, {});
      });
      await expectLater(
        AccessRepository(gateway).saveContactWithAccess(
          operationId: _accessOperationId,
          id: _contactId,
          scope: ContactScope.congregation,
          congregationId: _accessScopeId,
          name: 'Teacher One',
          roleCode: RoleCode.teacher,
          phoneE164: null,
          birthDate: null,
          email: 'synthetic@example.test',
          accessRole: AccessRole.supervision,
        ),
        throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'invalid')),
      );
      expect(calls, 0);
    },
  );
}
