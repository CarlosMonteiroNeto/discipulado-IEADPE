import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';

/// A full-page scroll wrapper so the on-screen keyboard never covers the
/// focused field and footer actions stay reachable on small screens.
///
/// The bottom padding tracks the keyboard inset, giving the layout extra room
/// to bring the trailing save/cancel buttons above the keyboard. Painting the
/// content taller than the viewport makes it scrollable; nesting inside an
/// outer scroll view is harmless (it expands to its content).
class AppFormScrollView extends StatelessWidget {
  const AppFormScrollView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
  }
}

class _AppFormFieldEntry {
  const _AppFormFieldEntry(this.fieldKey, this.focusNode);

  final GlobalKey<FormFieldState<String>> fieldKey;
  final FocusNode focusNode;

  bool get hasError => fieldKey.currentState?.hasError ?? false;
}

class _AppFormScope extends InheritedWidget {
  const _AppFormScope({required this.state, required super.child});

  final AppFormState state;

  @override
  bool updateShouldNotify(_AppFormScope oldWidget) => state != oldWidget.state;
}

/// Groups [AppTextField]s and focuses the first invalid field on submit.
class AppForm extends StatefulWidget {
  const AppForm({super.key, required this.child});

  final Widget child;

  static AppFormState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppFormScope>()?.state;

  @override
  State<AppForm> createState() => AppFormState();
}

class AppFormState extends State<AppForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_AppFormFieldEntry> _entries = <_AppFormFieldEntry>[];

  void _register(_AppFormFieldEntry entry) {
    if (!_entries.contains(entry)) {
      _entries.add(entry);
    }
  }

  void _unregister(_AppFormFieldEntry entry) {
    _entries.remove(entry);
  }

  /// Validates every field and, when invalid, focuses the first field that
  /// reported an error so keyboard users land on the problem immediately.
  bool validateAndFocusFirstError() {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      for (final _AppFormFieldEntry entry in _entries) {
        if (entry.hasError) {
          entry.focusNode.requestFocus();
          break;
        }
      }
    }
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    return _AppFormScope(
      state: this,
      child: Form(key: _formKey, child: widget.child),
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.helperText,
    this.required = false,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String? value)? validator;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? helperText;
  final bool required;
  final bool readOnly;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final _AppFormFieldEntry _entry = _AppFormFieldEntry(
    _fieldKey,
    _focusNode,
  );
  AppFormState? _form;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppFormState? form = AppForm.maybeOf(context);
    if (form != _form) {
      _form?._unregister(_entry);
      _form = form;
      _form?._register(_entry);
    }
  }

  @override
  void dispose() {
    _form?._unregister(_entry);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      inputFormatters: widget.inputFormatters,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.required ? '${widget.label} *' : widget.label,
        helperText: widget.helperText,
        suffixIcon: widget.suffixIcon,
        filled: !widget.enabled,
        fillColor: tokens.disabledSurface,
      ),
    );
  }
}

final DateFormat _brazilianDateFormat = DateFormat('dd/MM/yyyy');

/// A date entry field that reads like a [TextFormField] but opens the
/// platform date picker on tap instead of accepting free-form input. The
/// selected date is written back as `dd/MM/yyyy` through the app's formatter
/// so validators keep consuming the same representation.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.enabled = true,
    this.helperText,
    this.focusNode,
    this.required = false,
    this.firstDate,
    this.lastDate,
    this.initialDate,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String? value)? validator;
  final bool enabled;
  final String? helperText;
  final FocusNode? focusNode;
  final bool required;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      validator: validator,
      enabled: enabled,
      helperText: helperText,
      focusNode: focusNode,
      required: required,
      readOnly: true,
      suffixIcon: IconButton(
        tooltip: 'Escolher data',
        icon: const Icon(Icons.calendar_today_outlined),
        onPressed: enabled ? () => _pick(context) : null,
      ),
      onTap: enabled ? () => _pick(context) : null,
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime today = DateTime.now();
    final DateTime? parsed = _parse(controller?.text);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? initialDate ?? today,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(today.year + 100, 12, 31),
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    controller?.text = _brazilianDateFormat.format(picked);
  }

  DateTime? _parse(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    return _brazilianDateFormat.tryParse(text);
  }
}

enum AppButtonVariant { primary, secondary, danger, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isSubmitting = false,
    this.icon,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isSubmitting;
  final IconData? icon;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  static const Key submittingIndicatorKey = Key('app-button-submitting');

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final bool disabled = onPressed == null || isSubmitting;
    final VoidCallback? effectiveOnPressed = disabled ? null : onPressed;
    final Widget child = isSubmitting
        ? Semantics(
            label: semanticLabel ?? 'Processando',
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    key: submittingIndicatorKey,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(label),
              ],
            ),
          )
        : _content(context);

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.error,
          foregroundColor: tokens.onError,
        ),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        child: child,
      ),
    };
  }

  Widget _content(BuildContext context) {
    final Widget text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    if (icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.x2),
        Flexible(child: text),
      ],
    );
  }
}
