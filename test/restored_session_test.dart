import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/configuration.dart';
import 'package:ieadpe_converts/features/intake/public_intake_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('restored session leaves anonymous registration mode', (
    tester,
  ) async {
    String part(Map<String, Object> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${part({'alg': 'none'})}.${part({'sub': 'saved-user', 'exp': 4102444800})}.signature';
    final session = Session(
      accessToken: token,
      tokenType: 'bearer',
      expiresIn: 3600,
      refreshToken: 'synthetic',
      user: User(
        id: 'saved-user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
    const preferences = MethodChannel('plugins.flutter.io/shared_preferences');
    const links = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      preferences,
      (call) async => call.method == 'getAll'
          ? <String, Object>{
              'flutter.sb-127-auth-token': jsonEncode(session.toJson()),
            }
          : true,
    );
    messenger.setMockMethodCallHandler(links, (_) async => null);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    await tester.pumpWidget(
      const App(
        configuration: Configuration(
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'sb_publishable_synthetic',
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(Supabase.instance.client.auth.currentSession, isNotNull);
    expect(
      find.byType(PublicRegistrationPage),
      findsNothing,
      reason: 'a restored session must not be presented as signed out',
    );
    await tester.pumpWidget(const SizedBox());
    var disposed = false;
    final disposal = Supabase.instance.dispose().then((_) => disposed = true);
    for (var i = 0; i < 30 && !disposed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await disposal;
    for (final c in [preferences, links, events]) {
      messenger.setMockMethodCallHandler(c, null);
    }
  });
}
