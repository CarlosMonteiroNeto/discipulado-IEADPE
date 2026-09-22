/// A filtered toolbar laid out on an aligned control grid.
///
/// [fields] (filter dropdowns and search inputs) share the available width
/// equally and are each capped at [AppSizes.filterFieldMaxWidth], so every
/// field is the same width and its right edge lines up with the others
/// instead of stopping at a ragged position. [actions] (chips, refresh and
/// create buttons) are pinned to the trailing edge. Below
/// [AppSizes.filterBarRowBreakpoint] the fields stack full width and the
/// actions wrap onto their own right-aligned line.
library;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    required this.fields,
    this.actions = const <Widget>[],
  });

  /// The search and filter controls, laid out at equal width.
  final List<Widget> fields;

  /// Trailing controls (filter chips, refresh/create buttons).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < AppSizes.filterBarRowBreakpoint) {
      return _stacked(context);
    }
    return _alignedRow(context);
  }

  Widget _alignedRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < fields.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.filterFieldMaxWidth,
              ),
              child: fields[i],
            ),
          ),
        ],
        if (actions.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.x3),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: actions,
          ),
        ],
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < fields.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.x3),
          fields[i],
        ],
        if (actions.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: actions,
          ),
        ],
      ],
    );
  }
}