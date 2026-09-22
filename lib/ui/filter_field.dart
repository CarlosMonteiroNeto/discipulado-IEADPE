/// A labelled filter dropdown shared by every list toolbar.
///
/// The static [label] caption sits above the field instead of floating inside
/// it, so the label can never overlap the selected value no matter the text
/// scale (the floating-label variant in Flutter clips at high scales). The
/// field itself expands to its parent's width (`isExpanded`), truncates long
/// items with an ellipsis, and offers an explicit "all / none" [nullLabel]
/// option. Callers place it inside [AppFilterBar], which sizes the fields.
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

  /// The caption shown above the field.
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
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: AppTheme.barFieldCaption(context, enabled: enabled),
        ),
        const SizedBox(height: AppSpacing.x1),
        DropdownButtonFormField<T?>(
          key: fieldKey,
          initialValue: value,
          isExpanded: true,
          iconEnabledColor: enabled ? null : tokens.outline,
          decoration: InputDecoration(
            enabled: enabled,
            filled: !enabled,
            fillColor: tokens.disabledSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x3,
            ),
          ),
          items: <DropdownMenuItem<T?>>[
            DropdownMenuItem<T?>(value: null, child: _ellipsized(nullLabel)),
            for (final AppFilterOption<T> option in options)
              DropdownMenuItem<T?>(
                value: option.value,
                key: option.key,
                child: _ellipsized(option.label),
              ),
            if (fallback != null)
              DropdownMenuItem<T?>(
                value: fallback!.value,
                key: fallback!.key,
                child: _ellipsized(fallback!.label),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  Widget _ellipsized(String text) => Text(
    text,
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}