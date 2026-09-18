import 'package:flutter/material.dart';

/// Platform accessibility preferences that affect web chrome.
class WebPreferences {
  const WebPreferences({
    required this.reduceMotion,
    required this.highContrast,
    required this.reduceTransparency,
  });

  final bool reduceMotion;
  final bool highContrast;
  final bool reduceTransparency;

  static WebPreferences fromContext(BuildContext context) {
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    final bool highContrast =
        (media?.highContrast ?? false) || features.highContrast;
    return WebPreferences(
      reduceMotion:
          (media?.disableAnimations ?? false) ||
          features.disableAnimations ||
          features.reduceMotion,
      highContrast: highContrast,
      reduceTransparency: highContrast || features.invertColors,
    );
  }
}

/// Motion helpers that honor reduced-motion settings.
abstract final class AppMotion {
  static bool isReduced(BuildContext context) =>
      WebPreferences.fromContext(context).reduceMotion;

  static Duration durationOf(BuildContext context, Duration normal) =>
      isReduced(context) ? Duration.zero : normal;
}

/// Resolves translucent chrome to its opaque accessibility fallback.
abstract final class AppSurface {
  static Color resolve(
    BuildContext context, {
    required Color translucent,
    required Color opaque,
  }) => WebPreferences.fromContext(context).reduceTransparency
      ? opaque
      : translucent;
}

/// A reversible panel that keeps its child state, never overshoots and drops
/// positional animation entirely under reduced motion.
class AppReversiblePanel extends StatelessWidget {
  const AppReversiblePanel({
    super.key,
    required this.expanded,
    required this.child,
    this.axis = Axis.vertical,
  });

  final bool expanded;
  final Widget child;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final Offset hidden = axis == Axis.horizontal
        ? const Offset(0.05, 0)
        : const Offset(0, 0.05);
    return AnimatedSlide(
      duration: AppMotion.durationOf(
        context,
        const Duration(milliseconds: 200),
      ),
      curve: Curves.easeOut,
      offset: expanded ? Offset.zero : hidden,
      child: child,
    );
  }
}
