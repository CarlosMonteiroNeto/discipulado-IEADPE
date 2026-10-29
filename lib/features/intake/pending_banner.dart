import 'package:flutter/material.dart';

import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';

/// Entry point to the pending review queue, shown above the converts list.
class PendingBanner extends StatelessWidget {
  const PendingBanner({
    super.key,
    required this.count,
    required this.onReview,
    this.capped = false,
  });

  final int count;
  final bool capped;
  final VoidCallback onReview;

  String get _summary {
    if (capped) return 'Mais de $count cadastros pendentes';
    return count == 1 ? '1 cadastro pendente' : '$count cadastros pendentes';
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Base44Panel(
      key: const ValueKey('pending-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedSpace.x3,
        vertical: UnifiedSpace.x1,
      ),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.inbox_outlined,
              color: UnifiedColors.brandNavy,
            ),
          ),
          const SizedBox(width: UnifiedSpace.x2),
          Expanded(
            child: Text(
              _summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: UnifiedColors.brandNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('pending-banner-review'),
            onPressed: onReview,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }
}
