import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_codec.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';

const _op = '33333333-3333-4333-8333-333333333333';
const _id = '11111111-1111-4111-8111-111111111111';
const _scope = '22222222-2222-4222-8222-222222222222';

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
        'save_student': {'id': _id, 'congregation_id': _scope, 'name': 'A'},
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
      'revision': 1,
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
    expect(active.enrollment.status.name, 'active');
  });
}
