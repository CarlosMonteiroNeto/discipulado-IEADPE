import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The S10 brand palette. Declared exactly once; feature code consumes the
/// semantic tokens on [AppTokens] instead of these raw values.
abstract final class AppBrandColors {
  static const Color primary = Color(0xFF002060);
  static const Color secondary = Color(0xFF00A3E0);
  static const Color accent = Color(0xFFE31B23);
  static const Color white = Color(0xFFFFFFFF);
}

/// Consistent 4/8 spacing scale shared by every layout.
abstract final class AppSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x12 = 48;

  static const List<double> scale = <double>[x1, x2, x3, x4, x6, x8, x12];
}

/// Unified shape/radius system.
abstract final class AppRadii {
  static const double control = 8;
  static const double card = 12;
  static const double dialog = 16;

  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialog),
  );
}

/// Control metrics that keep every interactive element accessible.
abstract final class AppSizes {
  static const double minTouchTarget = 44;
  static const double controlHeight = 48;
  static const double compactControlHeight = 44;
  static const double maxContentWidth = 1200;
  static const double bodyFontSize = 16;

  /// Shared width for labelled filter fields (dropdowns) and search fields in
  /// a filtered toolbar: fields share the available row width equally and
  /// never grow beyond this bound, so both edges line up instead of ending at
  /// ragged widths.
  static const double filterFieldMaxWidth = 360;

  /// Minimum content width at which a filtered toolbar lays its fields on a
  /// single aligned row; below it fields stack full width.
  static const double filterBarRowBreakpoint = 1000;
}

/// Semantic color tokens shared by light and dark modes.
///
/// Every text pairing meets WCAG AA (>= 4.5:1) and every control boundary and
/// focus indication meets >= 3:1, verified by `test/ui/theme_contrast_test.dart`.
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.accent,
    required this.onAccent,
    required this.error,
    required this.onError,
    required this.outline,
    required this.focusRing,
    required this.disabledSurface,
    required this.onDisabled,
  });

  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color accent;
  final Color onAccent;
  final Color error;
  final Color onError;
  final Color outline;
  final Color focusRing;
  final Color disabledSurface;
  final Color onDisabled;

  /// Focus-indicator color for a control filled with [fill].
  ///
  /// No single token clears 3:1 against both the brand fills and the neutral
  /// surfaces, so the ring color actually drawn on a filled control is chosen
  /// per fill from the tokens that clear the fill it borders.
  Color focusRingFor(Color fill) => focusRingForAll(<Color>[fill]);

  /// Focus-indicator color clearing 3:1 against every fill in [fills].
  ///
  /// Used by a control family that can render more than one fill, such as a
  /// filled button that is either primary or danger/error.
  Color focusRingForAll(Iterable<Color> fills) {
    final List<Color> targets = fills.toList(growable: false);
    if (targets.isEmpty) {
      return focusRing;
    }
    for (final Color candidate in <Color>[focusRing, onSurface, surface]) {
      if (targets.every((fill) => appContrastRatio(candidate, fill) >= 3.0)) {
        return candidate;
      }
    }
    return surface;
  }

  /// Pressed/focused/hovered overlay for a control filled with [fill].
  ///
  /// Picks the ink token most distinct from the fill instead of reusing
  /// [primary] unconditionally, so the overlay stays visible on a primary or
  /// danger fill.
  Color controlOverlay(Color fill) {
    final Color ink =
        appContrastRatio(onSurface, fill) >= appContrastRatio(surface, fill)
        ? onSurface
        : surface;
    return ink.withValues(alpha: 0.2);
  }

  static const AppTokens light = AppTokens(
    surface: AppBrandColors.white,
    onSurface: Color(0xFF1A1A1A),
    surfaceVariant: Color(0xFFF2F4F7),
    onSurfaceVariant: Color(0xFF3D4654),
    primary: AppBrandColors.primary,
    onPrimary: AppBrandColors.white,
    secondary: AppBrandColors.secondary,
    onSecondary: AppBrandColors.primary,
    accent: AppBrandColors.accent,
    onAccent: AppBrandColors.white,
    error: Color(0xFFB3261E),
    onError: AppBrandColors.white,
    outline: Color(0xFF6B7280),
    focusRing: Color(0xFF3A6FD8),
    disabledSurface: Color(0xFFE3E6EA),
    onDisabled: Color(0xFF4B5563),
  );

  static const AppTokens dark = AppTokens(
    surface: Color(0xFF101418),
    onSurface: Color(0xFFE6E9EE),
    surfaceVariant: Color(0xFF1F262E),
    onSurfaceVariant: Color(0xFFC3CAD4),
    primary: Color(0xFFA8C7FA),
    onPrimary: AppBrandColors.primary,
    secondary: Color(0xFF8CD8FF),
    onSecondary: AppBrandColors.primary,
    accent: Color(0xFFFF6B6B),
    onAccent: Color(0xFF101418),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF8A9199),
    focusRing: Color(0xFFE6E9EE),
    disabledSurface: Color(0xFF2A323B),
    onDisabled: Color(0xFF9AA3AD),
  );

  @override
  AppTokens copyWith({
    Color? surface,
    Color? onSurface,
    Color? surfaceVariant,
    Color? onSurfaceVariant,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? accent,
    Color? onAccent,
    Color? error,
    Color? onError,
    Color? outline,
    Color? focusRing,
    Color? disabledSurface,
    Color? onDisabled,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      outline: outline ?? this.outline,
      focusRing: focusRing ?? this.focusRing,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      onDisabled: onDisabled ?? this.onDisabled,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      disabledSurface: Color.lerp(disabledSurface, other.disabledSurface, t)!,
      onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
    );
  }
}

/// Builds the light and dark themes from the shared tokens.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppTokens.light);

  static ThemeData get dark => _build(Brightness.dark, AppTokens.dark);

  static AppTokens tokensOf(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? AppTokens.light;

  /// Caption rendered above a control in a filtered toolbar. A static label
  /// (never a floating one) keeps the caption out of the value area at every
  /// text scale, matching the labelSmall+body idiom used by detail pages.
  static TextStyle? barFieldCaption(
    BuildContext context, {
    bool enabled = true,
  }) {
    final AppTokens tokens = tokensOf(context);
    return Theme.of(context).textTheme.labelMedium?.copyWith(
      color: enabled ? tokens.onSurfaceVariant : tokens.onDisabled,
      fontWeight: FontWeight.w600,
    );
  }

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      secondary: tokens.secondary,
      onSecondary: tokens.onSecondary,
      error: tokens.error,
      onError: tokens.onError,
      surface: tokens.surface,
      onSurface: tokens.onSurface,
      surfaceContainerHighest: tokens.surfaceVariant,
      onSurfaceVariant: tokens.onSurfaceVariant,
      outline: tokens.outline,
      outlineVariant: tokens.outline,
      tertiary: tokens.accent,
      onTertiary: tokens.onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.surface,
      extensions: <ThemeExtension<dynamic>>[tokens],
      textTheme: _textTheme(brightness),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          tokens,
          fill: tokens.primary,
          ringFills: <Color>[tokens.primary, tokens.error],
        ),
      ),
      // Material 3 ElevatedButton is surface-filled: its background is
      // ColorScheme.surfaceContainerLow, which falls back to surface in this
      // custom scheme. Declaring primary here would measure the ring and
      // overlay against a fill the button never renders.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(tokens, fill: tokens.surface),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          tokens,
          fill: tokens.surface,
          minHeight: AppSizes.compactControlHeight,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(
          tokens,
          fill: tokens.surface,
          minHeight: AppSizes.compactControlHeight,
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.dialogRadius),
      ),
      inputDecorationTheme: _inputDecorationTheme(tokens),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.onSurface,
        contentTextStyle: TextStyle(color: tokens.surface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.controlRadius,
        ),
      ),
    );
  }

  /// Platform typography with the S10 body minimum applied. No custom family.
  static TextTheme _textTheme(Brightness brightness) {
    final TextTheme base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return base.copyWith(
      bodyLarge: base.bodyLarge!.copyWith(fontSize: 18),
      bodyMedium: base.bodyMedium!.copyWith(fontSize: AppSizes.bodyFontSize),
      labelLarge: base.labelLarge!.copyWith(fontSize: AppSizes.bodyFontSize),
    );
  }

  static ButtonStyle _buttonStyle(
    AppTokens tokens, {
    required Color fill,
    double minHeight = AppSizes.controlHeight,
    List<Color>? ringFills,
  }) {
    final List<Color> ringTargets = ringFills ?? <Color>[fill];
    final Color focusColor = tokens.focusRingForAll(ringTargets);
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(AppSizes.minTouchTarget, minHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
      ),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontSize: AppSizes.bodyFontSize, fontWeight: FontWeight.w600),
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.pressed)) {
          return tokens.controlOverlay(fill);
        }
        if (states.contains(WidgetState.focused)) {
          return tokens.controlOverlay(fill);
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.controlOverlay(fill).withValues(alpha: 0.12);
        }
        return null;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: focusColor, width: 2);
        }
        return null;
      }),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(AppTokens tokens) {
    final OutlineInputBorder base = OutlineInputBorder(
      borderRadius: AppRadii.controlRadius,
      borderSide: BorderSide(color: tokens.outline),
    );
    return InputDecorationTheme(
      border: base,
      enabledBorder: base,
      focusedBorder: base.copyWith(
        borderSide: BorderSide(color: tokens.focusRing, width: 2),
      ),
      errorBorder: base.copyWith(
        borderSide: BorderSide(color: tokens.error, width: 2),
      ),
      focusedErrorBorder: base.copyWith(
        borderSide: BorderSide(color: tokens.error, width: 2),
      ),
      errorStyle: TextStyle(color: tokens.error),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x3,
      ),
    );
  }
}

double _linearize(double channel) {
  if (channel <= 0.03928) {
    return channel / 12.92;
  }
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG 2.x relative luminance of an sRGB color.
double appRelativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// WCAG 2.x contrast ratio between two opaque sRGB colors.
double appContrastRatio(Color a, Color b) {
  final double la = appRelativeLuminance(a);
  final double lb = appRelativeLuminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
