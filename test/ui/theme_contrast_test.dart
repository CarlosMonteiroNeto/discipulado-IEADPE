import 'package:discipulado_ieadpe/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('brand palette', () {
    test('declares the S10 brand colors exactly', () {
      expect(AppBrandColors.primary, const Color(0xFF002060));
      expect(AppBrandColors.secondary, const Color(0xFF00A3E0));
      expect(AppBrandColors.accent, const Color(0xFFE31B23));
      expect(AppBrandColors.white, const Color(0xFFFFFFFF));
    });

    test('white is a permitted neutral surface in light mode', () {
      expect(AppTokens.light.surface, AppBrandColors.white);
    });
  });

  final themes = <String, AppTokens>{
    'light': AppTokens.light,
    'dark': AppTokens.dark,
  };

  themes.forEach((mode, tokens) {
    group('$mode semantic contrast', () {
      final textPairs = <String, List<Color>>{
        'onSurface/surface': [tokens.onSurface, tokens.surface],
        'onSurfaceVariant/surfaceVariant': [
          tokens.onSurfaceVariant,
          tokens.surfaceVariant,
        ],
        'onPrimary/primary': [tokens.onPrimary, tokens.primary],
        'onSecondary/secondary': [tokens.onSecondary, tokens.secondary],
        'onAccent/accent': [tokens.onAccent, tokens.accent],
        'onError/error': [tokens.onError, tokens.error],
        'onDisabled/disabledSurface': [
          tokens.onDisabled,
          tokens.disabledSurface,
        ],
        'error/surface': [tokens.error, tokens.surface],
      };

      textPairs.forEach((pair, colors) {
        test('$pair meets 4.5:1', () {
          expect(
            appContrastRatio(colors[0], colors[1]),
            greaterThanOrEqualTo(4.5),
            reason: pair,
          );
        });
      });

      final boundaryPairs = <String, List<Color>>{
        'outline/surface': [tokens.outline, tokens.surface],
        'outline/surfaceVariant': [tokens.outline, tokens.surfaceVariant],
        'focusRing/surface': [tokens.focusRing, tokens.surface],
        'focusRing/surfaceVariant': [tokens.focusRing, tokens.surfaceVariant],
        'focusRing/disabledSurface': [tokens.focusRing, tokens.disabledSurface],
      };

      boundaryPairs.forEach((pair, colors) {
        test('$pair meets 3:1', () {
          expect(
            appContrastRatio(colors[0], colors[1]),
            greaterThanOrEqualTo(3.0),
            reason: pair,
          );
        });
      });

      // The indicator drawn on a filled control must clear the fill it
      // borders, not only the neutral surfaces.
      final fills = <String, Color>{
        'primary': tokens.primary,
        'secondary': tokens.secondary,
        'accent': tokens.accent,
        'error': tokens.error,
      };

      fills.forEach((name, fill) {
        test('focus indicator on $name meets 3:1', () {
          expect(
            appContrastRatio(tokens.focusRingFor(fill), fill),
            greaterThanOrEqualTo(3.0),
            reason: 'focusRingFor($name)',
          );
        });
      });
    });
  });

  test('light focusRing meets 3:1 against the primary fill', () {
    expect(
      appContrastRatio(AppTokens.light.focusRing, AppTokens.light.primary),
      greaterThanOrEqualTo(3.0),
    );
  });

  test('dark focusRing is not the dark primary fill', () {
    expect(AppTokens.dark.focusRing, isNot(AppTokens.dark.primary));
  });

  test('contrastRatio matches the hand-computed black-on-white extreme', () {
    expect(
      appContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21.0, 0.01),
    );
  });
}
