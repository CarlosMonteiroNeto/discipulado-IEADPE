import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';
import 'package:ieadpe_converts/routing/router.dart';

void main() {
  test('scope RPC uses server snapshots and ignores editable metadata roles', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    const congregationA = '11111111-1111-1111-1111-111111111111';
    const congregationB = '22222222-2222-2222-2222-222222222222';
    final snapshots = [
      {
        'is_admin': true,
        'is_supervision': false,
        'congregation_ids': <String>[],
        'ministry_supervision': true,
        'ministry_congregation_ids': <String>[],
      },
      {
        'is_admin': false,
        'is_supervision': true,
        'congregation_ids': <String>[],
        'ministry_supervision': true,
        'ministry_congregation_ids': <String>[],
      },
      {
        'is_admin': false,
        'is_supervision': false,
        'congregation_ids': [congregationA],
        'ministry_supervision': false,
        'ministry_congregation_ids': [congregationA],
      },
      {
        'is_admin': false,
        'is_supervision': false,
        'congregation_ids': <String>[],
        'ministry_supervision': false,
        'ministry_congregation_ids': <String>[],
      },
    ];
    Object response = {
      'is_admin': false,
      'is_supervision': false,
      'congregation_ids': [congregationA],
      'ministry_supervision': false,
      'ministry_congregation_ids': [congregationB],
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
    expect(scope.congregationIds, {congregationA});
    expect(scope.isMinistrySupervision, isFalse);
    expect(scope.ministryCongregationIds, {congregationB});

    response = snapshots[0];
    final adminScope = await repository.loadScope();
    expect(adminScope.isAdmin, isTrue);
    expect(adminScope.isSupervision, isFalse);
    expect(adminScope.congregationIds, isEmpty);
    expect(adminScope.isMinistrySupervision, isTrue);
    expect(adminScope.ministryCongregationIds, isEmpty);
    final adminRoutes = routesFor(adminScope);
    expect(adminRoutes, contains('/admin'));
    expect(adminRoutes, contains('/ministry/students'));

    response = snapshots[1];
    final supervisionScope = await repository.loadScope();
    expect(supervisionScope.isAdmin, isFalse);
    expect(supervisionScope.isSupervision, isTrue);
    expect(supervisionScope.congregationIds, isEmpty);
    expect(supervisionScope.isMinistrySupervision, isTrue);
    expect(supervisionScope.ministryCongregationIds, isEmpty);
    final supervisionRoutes = routesFor(supervisionScope);
    expect(supervisionRoutes, contains('/admin'));
    expect(supervisionRoutes, contains('/ministry/students'));

    response = snapshots[2];
    final directionScope = await repository.loadScope();
    expect(directionScope.isAdmin, isFalse);
    expect(directionScope.isSupervision, isFalse);
    expect(directionScope.congregationIds, {congregationA});
    expect(directionScope.isMinistrySupervision, isFalse);
    expect(directionScope.ministryCongregationIds, {congregationA});
    final directionRoutes = routesFor(directionScope);
    expect(directionRoutes, contains('/ministry/students'));
    expect(directionRoutes, isNot(contains('/admin')));
    expect(directionScope.canAccessMinistry(congregationA), isTrue);
    expect(directionScope.canAccessMinistry(congregationB), isFalse);

    // A legacy campaign assignment (for example an archived congregation) may
    // remain in campaign scope while the server excludes it from Ministry IDs.
    response = {
      'is_admin': false,
      'is_supervision': false,
      'congregation_ids': [congregationA, congregationB],
      'ministry_supervision': false,
      'ministry_congregation_ids': [congregationA],
    };
    final campaignOnlyScope = await repository.loadScope();
    expect(campaignOnlyScope.congregationIds, {congregationA, congregationB});
    expect(campaignOnlyScope.ministryCongregationIds, {congregationA});
    expect(campaignOnlyScope.canAccessMinistry(congregationB), isFalse);
    final campaignOnlyRoutes = routesFor(campaignOnlyScope);
    expect(campaignOnlyRoutes, contains('/ministry/students'));
    expect(campaignOnlyRoutes, isNot(contains('/admin')));

    response = snapshots[3];
    final revokedScope = await repository.loadScope();
    expect(revokedScope.isAdmin, isFalse);
    expect(revokedScope.isSupervision, isFalse);
    expect(revokedScope.congregationIds, isEmpty);
    expect(revokedScope.isMinistrySupervision, isFalse);
    expect(revokedScope.ministryCongregationIds, isEmpty);
    final revokedRoutes = routesFor(revokedScope);
    expect(revokedRoutes, isNot(contains('/ministry')));
    expect(revokedRoutes, isNot(contains('/admin')));

    response = {
      'is_admin': true,
      'is_supervision': false,
      'congregation_ids': [],
      'ministry_supervision': false,
      'ministry_congregation_ids': ['not-a-uuid'],
    };
    await expectLater(repository.loadScope(), throwsFormatException);
  });

  test('rejects a server scope snapshot missing ministry fields', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'is_admin': false,
          'is_supervision': false,
          'congregation_ids': [],
        }),
      );
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
    await client.auth.recoverSession(
      jsonEncode({
        'access_token':
            'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature',
        'token_type': 'bearer',
        'user': {
          'id': 'synthetic-user',
          'aud': 'authenticated',
          'created_at': '2026-10-15T00:00:00Z',
        },
      }),
    );
    final repository = AuthRepository(
      client,
      AuthRedirectPolicy(Uri.parse('https://app.test/auth/callback')),
    );
    await expectLater(repository.loadScope(), throwsFormatException);
  });
}
