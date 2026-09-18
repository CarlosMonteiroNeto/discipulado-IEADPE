import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_fields.dart';

/// Stable keys used by tests and by callers that need to target the actions.
abstract final class ConfirmationDialog {
  static const Key dialogKey = Key('confirmation-dialog');
  static const Key confirmKey = Key('confirmation-confirm');
  static const Key cancelKey = Key('confirmation-cancel');
}

/// Shows a focus-trapped confirmation dialog.
///
/// Escape and the cancel action both resolve to `false`; dismissing restores
/// focus to the element that opened the dialog. The returned future completes
/// with the outcome so callers can announce it.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final FocusNode? previousFocus = FocusManager.instance.primaryFocus;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(dialogContext).pop(false),
        },
        child: AlertDialog(
          key: ConfirmationDialog.dialogKey,
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            AppButton(
              key: ConfirmationDialog.cancelKey,
              label: cancelLabel,
              variant: AppButtonVariant.text,
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton(
              key: ConfirmationDialog.confirmKey,
              label: confirmLabel,
              variant: destructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      );
    },
  );
  previousFocus?.requestFocus();
  return confirmed ?? false;
}
