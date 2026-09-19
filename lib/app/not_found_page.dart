/// Safe terminal screens for unknown paths and refused scopes (S10, S12).
///
/// Both consume `lib/ui`/`app_theme.dart` tokens exclusively and never render
/// protected data.
library;

import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.message});

  final String? message;

  static const Key pageKey = Key('not-found-page');
  static const String title = 'Página não encontrada';
  static const String defaultMessage =
      'O endereço acessado não existe ou não está disponível para a sua conta.';

  @override
  Widget build(BuildContext context) {
    return _SafeScreen(
      key: pageKey,
      icon: Icons.search_off,
      title: title,
      message: message ?? defaultMessage,
    );
  }
}

class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key, this.message});

  final String? message;

  static const Key pageKey = Key('forbidden-page');
  static const String title = 'Acesso negado';
  static const String defaultMessage =
      'Você não tem acesso a este recurso nesta congregação.';

  @override
  Widget build(BuildContext context) {
    return _SafeScreen(
      key: pageKey,
      icon: Icons.lock_outline,
      title: title,
      message: message ?? defaultMessage,
    );
  }
}

class _SafeScreen extends StatelessWidget {
  const _SafeScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      backgroundColor: tokens.surface,
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
                    icon,
                    size: AppSizes.controlHeight,
                    color: tokens.outline,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
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
