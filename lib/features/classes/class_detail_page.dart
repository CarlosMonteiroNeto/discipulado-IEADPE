/// Class detail: teacher, period, roster, sessions and counts (S08, S09, S10).
///
/// Completed classes are read-only except for archival; session rows link to
/// the deep-linkable attendance route `/turmas/{classId}/chamadas/{sessionId}`.
library;

import 'package:flutter/material.dart';

import '../../domain/class_group.dart';
import '../../domain/contact.dart';
import '../../domain/enrollment.dart';
import '../../domain/ports.dart';
import '../../domain/session.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/confirmation_dialog.dart';
import '../../ui/form_fields.dart';
import '../attendance/session_editor.dart';
import 'academic_repository.dart';
import 'class_form.dart';
import 'enrollment_editor.dart';

class ClassDetailPage extends StatefulWidget {
  const ClassDetailPage({
    super.key,
    required this.repository,
    required this.classId,
    required this.congregationId,
    this.onOpenSession,
    this.onDone,
  });

  final AcademicRepository repository;
  final String classId;
  final String congregationId;
  final void Function(ClassGroup classGroup, Session session)? onOpenSession;
  final VoidCallback? onDone;

  static const Key editKey = Key('class-detail-edit');
  static const Key completeKey = Key('class-detail-complete');
  static const Key archiveKey = Key('class-detail-archive');
  static const Key newSessionKey = Key('class-detail-new-session');
  static const Key errorKey = Key('class-detail-error');
  static const Key reloadKey = Key('class-detail-reload');

  static String routePath(String classId) => '/turmas/$classId';

  static Key openSessionKey(String sessionId) =>
      Key('class-detail-session-$sessionId');

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  ClassGroup? _classGroup;
  List<Enrollment> _enrollments = const <Enrollment>[];
  List<Session> _sessions = const <Session>[];
  List<Contact> _teachers = const <Contact>[];
  List<StudentOption> _students = const <StudentOption>[];
  bool _loading = true;
  bool _notFound = false;
  bool _editing = false;
  bool _creatingSession = false;
  AppFailure? _failure;

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
    });
    try {
      final ClassGroup? classGroup = await widget.repository.getClass(
        id: widget.classId,
        congregationId: widget.congregationId,
      );
      if (!mounted) return;
      if (classGroup == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        return;
      }
      final List<Contact> teachers = await widget.repository
          .listEligibleTeachers(congregationId: widget.congregationId);
      final List<StudentOption> students = await widget.repository
          .listEligibleStudents(congregationId: widget.congregationId);
      final List<Enrollment> enrollments = await widget.repository
          .listEnrollments(
            congregationId: widget.congregationId,
            classId: widget.classId,
          );
      final List<Session> sessions = await widget.repository.listSessions(
        congregationId: widget.congregationId,
        classId: widget.classId,
      );
      if (!mounted) return;
      setState(() {
        _classGroup = classGroup;
        _teachers = teachers;
        _students = students;
        _enrollments = enrollments;
        _sessions = sessions;
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

  String? _teacherName(String? teacherContactId) {
    if (teacherContactId == null) {
      return null;
    }
    for (final Contact teacher in _teachers) {
      if (teacher.id == teacherContactId) {
        return teacher.name;
      }
    }
    return teacherContactId;
  }

  Future<void> _setStatus(ClassGroup classGroup, ClassStatus status) async {
    final bool confirmed = await showConfirmationDialog(
      context,
      title: status == ClassStatus.completed
          ? 'Concluir turma'
          : 'Arquivar turma',
      message: status == ClassStatus.completed
          ? 'Concluir ${classGroup.name}? A turma ficará somente leitura.'
          : 'Arquivar ${classGroup.name}?',
      confirmLabel: status == ClassStatus.completed ? 'Concluir' : 'Arquivar',
      destructive: status == ClassStatus.archived,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.repository.setClassStatus(
        id: classGroup.id,
        congregationId: widget.congregationId,
        status: status,
        expectedRevision: classGroup.revision,
      );
      if (!mounted) return;
      widget.onDone?.call();
      await _load();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
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
    // Editing is status-gated (S08): completed and archived classes expose no
    // ClassForm, even if a stale tap set the flag before a reload.
    if (_editing &&
        _classGroup != null &&
        _classGroup!.status == ClassStatus.active) {
      final ClassGroup classGroup = _classGroup!;
      return SingleChildScrollView(
        child: ClassForm(
          repository: widget.repository,
          config: ClassFormConfig(
            congregationId: widget.congregationId,
            classId: classGroup.id,
            expectedRevision: classGroup.revision,
            initial: classGroup,
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
    if (failure != null && _classGroup == null) {
      return AsyncContent<void>(
        state: AsyncViewState<void>.fromFailure(failure),
        onRetry: _load,
      );
    }
    final ClassGroup? classGroup = _classGroup;
    if (classGroup == null) {
      return const AsyncContent<void>(state: AsyncViewState<void>.notFound());
    }
    return _detail(context, classGroup);
  }

  Widget _detail(BuildContext context, ClassGroup classGroup) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final bool active = classGroup.status == ClassStatus.active;
    final String? teacherName = _teacherName(classGroup.teacherContactId);
    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                classGroup.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Chip(label: Text(classStatusLabel(classGroup.status))),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text('Professor(a)', style: Theme.of(context).textTheme.labelSmall),
        Text(
          teacherName ?? 'Não definido',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          'Período: ${formatBrazilianDate(classGroup.startDate)} – '
          '${classGroup.endDate == null ? 'em andamento' : formatBrazilianDate(classGroup.endDate!)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          '${_enrollments.length} matrícula(s) · ${_sessions.length} chamada(s)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          Text(
            _failure!.message,
            key: ClassDetailPage.errorKey,
            style: TextStyle(color: tokens.error),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: ClassDetailPage.reloadKey,
              label: 'Recarregar',
              variant: AppButtonVariant.secondary,
              onPressed: _load,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x6),
        if (active)
          EnrollmentEditor(
            repository: widget.repository,
            congregationId: widget.congregationId,
            classGroup: classGroup,
            enrollments: _enrollments,
            students: _students,
            onChanged: _load,
          ),
        if (!active)
          Text(
            'Turma ${classStatusLabel(classGroup.status).toLowerCase()}: as matrículas e chamadas estão somente leitura.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: AppSpacing.x6),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Chamadas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (active)
              AppButton(
                key: ClassDetailPage.newSessionKey,
                label: 'Nova chamada',
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _creatingSession = true),
              ),
          ],
        ),
        if (_creatingSession && active)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            child: SessionEditor(
              repository: widget.repository,
              congregationId: widget.congregationId,
              classId: classGroup.id,
              onCreated: (_) {
                setState(() => _creatingSession = false);
                _load();
              },
              onCancel: () => setState(() => _creatingSession = false),
            ),
          ),
        if (_sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.x3),
            child: Text('Nenhuma chamada registrada.'),
          ),
        for (final Session session in _sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.topic ?? 'Chamada'),
            subtitle: Text(
              '${formatBrazilianDate(session.date)} · '
              '${sessionStatusLabel(session.status)}',
            ),
            trailing: active && session.status != SessionStatus.canceled
                ? AppButton(
                    key: ClassDetailPage.openSessionKey(session.id),
                    label: 'Abrir',
                    variant: AppButtonVariant.text,
                    onPressed: () =>
                        widget.onOpenSession?.call(classGroup, session),
                  )
                : null,
          ),
        const SizedBox(height: AppSpacing.x6),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: <Widget>[
            if (classGroup.status == ClassStatus.active)
              AppButton(
                key: ClassDetailPage.editKey,
                label: 'Editar',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _editing = true),
              ),
            if (classGroup.status == ClassStatus.active)
              AppButton(
                key: ClassDetailPage.completeKey,
                label: 'Concluir',
                variant: AppButtonVariant.secondary,
                onPressed: () => _setStatus(classGroup, ClassStatus.completed),
              ),
            if (classGroup.status != ClassStatus.archived)
              AppButton(
                key: ClassDetailPage.archiveKey,
                label: 'Arquivar',
                variant: AppButtonVariant.danger,
                onPressed: () => _setStatus(classGroup, ClassStatus.archived),
              ),
          ],
        ),
      ],
    );
  }
}

String sessionStatusLabel(SessionStatus status) => switch (status) {
  SessionStatus.open => 'Aberta',
  SessionStatus.finalized => 'Finalizada',
  SessionStatus.canceled => 'Cancelada',
};
