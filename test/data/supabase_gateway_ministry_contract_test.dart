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
}
