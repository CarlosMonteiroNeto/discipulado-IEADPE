import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/ui/unified_theme.dart';

double _contrastRatio(Color foreground, Color background) {
  double channel(double normalized) {
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  final foregroundLuminance =
      0.2126 * channel(foreground.r) +
      0.7152 * channel(foreground.g) +
      0.0722 * channel(foreground.b);
  final backgroundLuminance =
      0.2126 * channel(background.r) +
      0.7152 * channel(background.g) +
      0.0722 * channel(background.b);
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test(
    'named theme tokens retain the approved spacing and layout contract',
    () {
      expect(
        [
          UnifiedSpace.x1,
          UnifiedSpace.x2,
          UnifiedSpace.x3,
          UnifiedSpace.x4,
          UnifiedSpace.x6,
          UnifiedSpace.x8,
          UnifiedSpace.x12,
        ],
        [4, 8, 12, 16, 24, 32, 48],
      );
      expect(UnifiedSpace.phoneInset, 16);
      expect(UnifiedSpace.wideInset, 24);
      expect(UnifiedLayout.navigationBreakpoint, 768);
      expect(UnifiedLayout.maxContentWidth, 896);
      expect(UnifiedSize.minTouchTarget, 48);
    },
  );

  test('unified theme uses the shared type scale', () {
    final text = buildUnifiedTheme().textTheme;

    expect(text.bodyMedium?.fontSize, 16);
    expect(text.bodySmall?.fontSize, 14);
    expect(text.titleLarge?.fontSize, 20);
    expect(text.headlineSmall?.fontSize, 24);
  });

  test(
    'semantic status colors meet ordinary text contrast on their surfaces',
    () {
      final theme = buildUnifiedTheme();
      expect(theme.colorScheme.tertiary, UnifiedColors.success);

      for (final (foreground, background) in [
        (UnifiedColors.brandNavy, UnifiedColors.selected),
        (UnifiedColors.success, UnifiedColors.successSurface),
        (UnifiedColors.warning, UnifiedColors.warningSurface),
        (UnifiedColors.error, UnifiedColors.errorSurface),
        (UnifiedColors.disabledText, UnifiedColors.disabledSurface),
      ]) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background must remain readable',
        );
      }
      expect(
        _contrastRatio(Colors.white, UnifiedColors.green),
        greaterThanOrEqualTo(4.5),
        reason: 'White WhatsApp button text needs ordinary-text contrast',
      );
      expect(
        _contrastRatio(UnifiedColors.borderStrong, Colors.white),
        greaterThanOrEqualTo(3),
      );
    },
  );

  test('form outlines meet the minimum visible boundary contrast', () {
    final input = buildUnifiedTheme().inputDecorationTheme;
    final enabled = input.enabledBorder! as OutlineInputBorder;
    final focused = input.focusedBorder! as OutlineInputBorder;

    expect(
      _contrastRatio(enabled.borderSide.color, Colors.white),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(focused.borderSide.color, Colors.white),
      greaterThanOrEqualTo(3),
    );
    expect(focused.borderSide.width, greaterThanOrEqualTo(2));
  });

  testWidgets('filled buttons show a visible boundary after keyboard focus', (
    tester,
  ) async {
    final theme = buildUnifiedTheme();
    final inputFocus = FocusNode();
    final buttonFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    addTearDown(buttonFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              TextField(autofocus: true, focusNode: inputFocus),
              FilledButton(
                key: const ValueKey('focus-save'),
                focusNode: buttonFocus,
                onPressed: () {},
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final style = theme.filledButtonTheme.style!;
    final minimumSize = style.minimumSize!.resolve(const {});
    final focusSide = style.side?.resolve(const {WidgetState.focused});
    expect(buttonFocus.hasFocus, isTrue);
    expect(minimumSize!.width, greaterThanOrEqualTo(48));
    expect(minimumSize.height, greaterThanOrEqualTo(48));
    expect(focusSide, isNotNull);
    expect(
      _contrastRatio(focusSide!.color, UnifiedColors.brandNavy),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('theme text remains at the user-selected 200 percent scale', (
    tester,
  ) async {
    final theme = buildUnifiedTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Text('Texto ampliado', style: theme.textTheme.bodyMedium),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Texto ampliado'),
    );
    expect(paragraph.textScaler.scale(paragraph.text.style!.fontSize!), 32);
    expect(tester.takeException(), isNull);
  });
}
