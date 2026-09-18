import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:discipulado_ieadpe/ui/web_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  testWidgets('reduced motion collapses transitions to zero', (tester) async {
    late Duration duration;
    await pumpApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            duration = AppMotion.durationOf(
              context,
              const Duration(milliseconds: 300),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(duration, Duration.zero);
  });

  testWidgets('default motion keeps the requested bounded duration', (
    tester,
  ) async {
    late Duration duration;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          duration = AppMotion.durationOf(
            context,
            const Duration(milliseconds: 300),
          );
          return const SizedBox.shrink();
        },
      ),
    );

    expect(duration, const Duration(milliseconds: 300));
  });

  testWidgets(
    'translucent chrome falls back to an opaque surface under high contrast',
    (tester) async {
      const translucent = Color(0xE6FFFFFF);
      const opaque = Color(0xFFFFFFFF);
      late Color resolved;

      await pumpApp(
        tester,
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: Builder(
            builder: (context) {
              resolved = AppSurface.resolve(
                context,
                translucent: translucent,
                opaque: opaque,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, opaque);

      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            resolved = AppSurface.resolve(
              context,
              translucent: translucent,
              opaque: opaque,
            );
            return const SizedBox.shrink();
          },
        ),
      );
      expect(resolved, translucent);
    },
  );

  testWidgets('reads the platform accessibility features', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          highContrast: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    late WebPreferences preferences;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          preferences = WebPreferences.fromContext(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(preferences.reduceMotion, isTrue);
    expect(preferences.highContrast, isTrue);
    expect(preferences.reduceTransparency, isTrue);
  });

  testWidgets(
    'reversible panel drops positional animation but preserves form state',
    (tester) async {
      final controller = TextEditingController(text: 'rascunho preservado');
      addTearDown(controller.dispose);
      var expanded = true;

      await pumpApp(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppButton(
                    label: expanded ? 'Recolher' : 'Expandir',
                    onPressed: () => setState(() => expanded = !expanded),
                  ),
                  AppReversiblePanel(
                    expanded: expanded,
                    child: TextField(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Recolher'));
      await tester.pump();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        isNot(Offset.zero),
      );

      await tester.tap(find.text('Expandir'));
      await tester.pump();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        Offset.zero,
      );
      expect(find.text('rascunho preservado'), findsOneWidget);
    },
  );
}
