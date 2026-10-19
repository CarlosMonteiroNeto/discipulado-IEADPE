import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_handoff_repository.dart';
import 'package:ieadpe_converts/features/ministry/domain/ministry_models.dart';

const _convert = '11111111-1111-4111-8111-111111111111';
const _student = '22222222-2222-4222-8222-222222222222';
const _person = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _scope = '33333333-3333-4333-8333-333333333333';
const _operation = '44444444-4444-4444-8444-444444444444';

Future<void> _respond(HttpRequest request, Object value) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

void main() {
  test('loads bounded minimal convert referrals as typed page', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      expect(
        request.uri.path,
        '/rest/v1/rpc/ieadpe_ministry_list_convert_referrals',
      );
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'request': {'congregation_id': _scope, 'limit': 20, 'cursor': null},
      });
      await _respond(request, {
        'items': [
          {
            'convert_id': _convert,
            'congregation_id': _scope,
            'name': 'Maria da Silva',
            'phone': null,
            'address': 'Rua das Flores',
            'conversion_date': '2026-10-01',
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
    final repository = MinistryHandoffRepository(
      SupabaseGateway(client, ProtectedDataBoundary()),
    );

    final page = await repository.listConvertReferrals(
      congregationId: _scope,
      limit: 20,
    );

    expect(page.items.single.convertId, _convert);
    expect(page.items.single.phone, isNull);
    expect(page.items.single.address, 'Rua das Flores');
    expect(page.items.single.conversionDate, '2026-10-01');
    expect(page.nextCursor, isNull);
  });

  test('promotes using the operation ID and exact chosen student', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      expect(
        request.uri.path,
        '/rest/v1/rpc/ieadpe_promote_convert_to_student',
      );
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'operation_id': _operation,
        'payload': {
          'convert_id': _convert,
          'congregation_id': _scope,
          'student_id': _student,
          'expected_student_revision': 7,
        },
      });
      await _respond(request, {
        'convert_id': _convert,
        'student_id': _student,
        'person_id': _person,
        'congregation_id': _scope,
        'status': 'linked',
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
    final repository = MinistryHandoffRepository(
      SupabaseGateway(client, ProtectedDataBoundary()),
    );

    final result = await repository.promote(
      operationId: _operation,
      convertId: _convert,
      congregationId: _scope,
      studentId: _student,
      expectedStudentRevision: 7,
    );

    expect(result.studentId, _student);
    expect(result.personId, _person);
    expect(result.status, 'linked');
  });

  test('rejects malformed referral pages and promotion responses', () {
    expect(
      () => decodeConvertReferralPage({
        'items': [
          {
            'convert_id': _convert,
            'congregation_id': _scope,
            'name': 'Maria',
            'phone': null,
            'address': null,
            'conversion_date': '2026-02-30',
          },
        ],
        'next_cursor': null,
      }),
      throwsA(isA<MinistryDataException>()),
    );
    expect(
      () => decodePromotionResult({
        'convert_id': _convert,
        'student_id': _student,
        'person_id': _person,
        'congregation_id': _scope,
        'status': 'created',
      }),
      throwsA(isA<MinistryDataException>()),
    );
  });
}
