import 'package:flutter/material.dart';

import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';

/// Keeps the Admin access tab as a navigation entry into the unified Team UI.
/// Access changes require a scoped contact and are performed there.
class AccessPanel extends StatelessWidget {
  const AccessPanel({
    super.key,
    required this.canOpenTeam,
    required this.onOpenTeam,
    required this.onScopeRefresh,
  });

  final bool canOpenTeam;
  final VoidCallback onOpenTeam;
  final Future<void> Function() onScopeRefresh;

  @override
  Widget build(BuildContext context) => Base44Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Base44PageHeading(
          title: 'Acessos da equipe',
          icon: Icons.people_outline,
          subtitle:
              'Gerencie o acesso junto ao contato e à função correspondente.',
        ),
        const SizedBox(height: UnifiedSpace.x3),
        const Text(
          'A concessão, atualização e revogação de acesso ficam no cadastro do contato da equipe.',
        ),
        const SizedBox(height: UnifiedSpace.x3),
        if (!canOpenTeam) ...[
          const SizedBox(height: UnifiedSpace.x3),
          const Text(
            'O servidor não confirmou acesso à equipe. Atualize seu acesso para tentar novamente.',
          ),
          const SizedBox(height: UnifiedSpace.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onScopeRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar acesso'),
            ),
          ),
        ] else ...[
          const SizedBox(height: UnifiedSpace.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onOpenTeam,
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Abrir equipe'),
            ),
          ),
        ],
      ],
    ),
  );
}
