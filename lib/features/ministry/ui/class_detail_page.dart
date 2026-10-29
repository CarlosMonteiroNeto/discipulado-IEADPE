import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import '../domain/session_navigation_context.dart';
import 'attendance_page.dart';
import 'session_list.dart';
import 'class_form.dart';
import 'class_enrollment_panel.dart';

class ClassDetailPage extends StatefulWidget {
  const ClassDetailPage({
    super.key,
    required this.repository,
    required this.congregationId,
    this.congregationName,
    required this.classSummary,
    required this.onChanged,
  });

  final MinistryRepository repository;
  final String congregationId;
  final String? congregationName;
  final MinistryClassSummary classSummary;
  final VoidCallback onChanged;

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  final _uuid = const Uuid();
  late MinistryClassSummary _classSummary;
  String? _teacherName;
  bool _loadingTeacher = false;
  bool _statusBusy = false;
  String? _error;
  String? _statusSignature;
  String? _statusOperationId;
  int _enrollmentReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _classSummary = widget.classSummary;
    _loadTeacherName();
  }

  @override
  void didUpdateWidget(covariant ClassDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.classSummary.id != widget.classSummary.id ||
        oldWidget.classSummary.teacherContactId !=
            widget.classSummary.teacherContactId) {
      _classSummary = widget.classSummary;
      _teacherName = null;
      _loadTeacherName();
    }
  }

  Future<void> _loadTeacherName() async {
    final teacherId = _classSummary.teacherContactId;
    if (teacherId == null) {
      setState(() => _teacherName = null);
      return;
    }
    setState(() {
      _loadingTeacher = true;
      _teacherName = null;
    });
    try {
      final detail = await widget.repository.getTeacherContact(
        congregationId: widget.congregationId,
        contactId: teacherId,
      );
      if (!mounted || teacherId != _classSummary.teacherContactId) return;
      setState(() {
        _teacherName = detail.name;
        _loadingTeacher = false;
      });
    } catch (_) {
      if (!mounted || teacherId != _classSummary.teacherContactId) return;
      setState(() {
        _teacherName = 'Responsável indisponível';
        _loadingTeacher = false;
      });
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<MinistryClassSummary>(
      MaterialPageRoute(
        builder: (_) => ClassForm(
          repository: widget.repository,
          congregationId: widget.congregationId,
          congregationName: widget.congregationName,
          initialClass: _classSummary,
          onCancel: () => Navigator.of(context).pop(),
          onSaved: (summary) => Navigator.of(context).pop(summary),
        ),
      ),
    );
    if (!mounted || saved == null) return;
    setState(() {
      _classSummary = saved;
      _teacherName = null;
    });
    _loadTeacherName();
    widget.onChanged();
  }

  Future<void> _openSession(String sessionId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AttendancePage(
          repository: widget.repository,
          congregationId: widget.congregationId,
          selectedSession: SessionNavigationContext(
            congregationId: widget.congregationId,
            classId: _classSummary.id,
            sessionId: sessionId,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _enrollmentReloadToken++);
  }

  Future<void> _openSessions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SessionListPage(
          repository: widget.repository,
          congregationId: widget.congregationId,
          classSummary: _classSummary,
          onOpenSession: _openSession,
        ),
      ),
    );
    if (mounted) setState(() => _enrollmentReloadToken++);
  }

  Future<bool> _confirmStatus(ClassStatus next) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => ClassStatusConfirmationDialog(
        archived: next == ClassStatus.archived,
        completed: next == ClassStatus.completed,
      ),
    );
    return accepted == true;
  }

  Future<void> _changeStatus(ClassStatus next) async {
    if (_statusBusy) return;
    if (next != ClassStatus.active && !await _confirmStatus(next)) return;
    final signature = jsonEncode({
      'id': _classSummary.id,
      'congregation_id': widget.congregationId,
      'current_status': _classSummary.status.wire,
      'status': next.wire,
      'expected_revision': _classSummary.revision,
    });
    if (_statusSignature != signature) {
      _statusSignature = signature;
      _statusOperationId = _uuid.v4();
    }
    setState(() {
      _statusBusy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.setClassStatus(
        operationId: _statusOperationId!,
        id: _classSummary.id,
        congregationId: widget.congregationId,
        currentStatus: _classSummary.status,
        status: next,
        expectedRevision: _classSummary.revision,
      );
      if (!mounted) return;
      setState(() {
        _classSummary = MinistryClassSummary(
          id: _classSummary.id,
          name: _classSummary.name,
          status: next,
          startDate: _classSummary.startDate,
          endDate: _classSummary.endDate,
          revision: result.revision,
          teacherContactId: _classSummary.teacherContactId,
        );
        _statusBusy = false;
        _statusSignature = null;
        _statusOperationId = null;
      });
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusBusy = false;
        _error = error is DataFailure && error.code == 'stale_revision'
            ? 'A turma foi alterada por outra pessoa. Atualize a lista antes de tentar novamente.'
            : 'Não foi possível atualizar a situação da turma. Tente novamente.';
      });
    }
  }

  String get _statusLabel => switch (_classSummary.status) {
    ClassStatus.active => 'Ativa',
    ClassStatus.completed => 'Concluída',
    ClassStatus.archived => 'Arquivada',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('Detalhes da turma')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(UnifiedSpace.x4),
            children: [
              Base44PageHeading(
                title: _classSummary.name,
                icon: Icons.groups_outlined,
                subtitle: _statusLabel,
                trailing: _classSummary.status == ClassStatus.active
                    ? OutlinedButton.icon(
                        onPressed: _statusBusy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar turma'),
                      )
                    : null,
              ),
              const SizedBox(height: UnifiedSpace.x4),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(label: 'Situação', value: _statusLabel),
                    const Divider(height: UnifiedSpace.x6),
                    _DetailRow(
                      label: 'Responsável principal',
                      value: _classSummary.teacherContactId == null
                          ? 'Sem responsável definido'
                          : _loadingTeacher
                          ? 'Carregando…'
                          : _teacherName ?? 'Responsável indisponível',
                    ),
                    const Divider(height: UnifiedSpace.x6),
                    _DetailRow(
                      label: 'Data de início',
                      value: _classSummary.startDate,
                    ),
                    const Divider(height: UnifiedSpace.x6),
                    _DetailRow(
                      label: 'Data de término',
                      value: _classSummary.endDate ?? 'Em andamento',
                    ),
                    const SizedBox(height: UnifiedSpace.x4),
                    OutlinedButton.icon(
                      onPressed: _openSessions,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Ver aulas'),
                    ),
                  ],
                ),
              ),
              if (_classSummary.status == ClassStatus.active) ...[
                const SizedBox(height: UnifiedSpace.x3),
                ClassEnrollmentPanel(
                  repository: widget.repository,
                  congregationId: widget.congregationId,
                  classId: _classSummary.id,
                  classStartDate: _classSummary.startDate,
                  classEndDate: _classSummary.endDate,
                  reloadToken: _enrollmentReloadToken,
                  onChanged: widget.onChanged,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: UnifiedSpace.x3),
                Base44Panel(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: UnifiedColors.error),
                  ),
                ),
              ],
              if (_classSummary.status == ClassStatus.active) ...[
                const SizedBox(height: UnifiedSpace.x3),
                FilledButton.icon(
                  onPressed: _statusBusy
                      ? null
                      : () => _changeStatus(ClassStatus.completed),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Concluir turma'),
                ),
                const SizedBox(height: UnifiedSpace.x2),
                OutlinedButton.icon(
                  onPressed: _statusBusy
                      ? null
                      : () => _changeStatus(ClassStatus.archived),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arquivar turma'),
                ),
              ] else if (_classSummary.status == ClassStatus.completed) ...[
                const SizedBox(height: UnifiedSpace.x3),
                OutlinedButton.icon(
                  onPressed: _statusBusy
                      ? null
                      : () => _changeStatus(ClassStatus.archived),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arquivar turma'),
                ),
              ] else ...[
                const SizedBox(height: UnifiedSpace.x3),
                FilledButton.icon(
                  onPressed: _statusBusy
                      ? null
                      : () => _changeStatus(ClassStatus.active),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Reativar turma'),
                ),
              ],
              if (_statusBusy)
                const Padding(
                  padding: EdgeInsets.only(top: UnifiedSpace.x3),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Atualizando turma',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ClassStatusConfirmationDialog extends StatelessWidget {
  const ClassStatusConfirmationDialog({
    super.key,
    required this.archived,
    required this.completed,
  });

  final bool archived;
  final bool completed;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: const Key('class-status-confirmation-dialog'),
    child: AlertDialog(
      title: Text(archived ? 'Arquivar turma?' : 'Concluir turma?'),
      content: Text(
        archived ? 'Os registros e o histórico da turma serão mantidos.' : 'Após concluir, os dados da turma ficam somente leitura. A conclusão exige que não haja matrículas ativas nem chamadas abertas.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            archived
                ? 'Confirmar arquivamento'
                : completed
                ? 'Confirmar conclusão'
                : 'Confirmar',
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: UnifiedSpace.x1),
      Text(value, softWrap: true),
    ],
  );
}
