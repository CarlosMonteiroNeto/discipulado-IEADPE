import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _student = '11111111-1111-4111-8111-111111111111';
const _classId = '22222222-2222-4222-8222-222222222222';

Future<void> _respond(HttpRequest request, Object value) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

void main() {
  test(
    'student page sends congregation scope and decodes linked provenance id',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_list_students');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {
            'congregation_id': _scope,
            'name_prefix': 'Ana',
            'limit': 10,
            'cursor': null,
          },
        });
        await _respond(request, {
          'items': [
            {
              'id': _student,
              'name': 'Ana',
              'phone_e164': null,
              'convert_id': '44444444-4444-4444-8444-444444444444',
              'revision': 2,
            },
          ],
          'next_cursor': 'cursor',
        });
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await client.dispose();
        await serving.cancel();
        await server.close(force: true);
      });
      final repo = MinistryBrowserRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      final page = await repo.listStudents(
        congregationId: _scope,
        namePrefix: 'Ana',
        limit: 10,
      );

      expect(page.items.single.convertId, isNotNull);
      expect(page.items.single.revision, 2);
      expect(page.nextCursor, 'cursor');
    },
  );

  test('class page carries status filter and date-only values', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_list_classes');
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'request': {
          'congregation_id': _scope,
          'status': 'active',
          'limit': 20,
          'cursor': null,
        },
      });
      await _respond(request, {
        'items': [
          {
            'id': _classId,
            'name': 'Fundamentos',
            'status': 'active',
            'start_date': '2026-10-01',
            'end_date': null,
            'revision': 1,
          },
        ],
        'next_cursor': null,
      });
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() async {
      await client.dispose();
      await serving.cancel();
      await server.close(force: true);
    });
    final repo = MinistryBrowserRepository(
      SupabaseGateway(client, ProtectedDataBoundary()),
    );

    final page = await repo.listClasses(
      congregationId: _scope,
      status: 'active',
      limit: 20,
    );

    expect(page.items.single.id, _classId);
    expect(page.items.single.startDate, '2026-10-01');
    expect(page.items.single.endDate, isNull);
  });

  test(
    'rejects a class status outside the defined enum before transport',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var calls = 0;
      final serving = server.listen((request) async {
        calls++;
        await _respond(request, {});
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await client.dispose();
        await serving.cancel();
        await server.close(force: true);
      });
      final repo = MinistryBrowserRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      await expectLater(
        repo.listClasses(congregationId: _scope, status: 'everything'),
        throwsA(isA<DataFailure>()),
      );
      expect(calls, 0);
    },
  );
}
