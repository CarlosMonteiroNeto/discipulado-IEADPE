import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

const _scope = '33333333-3333-4333-8333-333333333333';
const _student = '11111111-1111-4111-8111-111111111111';
const _classId = '22222222-2222-4222-8222-222222222222';
const _person = '44444444-4444-4444-8444-444444444444';
const _legacyStudent = '55555555-5555-4555-8555-555555555555';

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
  test(
    'ministry congregation picker sorts all pages with Matriz first',
    () async {
      const next = '55555555-5555-4555-8555-555555555555';
      const secondId = '66666666-6666-4666-8666-666666666666';
      final gateway = _BrowserGateway(
        (rpc, parameters) => parameters['cursor'] == null
            ? {
                'items': [
                  {'id': _scope, 'name': 'Zeta'},
                ],
                'next_cursor': next,
              }
            : {
                'items': [
                  {'id': secondId, 'name': 'Matriz'},
                ],
                'next_cursor': null,
              },
      );
      final pager = MinistryCongregationDirectoryPager(
        MinistryBrowserRepository(gateway),
        sortNames: (names) async => [...names]..sort(),
      );
      final page = await pager.loadFirst();
      expect(page.items.map((item) => item.name), ['Matriz', 'Zeta']);
      expect(gateway.reads, 2);
    },
  );
  test('ordered directory pages stay bounded and can be revisited', () async {
    String id(int number) =>
        '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}';
    final cursors = <Object?>[];
    final gateway = _BrowserGateway((rpc, parameters) {
      cursors.add(parameters['cursor']);
      if (parameters['cursor'] == null) {
        return {
          'items': [
            for (var i = 1; i <= 99; i++)
              {'id': id(i), 'name': 'Local ${i.toString().padLeft(3, '0')}'},
          ],
          'next_cursor': id(99),
        };
      }
      return {
        'items': [
          {'id': id(100), 'name': 'Matriz'},
        ],
        'next_cursor': null,
      };
    });
    final pager = MinistryCongregationDirectoryPager(
      MinistryBrowserRepository(gateway),
      sortNames: (names) async => [...names]..sort(),
    );
    final first = await pager.loadFirst();
    expect(first.items.length, 99);
    expect(first.items.first.name, 'Matriz');
    expect(cursors, [null, id(99)]);
    expect(pager.hasNext, isTrue);
    final second = await pager.next();
    expect(second!.items.single.name, 'Local 099');
    expect(pager.hasPrevious, isTrue);
    final previous = await pager.previous();
    expect(previous!.items.first.name, 'Matriz');
    expect(gateway.reads, 2);
    gateway.boundary.invalidate();
    await expectLater(pager.next(), throwsA(isA<DataFailure>()));
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
    'student page decodes canonical link state and blank phone strings',
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
              'person_id': _person,
              'congregation_id': _scope,
              'name': 'Ana Silva',
              'phone': '   ',
              'birth_date': '1990-02-28',
              'address': {
                'street': 'Rua A',
                'district': null,
                'city': null,
                'postal_code': null,
                'state_code': null,
              },
              'education': 'Ensino médio',
              'marital_status': null,
              'new_convert': false,
              'water_baptized': null,
              'wants_baptism': null,
              'archived_at': null,
              'revision': 7,
              'person_revision': 3,
              'link_state': 'linked',
            },
            {
              'id': _legacyStudent,
              'person_id': null,
              'congregation_id': _scope,
              'name': 'Ana Silva',
              'phone': '',
              'birth_date': null,
              'address': null,
              'education': null,
              'marital_status': null,
              'new_convert': null,
              'water_baptized': null,
              'wants_baptism': null,
              'archived_at': null,
              'revision': 2,
              'person_revision': null,
              'link_state': 'unlinked',
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

      expect(page.items.first.personId, _person);
      expect(page.items.first.personRevision, 3);
      expect(page.items.first.revision, 7);
      expect(page.items.first.linkState, PersonLinkState.linked);
      expect(page.items.first.name, 'Ana Silva');
      expect(page.items.first.phone, '   ');
      expect(page.items.first.address?.street, 'Rua A');
      expect(page.items.last.personId, isNull);
      expect(page.items.last.personRevision, isNull);
      expect(page.items.last.revision, 2);
      expect(page.items.last.linkState, PersonLinkState.unlinked);
      expect(page.items.last.phone, '');
      expect(page.nextCursor, 'cursor');
    },
  );

  test('student page rejects non-string phone values', () async {
    final gateway = _BrowserGateway((rpc, parameters) {
      expect(rpc, 'ministry_list_students');
      return {
        'items': [
          {
            'id': _student,
            'person_id': _person,
            'congregation_id': _scope,
            'name': 'Ana Silva',
            'phone': 123,
            'birth_date': null,
            'address': null,
            'education': null,
            'marital_status': null,
            'new_convert': null,
            'water_baptized': null,
            'wants_baptism': null,
            'archived_at': null,
            'revision': 2,
            'person_revision': 1,
            'link_state': 'linked',
          },
        ],
        'next_cursor': null,
      };
    });
    final repo = MinistryBrowserRepository(gateway);

    await expectLater(
      repo.listStudents(congregationId: _scope),
      throwsA(isA<DataFailure>()),
    );
  });

  test(
    'list_students decoder accepts a legacy canonical name over 200 chars',
    () async {
      final name = List.filled(201, 'A').join();
      final gateway = _BrowserGateway((rpc, parameters) {
        expect(rpc, 'ministry_list_students');
        return {
          'items': [
            {
              'id': _student,
              'person_id': _person,
              'congregation_id': _scope,
              'name': name,
              'phone': null,
              'birth_date': null,
              'address': null,
              'education': null,
              'marital_status': null,
              'new_convert': null,
              'water_baptized': null,
              'wants_baptism': null,
              'archived_at': null,
              'revision': 2,
              'person_revision': 1,
              'link_state': 'linked',
            },
          ],
          'next_cursor': null,
        };
      });

      final page = await MinistryBrowserRepository(gateway)
          .listStudents(congregationId: _scope);

      expect(page.items.single.name, name);
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
            'teacher_contact_id': _person,
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
    expect(page.items.single.teacherContactId, _person);
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
