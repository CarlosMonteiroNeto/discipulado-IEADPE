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
}

ThemeData buildUnifiedTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: UnifiedColors.brandBlue),
  scaffoldBackgroundColor: UnifiedColors.page,
  appBarTheme: const AppBarTheme(
    backgroundColor: UnifiedColors.brandNavy,
    foregroundColor: Colors.white,
  ),
);
