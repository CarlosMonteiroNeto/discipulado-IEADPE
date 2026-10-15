import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/app.dart';
import 'package:ieadpe_converts/configuration.dart';

void main() {
  testWidgets('bootstrap uses Brazilian Portuguese', (tester) async {
    await tester.pumpWidget(const App());
    expect(
      Localizations.localeOf(tester.element(find.byType(Scaffold))),
      const Locale('pt', 'BR'),
    );
  });

  testWidgets('missing backend recovers safely through keyboard activation', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    expect(find.text('Serviço indisponível'), findsOneWidget);
    expect(find.textContaining('SUPABASE'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Serviço indisponível'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px screen supports 200 percent text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: App(),
      ),
    );
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid backend settings remain unavailable', (tester) async {
    for (final url in [
      '',
      'not a url',
      'http://remote.example',
      'https://user:password@example.com',
    ]) {
      await tester.pumpWidget(
        App(
          key: ValueKey(url),
          configuration: Configuration(
            supabaseUrl: url,
            supabasePublishableKey: 'sb_publishable_synthetic',
          ),
        ),
      );
      expect(find.text('Serviço indisponível'), findsOneWidget);
    }
  });

  testWidgets('configured bootstrap does not claim an authenticated session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const App(
        configuration: Configuration(
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'sb_publishable_synthetic',
        ),
      ),
    );
    expect(find.text('Aplicativo em preparação'), findsOneWidget);
  });
}
