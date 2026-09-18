import 'package:flutter/material.dart';

import 'confirmation_dialog.dart';

/// Tracks whether a form holds unsaved changes and exposes the hooks needed to
/// intercept in-app routing, browser history and supported unload.
///
/// It deliberately never persists a draft locally: `persistsDraftLocally` is a
/// contract, not a setting, so sensitive form data stays in memory only.
class DirtyFormGuard extends ChangeNotifier {
  bool _dirty = false;
  final List<Future<bool> Function()> _inAppHooks = <Future<bool> Function()>[];
  bool Function()? _unloadHook;

  bool get isDirty => _dirty;

  /// Sensitive drafts are never written to local storage.
  bool get persistsDraftLocally => false;

  /// Whether a browser unload should ask for confirmation.
  bool get shouldConfirmUnload => _unloadHook?.call() ?? _dirty;

  void setDirty(bool value) {
    if (_dirty == value) {
      return;
    }
    _dirty = value;
    notifyListeners();
  }

  void markDirty() => setDirty(true);

  void markClean() => setDirty(false);

  void registerInAppNavigationHook(Future<bool> Function() hook) {
    _inAppHooks.add(hook);
  }

  void registerUnloadConfirmation(bool Function() shouldConfirm) {
    _unloadHook = shouldConfirm;
  }

  /// Runs the registered in-app routing hooks. Returns `false` when any hook
  /// vetoes leaving so the caller can abort the navigation.
  Future<bool> handleInAppNavigation() async {
    if (!_dirty) {
      return true;
    }
    for (final Future<bool> Function() hook in _inAppHooks) {
      final bool allowed = await hook();
      if (!allowed) {
        return false;
      }
    }
    return true;
  }

  /// Asks the user before discarding a dirty draft. Clean drafts leave without
  /// prompting.
  Future<bool> confirmLeave(BuildContext context, {String? message}) {
    if (!_dirty) {
      return Future<bool>.value(true);
    }
    return showConfirmationDialog(
      context,
      title: 'Alterações não salvas',
      message: message ?? 'Descartar as alterações não salvas?',
      confirmLabel: 'Descartar',
      cancelLabel: 'Continuar editando',
      destructive: true,
    );
  }

  /// Wraps a form so browser history and in-app pops are intercepted.
  Widget wrap(BuildContext context, {required Widget child}) {
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool leave = await confirmLeave(context);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
