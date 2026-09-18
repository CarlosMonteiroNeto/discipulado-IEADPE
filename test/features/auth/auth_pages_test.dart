import 'dart:async';

import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/auth/access_denied_page.dart';
import 'package:discipulado_ieadpe/features/auth/auth_controller.dart';
import 'package:discipulado_ieadpe/features/auth/password_reset_page.dart';
import 'package:discipulado_ieadpe/features/auth/sign_in_page.dart';
import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AuthSession?> sessions =
      StreamController<AuthSession?>.broadcast();
  int signOutCalls = 0;

  @override
  Stream<AuthSession?> watchSession() => sessions.stream;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

AuthSession _session() => AuthSession(
  uid: 'u1',
  profile: AccessProfile(
    accessRole: AccessRole.congregationStaff,
    congregationId: 'c1',
    active: true,
    revision: 1,
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
);

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Future<void> _enter(WidgetTester tester, Key key, String text) =>
    tester.enterText(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
      text,
    );

void main() {
  late _FakeAuthRepository repository;
  late AuthController controller;

  setUp(() {
    repository = _FakeAuthRepository();
    controller = AuthController(repository: repository)..start();
  });

  tearDown(() async {
    controller.dispose();
    await repository.sessions.close();
  });

  group('SignInPage', () {
    testWidgets('renders shared accessible controls with pt-BR labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(SignInPage(controller: controller)));

      expect(find.byKey(SignInPage.emailFieldKey), findsOneWidget);
      expect(find.byKey(SignInPage.passwordFieldKey), findsOneWidget);
      expect(find.byKey(SignInPage.submitKey), findsOneWidget);
      expect(find.text('E-mail *'), findsOneWidget);
      expect(find.text('Senha *'), findsOneWidget);
    });

    testWidgets('shows pt-BR field feedback on an empty submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(SignInPage(controller: controller)));

      await tester.tap(find.byKey(SignInPage.submitKey));
      await tester.pump();

      expect(find.text('Informe o e-mail.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
    });

    testWidgets('never logs the password or account payload', (
      WidgetTester tester,
    ) async {
      final List<String> logs = <String>[];
      final DebugPrintCallback original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
      try {
        await tester.pumpWidget(_wrap(SignInPage(controller: controller)));
        await _enter(tester, SignInPage.emailFieldKey, 'ana@example.com');
        await _enter(tester, SignInPage.passwordFieldKey, 'S3cr3t-password');
        await tester.tap(find.byKey(SignInPage.submitKey));
        await tester.pump();
      } finally {
        debugPrint = original;
      }

      expect(
        logs.any((String line) => line.contains('S3cr3t-password')),
        isFalse,
      );
      expect(
        logs.any((String line) => line.contains('ana@example.com')),
        isFalse,
      );
    });

    testWidgets('preserves a safe internal return destination', (
      WidgetTester tester,
    ) async {
      String? destination;
      await tester.pumpWidget(
        _wrap(
          SignInPage(
            controller: controller,
            returnTo: '/turmas/cl1',
            onAuthenticated: (String value) => destination = value,
          ),
        ),
      );
      await _enter(tester, SignInPage.emailFieldKey, 'ana@example.com');
      await _enter(tester, SignInPage.passwordFieldKey, 'segredo123');
      await tester.tap(find.byKey(SignInPage.submitKey));
      await tester.pump();

      repository.sessions.add(_session());
      await tester.pumpAndSettle();

      expect(destination, '/turmas/cl1');
    });

    testWidgets('prevents an external redirect target', (
      WidgetTester tester,
    ) async {
      String? destination;
      await tester.pumpWidget(
        _wrap(
          SignInPage(
            controller: controller,
            returnTo: 'https://evil.example',
            onAuthenticated: (String value) => destination = value,
          ),
        ),
      );
      await _enter(tester, SignInPage.emailFieldKey, 'ana@example.com');
      await _enter(tester, SignInPage.passwordFieldKey, 'segredo123');
      await tester.tap(find.byKey(SignInPage.submitKey));
      await tester.pump();

      repository.sessions.add(_session());
      await tester.pumpAndSettle();

      expect(destination, '/visao-geral');
    });
  });

  group('PasswordResetPage', () {
    testWidgets('answers with a generic anti-enumeration confirmation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(PasswordResetPage(controller: controller)));
      await _enter(
        tester,
        PasswordResetPage.emailFieldKey,
        'missing@example.com',
      );

      await tester.tap(find.byKey(PasswordResetPage.submitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(PasswordResetPage.confirmationKey), findsOneWidget);
      expect(
        find.text(
          'Se houver uma conta com este e-mail, enviaremos as instruções.',
        ),
        findsOneWidget,
      );
    });
  });

  group('AccessDeniedPage', () {
    testWidgets('shows Acesso não autorizado and signs out on demand', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(AccessDeniedPage(controller: controller)));

      expect(find.text('Acesso não autorizado'), findsOneWidget);
      await tester.tap(find.byKey(AccessDeniedPage.signOutKey));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
    });
  });
}
