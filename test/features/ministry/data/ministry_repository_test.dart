import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_codec.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

const _op = '33333333-3333-4333-8333-333333333333';
const _id = '11111111-1111-4111-8111-111111111111';
const _scope = '22222222-2222-4222-8222-222222222222';
const _person = '44444444-4444-4444-8444-444444444444';

Future<void> _respond(HttpRequest request, Object value) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

void main() {
  test(
    'ministry command uses operation receipt envelope and typed response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_set_student_archived',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': _op,
          'payload': {
            'id': _id,
            'congregation_id': _scope,
            'archived': true,
            'expected_revision': 2,
          },
        });
        await _respond(request, {'id': _id, 'revision': 3});
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );
      final result = await repo.setStudentArchived(
        operationId: _op,
        id: _id,
        congregationId: _scope,
        archived: true,
        expectedRevision: 2,
      );
      expect(result.id, _id);
      expect(result.revision, 3);
    },
  );

  test(
    'student registration sends separate person and academic objects',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_register_student',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': _op,
          'payload': {
            'id': _id,
            'person_id': _person,
            'congregation_id': _scope,
            'person': {
              'name': 'Ana Silva',
              'phone': null,
              'birth_date': '1990-02-28',
              'address': {
                'street': 'Rua A',
                'district': null,
                'city': 'Recife',
                'postal_code': null,
                'state_code': 'PE',
              },
            },
            'academic': {
              'education': 'Médio',
              'marital_status': null,
              'new_convert': false,
              'water_baptized': null,
              'wants_baptism': true,
            },
          },
        });
        await _respond(request, {
          'id': _id,
          'person_id': _person,
          'revision': 1,
          'person_revision': 1,
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      final result = await (repo as dynamic).registerStudent(
        operationId: _op,
        studentId: _id,
        personId: _person,
        congregationId: _scope,
        person: MinistryPersonDraft(
          name: 'Ana Silva',
          phone: null,
          birthDate: CalendarDate(1990, 2, 28),
          address: const Address(
            street: 'Rua A',
            district: null,
            city: 'Recife',
            postalCode: null,
            stateCode: 'PE',
          ),
        ),
        education: 'Médio',
        maritalStatus: null,
        newConvert: false,
        waterBaptized: null,
        wantsBaptism: true,
      );

      expect(result.studentId, _id);
      expect(result.personId, _person);
      expect(result.studentRevision, 1);
      expect(result.personRevision, 1);
    },
  );

  test(
    'person detail decodes every canonical edit field and its revision',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_get_person');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {'congregation_id': _scope, 'person_id': _person},
        });
        await _respond(request, {
          'person': {
            'id': _person,
            'congregation_id': _scope,
            'name': 'Ana Silva',
            'normalized_name': 'ana silva',
            'phone': '+5511999990000',
            'birth_date': '1990-02-28',
            'address': {
              'street': 'Rua A',
              'district': null,
              'city': null,
              'postal_code': null,
              'state_code': null,
            },
            'created_at': '2026-10-16T12:00:00Z',
            'updated_at': '2026-10-16T12:30:00Z',
            'updated_by': null,
          },
          'person_revision': 6,
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      final person = await repo.getPerson(
        congregationId: _scope,
        personId: _person,
      );

      expect(person.id, _person);
      expect(person.revision, 6);
      expect(person.updatedBy, isNull);
      expect(person.phone, '+5511999990000');
      expect(person.birthDate.toString(), '1990-02-28');
      expect(person.address?.street, 'Rua A');
    },
  );

  test(
    'canonical person save sends the exact nested payload and next revision',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_save_person');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': _op,
          'payload': {
            'id': _person,
            'congregation_id': _scope,
            'expected_revision': 4,
            'person': {
              'name': 'Ana Silva',
              'phone': null,
              'birth_date': '1990-02-28',
              'address': {
                'street': 'Rua A',
                'district': null,
                'city': null,
                'postal_code': null,
                'state_code': null,
              },
            },
          },
        });
        await _respond(request, {'id': _person, 'revision': 5});
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      final saved = await repo.savePerson(
        operationId: _op,
        id: _person,
        congregationId: _scope,
        expectedRevision: 4,
        person: MinistryPersonDraft(
          name: 'Ana Silva',
          phone: null,
          birthDate: CalendarDate(1990, 2, 28),
          address: const Address(
            street: 'Rua A',
            district: null,
            city: null,
            postalCode: null,
            stateCode: null,
          ),
        ),
      );

      expect(saved.id, _person);
      expect(saved.revision, 5);
    },
  );

  test(
    'people list sends the exact scoped page request and typed projection',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_list_people');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {
            'congregation_id': _scope,
            'name_prefix': 'Ana',
            'limit': 12,
            'cursor': null,
          },
        });
        await _respond(request, {
          'items': [
            {
              'id': _person,
              'congregation_id': _scope,
              'name': 'Ana Silva',
              'normalized_name': 'ana silva',
              'phone': '+5511999990000',
              'birth_date': '1990-02-28',
              'address': {
                'street': 'Rua A',
                'district': null,
                'city': null,
                'postal_code': null,
                'state_code': null,
              },
              'person_revision': 6,
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      final page = await repo.listPeople(
        congregationId: _scope,
        namePrefix: 'Ana',
        limit: 12,
      );

      expect(page.items.single.id, _person);
      expect(page.items.single.congregationId, _scope);
      expect(page.items.single.revision, 6);
      expect(page.items.single.birthDate.toString(), '1990-02-28');
      expect(page.items.single.address?.street, 'Rua A');
      expect(page.nextCursor, isNull);
    },
  );

  test('ministry list RPCs allow omitted optional parameters', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final serving = server.listen((request) async {
      paths.add(request.uri.path);
      bodies.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
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
    final gateway = SupabaseGateway(client, ProtectedDataBoundary());
    final context = gateway.context;

    expect(
      await gateway.readRpc(
        'ministry_list_people',
        context: context,
        parameters: {'congregation_id': _scope, 'limit': 12},
      ),
      isEmpty,
    );
    expect(
      await gateway.readRpc(
        'ministry_list_students',
        context: context,
        parameters: {'congregation_id': _scope, 'limit': 12},
      ),
      isEmpty,
    );
    expect(
      await gateway.readRpc(
        'ministry_list_class_students',
        context: context,
        parameters: {'congregation_id': _scope, 'class_id': _id, 'limit': 25},
      ),
      isEmpty,
    );

    expect(paths, [
      '/rest/v1/rpc/ieadpe_ministry_list_people',
      '/rest/v1/rpc/ieadpe_ministry_list_students',
      '/rest/v1/rpc/ieadpe_ministry_list_class_students',
    ]);
    expect(bodies, [
      {
        'request': {'congregation_id': _scope, 'limit': 12},
      },
      {
        'request': {'congregation_id': _scope, 'limit': 12},
      },
      {
        'request': {'congregation_id': _scope, 'class_id': _id, 'limit': 25},
      },
    ]);

    final invalidParameters = <String, List<Map<String, Object?>>>{
      'ministry_list_people': [
        {'limit': 12},
        {'congregation_id': _scope},
        {'congregation_id': _scope, 'limit': 12, 'unexpected': true},
      ],
      'ministry_list_students': [
        {'limit': 12},
        {'congregation_id': _scope},
      ],
      'ministry_list_class_students': [
        {'class_id': _id, 'limit': 25},
        {'congregation_id': _scope, 'limit': 25},
        {'congregation_id': _scope, 'class_id': _id},
      ],
    };
    for (final entry in invalidParameters.entries) {
      for (final parameters in entry.value) {
        await expectLater(
          gateway.readRpc(entry.key, context: context, parameters: parameters),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
          ),
        );
      }
    }
  });

  test(
    'student person link sends exact revisions and decodes both results',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_link_student_person',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': _op,
          'payload': {
            'congregation_id': _scope,
            'student_id': _id,
            'person_id': _person,
            'expected_student_revision': 4,
            'expected_person_revision': 2,
          },
        });
        await _respond(request, {
          'student_id': _id,
          'person_id': _person,
          'student_revision': 5,
          'person_revision': 2,
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      final result = await repo.linkStudentPerson(
        operationId: _op,
        congregationId: _scope,
        studentId: _id,
        personId: _person,
        expectedStudentRevision: 4,
        expectedPersonRevision: 2,
      );

      expect(result.studentId, _id);
      expect(result.personId, _person);
      expect(result.studentRevision, 5);
      expect(result.personRevision, 2);
    },
  );

  test(
    'student person link rejects a malformed independent revision result',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        await _respond(request, {
          'student_id': _id,
          'person_id': _person,
          'student_revision': 6,
          'person_revision': 3,
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );

      await expectLater(
        repo.linkStudentPerson(
          operationId: _op,
          congregationId: _scope,
          studentId: _id,
          personId: _person,
          expectedStudentRevision: 4,
          expectedPersonRevision: 2,
        ),
        throwsA(
          isA<DataFailure>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    },
  );

  test(
    'bounded directory read uses request envelope and strict typed rows',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_list_directory');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {
            'scope': 'congregation',
            'congregation_id': _scope,
            'role_code': null,
            'name_prefix': null,
            'limit': 2,
            'cursor': null,
          },
        });
        await _respond(request, {'items': [], 'next_cursor': null});
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
      final repo = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );
      final page = await repo.listDirectory(
        scope: 'congregation',
        congregationId: _scope,
        limit: 2,
      );
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    },
  );

  test('class roster read keeps congregation, class, and page scope', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      expect(
        request.uri.path,
        '/rest/v1/rpc/ieadpe_ministry_list_class_students',
      );
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'request': {
          'congregation_id': _scope,
          'class_id': _id,
          'limit': 25,
          'cursor': null,
        },
      });
      await _respond(request, {'items': [], 'next_cursor': null});
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
    final repo = MinistryRepository(
      SupabaseGateway(client, ProtectedDataBoundary()),
    );

    final page = await repo.listClassStudents(
      congregationId: _scope,
      classId: _id,
      limit: 25,
    );

    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });

  test('unknown operation and unsupported read fail before network', () async {
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
    final gateway = SupabaseGateway(client, ProtectedDataBoundary());
    await expectLater(
      gateway.ministryCommand('drop_all', _op, {}),
      throwsA(isA<DataFailure>()),
    );
    await expectLater(
      gateway.ministryCommand('save_person', _op, {
        'id': _person,
        'congregation_id': _scope,
        'expected_revision': 1,
        'person': {
          'name': 'Ana Silva',
          'phone': null,
          'birth_date': null,
          'address': {
            'street': null,
            'district': null,
            'city': null,
            'postal_code': null,
            'state_code': null,
            'unexpected': 'blocked',
          },
        },
      }),
      throwsA(isA<DataFailure>()),
    );
    await expectLater(
      gateway.readRpc('ministry_unbounded', context: gateway.context),
      throwsA(isA<DataFailure>()),
    );
    await expectLater(
      gateway.readRpc(
        'ministry_get_overview',
        context: gateway.context,
        parameters: {'congregation_id': _scope, 'session_id': _id},
      ),
      throwsA(isA<DataFailure>()),
    );
    await expectLater(
      gateway.readRpc(
        'ministry_get_person',
        context: gateway.context,
        parameters: {
          'congregation_id': _scope,
          'person_id': _person,
          'actor': _id,
        },
      ),
      throwsA(isA<DataFailure>()),
    );
    expect(calls, 0);
  });

  test('ministry gateway rejects unexpected command response fields', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen(
      (request) async => _respond(request, {
        'id': _id,
        'revision': 3,
        'private_phone': '+15555550123',
      }),
    );
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
    final gateway = SupabaseGateway(client, ProtectedDataBoundary());
    await expectLater(
      gateway.ministryCommand('set_student_archived', _op, {
        'id': _id,
        'congregation_id': _scope,
        'archived': true,
        'expected_revision': 2,
      }),
      throwsA(
        isA<DataFailure>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
  });

  test(
    'gateway registers all task 5 command names and rejects extras in payloads',
    () async {
      const commands = <String, Map<String, Object?>>{
        'save_person': {
          'id': _id,
          'congregation_id': _scope,
          'expected_revision': 1,
          'person': {
            'name': 'Ana Silva',
            'phone': '+5511999990000',
            'birth_date': null,
            'address': {
              'street': 'Rua A',
              'district': null,
              'city': null,
              'postal_code': null,
              'state_code': null,
            },
          },
        },
        'save_contact': {
          'id': _id,
          'scope': 'supervision',
          'congregation_id': null,
          'name': 'A',
          'role_code': null,
          'phone_e164': null,
          'birth_date': null,
        },
        'replace_role_holder': {
          'scope': 'supervision',
          'congregation_id': null,
          'role_code': 'teacher',
          'previous_contact_id': _id,
          'previous_expected_revision': 1,
          'id': _id,
          'expected_revision': 1,
        },
        'set_contact_archived': {
          'id': _id,
          'scope': 'supervision',
          'congregation_id': null,
          'archived': true,
          'expected_revision': 1,
        },
        'save_student': {
          'id': _id,
          'congregation_id': _scope,
          'expected_revision': 1,
          'education': 'Médio',
          'marital_status': null,
          'new_convert': false,
          'water_baptized': null,
          'wants_baptism': true,
        },
        'set_student_archived': {
          'id': _id,
          'congregation_id': _scope,
          'archived': true,
          'expected_revision': 1,
        },
        'save_class': {
          'id': _id,
          'congregation_id': _scope,
          'name': 'A',
          'teacher_contact_id': null,
          'start_date': '2026-01-01',
          'end_date': null,
        },
        'set_class_status': {
          'id': _id,
          'congregation_id': _scope,
          'status': 'active',
          'expected_revision': 1,
        },
        'enroll_student': {
          'id': _id,
          'congregation_id': _scope,
          'class_id': _id,
          'student_id': _id,
          'start_date': '2026-01-01',
        },
        'close_enrollment': {
          'id': _id,
          'congregation_id': _scope,
          'status': 'withdrawn',
          'end_date': '2026-01-01',
          'expected_revision': 1,
        },
        'create_session': {
          'id': _id,
          'congregation_id': _scope,
          'class_id': _id,
          'date': '2026-01-01',
          'topic': null,
        },
        'cancel_session': {
          'id': _id,
          'congregation_id': _scope,
          'expected_revision': 1,
        },
        'save_attendance': {
          'congregation_id': _scope,
          'session_id': _id,
          'expected_revision': 1,
          'marks': <String, String>{},
          'finalize': false,
        },
      };
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var calls = 0;
      final serving = server.listen((request) async {
        calls++;
        final command = request.uri.path
            .split('/')
            .last
            .replaceFirst('ieadpe_ministry_', '');
        expect(commands, contains(command));
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        expect(body.keys.toSet(), {'operation_id', 'payload'});
        final response = switch (command) {
          'replace_role_holder' => {
            'id': _id,
            'revision': 2,
            'previous_contact_id': _id,
            'previous_revision': 2,
          },
          'create_session' || 'cancel_session' => {
            'id': _id,
            'revision': 2,
            'status': command == 'create_session' ? 'open' : 'canceled',
          },
          'save_attendance' => {
            'id': _id,
            'revision': 2,
            'status': 'open',
            'roster_frozen': true,
            'attendance_count': 0,
          },
          _ => {'id': _id, 'revision': 2},
        };
        await _respond(request, response);
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
      final gateway = SupabaseGateway(client, ProtectedDataBoundary());
      for (final entry in commands.entries) {
        await gateway.ministryCommand(entry.key, _op, entry.value);
      }
      await expectLater(
        gateway.ministryCommand('save_student', _op, {
          ...commands['save_student']!,
          'name': 'A identidade é editada pelo cadastro canônico.',
        }),
        throwsA(isA<DataFailure>()),
      );
      await expectLater(
        gateway.ministryCommand('not_a_command', _op, {}),
        throwsA(isA<DataFailure>()),
      );
      await expectLater(
        gateway.ministryCommand('save_student', _op, {
          ...commands['save_student']!,
          'is_admin': true,
        }),
        throwsA(isA<DataFailure>()),
      );
      expect(calls, commands.length);
    },
  );

  test('attendance codec binds roster marks to the scoped session', () {
    final value = decodeRoster({
      'session': {
        'id': _id,
        'congregation_id': _scope,
        'revision': 1,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'updated_by': _op,
        'class_id': _id,
        'date': '2026-01-01',
        'topic': null,
        'status': 'open',
        'roster_frozen': true,
        'lesson_index': null,
        'lesson_part': null,
        'lesson_finished': false,
      },
      'roster': [
        {
          'enrollment_id': _id,
          'student_id': _scope,
          'student_name': 'Estudante',
          'status': 'unmarked',
        },
      ],
    });
    expect(value.session.id, _id);
    expect(value.marks.single.sessionId, _id);
    expect(value.marks.single.status.name, 'unmarked');
  });

  test(
    'revoked ministry read remains a permission failure, never an empty page',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        request.response.statusCode = 403;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'code': '42501', 'message': 'denied'}),
        );
        await request.response.close();
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
      final repository = MinistryRepository(
        SupabaseGateway(client, ProtectedDataBoundary()),
      );
      await expectLater(
        repository.listDirectory(scope: 'supervision'),
        throwsA(
          isA<DataFailure>().having(
            (error) => error.code,
            'code',
            'permission',
          ),
        ),
      );
    },
  );

  test('class roster preserves both active and archived student state', () {
    Map<String, Object?> student(String? archivedAt) => {
      'id': _id,
      'congregation_id': _scope,
      'person_id': _person,
      'person_revision': 4,
      'name': 'Estudante',
      'normalized_name': 'estudante',
      'phone_e164': null,
      'birth_date': null,
      'address': null,
      'education': null,
      'marital_status': null,
      'new_convert': null,
      'water_baptized': null,
      'wants_baptism': null,
      'archived_at': archivedAt,
      'revision': 7,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'updated_by': _op,
    };
    Map<String, Object?> enrollment() => {
      'id': _op,
      'congregation_id': _scope,
      'student_id': _id,
      'class_id': _id,
      'start_date': '2026-01-01',
      'end_date': null,
      'status': 'active',
      'revision': 1,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'updated_by': _op,
    };
    final active = decodeClassStudents({
      'items': [
        {'student': student(null), 'enrollment': enrollment()},
      ],
      'next_cursor': null,
    }).items.single;
    final archived = decodeClassStudents({
      'items': [
        {
          'student': student('2026-02-01T00:00:00Z'),
          'enrollment': enrollment(),
        },
      ],
      'next_cursor': null,
    }).items.single;
    expect(active.student.archived, isFalse);
    expect(archived.student.archived, isTrue);
    expect(active.student.personId, _person);
    expect(active.student.personRevision, 4);
    expect(active.student.revision, 7);
    expect(active.enrollment.status.name, 'active');
  });
}
