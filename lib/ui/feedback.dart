import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app_theme.dart';

enum AppFeedbackType { success, error, info }

/// Shared keys and defaults for the transient outcome channel.
abstract final class AppFeedback {
  static const Key messageKey = Key('app-feedback-message');
  static const Duration defaultDuration = Duration(seconds: 4);
}

/// Shows a transient message that screen readers announce as a live region.
void showAppFeedback(
  BuildContext context, {
  required String message,
  AppFeedbackType type = AppFeedbackType.info,
  Duration duration = AppFeedback.defaultDuration,
}) {
  final AppTokens tokens = AppTheme.tokensOf(context);
  final bool isError = type == AppFeedbackType.error;
  final Color background = isError ? tokens.error : tokens.onSurface;
  final Color foreground = isError ? tokens.onError : tokens.surface;
  final IconData icon = switch (type) {
    AppFeedbackType.success => Icons.check_circle_outline,
    AppFeedbackType.error => Icons.error_outline,
    AppFeedbackType.info => Icons.info_outline,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: background,
      duration: duration,
      content: Row(
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Semantics(
              key: AppFeedback.messageKey,
              liveRegion: true,
              label: message,
              excludeSemantics: true,
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Announces an outcome directly to assistive technology.
Future<void> announceToScreenReader(BuildContext context, String message) =>
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
