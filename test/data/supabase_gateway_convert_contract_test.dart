import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _operationId = 'c0000000-0000-4000-8000-000000000001';
const _congregationId = 'b0000000-0000-4000-8000-000000000001';
const _convertId = 'd0000000-0000-4000-8000-000000000001';
const _personId = 'e0000000-0000-4000-8000-000000000001';

Future<void> _respond(HttpRequest request, Map<String, Object?> value) async {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(value));
  await request.response.close();
}

void main() {
  test(
    'convert command accepts null worship type from a dynamic payload',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serving = server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['payload']['convert']['worship_type'], isNull);
        await _respond(request, {
          'id': _convertId,
          'person_id': _personId,
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
      final gateway = SupabaseGateway(client, ProtectedDataBoundary());
      final dynamic transport = gateway;

      final result = await transport.saveConvert(
        'create_convert',
        _operationId,
        {
          'congregation_id': _congregationId,
          'person': {
            'name': 'Ana Silva',
            'phone': null,
            'birth_date': null,
            'address': null,
          },
          'convert': {
            'landmark': 'Praça',
            'gender': 'female',
            'conversion_date': '2026-01-02',
            'worship_type': null,
            'age': null,
            'photo_asset_id': null,
          },
        },
      );

      expect(result.value.convertId, _convertId);
    },
  );

  test('convert commands reject empty and whitespace worship values', () async {
    final client = SupabaseClient(
      'http://127.0.0.1:1',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final dynamic transport = SupabaseGateway(client, ProtectedDataBoundary());
    for (final worshipType in ['', '   ']) {
      await expectLater(
        transport.saveConvert('create_convert', _operationId, {
          'congregation_id': _congregationId,
          'person': {
            'name': 'Ana Silva',
            'phone': null,
            'birth_date': null,
            'address': null,
          },
          'convert': {
            'landmark': 'Praça',
            'gender': 'female',
            'conversion_date': '2026-01-02',
            'worship_type': worshipType,
            'age': null,
            'photo_asset_id': null,
          },
        }),
        throwsA(isA<DataFailure>()),
      );
    }
    await expectLater(
      transport.importRow(_operationId, {'worship_type': ''}),
      throwsA(isA<DataFailure>()),
    );
  });

  test('convert command sends nested identity and parses independent revisions', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      expect(request.uri.path, '/rest/v1/rpc/ieadpe_create_convert');
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'operation_id': _operationId,
        'payload': {
          'congregation_id': _congregationId,
          'person': {
            'name': 'Ana Silva',
            'phone': '+5511999990000',
            'birth_date': '1990-02-28',
            'address': {
              'street': 'Rua A',
              'district': null,
              'city': null,
              'postal_code': null,
              'state_code': null,
            },
          },
          'convert': {
            'landmark': 'Praça',
            'gender': 'female',
            'conversion_date': '2026-01-02',
            'worship_type': '01 - Oração',
            'age': 36,
            'photo_asset_id': null,
          },
        },
      });
      await _respond(request, {
        'id': _convertId,
        'person_id': _personId,
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
    final gateway = SupabaseGateway(client, ProtectedDataBoundary());
    final dynamic transport = gateway;

    dynamic result;
    try {
      result = await transport.saveConvert('create_convert', _operationId, {
        'congregation_id': _congregationId,
        'person': {
          'name': 'Ana Silva',
          'phone': '+5511999990000',
          'birth_date': '1990-02-28',
          'address': {
            'street': 'Rua A',
            'district': null,
            'city': null,
            'postal_code': null,
            'state_code': null,
          },
        },
        'convert': {
          'landmark': 'Praça',
          'gender': 'female',
          'conversion_date': '2026-01-02',
          'worship_type': '01 - Oração',
          'age': 36,
          'photo_asset_id': null,
        },
      });
    } on NoSuchMethodError {
      // A missing typed command port is the expected RED before implementation.
    }

    expect(result, isNotNull);
    expect(result.value.convertId, _convertId);
    expect(result.value.personId, _personId);
    expect(result.value.convertRevision, 1);
    expect(result.value.personRevision, 1);
  });
}
