import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';

void main() {
  test('scope RPC uses current session and ignores editable metadata roles', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    Object response = {
      'is_admin': false,
      'is_supervision': false,
      'congregation_ids': ['11111111-1111-1111-1111-111111111111'],
    };
    final serving = server.listen((request) async {
      requests.add(request);
      expect(request.uri.path, '/rest/v1/rpc/ieadpe_get_scope');
      expect(request.method, 'POST');
      expect(await utf8.decoder.bind(request).join(), 'null');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() async {
      await client.dispose();
      await serving.cancel();
      await server.close(force: true);
    });
    final repository = AuthRepository(
      client,
      AuthRedirectPolicy(Uri.parse('https://app.test/auth/callback')),
    );
    await expectLater(repository.loadScope(), throwsA(isA<AuthException>()));
    expect(requests, isEmpty);
    await client.auth.recoverSession(
      jsonEncode({
        'access_token':
            'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature',
        'token_type': 'bearer',
        'user': {
          'id': 'synthetic-user',
          'aud': 'authenticated',
          'created_at': '2026-10-15T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {'is_admin': true, 'role': 'admin'},
        },
      }),
    );
    final scope = await repository.loadScope();
    expect(scope.isAdmin, isFalse);
    expect(scope.isSupervision, isFalse);
    expect(scope.congregationIds, {'11111111-1111-1111-1111-111111111111'});
    response = {'is_admin': true};
    await expectLater(repository.loadScope(), throwsFormatException);
  });
}
