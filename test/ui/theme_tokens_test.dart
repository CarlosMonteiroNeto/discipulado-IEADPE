import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('themes apply platform typography with body text at least 16', () {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      expect(theme.textTheme.bodyMedium!.fontSize, greaterThanOrEqualTo(16));
      expect(theme.textTheme.bodyLarge!.fontSize, greaterThanOrEqualTo(16));
      expect(theme.textTheme.labelLarge!.fontSize, greaterThanOrEqualTo(16));
      // No custom family: the platform default typography is retained.
      final defaultFamily = ThemeData(brightness: theme.brightness)
          .textTheme
          .bodyMedium!
          .fontFamily;
      expect(theme.textTheme.bodyMedium!.fontFamily, defaultFamily);
    }
  });

  test('spacing is a consistent ascending 4/8 scale', () {
    for (final value in AppSpacing.scale) {
      expect(value, greaterThan(0));
      expect(value % 4, 0, reason: '$value must be a 4/8 multiple');
    }
    expect(AppSpacing.scale, contains(4.0));
    expect(AppSpacing.scale, contains(8.0));
    final sorted = [...AppSpacing.scale]..sort();
    expect(AppSpacing.scale, equals(sorted));
  });

  test('touch targets and control heights are at least 44 logical pixels', () {
    expect(AppSizes.minTouchTarget, greaterThanOrEqualTo(44));
    expect(AppSizes.controlHeight, greaterThanOrEqualTo(44));
    expect(AppSizes.compactControlHeight, greaterThanOrEqualTo(44));
  });

  test('every button family shares the unified control radius', () {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final styles = <ButtonStyle?>[
        theme.filledButtonTheme.style,
        theme.elevatedButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
      ];
      for (final style in styles) {
        final shape =
            style!.shape!.resolve(const <WidgetState>{})!
                as RoundedRectangleBorder;
        expect(shape.borderRadius, AppRadii.controlRadius);
        final minimum = style.minimumSize!.resolve(const <WidgetState>{})!;
        expect(minimum.height, greaterThanOrEqualTo(44));
        expect(minimum.width, greaterThanOrEqualTo(44));
      }
    }
  });

  test('buttons publish press and focus feedback overlays', () {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final overlay = theme.filledButtonTheme.style!.overlayColor!;
      final resting = overlay.resolve(const <WidgetState>{});
      final pressed = overlay.resolve(const <WidgetState>{WidgetState.pressed});
      final focused = overlay.resolve(const <WidgetState>{WidgetState.focused});
      expect(pressed, isNotNull);
      expect(focused, isNotNull);
      expect(focused, isNot(equals(resting)));
      expect(pressed, isNot(equals(resting)));
    }
  });

  test('dark mode ships dark surfaces using the same color language', () {
    expect(
      appRelativeLuminance(AppTokens.dark.surface),
      lessThan(appRelativeLuminance(AppTokens.light.surface)),
    );
    // Brand navy is retained as the on-primary ink instead of inverted text.
    expect(AppTokens.dark.onPrimary, AppTokens.light.primary);
  });

  test('the same tokens are reachable from the built themes', () {
    expect(
      AppTheme.light.extension<AppTokens>()!.primary,
      AppBrandColors.primary,
    );
    expect(
      AppTheme.dark.extension<AppTokens>()!.surface,
      AppTokens.dark.surface,
    );
    expect(
      AppRadii.controlRadius,
      const BorderRadius.all(Radius.circular(AppRadii.control)),
    );
  });
}
