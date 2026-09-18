/// Class create/edit form with an eligible-teacher selector (S05, S08).
///
/// Only active local contacts holding the teacher role are selectable; a
/// backend validation, conflict or unavailable failure keeps the operator's
/// in-memory values and offers an explicit reload.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/class_group.dart';
import '../../domain/common.dart';
import '../../domain/contact.dart';
import '../../domain/ports.dart';
import '../../ui/app_theme.dart';
import '../../ui/dirty_form_guard.dart';
import '../../ui/form_fields.dart';
import 'academic_repository.dart';

class ClassFormConfig {
  const ClassFormConfig({
    required this.congregationId,
    this.classId,
    this.expectedRevision,
    this.initial,
  });

  final String congregationId;
  final String? classId;
  final int? expectedRevision;
  final ClassGroup? initial;

  bool get isEditing => classId != null;
}

class ClassForm extends StatefulWidget {
  const ClassForm({
    super.key,
    required this.repository,
    required this.config,
    this.onSaved,
    this.onCancel,
  });

  final AcademicRepository repository;
  final ClassFormConfig config;
  final ValueChanged<AcademicMutationResult>? onSaved;
  final VoidCallback? onCancel;

  static const String invalidDateMessage =
      'Data inválida. Use o formato dd/MM/aaaa.';
  static const String endBeforeStartMessage =
      'A data de término deve ser igual ou posterior à data de início.';

  static const Key nameFieldKey = Key('class-form-name');
  static const Key teacherFieldKey = Key('class-form-teacher');
  static const Key startDateFieldKey = Key('class-form-start-date');
  static const Key endDateFieldKey = Key('class-form-end-date');
  static const Key saveKey = Key('class-form-save');
  static const Key cancelKey = Key('class-form-cancel');
  static const Key errorKey = Key('class-form-error');
  static const Key reloadKey = Key('class-form-reload');

  @override
  State<ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<ClassForm> {
  final GlobalKey<AppFormState> _formKey = GlobalKey<AppFormState>();
  final DirtyFormGuard _guard = DirtyFormGuard();

  late final TextEditingController _name;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;

  List<Contact> _teachers = const <Contact>[];
  String? _teacherId;
  int? _expectedRevision;
  AppFailure? _failure;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final ClassGroup? initial = widget.config.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _startDate = TextEditingController(
      text: initial == null ? '' : formatBrazilianDate(initial.startDate),
    );
    _endDate = TextEditingController(
      text: initial?.endDate == null
          ? ''
          : formatBrazilianDate(initial!.endDate!),
    );
    _teacherId = initial?.teacherContactId;
    _expectedRevision = widget.config.expectedRevision ?? initial?.revision;
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _startDate,
      _endDate,
    ]) {
      controller.addListener(_guard.markDirty);
    }
    _loadTeachers();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _startDate,
      _endDate,
    ]) {
      controller.removeListener(_guard.markDirty);
      controller.dispose();
    }
    _guard.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final List<Contact> teachers = await widget.repository
          .listEligibleTeachers(congregationId: widget.config.congregationId);
      if (!mounted) return;
      setState(() => _teachers = teachers);
    } on AppFailure {
      // Keep an empty selector; the form remains usable for editing.
    }
  }

  String? _validateRequiredDate(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Informe a data.';
    }
    return parseBrazilianDate(raw) == null
        ? ClassForm.invalidDateMessage
        : null;
  }

  String? _validateOptionalDate(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return parseBrazilianDate(raw) == null
        ? ClassForm.invalidDateMessage
        : null;
  }

  Future<void> _submit() async {
    final bool valid =
        _formKey.currentState?.validateAndFocusFirstError() ?? false;
    if (!valid) {
      return;
    }
    final CalendarDate? startDate = parseBrazilianDate(_startDate.text);
    if (startDate == null) {
      return;
    }
    final String endRaw = _endDate.text.trim();
    final CalendarDate? endDate = endRaw.isEmpty
        ? null
        : parseBrazilianDate(endRaw);
    if (endDate != null && endDate.compareTo(startDate) < 0) {
      setState(
        () => _failure = const AppFailure(
          code: AppFailureCode.validation,
          message: ClassForm.endBeforeStartMessage,
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final AcademicMutationResult result = await widget.repository.saveClass(
        draft: ClassDraft(
          name: _name.text,
          startDate: startDate,
          teacherContactId: _teacherId,
          endDate: endDate,
        ),
        congregationId: widget.config.congregationId,
        id: widget.config.classId,
        expectedRevision: _expectedRevision,
      );
      if (!mounted) return;
      _guard.markClean();
      setState(() => _submitting = false);
      widget.onSaved?.call(result);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      // The in-memory values are preserved; nothing is persisted locally.
      setState(() {
        _submitting = false;
        _failure = failure;
      });
    }
  }

  Future<void> _reload() async {
    final String? id = widget.config.classId;
    if (id == null) {
      setState(() => _failure = null);
      return;
    }
    try {
      final ClassGroup? classGroup = await widget.repository.getClass(
        id: id,
        congregationId: widget.config.congregationId,
      );
      if (!mounted) return;
      setState(() {
        if (classGroup != null) {
          _expectedRevision = classGroup.revision;
        }
        _failure = null;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    }
  }

  Future<void> _cancel() async {
    final bool leave = await _guard.confirmLeave(context);
    if (!leave || !mounted) {
      return;
    }
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final Widget form = AppForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            key: ClassForm.nameFieldKey,
            label: 'Nome',
            controller: _name,
            required: true,
            validator: (String? value) {
              final String trimmed = (value ?? '').trim();
              if (trimmed.length < 2) {
                return 'O nome deve ter pelo menos 2 caracteres.';
              }
              if (trimmed.length > 120) {
                return 'O nome deve ter no máximo 120 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.x3),
          DropdownButtonFormField<String?>(
            key: ClassForm.teacherFieldKey,
            initialValue: _teacherId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Professor(a)'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('Sem professor')),
              for (final Contact teacher in _teachers)
                DropdownMenuItem<String?>(
                  value: teacher.id,
                  child: Text(teacher.name),
                ),
            ],
            onChanged: _submitting
                ? null
                : (String? value) => setState(() {
                    _teacherId = value;
                    _guard.markDirty();
                  }),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: ClassForm.startDateFieldKey,
            label: 'Início',
            controller: _startDate,
            required: true,
            helperText: 'Formato dd/MM/aaaa.',
            keyboardType: TextInputType.datetime,
            validator: _validateRequiredDate,
          ),
          const SizedBox(height: AppSpacing.x3),
          AppTextField(
            key: ClassForm.endDateFieldKey,
            label: 'Término',
            controller: _endDate,
            helperText: 'Formato dd/MM/aaaa.',
            keyboardType: TextInputType.datetime,
            validator: _validateOptionalDate,
          ),
          if (_failure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x4),
            Text(
              _failure!.message,
              key: ClassForm.errorKey,
              style: TextStyle(color: tokens.error),
            ),
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                key: ClassForm.reloadKey,
                label: 'Recarregar',
                variant: AppButtonVariant.secondary,
                onPressed: _reload,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (widget.onCancel != null)
                AppButton(
                  key: ClassForm.cancelKey,
                  label: 'Cancelar',
                  variant: AppButtonVariant.text,
                  onPressed: _cancel,
                ),
              const SizedBox(width: AppSpacing.x2),
              AppButton(
                key: ClassForm.saveKey,
                label: 'Salvar',
                isSubmitting: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
      },
      child: _guard.wrap(context, child: form),
    );
  }
}
