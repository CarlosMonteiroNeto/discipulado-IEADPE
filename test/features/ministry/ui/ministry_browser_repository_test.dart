import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _student = '11111111-1111-4111-8111-111111111111';
const _classId = '22222222-2222-4222-8222-222222222222';

class _BrowserGateway implements ReadRpcGateway {
  _BrowserGateway(this.respond);
  final Map<String, dynamic> Function(String, Map<String, Object?>) respond;
  @override
  final boundary = ProtectedDataBoundary();
  int reads = 0;
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    reads++;
    return respond(rpc, parameters);
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => throw UnimplementedError();
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

Future<void> _respond(HttpRequest request, Object value) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

void main() {
  test(
    'supervisor congregation picker uses its bounded server projection',
    () async {
      final gateway = _BrowserGateway((rpc, parameters) {
        expect(rpc, 'ministry_list_congregations');
        expect(parameters, {'limit': 100, 'cursor': null});
        return {
          'items': [
            {'id': _scope, 'name': 'Central'},
          ],
          'next_cursor': null,
        };
      });
      final page = await MinistryBrowserRepository(gateway).listCongregations();
      expect(page.items.single.id, _scope);
      expect(page.items.single.name, 'Central');
      expect(gateway.reads, 1);
    },
  );
  test('directory pager loads its next page only when requested', () async {
    const nextCursor = '55555555-5555-4555-8555-555555555555';
    const secondScope = '66666666-6666-4666-8666-666666666666';
    final cursors = <Object?>[];
    final gateway = _BrowserGateway((rpc, parameters) {
      expect(rpc, 'ministry_list_congregations');
      expect(parameters['limit'], MinistryCongregationDirectoryPager.pageSize);
      cursors.add(parameters['cursor']);
      if (parameters['cursor'] == null) {
        return {
          'items': [
            {'id': _scope, 'name': 'Central'},
          ],
          'next_cursor': nextCursor,
        };
      }
      return {
        'items': [
          {'id': secondScope, 'name': 'Norte'},
        ],
        'next_cursor': null,
      };
    });
    final pager = MinistryCongregationDirectoryPager(
      MinistryBrowserRepository(gateway),
    );

    final firstPage = await pager.loadFirst();
    expect(firstPage.items.single.id, _scope);
    expect(gateway.reads, 1);
    expect(cursors, [null]);
    expect(pager.hasNext, isTrue);

    final secondPage = await pager.next();
    expect(secondPage!.items.single.id, secondScope);
    expect(gateway.reads, 2);
    expect(cursors, [null, nextCursor]);
    expect(pager.hasPrevious, isTrue);

    final firstAgain = await pager.previous();
    expect(firstAgain!.items.single.id, _scope);
    expect(gateway.reads, 3);
    expect(cursors, [null, nextCursor, null]);
    expect(pager.hasPrevious, isFalse);
    expect(pager.hasNext, isTrue);
  });
  test('active congregation remains visible beside a bounded next page', () {
    final page = [
      for (var i = 0; i < MinistryCongregationDirectoryPager.pageSize; i++)
        MinistryCongregationChoice(id: 'page-$i', name: 'Page $i'),
    ];
    final visible = visibleCongregationChoices(
      page: page,
      selectedId: 'active-id',
      selectedName: 'Active congregation',
    );
    expect(visible.length, 100);
    expect(visible.first.id, 'active-id');
    expect(visible.first.name, 'Active congregation');
  });
  test('zero page limit is rejected before protected transport', () async {
    final client = SupabaseClient(
      'http://127.0.0.1:1',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final repo = MinistryBrowserRepository(
      SupabaseGateway(client, ProtectedDataBoundary()),
    );

    await expectLater(
      repo.listStudents(congregationId: _scope, limit: 0),
      throwsA(isA<DataFailure>()),
    );
  });

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
