import 'package:flutter/material.dart';

/// The shared Base44 palette used by the convert and ministry surfaces.
abstract final class UnifiedColors {
  static const brandNavy = Color(0xff1e3a5f);
  static const brandBlue = Color(0xff2563eb);
  static const page = Color(0xfff8fafc);
  static const pageTint = Color(0xffeff6ff);
  static const surface = Colors.white;
  static const selected = Color(0xffdbeafe);
  static const text = Color(0xff1e293b);
  static const muted = Color(0xff64748b);
  static const border = Color(0xffe2e8f0);
  static const borderStrong = Color(0xff64748b);
  static const focus = brandBlue;
  static const success = Color(0xff166534);
  static const successSurface = Color(0xffdcfce7);
  static const warning = Color(0xff78350f);
  static const warningSurface = Color(0xfffef3c7);
  static const error = Color(0xffb91c1c);
  static const errorSurface = Color(0xfffee2e2);
  static const disabledText = Color(0xff475569);
  static const disabledSurface = Color(0xffe2e8f0);
  static const whatsapp = Color(0xff15803d);

  /// Retained for existing convert surfaces that already use these names.
  static const green = whatsapp;
  static const red = error;
}

/// Spacing values used by shared layouts and form content.
abstract final class UnifiedSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x12 = 48.0;

  static const phoneInset = x4;
  static const wideInset = x6;
  static const fieldGap = x4;
  static const sectionGap = x6;
}

abstract final class UnifiedRadius {
  static const compact = 8.0;
  static const standard = 12.0;
  static const large = 16.0;
  static const badge = 999.0;
}

abstract final class UnifiedType {
  static const bodySize = 16.0;
  static const bodyHeight = 1.5;
  static const supportingSize = 14.0;
  static const supportingHeight = 1.4;
  static const sectionSize = 20.0;
  static const sectionHeight = 1.3;
  static const pageTitleSize = 24.0;
  static const pageTitleHeight = 1.2;
}

abstract final class UnifiedSize {
  static const inlineIcon = 20.0;
  static const actionIcon = 24.0;
  static const minTouchTarget = 48.0;
}

abstract final class UnifiedLayout {
  static const navigationBreakpoint = 768.0;
  static const maxContentWidth = 896.0;
}

abstract final class UnifiedMotion {
  static Duration durationFor(
    BuildContext context, {
    Duration requested = const Duration(milliseconds: 180),
  }) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : requested;
}

ThemeData buildUnifiedTheme() {
  const colors = ColorScheme.light(
    primary: UnifiedColors.brandNavy,
    onPrimary: Colors.white,
    primaryContainer: UnifiedColors.selected,
    onPrimaryContainer: UnifiedColors.brandNavy,
    secondary: UnifiedColors.brandBlue,
    onSecondary: Colors.white,
    secondaryContainer: UnifiedColors.pageTint,
    onSecondaryContainer: UnifiedColors.brandNavy,
    tertiary: UnifiedColors.success,
    onTertiary: Colors.white,
    tertiaryContainer: UnifiedColors.successSurface,
    onTertiaryContainer: UnifiedColors.success,
    error: UnifiedColors.error,
    onError: Colors.white,
    errorContainer: UnifiedColors.errorSurface,
    onErrorContainer: UnifiedColors.error,
    surface: UnifiedColors.surface,
    onSurface: UnifiedColors.text,
    outline: UnifiedColors.borderStrong,
    outlineVariant: UnifiedColors.border,
    surfaceTint: Colors.transparent,
  );
  final baseText = ThemeData.light().textTheme;
  final text = baseText.copyWith(
    bodyLarge: const TextStyle(
      fontSize: UnifiedType.bodySize,
      height: UnifiedType.bodyHeight,
      color: UnifiedColors.text,
    ),
    bodyMedium: const TextStyle(
      fontSize: UnifiedType.bodySize,
      height: UnifiedType.bodyHeight,
      color: UnifiedColors.text,
    ),
    bodySmall: const TextStyle(
      fontSize: UnifiedType.supportingSize,
      height: UnifiedType.supportingHeight,
      color: UnifiedColors.muted,
    ),
    titleLarge: const TextStyle(
      fontSize: UnifiedType.sectionSize,
      height: UnifiedType.sectionHeight,
      color: UnifiedColors.text,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: const TextStyle(
      fontSize: UnifiedType.pageTitleSize,
      height: UnifiedType.pageTitleHeight,
      color: UnifiedColors.brandNavy,
      fontWeight: FontWeight.w700,
    ),
  );
  const fieldRadius = BorderRadius.all(Radius.circular(UnifiedRadius.standard));
  const compactRadius = BorderRadius.all(
    Radius.circular(UnifiedRadius.compact),
  );
  const panelRadius = BorderRadius.all(Radius.circular(UnifiedRadius.standard));
  const dialogRadius = BorderRadius.all(Radius.circular(UnifiedRadius.large));
  const inputOutline = OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: UnifiedColors.borderStrong),
  );
  const focusedInputOutline = OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: UnifiedColors.focus, width: 2),
  );
  final focusRing = WidgetStateProperty.resolveWith<BorderSide>((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: Colors.white, width: 2);
    }
    return BorderSide.none;
  });
  final secondaryFocusRing = WidgetStateProperty.resolveWith<BorderSide>((
    states,
  ) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: UnifiedColors.focus, width: 2);
    }
    return const BorderSide(color: UnifiedColors.brandNavy);
  });

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: UnifiedColors.page,
    visualDensity: VisualDensity.standard,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: UnifiedColors.brandNavy,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: UnifiedColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x140f172a),
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: UnifiedColors.border),
        borderRadius: panelRadius,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: UnifiedColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UnifiedSpace.x4,
        vertical: UnifiedSpace.x3,
      ),
      border: inputOutline,
      enabledBorder: inputOutline,
      disabledBorder: inputOutline,
      focusedBorder: focusedInputOutline,
      errorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: UnifiedColors.error, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: UnifiedColors.error, width: 2),
      ),
      labelStyle: text.bodyMedium,
      hintStyle: text.bodyMedium?.copyWith(color: UnifiedColors.muted),
      helperStyle: text.bodySmall,
      errorStyle: text.bodySmall?.copyWith(color: UnifiedColors.error),
      prefixIconColor: UnifiedColors.muted,
      suffixIconColor: UnifiedColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          UnifiedSize.minTouchTarget,
          UnifiedSize.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedSpace.x4,
          vertical: UnifiedSpace.x3,
        ),
        foregroundColor: Colors.white,
        backgroundColor: UnifiedColors.brandNavy,
        disabledForegroundColor: UnifiedColors.disabledText,
        disabledBackgroundColor: UnifiedColors.disabledSurface,
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ).copyWith(side: focusRing),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          UnifiedSize.minTouchTarget,
          UnifiedSize.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedSpace.x4,
          vertical: UnifiedSpace.x3,
        ),
        foregroundColor: UnifiedColors.brandNavy,
        disabledForegroundColor: UnifiedColors.disabledText,
        side: const BorderSide(color: UnifiedColors.brandNavy),
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ).copyWith(side: secondaryFocusRing),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(
          UnifiedSize.minTouchTarget,
          UnifiedSize.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedSpace.x3,
          vertical: UnifiedSpace.x2,
        ),
        foregroundColor: UnifiedColors.brandNavy,
        disabledForegroundColor: UnifiedColors.disabledText,
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ).copyWith(side: secondaryFocusRing),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(
          UnifiedSize.minTouchTarget,
          UnifiedSize.minTouchTarget,
        ),
        foregroundColor: UnifiedColors.brandNavy,
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ).copyWith(side: secondaryFocusRing),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: UnifiedColors.surface,
      selectedColor: UnifiedColors.selected,
      labelStyle: text.bodySmall?.copyWith(color: UnifiedColors.text),
      side: const BorderSide(color: UnifiedColors.border),
      shape: RoundedRectangleBorder(borderRadius: compactRadius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: UnifiedColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: dialogRadius),
    ),
    dividerTheme: const DividerThemeData(color: UnifiedColors.border),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: UnifiedColors.brandBlue,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: UnifiedColors.brandNavy,
      foregroundColor: Colors.white,
      focusColor: UnifiedColors.focus,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: UnifiedColors.brandNavy,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    disabledColor: UnifiedColors.disabledText,
    focusColor: UnifiedColors.focus,
    hoverColor: UnifiedColors.selected,
  );
}
