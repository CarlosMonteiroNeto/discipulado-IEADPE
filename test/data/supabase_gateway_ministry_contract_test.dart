import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';

import 'repositories_test.dart' as fixture;

void main() {
  test('teacher contact saves require the nullable email key', () async {
    var requestCount = 0;
    final gateway = await fixture.fixture((request) async {
      requestCount++;
      expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_save_contact');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body, {
        'operation_id': fixture.operationId,
        'payload': {
          'id': fixture.id(1),
          'expected_revision': 4,
          'scope': 'congregation',
          'congregation_id': fixture.scopeId,
          'name': 'Teacher One',
          'role_code': 'teacher',
          'phone_e164': null,
          'birth_date': null,
          'email': null,
        },
      });
      await fixture.respond(request, {'id': fixture.id(1), 'revision': 5});
    });

    final payload = <String, Object?>{
      'id': fixture.id(1),
      'expected_revision': 4,
      'scope': 'congregation',
      'congregation_id': fixture.scopeId,
      'name': 'Teacher One',
      'role_code': 'teacher',
      'phone_e164': null,
      'birth_date': null,
    };
    await expectLater(
      gateway.ministryCommand('save_contact', fixture.operationId, payload),
      throwsA(isA<DataFailure>()),
    );
    expect(requestCount, 0);

    final saved = await gateway.ministryCommand(
      'save_contact',
      fixture.operationId,
      {...payload, 'email': null},
    );
    expect(saved, {'id': fixture.id(1), 'revision': 5});
    expect(requestCount, 1);
  });

  test('contact access save and revoke use strict RPC envelopes', () async {
    var requestCount = 0;
    final gateway = await fixture.fixture((request) async {
      requestCount++;
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      if (requestCount == 1) {
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_save_contact_with_access',
        );
        expect(body, {
          'operation_id': fixture.operationId,
          'payload': {
            'id': fixture.id(1),
            'expected_revision': 4,
            'scope': 'congregation',
            'congregation_id': fixture.scopeId,
            'name': 'Teacher One',
            'role_code': 'teacher',
            'phone_e164': null,
            'birth_date': null,
            'email': 'teacher@example.test',
            'access': {
              'id': fixture.id(2),
              'user_email': 'teacher@example.test',
              'role': 'Membro da direção da campanha',
              'congregation_id': fixture.scopeId,
            },
          },
        });
        await fixture.respond(request, {
          'id': fixture.id(1),
          'revision': 5,
          'access_id': fixture.id(2),
        });
      } else {
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_revoke_contact_access',
        );
        expect(body, {
          'operation_id': fixture.operationId,
          'payload': {
            'id': fixture.id(1),
            'scope': 'congregation',
            'congregation_id': fixture.scopeId,
            'expected_revision': 5,
          },
        });
        await fixture.respond(request, {
          'id': fixture.id(1),
          'revision': 6,
          'revoked_access_id': fixture.id(2),
        });
      }
    });

    final saved = await gateway.ministryCommand(
      'save_contact_with_access',
      fixture.operationId,
      {
        'id': fixture.id(1),
        'expected_revision': 4,
        'scope': 'congregation',
        'congregation_id': fixture.scopeId,
        'name': 'Teacher One',
        'role_code': 'teacher',
        'phone_e164': null,
        'birth_date': null,
        'email': 'teacher@example.test',
        'access': {
          'id': fixture.id(2),
          'user_email': 'teacher@example.test',
          'role': 'Membro da direção da campanha',
          'congregation_id': fixture.scopeId,
        },
      },
    );
    expect(saved, {
      'id': fixture.id(1),
      'revision': 5,
      'access_id': fixture.id(2),
    });

    final revoked = await gateway.ministryCommand(
      'revoke_contact_access',
      fixture.operationId,
      {
        'id': fixture.id(1),
        'scope': 'congregation',
        'congregation_id': fixture.scopeId,
        'expected_revision': 5,
      },
    );
    expect(revoked, {
      'id': fixture.id(1),
      'revision': 6,
      'revoked_access_id': fixture.id(2),
    });
  });

  test('access candidate read uses the manager-only scoped envelope', () async {
    var requestCount = 0;
    final gateway = await fixture.fixture((request) async {
      requestCount++;
      expect(
        request.uri.path,
        '/rest/v1/rpc/ieadpe_ministry_list_access_candidates',
      );
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'request': {
          'scope': 'congregation',
          'congregation_id': fixture.scopeId,
          'role': 'Membro da direção da campanha',
          'limit': 25,
          'cursor': null,
        },
      });
      await fixture.respond(request, {'items': [], 'next_cursor': null});
    });

    final result = await gateway.readRpc(
      'ministry_list_access_candidates',
      context: gateway.context,
      parameters: {
        'scope': 'congregation',
        'congregation_id': fixture.scopeId,
        'role': 'Membro da direção da campanha',
        'limit': 25,
        'cursor': null,
      },
    );
    expect(result, {'items': [], 'next_cursor': null});
    await expectLater(
      gateway.readRpc(
        'ministry_list_access_candidates',
        context: gateway.context,
        parameters: {
          'scope': 'congregation',
          'congregation_id': fixture.scopeId,
          'role': 'Membro da direção da campanha',
          'limit': 25,
          'cursor': null,
          'user_id': fixture.id(3),
        },
      ),
      throwsA(isA<DataFailure>()),
    );
    expect(requestCount, 1);
  });

  test('class sessions gateway requires exact keys', () async {
    var requestCount = 0;
    final gateway = await fixture.fixture((request) async {
      requestCount++;
      expect(
        request.uri.path,
        '/rest/v1/rpc/ieadpe_ministry_list_class_sessions',
      );
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'request': {
          'congregation_id': fixture.scopeId,
          'class_id': fixture.id(2),
          'limit': 50,
          'cursor': null,
        },
      });
      await fixture.respond(request, {'items': [], 'next_cursor': null});
    });

    await expectLater(
      gateway.readRpc(
        'ministry_list_class_sessions',
        context: gateway.context,
        parameters: {
          'congregation_id': fixture.scopeId,
          'class_id': fixture.id(2),
          'limit': 50,
        },
      ),
      throwsA(isA<DataFailure>()),
    );
    await expectLater(
      gateway.readRpc(
        'ministry_list_class_sessions',
        context: gateway.context,
        parameters: {
          'congregation_id': fixture.scopeId,
          'class_id': fixture.id(2),
          'limit': 50,
          'cursor': null,
          'role': 'teacher',
        },
      ),
      throwsA(isA<DataFailure>()),
    );
    final result = await gateway.readRpc(
      'ministry_list_class_sessions',
      context: gateway.context,
      parameters: {
        'congregation_id': fixture.scopeId,
        'class_id': fixture.id(2),
        'limit': 50,
        'cursor': null,
      },
    );
    expect(result, {'items': [], 'next_cursor': null});
    expect(requestCount, 1);
  });

  test(
    'create session transports optional replacement linkage strictly',
    () async {
      var requestCount = 0;
      final gateway = await fixture.fixture((request) async {
        requestCount++;
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_create_session');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': fixture.operationId,
          'payload': {
            'id': fixture.id(1),
            'congregation_id': fixture.scopeId,
            'class_id': fixture.id(2),
            'date': '2026-10-20',
            'topic': null,
            'replaces_session_id': fixture.id(3),
          },
        });
        await fixture.respond(request, {
          'id': fixture.id(1),
          'revision': 2,
          'status': 'open',
        });
      });
      final payload = <String, Object?>{
        'id': fixture.id(1),
        'congregation_id': fixture.scopeId,
        'class_id': fixture.id(2),
        'date': '2026-10-20',
        'topic': null,
      };

      await expectLater(
        gateway.ministryCommand('create_session', fixture.operationId, {
          ...payload,
          'replaces_id': fixture.id(3),
        }),
        throwsA(isA<DataFailure>()),
      );
      await expectLater(
        gateway.ministryCommand('create_session', fixture.operationId, {
          ...payload,
          'replaces_session_id': 7,
        }),
        throwsA(isA<DataFailure>()),
      );
      await expectLater(
        gateway.ministryCommand('create_session', fixture.operationId, {
          ...payload,
          'replaces_session_id': 'not-a-uuid',
        }),
        throwsA(isA<DataFailure>()),
      );
      expect(requestCount, 0);

      final saved = await gateway.ministryCommand(
        'create_session',
        fixture.operationId,
        {...payload, 'replaces_session_id': fixture.id(3)},
      );
      expect(saved, {'id': fixture.id(1), 'revision': 2, 'status': 'open'});
      expect(requestCount, 1);
    },
  );

  test(
    'linked contact commands reject malformed payloads and result envelopes',
    () async {
      var requestCount = 0;
      final gateway = await fixture.fixture((request) async {
        requestCount++;
        await fixture.respond(request, {
          'id': fixture.id(1),
          'revision': 2,
          'access_id': fixture.id(2),
          'unexpected': true,
        });
      });
      final payload = <String, Object?>{
        'scope': 'congregation',
        'congregation_id': fixture.scopeId,
        'name': 'Teacher One',
        'role_code': 'teacher',
        'phone_e164': null,
        'birth_date': null,
        'email': 'teacher@example.test',
        'access': {
          'user_email': 'teacher@example.test',
          'role': 'Membro da direção da campanha',
          'congregation_id': fixture.scopeId,
        },
      };
      await expectLater(
        gateway.ministryCommand(
          'save_contact_with_access',
          fixture.operationId,
          {...payload, 'role_title_is_authority': true},
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(requestCount, 0);

      final explicitNullIdPayload = <String, Object?>{
        ...payload,
        'access': <String, Object?>{
          ...Map<String, Object?>.from(payload['access']! as Map),
          'id': null,
        },
      };
      await expectLater(
        gateway.ministryCommand(
          'save_contact_with_access',
          fixture.operationId,
          explicitNullIdPayload,
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(requestCount, 0);

      await expectLater(
        gateway.ministryCommand(
          'save_contact_with_access',
          fixture.operationId,
          payload,
        ),
        throwsA(
          isA<DataFailure>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
      expect(requestCount, 1);
    },
  );

  test('academic SQLSTATE mapping stays narrow and distinguishable', () async {
    var requestCount = 0;
    final gateway = await fixture.fixture((request) async {
      requestCount++;
      expect(request.uri.path, '/rest/v1/rpc/ieadpe_ministry_create_session');
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'operation_id': fixture.operationId,
        'payload': {
          'id': fixture.id(1),
          'congregation_id': fixture.scopeId,
          'class_id': fixture.id(2),
          'date': '2026-10-20',
          'topic': null,
          'replaces_session_id': fixture.id(3),
        },
      });
      switch (requestCount) {
        case 1:
          await fixture.respond(request, {
            'code': '23505',
            'message': 'academic_conflict',
          }, 409);
          break;
        case 2:
          await fixture.respond(request, {
            'code': '22023',
            'message': 'academic_invalid',
          }, 400);
          break;
        case 3:
          await fixture.respond(request, {
            'code': '23505',
            'message': 'duplicate_session',
          }, 409);
          break;
        case 4:
          await fixture.respond(request, {
            'code': '22023',
            'message': 'operation_conflict',
          }, 400);
          break;
      }
    });
    final payload = <String, Object?>{
      'id': fixture.id(1),
      'congregation_id': fixture.scopeId,
      'class_id': fixture.id(2),
      'date': '2026-10-20',
      'topic': null,
      'replaces_session_id': fixture.id(3),
    };

    for (final expected in [
      'academic_conflict',
      'academic_invalid',
      'backend',
      'invalid',
    ]) {
      await expectLater(
        gateway.ministryCommand('create_session', fixture.operationId, payload),
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', expected),
        ),
      );
    }
  });

  test(
    'student enrollment history uses the exact bounded read envelope',
    () async {
      var requestCount = 0;
      final gateway = await fixture.fixture((request) async {
        requestCount++;
        expect(
          request.uri.path,
          '/rest/v1/rpc/ieadpe_ministry_list_student_enrollments',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {
            'congregation_id': fixture.scopeId,
            'student_id': fixture.id(2),
            'limit': 100,
            'cursor': null,
          },
        });
        await fixture.respond(request, {'items': [], 'next_cursor': null});
      });

      final valid = <String, Object?>{
        'congregation_id': fixture.scopeId,
        'student_id': fixture.id(2),
        'limit': 100,
        'cursor': null,
      };
      expect(
        await gateway.readRpc(
          'ministry_list_student_enrollments',
          context: gateway.context,
          parameters: valid,
        ),
        {'items': [], 'next_cursor': null},
      );
      expect(requestCount, 1);

      final invalid = <Map<String, Object?>>[
        {...valid}..remove('cursor'),
        {...valid}..remove('student_id'),
        {...valid}..remove('limit'),
        {...valid}..remove('congregation_id'),
        {...valid, 'class_id': fixture.id(3)},
        {...valid, 'unexpected': true},
      ];
      for (final parameters in invalid) {
        await expectLater(
          gateway.readRpc(
            'ministry_list_student_enrollments',
            context: gateway.context,
            parameters: parameters,
          ),
          throwsA(
            isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
          ),
        );
      }
      expect(requestCount, 1);
    },
  );
}
