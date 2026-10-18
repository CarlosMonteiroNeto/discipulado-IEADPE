import 'package:flutter/material.dart';

/// Shared semantic palette. The convert shell's navy to blue gradient remains
/// the brand anchor; ministry pages use the same readable surface and action
/// colors so the two modules feel like one application.
abstract final class UnifiedColors {
  static const brandNavy = Color(0xff1e3a5f);
  static const brandBlue = Color(0xff2563eb);
  static const page = Color(0xfff8fafc);
  static const pageTint = Color(0xffeff6ff);
  static const selected = Color(0xffdbeafe);
  static const text = Color(0xff1e293b);
  static const muted = Color(0xff64748b);
  static const border = Color(0xffe2e8f0);
  static const green = Color(0xff16a34a);
  static const red = Color(0xffb91c1c);
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
    error: UnifiedColors.red,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: UnifiedColors.text,
    surfaceTint: Colors.transparent,
  );
  final text = ThemeData.light().textTheme.apply(
    bodyColor: UnifiedColors.text,
    displayColor: UnifiedColors.text,
  );
  const radius = BorderRadius.all(Radius.circular(12));
  const outline = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: UnifiedColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: UnifiedColors.page,
    visualDensity: VisualDensity.standard,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        color: UnifiedColors.brandNavy,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: text.titleLarge?.copyWith(
        color: UnifiedColors.text,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(
        color: UnifiedColors.text,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: text.bodySmall?.copyWith(color: UnifiedColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: UnifiedColors.brandNavy,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x140f172a),
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: UnifiedColors.border),
        borderRadius: radius,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: outline,
      enabledBorder: outline,
      disabledBorder: outline,
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: UnifiedColors.brandNavy, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: UnifiedColors.red, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: UnifiedColors.red, width: 2),
      ),
      prefixIconColor: UnifiedColors.muted,
      suffixIconColor: UnifiedColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: Colors.white,
        backgroundColor: UnifiedColors.brandNavy,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: UnifiedColors.brandNavy,
        side: const BorderSide(color: UnifiedColors.brandNavy),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        foregroundColor: UnifiedColors.brandNavy,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: UnifiedColors.brandNavy,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: UnifiedColors.selected,
      labelStyle: text.bodySmall?.copyWith(color: UnifiedColors.text),
      side: const BorderSide(color: UnifiedColors.border),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerTheme: const DividerThemeData(color: UnifiedColors.border),
    focusColor: UnifiedColors.brandBlue,
    hoverColor: UnifiedColors.selected,
  );
}
