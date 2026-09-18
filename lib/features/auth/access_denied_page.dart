/// Shown for a signed-in identity without an active access profile (S04, S10).
library;

import 'package:flutter/material.dart';

import '../../ui/app_theme.dart';
import '../../ui/form_fields.dart';
import 'auth_controller.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key, required this.controller});

  final AuthController controller;

  static const Key signOutKey = Key('access-denied-sign-out');

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline,
                    size: AppSizes.controlHeight,
                    color: tokens.outline,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    'Acesso não autorizado',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Sua conta não possui um perfil ativo. Saia e contate um responsável.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  AppButton(
                    key: signOutKey,
                    label: 'Sair',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => controller.signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
