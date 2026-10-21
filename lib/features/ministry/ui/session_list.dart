import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import 'session_form.dart';

class SessionListPage extends StatefulWidget {
  const SessionListPage({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.classSummary,
    required this.onOpenSession,
  });
  final MinistryRepository repository;
  final String congregationId;
  final MinistryClassSummary classSummary;
  final Future<void> Function(String sessionId) onOpenSession;
  @override
  State<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends State<SessionListPage> {
  final _uuid = const Uuid();
  final _scrollController = ScrollController();
  final List<MinistrySessionSummary> _sessions = [];
  String? _nextCursor;
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  _PendingCancel? _pendingCancel;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SessionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.classSummary.id != widget.classSummary.id) {
      _loadToken++;
      _sessions.clear();
      _nextCursor = null;
      _pendingCancel = null;
      _load();
    }
  }

  Future<void> _load({bool append = false}) async {
    final token = ++_loadToken;
    final cursor = append ? _nextCursor : null;
    if (append ? cursor == null : false) return;
    setState(() {
      _loading = !append;
      _loadingMore = append;
      _error = null;
      if (!append) {
        _sessions.clear();
        _nextCursor = null;
      }
    });
    try {
      final page = await widget.repository.listClassSessions(
        congregationId: widget.congregationId,
        classId: widget.classSummary.id,
        limit: 50,
        cursor: cursor,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        if (!append) _sessions.clear();
        final ids = _sessions.map((item) => item.id).toSet();
        for (final item in page.items) {
          if (ids.add(item.id)) _sessions.add(item);
        }
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Não foi possível carregar as aulas. Tente novamente.';
      });
    }
  }

  Future<void> _refreshLoadedSessions() async {
    final token = ++_loadToken;
    // Claim ownership from any in-flight load: the invalidated request bails on
    // its token check, so the flags it set must not stay stuck.
    setState(() {
      _loading = false;
      _loadingMore = false;
    });
    final targetCount = _sessions.length;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    try {
      final refreshed = <MinistrySessionSummary>[];
      final ids = <String>{};
      String? cursor;
      String? nextCursor;
      do {
        final page = await widget.repository.listClassSessions(
          congregationId: widget.congregationId,
          classId: widget.classSummary.id,
          limit: 50,
          cursor: cursor,
        );
        if (!mounted || token != _loadToken) return;
        for (final item in page.items) {
          if (ids.add(item.id)) refreshed.add(item);
        }
        nextCursor = page.nextCursor;
        cursor = nextCursor;
        if (page.items.isEmpty) break;
      } while (nextCursor != null && refreshed.length < targetCount);
      setState(() {
        _sessions
          ..clear()
          ..addAll(refreshed);
        _nextCursor = nextCursor;
        _error = null;
      });
      if (previousOffset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              token != _loadToken ||
              !_scrollController.hasClients) {
            return;
          }
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(previousOffset > max ? max : previousOffset);
        });
      }
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(
        () => _error = 'Não foi possível carregar as aulas. Tente novamente.',
      );
    }
  }

  Future<void> _create({MinistrySessionSummary? replaces}) async {
    if (_busy ||
        _pendingCancel != null ||
        widget.classSummary.status != ClassStatus.active) {
      return;
    }
    final result = await Navigator.of(context).push<SessionFormResult>(
      MaterialPageRoute(
        builder: (_) => SessionForm(
          repository: widget.repository,
          congregationId: widget.congregationId,
          classSummary: widget.classSummary,
          existingSessions: List.unmodifiable(_sessions),
          replacesSessionId: replaces?.id,
          initialDate: replaces?.date,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.conflict) {
      setState(() {
        _error = null;
        _notice =
            'Outra pessoa registrou uma substituta para esta aula. '
            'A lista foi atualizada com o vínculo atual.';
      });
      await _refreshLoadedSessions();
      return;
    }
    final id = result.sessionId;
    if (id == null) return;
    await widget.onOpenSession(id);
    if (mounted) await _refreshLoadedSessions();
  }

  Future<void> _open(MinistrySessionSummary session) async {
    try {
      await widget.onOpenSession(session.id);
      if (mounted) await _refreshLoadedSessions();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível abrir a aula. Atualize e tente novamente.',
        );
      }
    }
  }

  Future<void> _cancel(MinistrySessionSummary item) async {
    if (_busy || item.status == SessionStatus.canceled) return;
    setState(() => _notice = null);
    MinistryRoster roster;
    try {
      roster = await widget.repository.getSessionAttendance(
        congregationId: widget.congregationId,
        sessionId: item.id,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível atualizar a aula. Atualize os dados e tente novamente.',
        );
      }
      return;
    }
    if (!mounted) return;
    final session = roster.session;
    if (session.id != item.id ||
        item.classId != widget.classSummary.id ||
        item.congregationId != widget.congregationId ||
        session.classId != item.classId ||
        session.classId != widget.classSummary.id ||
        session.congregationId != item.congregationId ||
        session.congregationId != widget.congregationId) {
      setState(
        () => _error = 'A aula retornada não corresponde ao contexto atual. Atualize os dados e tente novamente.',
      );
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar aula?'),
        content: Text(
          '${widget.classSummary.name} · '
          '${session.date.toString().split('-').reversed.join('/')} · '
          '${session.topic ?? 'Sem tema'}\n'
          'A aula será cancelada e o histórico da turma será mantido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar aula'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final signature = jsonEncode([
      widget.congregationId,
      session.id,
      session.metadata.revision,
    ]);
    final pending = _pendingCancel;
    if (pending != null && pending.signature != signature) {
      setState(
        () =>
            _error = 'Resolva primeiro a solicitação de cancelamento pendente.',
      );
      return;
    }
    final request =
        pending ??
        _PendingCancel(
          _uuid.v4(),
          widget.congregationId,
          session.id,
          session.metadata.revision,
          signature,
        );
    _pendingCancel ??= request;
    await _submitCancel(request);
  }

  Future<void> _submitCancel(_PendingCancel request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.cancelSession(
        operationId: request.operationId,
        id: request.id,
        congregationId: request.congregationId,
        expectedRevision: request.revision,
      );
      if (identical(_pendingCancel, request)) _pendingCancel = null;
      if (mounted) {
        final canceled = _loaded(request.id);
        final identity = canceled == null
            ? widget.classSummary.name
            : '${widget.classSummary.name} · '
                  '${_displayDate(canceled.date)} · '
                  '${canceled.topic ?? 'Sem tema'}';
        setState(() {
          _busy = false;
          _error = null;
          _notice = 'Aula cancelada: $identity. O histórico foi mantido.';
        });
        await _load();
      }
    } catch (error) {
      if (!mounted) return;
      if (error is DataFailure &&
          const {
            'invalid',
            'permission',
            'forbidden',
            'invalid_congregation',
            'stale_revision',
            'class_not_active',
            'operation_conflict',
          }.contains(error.code) &&
          identical(_pendingCancel, request)) {
        _pendingCancel = null;
      }
      setState(() {
        _busy = false;
        if (error is DataFailure && error.code == 'stale_revision') {
          _notice = 'A aula foi alterada. Atualize e confirme o cancelamento novamente.';
        } else {
          _error = 'Não foi possível cancelar a aula. Tente novamente.';
        }
      });
      if (error is DataFailure && error.code == 'stale_revision') await _load();
    }
  }

  String _displayDate(CalendarDate date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  MinistrySessionSummary? _loaded(String? id) {
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  String? _lineage(MinistrySessionSummary item) {
    final parts = <String>[];
    if (item.replacesSessionId != null) {
      final parent = _loaded(item.replacesSessionId);
      parts.add(
        parent == null
            ? 'Substituta de uma aula cancelada'
            : 'Substituta de ${_displayDate(parent.date)}',
      );
    }
    if (item.status == SessionStatus.canceled &&
        item.replacementSessionId != null) {
      final child = _loaded(item.replacementSessionId);
      parts.add(
        child == null
            ? 'Substituição já registrada'
            : 'Substituída pela aula de ${_displayDate(child.date)}',
      );
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _label(SessionStatus status) => switch (status) {
    SessionStatus.open => 'Aberta',
    SessionStatus.finalized => 'Finalizada',
    SessionStatus.canceled => 'Cancelada',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.classSummary.name)),
    body: SafeArea(
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.classSummary.status == ClassStatus.active)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('create-session'),
                onPressed: _busy || _pendingCancel != null ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('Nova aula'),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('refresh-sessions'),
              onPressed: _loading || _loadingMore ? null : () => _load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar aulas'),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_notice != null)
            Text(_notice!, style: const TextStyle(color: Colors.orange)),
          if (!_loading && _error == null && _sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhuma aula registrada nesta turma.'),
            ),
          for (final item in _sessions)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(_displayDate(item.date)),
                    subtitle: Text(
                      [
                        '${_label(item.status)}'
                            '${item.topic == null ? '' : ' · ${item.topic}'}',
                        ?_lineage(item),
                      ].join(' · '),
                    ),
                    onTap: () => _open(item),
                  ),
                  if (item.status != SessionStatus.canceled)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: TextButton(
                          key: Key('cancel-session-${item.id}'),
                          onPressed: _busy ? null : () => _cancel(item),
                          child: const Text('Cancelar aula'),
                        ),
                      ),
                    )
                  else if (item.replacementSessionId == null)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 8,
                        bottom: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: widget.classSummary.status == ClassStatus.active
                            ? TextButton.icon(
                                key: Key('replace-session-${item.id}'),
                                onPressed: _busy || _pendingCancel != null
                                    ? null
                                    : () => _create(replaces: item),
                                icon: const Icon(Icons.replay_outlined),
                                label: const Text('Registrar substituta'),
                              )
                            : const Text(
                                'Substituição indisponível: a turma não está ativa.',
                              ),
                      ),
                    ),
                ],
              ),
            ),
          if (_nextCursor != null)
            TextButton(
              onPressed: _loadingMore ? null : () => _load(append: true),
              child: const Text('Carregar mais'),
            ),
          if (_pendingCancel != null)
            TextButton(
              key: const Key('retry-pending-session-cancel'),
              onPressed: _busy ? null : () => _submitCancel(_pendingCancel!),
              child: const Text('Repetir cancelamento pendente'),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

class _PendingCancel {
  const _PendingCancel(
    this.operationId,
    this.congregationId,
    this.id,
    this.revision,
    this.signature,
  );
  final String operationId, congregationId, id, signature;
  final int revision;
}
