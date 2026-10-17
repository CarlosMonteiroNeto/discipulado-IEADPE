import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.repository,
    this.congregationId,
    this.createOperationId,
  });
  final MinistryRepository repository;
  final String? congregationId;
  final String Function()? createOperationId;
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _uuid = const Uuid();
  MinistryPage<PendingMinistrySession>? _page;
  MinistryRoster? _roster;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  String? _retryCursor;
  String? _operationId;
  final Map<String, AttendanceStatus> _marks = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  String _newOperation() => widget.createOperationId?.call() ?? _uuid.v4();
  Future<void> _load({String? cursor}) async {
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
      if (mounted) {
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
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar as chamadas. Tente novamente.';
        });
      }
    }
  }

  Future<void> _open(PendingMinistrySession item) async {
    setState(() {
      _loading = true;
      _error = null;
      _roster = null;
      _marks.clear();
      _operationId = null;
    });
    try {
      final roster = await widget.repository.getSessionAttendance(
        congregationId: item.congregationId,
        sessionId: item.id,
      );
      if (mounted) {
        setState(() {
          _roster = roster;
          _loading = false;
          for (final mark in roster.marks) {
            _marks[mark.enrollmentId] = mark.status;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível abrir a chamada. Tente novamente.';
        });
      }
    }
  }

  Future<void> _save({required bool finalize}) async {
    final roster = _roster;
    if (roster == null) return;
    final congregationId = roster.session.metadata.congregationId;
    if (congregationId == null) return;
    final operation = _operationId ??= _newOperation();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.command(
        name: 'save_attendance',
        operationId: operation,
        payload: {
          'congregation_id': congregationId,
          'session_id': roster.session.id,
          'expected_revision': roster.session.metadata.revision,
          'marks': {
            for (final mark in roster.marks)
              mark.enrollmentId:
                  (_marks[mark.enrollmentId] ?? mark.status).wire,
          },
          'finalize': finalize,
        },
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _operationId = null;
      });
      await _open(
        PendingMinistrySession(
          id: roster.session.id,
          classId: roster.session.classId,
          className: roster.session.classId,
          congregationId: congregationId,
          date: roster.session.date,
          topic: roster.session.topic,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is DataFailure && error.code == 'permission'
              ? 'Seu acesso mudou. Atualize a sessão.'
              : 'Não foi possível salvar. As marcações e o código de operação foram mantidos; tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Frequência',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'A chamada preserva a lista de alunos registrada no início da sessão.',
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: _roster == null
                                ? () => _load(cursor: _retryCursor)
                                : () => _save(finalize: false),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando frequência',
                  ),
                ),
              if (_roster == null) ...[
                for (final item
                    in _page?.items ?? const <PendingMinistrySession>[])
                  Card(
                    child: ListTile(
                      title: Text(item.className),
                      subtitle: Text(
                        '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _loading ? null : () => _open(item),
                    ),
                  ),
                if (!_loading && _page?.items.isEmpty == true)
                  const Text('Não há chamadas pendentes.'),
                if (_page?.nextCursor != null)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _load(cursor: _page!.nextCursor),
                    child: Text(
                      _loading
                          ? 'Carregando chamadas…'
                          : 'Carregar mais chamadas',
                    ),
                  ),
              ] else ...[
                Text(
                  'Lista congelada · ${_roster!.session.date.year}-${_roster!.session.date.month.toString().padLeft(2, '0')}-${_roster!.session.date.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final mark in _roster!.marks)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              mark.studentName,
                              semanticsLabel: 'Aluno ${mark.studentName}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<AttendanceStatus>(
                            value: _marks[mark.enrollmentId] ?? mark.status,
                            items: [
                              for (final status in AttendanceStatus.values)
                                DropdownMenuItem(
                                  value: status,
                                  child: Text(_label(status)),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(
                                        () => _marks[mark.enrollmentId] = value,
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => _save(finalize: false),
                      child: const Text('Salvar chamada'),
                    ),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(finalize: true),
                      child: const Text('Salvar e finalizar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  String _label(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => 'Presente',
    AttendanceStatus.absent => 'Ausente',
    AttendanceStatus.excused => 'Justificado',
    AttendanceStatus.unmarked => 'Sem marcação',
  };
}
