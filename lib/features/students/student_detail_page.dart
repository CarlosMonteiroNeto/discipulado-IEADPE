/// Private student detail with grouped data and immutable enrollment history
/// (S07, S08, S10).
///
/// The detail is the only place a private record is rendered: list rows and
/// URLs never expose birth date, address or religious answers. Archive and
/// restore use the existing stable ID and require confirmation; an active
/// enrollment denial explains that the enrollment must close first.
library;

import 'package:flutter/material.dart';

import '../../domain/student.dart';
import '../../domain/ports.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/confirmation_dialog.dart';
import '../../ui/feedback.dart';
import '../../ui/form_fields.dart';
import 'enrollment_history.dart';
import 'student_form_page.dart';
import 'student_repository.dart';

class StudentDetailPage extends StatefulWidget {
  const StudentDetailPage({
    super.key,
    required this.repository,
    required this.studentId,
    required this.congregationId,
    this.onDone,
  });

  final StudentRepository repository;
  final String studentId;
  final String congregationId;
  final VoidCallback? onDone;

  static const String activeEnrollmentMessage =
      'Este aluno possui uma matrícula ativa. Encerre a matrícula antes de '
      'arquivar.';

  static const Key editKey = Key('student-detail-edit');
  static const Key archiveKey = Key('student-detail-archive');
  static const Key restoreKey = Key('student-detail-restore');
  static const Key archiveErrorKey = Key('student-detail-archive-error');

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  Student? _student;
  List<EnrollmentHistoryEntry> _history = const <EnrollmentHistoryEntry>[];
  bool _loading = true;
  bool _notFound = false;
  AppFailure? _failure;
  String? _archiveError;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
      _notFound = false;
      _archiveError = null;
    });
    try {
      final Student? student = await widget.repository.getStudent(
        id: widget.studentId,
        congregationId: widget.congregationId,
      );
      if (!mounted) return;
      if (student == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        return;
      }
      final List<EnrollmentHistoryEntry> history = await widget.repository
          .enrollmentHistory(
            studentId: student.id,
            congregationId: widget.congregationId,
          );
      if (!mounted) return;
      setState(() {
        _student = student;
        _history = history;
        _loading = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = failure;
      });
    }
  }

  Future<void> _archive() async {
    final Student? student = _student;
    if (student == null) return;
    final bool confirmed = await showConfirmationDialog(
      context,
      title: 'Arquivar aluno',
      message: 'Arquivar ${student.name}?',
      confirmLabel: 'Arquivar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _setArchived(student, true);
  }

  Future<void> _restore() async {
    final Student? student = _student;
    if (student == null) return;
    final bool confirmed = await showConfirmationDialog(
      context,
      title: 'Restaurar aluno',
      message: 'Restaurar ${student.name}?',
      confirmLabel: 'Restaurar',
    );
    if (!confirmed || !mounted) return;
    await _setArchived(student, false);
  }

  Future<void> _setArchived(Student student, bool archived) async {
    try {
      await widget.repository.setStudentArchived(
        id: student.id,
        congregationId: widget.congregationId,
        archived: archived,
        expectedRevision: student.revision,
      );
      if (!mounted) return;
      widget.onDone?.call();
      await _load();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      if (archived && failure.code == AppFailureCode.conflict) {
        setState(
          () => _archiveError = StudentDetailPage.activeEnrollmentMessage,
        );
        return;
      }
      showAppFeedback(
        context,
        message: failure.message,
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      backgroundColor: tokens.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final Student? student = _student;
    if (_editing && student != null) {
      return SingleChildScrollView(
        child: StudentFormPage(
          repository: widget.repository,
          config: StudentFormConfig(
            congregationId: widget.congregationId,
            studentId: student.id,
            expectedRevision: student.revision,
            initial: student,
          ),
          onSaved: (_) {
            setState(() => _editing = false);
            _load();
          },
          onCancel: () => setState(() => _editing = false),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound) {
      return const AsyncContent<void>(state: AsyncViewState<void>.notFound());
    }
    final AppFailure? failure = _failure;
    if (failure != null) {
      return AsyncContent<void>(
        state: AsyncViewState<void>.fromFailure(failure),
        onRetry: _load,
      );
    }
    if (student == null) {
      return const AsyncContent<void>(state: AsyncViewState<void>.notFound());
    }
    return _detail(context, student);
  }

  Widget _detail(BuildContext context, Student student) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                student.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Chip(label: Text(student.archived ? 'Arquivado' : 'Ativo')),
          ],
        ),
        _section(context, 'Dados pessoais'),
        _field(
          context,
          'Data de nascimento',
          student.birthDate == null
              ? 'Não informado'
              : formatBrazilianDate(student.birthDate!),
        ),
        _field(context, 'Escolaridade', student.education ?? 'Não informado'),
        _field(
          context,
          'Estado civil',
          student.maritalStatus ?? 'Não informado',
        ),
        _section(context, 'Contato'),
        _field(context, 'Telefone', student.phoneE164 ?? 'Não informado'),
        _field(context, 'Endereço', _addressLabel(student.address)),
        _section(context, 'Discipulado'),
        _field(context, 'Novo convertido', _boolLabel(student.newConvert)),
        _field(
          context,
          'Batizado nas águas',
          _boolLabel(student.waterBaptized),
        ),
        _field(context, 'Deseja o batismo', _boolLabel(student.wantsBaptism)),
        _section(context, 'Histórico de turmas'),
        EnrollmentHistoryView(entries: _history),
        if (_archiveError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x4),
          Text(
            _archiveError!,
            key: StudentDetailPage.archiveErrorKey,
            style: TextStyle(color: tokens.error),
          ),
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Recarregar',
              variant: AppButtonVariant.secondary,
              onPressed: _load,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x6),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: <Widget>[
            AppButton(
              key: StudentDetailPage.editKey,
              label: 'Editar',
              icon: Icons.edit_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => _editing = true),
            ),
            if (!student.archived)
              AppButton(
                key: StudentDetailPage.archiveKey,
                label: 'Arquivar',
                variant: AppButtonVariant.danger,
                onPressed: _archive,
              ),
            if (student.archived)
              AppButton(
                key: StudentDetailPage.restoreKey,
                label: 'Restaurar',
                variant: AppButtonVariant.secondary,
                onPressed: _restore,
              ),
          ],
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.x4, bottom: AppSpacing.x2),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _field(BuildContext context, String label, String value) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: tokens.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _boolLabel(bool? value) {
    if (value == null) return 'Não informado';
    return value ? 'Sim' : 'Não';
  }

  String _addressLabel(Address? address) {
    if (address == null) return 'Não informado';
    final List<String> parts = <String?>[
      address.street,
      address.district,
      address.city,
      address.postalCode,
      address.stateCode,
    ].whereType<String>().where((String part) => part.isNotEmpty).toList();
    return parts.isEmpty ? 'Não informado' : parts.join(', ');
  }
}
