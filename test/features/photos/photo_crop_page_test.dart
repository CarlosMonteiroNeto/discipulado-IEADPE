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

Future<(_HarnessState, GlobalKey<_HarnessState>)> _open(
  WidgetTester tester, {
  Uint8List? source,
  double textScale = 1,
}) async {
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: _Harness(key: key, source: source ?? _source()),
      ),
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

  testWidgets('keyboard position and zoom alternatives are available', (
    tester,
  ) async {
    final (harness, _) = await _open(tester);
    expect(find.byTooltip('Mover foto à esquerda'), findsOneWidget);
    expect(find.byTooltip('Mover foto à direita'), findsOneWidget);
    expect(find.byTooltip('Mover foto para cima'), findsOneWidget);
    expect(find.byTooltip('Mover foto para baixo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photo-crop-viewport')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _confirm(tester);
    final crop = await harness.result;
    expect(crop!.left, greaterThan(.25));
  });

  testWidgets('360px viewport, 200% text and reduced motion stay usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, textScale: 2);
    await tester.ensureVisible(find.text('Confirmar foto'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Ampliação'), findsOneWidget);
  });
}
