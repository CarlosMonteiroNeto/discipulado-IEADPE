import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_codec.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

const _op = '33333333-3333-4333-8333-333333333333';
const _id = '11111111-1111-4111-8111-111111111111';
const _scope = '22222222-2222-4222-8222-222222222222';
const _person = '44444444-4444-4444-8444-444444444444';
const _sessionCongregationId = '55555555-5555-4555-8555-555555555555';
const _sessionClassId = '66666666-6666-4666-8666-666666666666';
const _sessionId = '77777777-7777-4777-8777-777777777777';
const _sessionOperationId = '88888888-8888-4888-8888-888888888888';

class _RecordedMinistryCall {
  const _RecordedMinistryCall(this.name, this.operationId, this.payload);
  final String name;
  final String operationId;
  final Map<String, Object?> payload;
}

class _ClassSessionGateway implements ReadRpcGateway, MinistryCommandGateway {
  _ClassSessionGateway(this.response);

  final Map<String, dynamic> response;
  final boundary = ProtectedDataBoundary();
  final calls = <_RecordedMinistryCall>[];

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    calls.add(_RecordedMinistryCall(rpc, '', Map.of(parameters)));
    return response;
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    calls.add(_RecordedMinistryCall(command, operationId, Map.of(payload)));
    return {'id': payload['id'], 'revision': 2};
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

Map<String, dynamic> _classSessionWire() => {
  'items': [
    for (final status in ['open', 'finalized', 'canceled'])
      {
        'id': _sessionId,
        'class_id': _sessionClassId,
        'congregation_id': _sessionCongregationId,
        'date': '2099-01-10',
        'topic': null,
        'status': status,
        'revision': 1,
      },
  ],
  'next_cursor': null,
};

Future<void> _respond(HttpRequest request, Object value) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

class _TeacherRetryGateway implements ReadRpcGateway, MinistryCommandGateway {
  @override
  final boundary = ProtectedDataBoundary();

  String email = 'ana@example.test';
  final contactReads = <String>[];
  final operationIds = <String>[];
  final payloads = <Map<String, Object?>>[];
  String? receiptOperationId;
  Map<String, Object?>? receiptPayload;

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    if (rpc != 'ministry_get_contact') throw UnimplementedError(rpc);
    contactReads.add(rpc);
    return {
      'contact': {
        'id': _id,
        'name': 'Ana Silva',
        'normalized_name': 'ana silva',
        'scope': 'congregation',
        'congregation_id': _scope,
        'role_code': 'teacher',
        'phone_e164': '+5511999990000',
        'birth_date': '1982-02-03',
        'email': email,
        'archived_at': null,
        'revision': 4,
        'user_access_id': null,
        'access_linked': false,
        'created_at': '2026-10-19T00:00:00Z',
        'updated_at': '2026-10-19T00:00:00Z',
        'updated_by': _op,
      },
      'access': null,
    };
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    expect(command, 'save_contact');
    operationIds.add(operationId);
    payloads.add(Map<String, Object?>.of(payload));

    if (receiptPayload == null) {
      // Simulate the database committing a receipt before its response is lost.
      receiptOperationId = operationId;
      receiptPayload = Map<String, Object?>.of(payload);
      throw const DataFailure('response_lost');
    }

    if (operationId != receiptOperationId || !_samePayload(payload)) {
      throw const DataFailure('operation_conflict');
    }
    return {'id': _id, 'revision': 5};
  }

  bool _samePayload(Map<String, Object?> payload) {
    final receipt = receiptPayload!;
    return receipt.length == payload.length &&
        receipt.keys.every(
          (key) => payload.containsKey(key) && receipt[key] == payload[key],
        );
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

class _AccessCandidateGateway implements ReadRpcGateway {
  _AccessCandidateGateway(this.response);

  final Map<String, dynamic> response;
  final boundary = ProtectedDataBoundary();
  String? rpc;
  Map<String, Object?>? parameters;

  @override
  String get context => boundary.generation;

  @override
  void ensureCurrent(String context) {
    if (context != this.context) throw const DataFailure('stale');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => MutationResult.applied(
    operationId: operationId,
    value: '22222222-2222-4222-8222-222222222222',
  );

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    this.rpc = rpc;
    this.parameters = Map.of(parameters);
    return response;
  }
}

void main() {
  test('access candidate codec is strict and omits Auth identity', () {
    final page = decodeAccessCandidatePage({
      'items': [
        {
          'id': _id,
          'email': 'pending@example.test',
          'role': AccessRole.direction.wireValue,
          'scope': 'congregation',
          'congregation_id': _scope,
        },
      ],
      'next_cursor': null,
    });
    expect(page.items.single.id, _id);
    expect(page.items.single.email, 'pending@example.test');
    expect(page.items.single.role, AccessRole.direction);
    expect(page.items.single.scope, ContactScope.congregation);
    expect(page.items.single.congregationId, _scope);

    expect(
      () => decodeAccessCandidatePage({
        'items': [
          {
            'id': _id,
            'email': 'pending@example.test',
            'role': AccessRole.direction.wireValue,
            'scope': 'congregation',
            'congregation_id': _scope,
            'user_id': _person,
          },
        ],
        'next_cursor': null,
      }),
      throwsA(isA<MinistryDataException>()),
    );
  });

  test(
    'access candidate repository binds rows to the requested role and scope',
    () async {
      final gateway = _AccessCandidateGateway({
        'items': [],
        'next_cursor': null,
      });
      final repository = MinistryRepository(gateway);
      final page = await repository.listAccessCandidates(
        scope: ContactScope.congregation,
        congregationId: _scope,
        role: AccessRole.direction,
        limit: 25,
      );
      expect(page.items, isEmpty);
      expect(gateway.rpc, 'ministry_list_access_candidates');
      expect(gateway.parameters, {
        'scope': 'congregation',
        'congregation_id': _scope,
        'role': AccessRole.direction.wireValue,
        'limit': 25,
        'cursor': null,
      });
    },
  );

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
    'student and teacher details decode their exact scoped projections',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        if (request.uri.path == '/rest/v1/rpc/ieadpe_ministry_get_student') {
          expect(body, {
            'request': {'congregation_id': _scope, 'student_id': _id},
          });
          await _respond(request, {
            'student': {
              'id': _id,
              'person_id': _person,
              'congregation_id': _scope,
              'name': 'Ana Silva',
              'normalized_name': 'ana silva',
              'phone_e164': '+5511999990000',
              'birth_date': '1990-02-28',
              'address': null,
              'education': 'Médio',
              'marital_status': null,
              'new_convert': false,
              'water_baptized': null,
              'wants_baptism': true,
              'archived_at': null,
              'revision': 3,
              'person_revision': 7,
              'link_state': 'linked',
              'created_at': '2026-10-16T12:00:00Z',
              'updated_at': '2026-10-17T12:00:00Z',
              'updated_by': null,
            },
          });
        } else {
          expect(
            request.uri.path,
            '/rest/v1/rpc/ieadpe_ministry_get_teacher_contact',
          );
          expect(body, {
            'request': {'congregation_id': _scope, 'contact_id': _id},
          });
          await _respond(request, {
            'contact': {
              'id': _id,
              'congregation_id': _scope,
              'name': 'Professora Ana',
              'phone_e164': null,
              'birth_date': '1980-04-03',
              'revision': 2,
            },
          });
        }
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

      final student = await repository.getStudent(
        congregationId: _scope,
        studentId: _id,
      );
      final teacher = await repository.getTeacherContact(
        congregationId: _scope,
        contactId: _id,
      );

      expect(student.revision, 3);
      expect(student.personRevision, 7);
      expect(student.name, 'Ana Silva');
      expect(teacher.revision, 2);
      expect(teacher.birthDate.toString(), '1980-04-03');
      expect(
        () => decodeTeacherContactDetail({
          'contact': {
            'id': _id,
            'congregation_id': _scope,
            'name': 'Professora Ana',
            'phone_e164': null,
            'birth_date': null,
            'revision': 2,
            'email': 'unexpected@example.test',
          },
        }),
        throwsA(isA<MinistryDataException>()),
      );
    },
  );

  test('teacher update resubmits current email and birth date, enrollment sends person ID', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      if (request.uri.path == '/rest/v1/rpc/ieadpe_ministry_get_contact') {
        expect(body, {
          'request': {
            'scope': 'congregation',
            'congregation_id': _scope,
            'contact_id': _id,
          },
        });
        await _respond(request, {
          'contact': {
            'id': _id,
            'name': 'Professora Ana',
            'normalized_name': 'professora ana',
            'scope': 'congregation',
            'congregation_id': _scope,
            'role_code': 'teacher',
            'phone_e164': '+5511999990000',
            'birth_date': '1980-04-03',
            'email': 'ana@example.test',
            'archived_at': null,
            'revision': 4,
            'user_access_id': null,
            'access_linked': false,
            'created_at': '2026-10-19T00:00:00Z',
            'updated_at': '2026-10-19T00:00:00Z',
            'updated_by': _op,
          },
          'access': null,
        });
      } else if (request.uri.path ==
          '/rest/v1/rpc/ieadpe_ministry_save_contact') {
        expect(body, {
          'operation_id': _op,
          'payload': {
            'id': _id,
            'scope': 'congregation',
            'congregation_id': _scope,
            'name': 'Professora Ana',
            'role_code': 'teacher',
            'phone_e164': '+5511999990000',
            'birth_date': '1980-04-03',
            'email': 'ana@example.test',
            'expected_revision': 4,
          },
        });
        await _respond(request, {'id': _id, 'revision': 5});
      } else {
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_enroll_student');
        expect(body, {
          'operation_id': _op,
          'payload': {
            'id': _id,
            'congregation_id': _scope,
            'class_id': _id,
            'person_id': _person,
            'start_date': '2026-10-19',
          },
        });
        await _respond(request, {
          'id': _id,
          'student_id': '55555555-5555-4555-8555-555555555555',
          'person_id': _person,
          'revision': 1,
          'student_revision': 3,
        });
      }
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

    final saved = await repository.saveTeacherContact(
      operationId: _op,
      id: _id,
      congregationId: _scope,
      name: 'Professora Ana',
      phoneE164: '+5511999990000',
      birthDate: CalendarDate(1980, 4, 3),
      expectedRevision: 4,
    );
    final enrollment = await repository.enrollStudent(
      operationId: _op,
      id: _id,
      congregationId: _scope,
      classId: _id,
      personId: _person,
      startDate: CalendarDate(2026, 10, 19),
    );
    expect(saved.revision, 5);
    expect(enrollment.personId, _person);
    expect(enrollment.studentRevision, 3);
  });

  test(
    'teacher retry replays the committed payload after email reassignment',
    () async {
      final gateway = _TeacherRetryGateway();
      final repository = MinistryRepository(gateway);

      await expectLater(
        repository.saveTeacherContact(
          operationId: _op,
          id: _id,
          congregationId: _scope,
          name: 'Ana Silva',
          phoneE164: '+5511999990001',
          birthDate: CalendarDate(1982, 2, 3),
          expectedRevision: 4,
        ),
        throwsA(isA<DataFailure>()),
      );

      gateway.email = 'reassigned@example.test';
      final saved = await repository.saveTeacherContact(
        operationId: _op,
        id: _id,
        congregationId: _scope,
        name: 'Ana Silva',
        phoneE164: '+5511999990001',
        birthDate: CalendarDate(1982, 2, 3),
        expectedRevision: 4,
      );

      expect(saved.revision, 5);
      expect(gateway.contactReads, hasLength(1));
      expect(gateway.operationIds, [_op, _op]);
      expect(gateway.payloads[0], {
        'id': _id,
        'scope': 'congregation',
        'congregation_id': _scope,
        'name': 'Ana Silva',
        'role_code': 'teacher',
        'phone_e164': '+5511999990001',
        'birth_date': '1982-02-03',
        'email': 'ana@example.test',
        'expected_revision': 4,
      });
      expect(gateway.payloads[1], gateway.payloads[0]);
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
          'email': null,
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
          'person_id': _person,
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
          'enroll_student' => {
            'id': _id,
            'student_id': '55555555-5555-4555-8555-555555555555',
            'person_id': _person,
            'revision': 2,
            'student_revision': 3,
          },
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

  test('class sessions decode all statuses and future dates', () {
    final wire = _classSessionWire();
    final page = decodeClassSessions(
      wire,
      congregationId: _sessionCongregationId,
      classId: _sessionClassId,
    );
    expect(page.items.map((session) => session.status.wire), [
      'open',
      'finalized',
      'canceled',
    ]);
    expect(page.items.first.date.toString(), '2099-01-10');
    expect(page.items.first.revision, 1);
    expect(page.nextCursor, isNull);
  });

  test('class session topics preserve nullable string values', () async {
    for (final topic in ['', '   ']) {
      final wire = _classSessionWire();
      final item = Map<String, dynamic>.from(
        (wire['items'] as List).first as Map,
      )..['topic'] = topic;
      wire['items'] = [item];
      final repository = MinistryRepository(_ClassSessionGateway(wire));
      final page = await repository.listClassSessions(
        congregationId: _sessionCongregationId,
        classId: _sessionClassId,
      );
      expect(page.items.single.topic, topic);
    }

    final wire = _classSessionWire();
    final item = Map<String, dynamic>.from((wire['items'] as List).first as Map)
      ..['topic'] = 7;
    wire['items'] = [item];
    final repository = MinistryRepository(_ClassSessionGateway(wire));
    await expectLater(
      repository.listClassSessions(
        congregationId: _sessionCongregationId,
        classId: _sessionClassId,
      ),
      throwsA(
        isA<DataFailure>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
  });

  test('class sessions reject foreign item and invalid wire data', () async {
    Map<String, dynamic> responseWith({
      String? id,
      String? congregationId,
      String? classId,
      String? date,
      String? status,
      Object? revision,
      bool includeRevision = true,
      bool addUnexpected = false,
      bool omitCursor = false,
      bool addUnknownPageKey = false,
    }) {
      final item = Map<String, dynamic>.from(
        (_classSessionWire()['items'] as List).first as Map,
      );
      if (id != null) item['id'] = id;
      if (congregationId != null) item['congregation_id'] = congregationId;
      if (classId != null) item['class_id'] = classId;
      if (date != null) item['date'] = date;
      if (status != null) item['status'] = status;
      if (includeRevision) item['revision'] = revision ?? 1;
      if (addUnexpected) item['role'] = 'teacher';
      if (!includeRevision) item.remove('revision');
      final response = <String, dynamic>{
        'items': [item],
      };
      if (!omitCursor) response['next_cursor'] = null;
      if (addUnknownPageKey) response['role'] = 'teacher';
      return response;
    }

    final invalidResponses = [
      responseWith(omitCursor: true),
      responseWith(addUnknownPageKey: true),
      responseWith(addUnexpected: true),
      responseWith(id: 'not-a-uuid'),
      responseWith(congregationId: _scope),
      responseWith(classId: _id),
      responseWith(date: '2099-02-30'),
      responseWith(status: 'scheduled'),
      responseWith(revision: 0),
      responseWith(includeRevision: false),
    ];
    for (final response in invalidResponses) {
      final repository = MinistryRepository(_ClassSessionGateway(response));
      await expectLater(
        repository.listClassSessions(
          congregationId: _sessionCongregationId,
          classId: _sessionClassId,
        ),
        throwsA(
          isA<DataFailure>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    }
  });

  test('session mutations preserve exact envelope', () async {
    final gateway = _ClassSessionGateway(_classSessionWire());
    final repository = MinistryRepository(gateway);
    final calls = gateway.calls;

    await repository.listClassSessions(
      congregationId: _sessionCongregationId,
      classId: _sessionClassId,
    );
    expect(calls.last.name, 'ministry_list_class_sessions');
    expect(calls.last.payload, {
      'congregation_id': _sessionCongregationId,
      'class_id': _sessionClassId,
      'limit': 50,
      'cursor': null,
    });
    await expectLater(
      repository.listClassSessions(
        congregationId: _sessionCongregationId,
        classId: _sessionClassId,
        limit: 101,
      ),
      throwsA(
        isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
      ),
    );
    expect(calls.length, 1);

    await repository.createSession(
      operationId: _sessionOperationId,
      id: _sessionId,
      congregationId: _sessionCongregationId,
      classId: _sessionClassId,
      date: CalendarDate.parse('2026-12-20'),
      topic: null,
    );
    expect(calls.last.name, 'create_session');
    expect(calls.last.operationId, _sessionOperationId);
    expect(calls.last.payload, {
      'id': _sessionId,
      'congregation_id': _sessionCongregationId,
      'class_id': _sessionClassId,
      'date': '2026-12-20',
      'topic': null,
    });

    await repository.cancelSession(
      operationId: _sessionOperationId,
      id: _sessionId,
      congregationId: _sessionCongregationId,
      expectedRevision: 7,
    );
    expect(calls.last.name, 'cancel_session');
    expect(calls.last.operationId, _sessionOperationId);
    expect(calls.last.payload, {
      'id': _sessionId,
      'congregation_id': _sessionCongregationId,
      'expected_revision': 7,
    });
  });
}
