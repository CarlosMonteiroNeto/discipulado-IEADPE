import 'package:flutter/material.dart';

import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import '../domain/session_navigation_context.dart';
import 'attendance_save_controller.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.repository,
    this.congregationId,
    this.selectedSession,
    this.createOperationId,
  });
  final MinistryRepository repository;
  final String? congregationId;
  final SessionNavigationContext? selectedSession;
  final String Function()? createOperationId;
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late AttendanceSaveController _saveController;
  MinistryPage<PendingMinistrySession>? _page;
  MinistryRoster? _roster;
  String? _error;
  String? _notice;
  bool _loading = false;
  String? _retryCursor;
  int _requestGeneration = 0;
  bool _leaveDialogOpen = false;
  bool _allowPop = false;
  final Map<String, AttendanceStatus> _marks = {};

  @override
  void initState() {
    super.initState();
    _saveController = _newSaveController();
    if (widget.selectedSession case final selected?) {
      _loadSelected(selected);
    } else {
      _load();
    }
  }

  AttendanceSaveController _newSaveController() {
    final controller = AttendanceSaveController(
      repository: widget.repository,
      createOperationId: widget.createOperationId,
    )..addListener(_onSaveStateChanged);
    return controller;
  }

  void _onSaveStateChanged() {
    if (mounted) setState(() {});
  }

  /// Security invalidation must discard protected work before the page exposes
  /// a different context. Disposal is synchronous and also ignores late replies.
  void _resetSaveController() {
    _saveController.removeListener(_onSaveStateChanged);
    _saveController.dispose();
    _saveController = _newSaveController();
  }

  @override
  void didUpdateWidget(covariant AttendancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _resetSaveController();
    }
    if (oldWidget.selectedSession != widget.selectedSession ||
        oldWidget.congregationId != widget.congregationId) {
      _requestGeneration++;
      _resetSaveController();
      _page = null;
      _roster = null;
      _error = null;
      _notice = null;
      _loading = false;
      _retryCursor = null;
      _allowPop = false;
      _marks.clear();
      if (widget.selectedSession case final selected?) {
        _loadSelected(selected);
      } else {
        _load();
      }
    }
  }

  @override
  void dispose() {
    _saveController.removeListener(_onSaveStateChanged);
    _saveController.dispose();
    super.dispose();
  }

  bool _isCurrent(int generation) =>
      mounted && generation == _requestGeneration;

  Future<void> _retryLoad() {
    if (widget.selectedSession case final selected?) {
      return _loadSelected(selected);
    }
    return _load(cursor: _retryCursor);
  }

  Future<void> _load({String? cursor}) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _retryCursor = cursor;
    });
    try {
      final page = await widget.repository.listPendingSessions(
        congregationId: widget.congregationId,
        cursor: cursor,
      );
      if (_isCurrent(generation) && widget.selectedSession == null) {
        setState(() {
          _page = cursor == null || _page == null
              ? page
              : MinistryPage(
                  items: [..._page!.items, ...page.items],
                  nextCursor: page.nextCursor,
                );
          _loading = false;
        });
      }
    } catch (_) {
      if (_isCurrent(generation) && widget.selectedSession == null) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar as chamadas. Tente novamente.';
        });
      }
    }
  }

  Future<void> _loadSelected(SessionNavigationContext selected) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _page = null;
      _roster = null;
      _marks.clear();
    });
    try {
      final roster = await widget.repository.getSessionAttendance(
        congregationId: selected.congregationId,
        sessionId: selected.sessionId,
      );
      final session = roster.session;
      if (session.id != selected.sessionId ||
          session.classId != selected.classId ||
          session.congregationId != selected.congregationId) {
        throw const DataFailure('invalid_response');
      }
      if (!_isCurrent(generation) || widget.selectedSession != selected) return;
      setState(() {
        _roster = roster;
        _loading = false;
        for (final mark in roster.marks) {
          _marks[mark.enrollmentId] = mark.status;
        }
      });
    } catch (_) {
      if (_isCurrent(generation) && widget.selectedSession == selected) {
        setState(() {
          _loading = false;
          _roster = null;
          _marks.clear();
          _error = 'Não foi possível abrir a chamada. Tente novamente.';
        });
      }
    }
  }

  Future<void> _open(PendingMinistrySession item) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _roster = null;
      _marks.clear();
    });
    try {
      final roster = await widget.repository.getSessionAttendance(
        congregationId: item.congregationId,
        sessionId: item.id,
      );
      if (!_isCurrent(generation) || widget.selectedSession != null) return;
      setState(() {
        _roster = roster;
        _loading = false;
        for (final mark in roster.marks) {
          _marks[mark.enrollmentId] = mark.status;
        }
      });
    } catch (_) {
      if (_isCurrent(generation) && widget.selectedSession == null) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível abrir a chamada. Tente novamente.';
        });
      }
    }
  }

  Future<void> _reloadRoster(Session session) async {
    final congregationId = session.metadata.congregationId;
    if (congregationId == null) return;
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _roster = null;
      _marks.clear();
    });
    try {
      final roster = await widget.repository.getSessionAttendance(
        congregationId: congregationId,
        sessionId: session.id,
      );
      if (roster.session.id != session.id ||
          roster.session.classId != session.classId ||
          roster.session.congregationId != congregationId) {
        throw const DataFailure('invalid_response');
      }
      if (!_isCurrent(generation) || widget.selectedSession != null) return;
      setState(() {
        _roster = roster;
        _loading = false;
        for (final mark in roster.marks) {
          _marks[mark.enrollmentId] = mark.status;
        }
      });
    } catch (_) {
      if (_isCurrent(generation) && widget.selectedSession == null) {
        setState(() {
          _loading = false;
          _roster = null;
          _marks.clear();
          _error = 'Não foi possível atualizar a chamada. Tente novamente.';
        });
      }
    }
  }

  SessionNavigationContext _contextFor(MinistryRoster roster) {
    final selected = widget.selectedSession;
    if (selected != null) return selected;
    return SessionNavigationContext(
      congregationId: roster.session.metadata.congregationId!,
      classId: roster.session.classId,
      sessionId: roster.session.id,
    );
  }

  Future<bool> _confirmFinalize() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar chamada?'),
        content: const Text(
          'Após finalizar, a chamada não poderá ser editada. '
          'Para corrigir, cancele e registre uma substituta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar chamada'),
          ),
        ],
      ),
    );
    return accepted == true && mounted;
  }

  Future<void> _save({required bool finalize}) async {
    final roster = _roster;
    if (roster == null ||
        roster.session.status != SessionStatus.open ||
        _saveController.pending != null ||
        _saveController.isBusy) {
      return;
    }
    if (finalize && !await _confirmFinalize()) return;
    if (!mounted || _roster != roster) return;
    final generation = _requestGeneration;
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await _saveController.submit(
        context: _contextFor(roster),
        expectedRevision: roster.session.metadata.revision,
        marks: {
          for (final mark in roster.marks)
            mark.enrollmentId: _marks[mark.enrollmentId] ?? mark.status,
        },
        finalize: finalize,
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleSaveFailure(error);
      return;
    }
    if (!_isCurrent(generation)) return;
    setState(() {
      _notice = finalize
          ? 'Chamada finalizada e confirmada pelo servidor.'
          : 'Chamada salva e confirmada pelo servidor.';
    });
    await _reloadAfterAcknowledgement(roster);
  }

  Future<void> _retryPendingSave() async {
    final pending = _saveController.pending;
    if (pending == null || !_saveController.hasUnknownResult) return;
    final roster = _roster;
    final generation = _requestGeneration;
    setState(() => _error = null);
    try {
      await _saveController.retryPending();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleSaveFailure(error);
      return;
    }
    if (!_isCurrent(generation)) return;
    setState(() {
      _notice = pending.finalize
          ? 'Chamada finalizada e confirmada pelo servidor.'
          : 'Chamada salva e confirmada pelo servidor.';
    });
    if (roster != null) await _reloadAfterAcknowledgement(roster);
  }

  Future<void> _refreshAfterRejection() async {
    final roster = _roster;
    if (roster == null || _saveController.pending == null) return;
    if (widget.selectedSession case final selected?) {
      await _loadSelected(selected);
    } else {
      await _reloadRoster(roster.session);
    }
    if (!mounted || _roster == null) return;
    _saveController.clear();
    setState(() {
      _error = null;
      _notice = 'Chamada atualizada. Revise as marcações e salve novamente.';
    });
  }

  void _handleSaveFailure(Object error) {
    final code = error is DataFailure ? error.code : null;
    if (code == 'permission' || code == 'stale') {
      setState(() {
        _roster = null;
        _marks.clear();
        _notice = null;
        _error = code == 'permission'
            ? 'Seu acesso mudou. Atualize a sessão.'
            : 'O contexto protegido mudou. A chamada foi fechada.';
      });
      return;
    }
    if (_saveController.hasUnknownResult) {
      setState(() {
        _notice = null;
        _error =
            'Não foi possível confirmar se a chamada foi salva. '
            'Ela pode ter sido concluída no servidor. '
            '“Tentar novamente” reenvia exatamente a mesma solicitação, '
            'com a mesma ação.';
      });
      return;
    }
    if (code == 'stale_revision') {
      setState(() {
        _notice = null;
        _error =
            'A chamada foi alterada por outra pessoa. '
            'Atualize e revise as marcações antes de salvar novamente.';
      });
      return;
    }
    setState(() {
      _notice = null;
      _error = 'A chamada não foi salva. Revise e tente novamente.';
    });
  }

  Future<void> _reloadAfterAcknowledgement(MinistryRoster roster) async {
    if (widget.selectedSession case final selected?) {
      await _loadSelected(selected);
    } else {
      await _reloadRoster(roster.session);
    }
  }

  Future<void> _confirmLeave() async {
    if (_leaveDialogOpen || !mounted) return;
    final unknown = _saveController.hasUnknownResult;
    final busy = _saveController.isBusy;
    if (!unknown && !busy) {
      setState(() => _allowPop = true);
      Navigator.of(context).maybePop();
      return;
    }
    _leaveDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da chamada?'),
        content: Text(
          unknown
              ? 'A solicitação anterior pode ter sido concluída no servidor. '
                    'Ao sair, não haverá reenvio automático; ao retornar, a '
                    'chamada será lida novamente.'
              : 'O envio ainda pode ser concluído no servidor. Ao sair, não '
                    'haverá reenvio automático; ao retornar, a chamada será '
                    'lida novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Permanecer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair mesmo assim'),
          ),
        ],
      ),
    );
    _leaveDialogOpen = false;
    if (leave != true || !mounted) return;
    setState(() => _allowPop = true);
    _saveController.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _saveController.pending;
    final busy = _saveController.isBusy;
    final unknown = _saveController.hasUnknownResult;
    final blocked = pending != null || busy;
    return PopScope(
      canPop: _allowPop || (!busy && !unknown),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 896),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Base44PageHeading(
                    title: 'Frequência',
                    icon: Icons.fact_check_outlined,
                  ),
                  const SizedBox(height: 16),
                  const Base44Panel(
                    child: Text(
                      'A chamada preserva a lista de alunos registrada no início da sessão.',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Base44Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 8),
                            if (unknown)
                              TextButton.icon(
                                key: const Key('retry-attendance-save'),
                                onPressed: _retryPendingSave,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              )
                            else if (pending != null)
                              TextButton.icon(
                                onPressed: _refreshAfterRejection,
                                icon: const Icon(Icons.sync),
                                label: const Text('Atualizar e revisar'),
                              )
                            else if (_roster == null)
                              TextButton.icon(
                                onPressed: _retryLoad,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Base44Panel(
                        child: Text(
                          _notice!,
                          style: const TextStyle(
                            color: UnifiedColors.brandNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_loading)
                    const Base44Panel(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Carregando frequência',
                        ),
                      ),
                    ),
                  if (_roster == null) ...[
                    for (final item
                        in _page?.items ?? const <PendingMinistrySession>[])
                      Card(
                        child: ListTile(
                          title: Text(item.className, softWrap: true),
                          subtitle: Text(
                            _displayDate(item.date),
                            softWrap: true,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: UnifiedColors.brandNavy,
                          ),
                          onTap: _loading ? null : () => _open(item),
                          minVerticalPadding: 12,
                        ),
                      ),
                    if (!_loading && _page?.items.isEmpty == true)
                      const Base44Panel(
                        child: Text('Não há chamadas pendentes.'),
                      ),
                    if (_page?.nextCursor != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _load(cursor: _page!.nextCursor),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            _loading
                                ? 'Carregando chamadas…'
                                : 'Carregar mais chamadas',
                          ),
                        ),
                      ),
                  ] else
                    _buildRoster(context, _roster!, blocked: blocked),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoster(
    BuildContext context,
    MinistryRoster roster, {
    required bool blocked,
  }) {
    final session = roster.session;
    final open = session.status == SessionStatus.open;
    final preview = open && !session.rosterFrozen;
    final listLabel = session.rosterFrozen
        ? 'Lista congelada'
        : preview
        ? 'Lista prevista'
        : 'Lista não congelada';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$listLabel · ${_displayDate(session.date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _statusBadge(session.status),
          ],
        ),
        if (preview) ...[
          const SizedBox(height: 8),
          const Base44Panel(
            child: Text('A lista será congelada no primeiro salvamento.'),
          ),
          if (roster.marks.isEmpty) ...[
            const SizedBox(height: 8),
            const Base44Panel(
              child: Text('Nenhum aluno elegível para a data desta aula.'),
            ),
          ],
        ],
        if (!open) ...[
          const SizedBox(height: 8),
          Base44Panel(
            child: Text(
              session.status == SessionStatus.finalized
                  ? 'Chamada finalizada. As marcações são somente leitura.'
                  : 'Chamada cancelada. As marcações são somente leitura.',
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final mark in roster.marks)
          Base44Panel(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 480 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final status = _marks[mark.enrollmentId] ?? mark.status;
                final studentName = Text(
                  mark.studentName,
                  semanticsLabel: 'Aluno ${mark.studentName}',
                  softWrap: true,
                );
                if (!open) {
                  final readonly = Row(
                    children: [
                      Expanded(child: studentName),
                      const SizedBox(width: 16),
                      Base44StatusBadge(
                        label: _label(status),
                        semanticsLabel: 'Frequência: ${_label(status)}',
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            studentName,
                            const SizedBox(height: 8),
                            Base44StatusBadge(
                              label: _label(status),
                              semanticsLabel: 'Frequência: ${_label(status)}',
                            ),
                          ],
                        )
                      : readonly;
                }
                final statusField = DropdownButtonFormField<AttendanceStatus>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Frequência',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: [
                    for (final value in AttendanceStatus.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_label(value), softWrap: true),
                      ),
                  ],
                  onChanged: blocked
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _marks[mark.enrollmentId] = value);
                          }
                        },
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      studentName,
                      const SizedBox(height: 8),
                      statusField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: studentName),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: statusField),
                  ],
                );
              },
            ),
          ),
        if (open) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: blocked ? null : () => _save(finalize: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar chamada'),
              ),
              FilledButton.icon(
                onPressed: blocked || roster.marks.isEmpty
                    ? null
                    : () => _save(finalize: true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Salvar e finalizar'),
              ),
            ],
          ),
        ],
        if (blocked && open)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Aguarde a confirmação da solicitação atual antes de alterar a chamada.',
            ),
          ),
      ],
    );
  }

  Base44StatusBadge _statusBadge(SessionStatus status) => switch (status) {
    SessionStatus.open => const Base44StatusBadge(
      label: 'Aberta',
      tone: Base44StatusTone.primary,
    ),
    SessionStatus.finalized => const Base44StatusBadge(
      label: 'Finalizada',
      tone: Base44StatusTone.neutral,
    ),
    SessionStatus.canceled => const Base44StatusBadge(
      label: 'Cancelada',
      tone: Base44StatusTone.error,
    ),
  };

  String _displayDate(CalendarDate date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _label(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => 'Presente',
    AttendanceStatus.absent => 'Ausente',
    AttendanceStatus.excused => 'Justificado',
    AttendanceStatus.unmarked => 'Sem marcação',
  };
}
