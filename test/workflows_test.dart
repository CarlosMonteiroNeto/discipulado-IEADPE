import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/io_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/features/converts/register_page.dart';
import 'package:ieadpe_converts/features/feedback/feedback_dialog.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';

class LoopbackHttp extends HttpOverrides {}

class RootFixture {
  late HttpServer server;
  late SupabaseClient client;
  late HttpClient http;
  late AuthRepository auth;
  bool admin = true, failScope = false;
  Completer<void>? scopeGate;
  final paths = <String>[];
  Future<void> initialize() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      Object value = <Object>[];
      if (request.uri.path.endsWith('ieadpe_get_scope')) {
        await scopeGate?.future;
        if (failScope) {
          request.response.statusCode = 403;
          value = {'code': '42501', 'message': 'synthetic'};
        } else {
          value = {
            'is_admin': admin,
            'is_supervision': false,
            'congregation_ids': <String>[],
          };
        }
      }
      if (request.uri.path.endsWith('ieadpe_weekly_overview')) {
        value = {
          'visible': false,
          'global': admin,
          'week_start': null,
          'rows': <Object>[],
          'next_cursor': null,
        };
      }
      request.response.write(jsonEncode(value));
      await request.response.close();
    });
    http = LoopbackHttp().createHttpClient(null)..idleTimeout = Duration.zero;
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic',
      httpClient: IOClient(http),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    auth = AuthRepository(
      client,
      AuthRedirectPolicy(Uri.parse('http://localhost:3000/auth/callback')),
    );
    await identity('11111111-1111-1111-1111-111111111111');
  }

  Future<void> identity(String id) => client.auth.recoverSession(
    jsonEncode({
      'access_token':
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature',
      'token_type': 'bearer',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'created_at': '2026-10-15T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
      },
    }),
  );
  Future<void> close() async {
    scopeGate?.complete();
    scopeGate = null;
    await client.dispose();
    http.close(force: true);
    await server.close(force: true);
  }
}

Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'production root mounts Google login for configured SDK without a session',
    (tester) async {
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ))!;
      final auth = AuthRepository(
        client,
        AuthRedirectPolicy(Uri.parse('http://localhost:3000/auth/callback')),
      );
      await tester.pumpWidget(App(auth: auth));
      await tester.pumpAndSettle();
      expect(find.text('Entrar com Google'), findsOneWidget);
      expect(find.text('Aplicativo em preparação'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(client.dispose);
    },
  );
  testWidgets(
    'real SDK root retains picker through resume and destroys explicit equal-scope owners',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      final chosen = Completer<Uint8List?>();
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedApplication(
            repository: fixture.auth,
            pickPhoto: () => chosen.future,
          ),
        ),
      );
      await drain(tester);
      expect(find.byType(RegisterPage), findsOneWidget);
      final owner = tester.state(find.byType(RegisterPage));
      final rootContext = tester.element(find.byType(RegisterPage));
      final router = (rootContext
          .findAncestorWidgetOfExactType<ProtectedApplication>()!);
      expect(router.repository, same(fixture.auth));
      await tester.tap(find.text('Escolher foto'));
      await tester.pump();
      fixture.scopeGate = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Atualizando acesso…'), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
      chosen.complete(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
        ),
      );
      await tester.pump();
      fixture.scopeGate!.complete();
      fixture.scopeGate = null;
      await drain(tester);
      expect(tester.state(find.byType(RegisterPage)), same(owner));
      expect(find.text('Remover foto'), findsOneWidget);
      // Real UI permission callback must replace the owner despite equal flags.
      await tester.tap(find.byTooltip('Enviar sugestão'));
      await tester.pump();
      final callback = tester
          .widget<FeedbackDialog>(find.byType(FeedbackDialog))
          .onScopeRefresh;
      final refresh = callback();
      await drain(tester);
      await refresh;
      expect(find.text('Remover foto'), findsNothing);
      expect(tester.state(find.byType(RegisterPage)), isNot(same(owner)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  testWidgets(
    'SDK identity switch while chooser is pending discards old form and bytes',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      final chosen = Completer<Uint8List?>();
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedApplication(
            repository: fixture.auth,
            pickPhoto: () => chosen.future,
          ),
        ),
      );
      await drain(tester);
      final owner = tester.state(find.byType(RegisterPage));
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Synthetic private draft',
      );
      await tester.tap(find.text('Escolher foto'));
      await tester.pump();
      await tester.runAsync(
        () => fixture.identity('22222222-2222-2222-2222-222222222222'),
      );
      await drain(tester);
      chosen.complete(Uint8List.fromList([1, 2, 3]));
      await drain(tester);
      expect(tester.state(find.byType(RegisterPage)), isNot(same(owner)));
      expect(find.text('Synthetic private draft'), findsNothing);
      expect(find.text('Remover foto'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
  for (final changed in [false, true]) {
    testWidgets(
      'resume ${changed ? 'changed scope' : 'failure'} discards pending chooser and protected form',
      (tester) async {
        final fixture = RootFixture();
        await tester.runAsync(fixture.initialize);
        final chosen = Completer<Uint8List?>();
        await tester.pumpWidget(
          MaterialApp(
            home: ProtectedApplication(
              repository: fixture.auth,
              pickPhoto: () => chosen.future,
            ),
          ),
        );
        await drain(tester);
        final owner = tester.state(find.byType(RegisterPage));
        await tester.enterText(
          find.byKey(const ValueKey('name')),
          'Synthetic private draft',
        );
        await tester.tap(find.text('Escolher foto'));
        await tester.pump();
        fixture.admin = false;
        fixture.failScope = !changed;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await drain(tester);
        chosen.complete(Uint8List.fromList([1, 2, 3]));
        await drain(tester);
        expect(find.text('Synthetic private draft'), findsNothing);
        expect(find.text('Remover foto'), findsNothing);
        if (changed) {
          expect(tester.state(find.byType(RegisterPage)), isNot(same(owner)));
        } else {
          expect(find.byType(RegisterPage), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.close);
      },
    );
  }
  testWidgets(
    'actual SDK root connects all five Admin tabs and both feedback owners',
    (tester) async {
      final fixture = RootFixture();
      await tester.runAsync(fixture.initialize);
      await tester.pumpWidget(
        MaterialApp(home: ProtectedApplication(repository: fixture.auth)),
      );
      await drain(tester);
      tester.widget<AppShell>(find.byType(AppShell)).onNavigate('/admin');
      await drain(tester);
      for (final label in [
        'Congregações',
        'Acessos',
        'Relatório',
        'Eventos',
        'Backup',
      ]) {
        final choice = find.widgetWithText(ChoiceChip, label);
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await drain(tester);
        expect(find.textContaining('ainda não está disponível'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(fixture.paths, contains('/rest/v1/congregations'));
      expect(fixture.paths, contains('/rest/v1/user_access'));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    },
  );
}
