/// Enrollment start and close editor for a class (S07, S08).
///
/// Only unarchived same-congregation students are selectable. The S08 cap of
/// [maxEnrollmentRecords] total enrollment records is explained before adding
/// enrollment 101; an active-enrollment conflict names the existing class; a
/// backend failure keeps the operator's selection and offers an explicit retry.
library;

import 'package:flutter/material.dart';

import '../../domain/class_group.dart';
import '../../domain/common.dart';
import '../../domain/enrollment.dart';
import '../../domain/ports.dart';
import '../../ui/app_theme.dart';
import '../../ui/confirmation_dialog.dart';
import '../../ui/form_fields.dart';
import 'academic_repository.dart';

class EnrollmentEditor extends StatefulWidget {
  const EnrollmentEditor({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.classGroup,
    required this.enrollments,
    required this.students,
    this.onChanged,
  });

  final AcademicRepository repository;
  final String congregationId;
  final ClassGroup classGroup;
  final List<Enrollment> enrollments;
  final List<StudentOption> students;
  final Future<void> Function()? onChanged;

  static const String capacityMessage =
      'Limite de $maxEnrollmentRecords matrículas atingido. Crie outra turma '
      'para um novo grupo.';
  static const String invalidDateMessage =
      'Data inválida. Use o formato dd/MM/aaaa.';

  static const Key studentFieldKey = Key('enrollment-student');
  static const Key startDateFieldKey = Key('enrollment-start-date');
  static const Key addKey = Key('enrollment-add');
  static const Key capacityKey = Key('enrollment-capacity');
  static const Key conflictKey = Key('enrollment-conflict');
  static const Key errorKey = Key('enrollment-error');
  static const Key closeStatusKey = Key('enrollment-close-status');
  static const Key closeEndDateKey = Key('enrollment-close-end-date');
  static const Key closeConfirmKey = Key('enrollment-close-confirm');

  static Key closeKey(String enrollmentId) =>
      Key('enrollment-close-$enrollmentId');

  @override
  State<EnrollmentEditor> createState() => _EnrollmentEditorState();
}

class _EnrollmentEditorState extends State<EnrollmentEditor> {
  final TextEditingController _startDate = TextEditingController();
  String? _studentId;
  bool _submitting = false;
  String? _conflictMessage;
  String? _errorMessage;

  bool get _capacityReached =>
      widget.enrollments.length >= maxEnrollmentRecords;

  @override
  void dispose() {
    _startDate.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String? studentId = _studentId;
    if (studentId == null) {
      setState(() => _errorMessage = 'Selecione um aluno.');
      return;
    }
    final CalendarDate? startDate = parseBrazilianDate(_startDate.text);
    if (startDate == null) {
      setState(() => _errorMessage = EnrollmentEditor.invalidDateMessage);
      return;
    }
    setState(() {
      _submitting = true;
      _conflictMessage = null;
      _errorMessage = null;
    });
    try {
      await widget.repository.enrollStudent(
        congregationId: widget.congregationId,
        classId: widget.classGroup.id,
        studentId: studentId,
        startDate: startDate,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _studentId = null;
        _startDate.clear();
      });
      await widget.onChanged?.call();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      if (failure.code == AppFailureCode.conflict) {
        final String existing =
            failure.fieldErrors?['existingClassName'] ??
            failure.fieldErrors?['classId'] ??
            'outra turma';
        setState(() {
          _submitting = false;
          _conflictMessage = 'Aluno já matriculado na turma $existing.';
        });
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = failure.message;
      });
    }
  }

  Future<void> _close(Enrollment enrollment) async {
    final _CloseEnrollmentResult? result =
        await showDialog<_CloseEnrollmentResult>(
          context: context,
          builder: (BuildContext dialogContext) => _CloseEnrollmentDialog(
            studentName: _studentName(enrollment.studentId),
          ),
        );
    if (result == null || !mounted) {
      return;
    }
    try {
      await widget.repository.closeEnrollment(
        congregationId: widget.congregationId,
        classId: widget.classGroup.id,
        enrollmentId: enrollment.id,
        status: result.status,
        endDate: result.endDate,
        expectedRevision: enrollment.revision,
      );
      if (!mounted) return;
      await widget.onChanged?.call();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    }
  }

  String _studentName(String studentId) {
    for (final StudentOption student in widget.students) {
      if (student.id == studentId) {
        return student.name;
      }
    }
    return studentId;
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Matrículas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.x3),
        if (_capacityReached)
          Text(
            EnrollmentEditor.capacityMessage,
            key: EnrollmentEditor.capacityKey,
            style: TextStyle(color: tokens.error),
          ),
        const SizedBox(height: AppSpacing.x2),
        DropdownButtonFormField<String?>(
          key: EnrollmentEditor.studentFieldKey,
          initialValue: _studentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Aluno'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(child: Text('Selecione um aluno')),
            for (final StudentOption student in widget.students)
              DropdownMenuItem<String?>(
                value: student.id,
                child: Text(student.name),
              ),
          ],
          onChanged: _submitting
              ? null
              : (String? value) => setState(() => _studentId = value),
        ),
        const SizedBox(height: AppSpacing.x3),
        AppDateField(
          key: EnrollmentEditor.startDateFieldKey,
          label: 'Início',
          controller: _startDate,
          helperText: 'Formato dd/MM/aaaa.',
        ),
        const SizedBox(height: AppSpacing.x3),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            key: EnrollmentEditor.addKey,
            label: 'Matricular',
            isSubmitting: _submitting,
            onPressed: _capacityReached || _submitting ? null : _add,
          ),
        ),
        if (_conflictMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          Text(
            _conflictMessage!,
            key: EnrollmentEditor.conflictKey,
            style: TextStyle(color: tokens.error),
          ),
        ],
        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          Text(
            _errorMessage!,
            key: EnrollmentEditor.errorKey,
            style: TextStyle(color: tokens.error),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),
        for (final Enrollment enrollment in widget.enrollments)
          _EnrollmentRow(
            enrollment: enrollment,
            studentName: _studentName(enrollment.studentId),
            onClose: enrollment.status == EnrollmentStatus.active
                ? () => _close(enrollment)
                : null,
          ),
      ],
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  const _EnrollmentRow({
    required this.enrollment,
    required this.studentName,
    this.onClose,
  });

  final Enrollment enrollment;
  final String studentName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final String period = enrollment.endDate == null
        ? '${formatBrazilianDate(enrollment.startDate)} – em andamento'
        : '${formatBrazilianDate(enrollment.startDate)} – '
              '${formatBrazilianDate(enrollment.endDate!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(studentName),
                Text(
                  '$period · ${enrollmentStatusLabel(enrollment.status)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: tokens.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onClose != null)
            AppButton(
              key: EnrollmentEditor.closeKey(enrollment.id),
              label: 'Encerrar',
              variant: AppButtonVariant.text,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

String enrollmentStatusLabel(EnrollmentStatus status) => switch (status) {
  EnrollmentStatus.active => 'Ativa',
  EnrollmentStatus.completed => 'Concluída',
  EnrollmentStatus.withdrawn => 'Cancelada',
};

class _CloseEnrollmentResult {
  const _CloseEnrollmentResult({required this.status, required this.endDate});

  final EnrollmentStatus status;
  final CalendarDate endDate;
}

class _CloseEnrollmentDialog extends StatefulWidget {
  const _CloseEnrollmentDialog({required this.studentName});

  final String studentName;

  @override
  State<_CloseEnrollmentDialog> createState() => _CloseEnrollmentDialogState();
}

class _CloseEnrollmentDialogState extends State<_CloseEnrollmentDialog> {
  final TextEditingController _endDate = TextEditingController();
  EnrollmentStatus _status = EnrollmentStatus.completed;
  String? _error;

  @override
  void dispose() {
    _endDate.dispose();
    super.dispose();
  }

  void _confirm() {
    final CalendarDate? endDate = parseBrazilianDate(_endDate.text);
    if (endDate == null) {
      setState(() => _error = EnrollmentEditor.invalidDateMessage);
      return;
    }
    Navigator.of(context)
        .pop(_CloseEnrollmentResult(status: _status, endDate: endDate));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Encerrar matrícula'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Encerrar a matrícula de ${widget.studentName}?'),
          const SizedBox(height: AppSpacing.x4),
          DropdownButtonFormField<EnrollmentStatus>(
            key: EnrollmentEditor.closeStatusKey,
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Situação'),
            items: const <DropdownMenuItem<EnrollmentStatus>>[
              DropdownMenuItem<EnrollmentStatus>(
                value: EnrollmentStatus.completed,
                child: Text('Concluída'),
              ),
              DropdownMenuItem<EnrollmentStatus>(
                value: EnrollmentStatus.withdrawn,
                child: Text('Cancelada'),
              ),
            ],
            onChanged: (EnrollmentStatus? value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.x3),
          AppDateField(
            key: EnrollmentEditor.closeEndDateKey,
            label: 'Término',
            controller: _endDate,
            helperText: 'Formato dd/MM/aaaa.',
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.tokensOf(context).error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton(
          key: ConfirmationDialog.cancelKey,
          label: 'Cancelar',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          key: EnrollmentEditor.closeConfirmKey,
          label: 'Encerrar',
          onPressed: _confirm,
        ),
      ],
    );
  }
}
