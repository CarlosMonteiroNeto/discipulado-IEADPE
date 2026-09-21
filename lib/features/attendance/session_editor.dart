/// Session creation form. Preserves date/topic on failure and prevents a
/// duplicate submission (S08, S10).
library;

import 'package:flutter/material.dart';

import '../../domain/common.dart';
import '../../domain/ports.dart';
import '../../ui/app_theme.dart';
import '../../ui/form_fields.dart';
import '../classes/academic_repository.dart';

class SessionEditor extends StatefulWidget {
  const SessionEditor({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.classId,
    this.onCreated,
    this.onCancel,
  });

  final AcademicRepository repository;
  final String congregationId;
  final String classId;
  final ValueChanged<AcademicMutationResult>? onCreated;
  final VoidCallback? onCancel;

  static const String invalidDateMessage =
      'Data inválida. Use o formato dd/MM/aaaa.';

  static const Key dateFieldKey = Key('session-form-date');
  static const Key topicFieldKey = Key('session-form-topic');
  static const Key saveKey = Key('session-form-save');
  static const Key cancelKey = Key('session-form-cancel');
  static const Key errorKey = Key('session-form-error');

  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  final TextEditingController _date = TextEditingController();
  final TextEditingController _topic = TextEditingController();
  bool _submitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _date.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final CalendarDate? date = parseBrazilianDate(_date.text);
    if (date == null) {
      setState(
        () => _failure = const AppFailure(
          code: AppFailureCode.validation,
          message: SessionEditor.invalidDateMessage,
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final String topic = _topic.text.trim();
      final AcademicMutationResult result = await widget.repository
          .createSession(
            congregationId: widget.congregationId,
            classId: widget.classId,
            date: date,
            topic: topic.isEmpty ? null : topic,
          );
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onCreated?.call(result);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      // The typed date and topic are preserved for an explicit retry.
      setState(() {
        _submitting = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Nova chamada', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.x3),
        AppDateField(
          key: SessionEditor.dateFieldKey,
          label: 'Data',
          controller: _date,
          helperText: 'Formato dd/MM/aaaa.',
        ),
        const SizedBox(height: AppSpacing.x3),
        AppTextField(
          key: SessionEditor.topicFieldKey,
          label: 'Tema',
          controller: _topic,
        ),
        if (_failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          Text(
            _failure!.message,
            key: SessionEditor.errorKey,
            style: TextStyle(color: tokens.error),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (widget.onCancel != null)
              AppButton(
                key: SessionEditor.cancelKey,
                label: 'Cancelar',
                variant: AppButtonVariant.text,
                onPressed: _submitting ? null : widget.onCancel,
              ),
            const SizedBox(width: AppSpacing.x2),
            AppButton(
              key: SessionEditor.saveKey,
              label: 'Criar chamada',
              isSubmitting: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
