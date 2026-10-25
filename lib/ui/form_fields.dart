import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'br_input.dart';

/// Input formatter for the national Brazilian phone shape.
class BrPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBefore = brPhoneNationalDigits(
      newValue.text.substring(0, cursor),
    ).length;
    final digits = brPhoneNationalDigits(newValue.text);
    final formatted = formatBrPhone(digits);

    var seen = 0;
    var offset = 0;
    while (offset < formatted.length && seen < digitsBefore) {
      if (RegExp(r'\d').hasMatch(formatted[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// A text field that validates after the first blur and on every later edit.
class AppTextFormField extends StatefulWidget {
  const AppTextFormField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    this.helperText,
    this.hintText,
    this.validator,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.prefixIcon,
    this.autofillHints,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onChanged,
    this.floatingLabelBehavior,
    this.contentPadding,
    this.helperMaxLines,
    this.filled = true,
    this.fillColor = Colors.white,
  });

  /// Key exposed to tests and callers without taking the internal FormField key.
  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? hintText;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final EdgeInsetsGeometry? contentPadding;
  final int? helperMaxLines;
  final bool filled;
  final Color fillColor;

  @override
  State<AppTextFormField> createState() => AppTextFormFieldState();
}

class AppTextFormFieldState extends State<AppTextFormField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  void validate() => _fieldKey.currentState?.validate();

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    validate();
    if (mounted && _autovalidateMode == AutovalidateMode.disabled) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.fieldKey,
    child: TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      autovalidateMode: _autovalidateMode,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: widget.helperMaxLines,
        hintText: widget.hintText,
        filled: widget.filled,
        fillColor: widget.fillColor,
        border: const OutlineInputBorder(),
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        floatingLabelBehavior: widget.floatingLabelBehavior,
        contentPadding: widget.contentPadding,
      ),
    ),
  );
}

class BrPhoneField extends StatelessWidget {
  const BrPhoneField({
    super.key,
    this.fieldKey,
    required this.controller,
    this.label = 'Telefone (opcional)',
    this.helperText = '11 dígitos com DDD',
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String helperText;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => AppTextFormField(
    fieldKey: fieldKey,
    controller: controller,
    label: label,
    helperText: helperText,
    enabled: enabled,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.next,
    inputFormatters: [BrPhoneInputFormatter()],
    validator: (value) => brPhoneValidationError(value, required: required),
    focusNode: focusNode,
    onChanged: onChanged,
  );
}

class BrDateField extends StatefulWidget {
  const BrDateField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    this.helperText = 'Selecione no calendário',
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.allowClear = false,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.onChanged,
    this.focusNode,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String helperText;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool readOnly;
  final bool allowClear;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;
  final ValueChanged<DateTime?>? onChanged;
  final FocusNode? focusNode;

  @override
  State<BrDateField> createState() => _BrDateFieldState();
}

class _BrDateFieldState extends State<BrDateField> {
  final _field = GlobalKey<AppTextFormFieldState>();

  DateTime get _firstDate => widget.firstDate ?? DateTime(1900);

  DateTime get _lastDate => widget.lastDate ?? DateTime(2100);

  @override
  void initState() {
    super.initState();
    final display = brDateDisplay(widget.controller.text);
    if (display.isNotEmpty && display != widget.controller.text) {
      widget.controller.text = display;
    }
    widget.controller.addListener(_refreshSuffix);
  }

  @override
  void didUpdateWidget(covariant BrDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshSuffix);
      widget.controller.addListener(_refreshSuffix);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshSuffix);
    super.dispose();
  }

  void _refreshSuffix() {
    if (mounted) setState(() {});
  }

  DateTime _initialDate() {
    final candidate =
        parseDateInput(widget.controller.text) ??
        widget.initialDate ??
        DateTime.now();
    if (candidate.isBefore(_firstDate)) return _firstDate;
    if (candidate.isAfter(_lastDate)) return _lastDate;
    return candidate;
  }

  Future<void> _pick() async {
    if (!widget.enabled || widget.readOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDate(),
      firstDate: _firstDate,
      lastDate: _lastDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: widget.label,
    );
    if (picked == null || !mounted) return;
    widget.controller.text = formatBrDate(picked);
    _field.currentState?.validate();
    widget.onChanged?.call(picked);
  }

  void _clear() {
    widget.controller.clear();
    _field.currentState?.validate();
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final canClear = widget.allowClear && widget.controller.text.isNotEmpty;
    return AppTextFormField(
      key: _field,
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      label: widget.label,
      helperText: widget.helperText,
      enabled: widget.enabled,
      readOnly: true,
      onTap: widget.enabled && !widget.readOnly ? _pick : null,
      keyboardType: TextInputType.datetime,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canClear)
            IconButton(
              tooltip: 'Limpar data',
              onPressed: widget.enabled ? _clear : null,
              icon: const Icon(Icons.close),
            ),
          IconButton(
            tooltip: 'Abrir calendário',
            onPressed: widget.enabled && !widget.readOnly ? _pick : null,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
        ],
      ),
      validator: widget.validator ?? (value) => brDateValidationError(value),
      focusNode: widget.focusNode,
    );
  }
}
