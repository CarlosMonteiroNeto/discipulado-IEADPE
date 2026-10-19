import 'package:flutter/material.dart';

import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';

/// Keeps the Admin access tab as a navigation entry into the unified Team UI.
/// Access changes require a scoped contact and are performed there.
class AccessPanel extends StatelessWidget {
  const AccessPanel({super.key, required this.onOpenTeam});

  final VoidCallback onOpenTeam;

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
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onOpenTeam,
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Abrir equipe'),
          ),
        ),
      ],
    ),
  );
}
