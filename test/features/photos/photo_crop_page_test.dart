import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ieadpe_converts/features/photos/photo_crop.dart';
import 'package:ieadpe_converts/features/photos/photo_crop_page.dart';

Uint8List _source({int width = 400, int height = 200}) {
  final pixels = image.Image(width: width, height: height);
  image.fill(pixels, color: image.ColorRgb8(160, 80, 30));
  return Uint8List.fromList(image.encodePng(pixels));
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.source});
  final Uint8List source;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Future<NormalizedPhotoCrop?>? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open-crop'),
        onPressed: () => result = showPhotoCrop(context, widget.source),
        child: const Text('Abrir ajuste'),
      ),
    ),
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
    super.didPush(route, previousRoute);
  }
}

Future<(_HarnessState, GlobalKey<_HarnessState>)> _open(
  WidgetTester tester, {
  Uint8List? source,
  double textScale = 1,
  bool disableAnimations = true,
  bool highContrast = false,
  NavigatorObserver? observer,
}) async {
  if (highContrast) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: _Harness(key: key, source: source ?? _source()),
      ),
      navigatorObservers: observer == null ? const [] : [observer],
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-crop')));
  await tester.pumpAndSettle();
  return (key.currentState!, key);
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Confirmar foto'));
  await tester.tap(find.text('Confirmar foto'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirm returns the square framing and cancel returns null', (
    tester,
  ) async {
    final (harness, _) = await _open(tester);
    await _confirm(tester);
    final crop = await harness.result;
    expect(crop!.left, closeTo(.25, .01));
    expect(crop.top, closeTo(0, .01));
    expect(crop.size, closeTo(1, .01));

    final (cancelled, _) = await _open(tester);
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await cancelled.result, isNull);
  });

  testWidgets('zoom retains the selected center and reset restores framing', (
    tester,
  ) async {
    final (harness, _) = await _open(tester);
    await tester.ensureVisible(find.byTooltip('Aproximar foto'));
    await tester.tap(find.byTooltip('Aproximar foto'));
    await tester.pump();
    await _confirm(tester);
    final zoomed = await harness.result;
    expect(zoomed!.size, lessThan(1));
    expect(zoomed.left + zoomed.size * .25, closeTo(.5, .03));

    final (resetHarness, _) = await _open(tester);
    await tester.ensureVisible(find.byTooltip('Aproximar foto'));
    await tester.tap(find.byTooltip('Aproximar foto'));
    await tester.pump();
    await tester.ensureVisible(find.text('Redefinir'));
    await tester.tap(find.text('Redefinir'));
    await tester.pump();
    await _confirm(tester);
    final reset = await resetHarness.result;
    expect(reset!.left, closeTo(.25, .01));
    expect(reset.size, closeTo(1, .01));
  });

  testWidgets('pan tracks the pointer from its grab point', (tester) async {
    final (harness, _) = await _open(tester);
    final viewport = find.byKey(const ValueKey('photo-crop-viewport'));
    await tester.drag(viewport, const Offset(40, 0));
    await tester.pumpAndSettle();
    await _confirm(tester);
    final crop = await harness.result;
    expect(crop!.left, lessThan(.25));
    expect(crop.left, closeTo(.196, .025));
  });

  testWidgets('keyboard and semantic controls move the displayed image', (
    tester,
  ) async {
    Future<NormalizedPhotoCrop> afterMove({
      String? tooltip,
      LogicalKeyboardKey? key,
    }) async {
      final (harness, _) = await _open(
        tester,
        source: _source(width: 400, height: 400),
      );
      await tester.ensureVisible(find.byTooltip('Aproximar foto'));
      await tester.tap(find.byTooltip('Aproximar foto'));
      await tester.pump();
      if (tooltip != null) {
        await tester.ensureVisible(find.byTooltip(tooltip));
        await tester.tap(find.byTooltip(tooltip));
      }
      if (key != null) {
        await tester.tap(find.byKey(const ValueKey('photo-crop-viewport')));
        await tester.sendKeyEvent(key);
      }
      await _confirm(tester);
      return (await harness.result)!;
    }

    const center = .04545;
    expect(
      (await afterMove(tooltip: 'Mover foto à esquerda')).left,
      greaterThan(center),
    );
    expect(
      (await afterMove(tooltip: 'Mover foto à direita')).left,
      lessThan(center),
    );
    expect(
      (await afterMove(tooltip: 'Mover foto para cima')).top,
      greaterThan(center),
    );
    expect(
      (await afterMove(tooltip: 'Mover foto para baixo')).top,
      lessThan(center),
    );
    expect(
      (await afterMove(key: LogicalKeyboardKey.arrowLeft)).left,
      greaterThan(center),
    );
    expect(
      (await afterMove(key: LogicalKeyboardKey.arrowRight)).left,
      lessThan(center),
    );
    expect(
      (await afterMove(key: LogicalKeyboardKey.arrowUp)).top,
      greaterThan(center),
    );
    expect(
      (await afterMove(key: LogicalKeyboardKey.arrowDown)).top,
      lessThan(center),
    );
  });

  testWidgets('corrupt image shows a recoverable crop message', (tester) async {
    final (harness, _) = await _open(
      tester,
      source: Uint8List.fromList([1, 2, 3]),
    );

    expect(find.text('Não foi possível abrir esta imagem.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Voltar para o formulário'));
    await tester.pumpAndSettle();
    expect(await harness.result, isNull);
  });

  testWidgets('crop route disables its transition when reduced motion is on', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    await _open(tester, observer: observer, disableAnimations: true);

    expect(observer.pushed, isA<PageRoute<dynamic>>());
    final route = observer.pushed! as PageRoute<dynamic>;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('crop route keeps its normal transition when motion is allowed', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    await _open(tester, observer: observer, disableAnimations: false);

    expect(observer.pushed, isA<PageRoute<dynamic>>());
    final route = observer.pushed! as PageRoute<dynamic>;
    expect(route.transitionDuration, isNot(Duration.zero));
  });

  testWidgets('360, 768 and 1440px crop viewports stay usable at 200% text', (
    tester,
  ) async {
    for (final viewportCase in [
      (width: 360.0, highContrast: false),
      (width: 768.0, highContrast: true),
      (width: 1440.0, highContrast: true),
    ]) {
      tester.view.physicalSize = Size(viewportCase.width, 900);
      tester.view.devicePixelRatio = 1;
      await _open(
        tester,
        textScale: 2,
        highContrast: viewportCase.highContrast,
      );
      final viewport = find.byKey(const ValueKey('photo-crop-viewport'));
      expect(tester.getSize(viewport).width, lessThanOrEqualTo(480));
      expect(
        find.byKey(
          ValueKey(
            viewportCase.highContrast
                ? 'photo-crop-guide-high-contrast'
                : 'photo-crop-guide-standard',
          ),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Confirmar foto'));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Ampliação'), findsOneWidget);
      await _confirm(tester);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
