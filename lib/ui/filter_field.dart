/// A labelled filter dropdown shared by every list toolbar.
///
/// Wraps `DropdownButtonFormField` with the app's layout rules: a label that
/// always floats above the field (so it never overlaps the selected value),
/// expanded items that truncate with an ellipsis, and an explicit "all / none"
/// null option. [AppSizes.filterControlWidth] sizes the field; callers wrap it
/// in the shared width and let `Wrap` reflow on narrow viewports.
library;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// One selectable option with a stable value and display label.
class AppFilterOption<T> {
  const AppFilterOption({required this.value, required this.label, this.key});

  final T value;
  final String label;

  /// Optional key assigned to the rendered menu item (test seam).
  final Key? key;
}

class AppFilterField<T> extends StatelessWidget {
  const AppFilterField({
    super.key,
    this.fieldKey,
    required this.label,
    required this.nullLabel,
    required this.options,
    required this.onChanged,
    this.value,
    this.enabled = true,
    this.fallback,
  });

  /// Key assigned to the inner [DropdownButtonFormField], so tests and callers
  /// can tap, read and assert on the actual field (the wrapper keeps its own
  /// [key] for the `AppFilterField` element itself).
  final Key? fieldKey;

  /// The `InputDecoration.labelText`.
  final String label;

  /// Label for the null ("Todas" / "Todos") first option.
  final String nullLabel;

  /// The selectable options, excluding the null one.
  final List<AppFilterOption<T>> options;

  /// Invoked with the selected value; `null` selects [nullLabel].
  final ValueChanged<T?>? onChanged;

  /// The currently selected value.
  final T? value;

  /// When false the field renders disabled and ignores taps.
  final bool enabled;

  /// A conditional extra option rendered below [options] (for example the
  /// "Congregação selecionada" placeholder when the selected id is missing
  /// from the catalog).
  final AppFilterOption<T>? fallback;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T?>(
      key: fieldKey,
      initialValue: value,
      isExpanded: true,
      iconEnabledColor: enabled ? null : Theme.of(context).colorScheme.outline,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        enabled: enabled,
      ),
      items: <DropdownMenuItem<T?>>[
        DropdownMenuItem<T?>(value: null, child: _ellipsized(nullLabel)),
        for (final AppFilterOption<T> option in options)
          DropdownMenuItem<T?>(value: option.value, key: option.key, child: _ellipsized(option.label)),
        if (fallback != null)
          DropdownMenuItem<T?>(value: fallback!.value, key: fallback!.key, child: _ellipsized(fallback!.label)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _ellipsized(String text) => Text(
    text,
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}