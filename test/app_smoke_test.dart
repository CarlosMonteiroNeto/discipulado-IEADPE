import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tentar novamente'),
    );
    final focus = FocusManager.instance.primaryFocus;
    expect(
      focus?.context?.findAncestorWidgetOfExactType<FilledButton>(),
      same(retry),
    );
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
  testWidgets('configured App initializes actual SDK and stays unauthenticated', (tester) async {
    const preferences = MethodChannel('plugins.flutter.io/shared_preferences');
    const links = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(preferences, (call) async => call.method == 'getAll' ? <String,Object>{} : true);
    messenger.setMockMethodCallHandler(links, (_) async => null);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() { for (final channel in [preferences, links, events]) { messenger.setMockMethodCallHandler(channel, null); } });
    await tester.pumpWidget(const App(configuration: Configuration(supabaseUrl: 'http://127.0.0.1:54321', supabasePublishableKey: 'sb_publishable_synthetic')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(Supabase.instance.isInitialized, isTrue);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(find.text('Aplicativo em preparação'), findsNothing);
    expect(find.text('Entrar com Google'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    var disposed = false;
    final disposal = Supabase.instance.dispose().then((_) => disposed = true);
    for (var i = 0; i < 30 && !disposed; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(disposed, isTrue, reason: 'SDK isolate and stream cleanup must complete');
    await disposal;
    await tester.pump();
  });
}
