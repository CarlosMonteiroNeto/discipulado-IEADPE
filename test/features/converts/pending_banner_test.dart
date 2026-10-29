import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/intake/pending_banner.dart';

void main() {
  testWidgets('a zero queue hides the banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingBanner(count: 0, onReview: () {}),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('pending-banner')), findsNothing);
    expect(find.text('Revisar'), findsNothing);
  });

  testWidgets('one pending submission reads in the singular', (tester) async {
    var reviewed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingBanner(count: 1, onReview: () => reviewed++),
        ),
      ),
    );

    expect(find.text('1 cadastro pendente'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pending-banner-review')));
    expect(reviewed, 1);
  });

  testWidgets('a full queue announces the count instead of a bare plus', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingBanner(count: 50, capped: true, onReview: () {}),
        ),
      ),
    );

    expect(find.text('Mais de 50 cadastros pendentes'), findsOneWidget);
  });

  testWidgets('the banner stays usable at 320px with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: PendingBanner(count: 12, onReview: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Revisar'), findsOneWidget);
  });
}
