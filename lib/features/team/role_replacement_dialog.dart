/// Explicit confirmation before replacing the holder of an administrative
/// role (S06, S10). Cancelling sends no mutation; a conflict preserves the
/// selection and offers a reload.
library;

import 'package:flutter/material.dart';

import '../../domain/ports.dart';
import '../../ui/app_theme.dart';
import '../../ui/form_fields.dart';
import 'team_repository.dart';

class RoleReplacementDialog extends StatefulWidget {
  const RoleReplacementDialog({
    super.key,
    required this.repository,
    required this.request,
    required this.roleLabel,
    required this.holderName,
    this.onReload,
  });

  final TeamRepository repository;
  final RoleReplacementRequest request;
  final String roleLabel;
  final String holderName;

  /// Called when the operator asks to reload after a conflict.
  final Future<void> Function()? onReload;

  static const Key confirmKey = Key('role-replace-confirm');
  static const Key cancelKey = Key('role-replace-cancel');
  static const Key conflictKey = Key('role-replace-conflict');
  static const Key reloadKey = Key('role-replace-reload');
  static const Key holderKey = Key('role-replace-holder');

  @override
  State<RoleReplacementDialog> createState() => _RoleReplacementDialogState();
}

class _RoleReplacementDialogState extends State<RoleReplacementDialog> {
  bool _submitting = false;
  AppFailure? _conflict;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _conflict = null;
    });
    try {
      await widget.repository.replaceRoleHolder(request: widget.request);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _conflict = failure;
      });
    }
  }

  Future<void> _reload() async {
    await widget.onReload?.call();
    if (!mounted) return;
    setState(() => _conflict = null);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return AlertDialog(
      title: const Text('Substituir responsável'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Papel'),
          const SizedBox(height: AppSpacing.x1),
          Text(widget.roleLabel),
          const SizedBox(height: AppSpacing.x2),
          const Text('Responsável atual'),
          const SizedBox(height: AppSpacing.x1),
          Text(widget.holderName, key: RoleReplacementDialog.holderKey),
          if (_conflict != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            Text(
              _conflict!.message,
              key: RoleReplacementDialog.conflictKey,
              style: TextStyle(color: tokens.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (_conflict != null)
          AppButton(
            key: RoleReplacementDialog.reloadKey,
            label: 'Recarregar',
            variant: AppButtonVariant.secondary,
            onPressed: _submitting ? null : _reload,
          ),
        AppButton(
          key: RoleReplacementDialog.cancelKey,
          label: 'Cancelar',
          variant: AppButtonVariant.text,
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        AppButton(
          key: RoleReplacementDialog.confirmKey,
          label: 'Substituir',
          variant: AppButtonVariant.danger,
          isSubmitting: _submitting,
          onPressed: _submitting ? null : _confirm,
        ),
      ],
    );
  }
}
