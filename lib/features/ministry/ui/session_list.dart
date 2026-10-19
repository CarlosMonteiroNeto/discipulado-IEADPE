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

  Future<void> _create() async {
    if (_busy || widget.classSummary.status != ClassStatus.active) return;
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SessionForm(
          repository: widget.repository,
          congregationId: widget.congregationId,
          classSummary: widget.classSummary,
          existingSessions: List.unmodifiable(_sessions),
        ),
      ),
    );
    if (!mounted || id == null) return;
    await widget.onOpenSession(id);
    if (mounted) await _load();
  }

  Future<void> _open(MinistrySessionSummary session) async {
    await widget.onOpenSession(session.id);
    if (mounted) await _load();
  }

  Future<void> _cancel(MinistrySessionSummary item) async {
    if (_busy || item.status != SessionStatus.open) return;
    MinistryRoster roster;
    try {
      roster = await widget.repository.getSessionAttendance(
        congregationId: widget.congregationId,
        sessionId: item.id,
      );
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível atualizar a aula. Atualize os dados e tente novamente.',
        );
      return;
    }
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar aula?'),
        content: const Text(
          'A aula será cancelada e o histórico da turma será mantido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar cancelamento'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final session = roster.session;
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
        setState(() => _busy = false);
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
          identical(_pendingCancel, request))
        _pendingCancel = null;
      setState(() {
        _busy = false;
        _error = error is DataFailure && error.code == 'stale_revision'
            ? 'A aula foi alterada. Atualize e confirme o cancelamento novamente.'
            : 'Não foi possível cancelar a aula. Tente novamente.';
      });
      if (error is DataFailure && error.code == 'stale_revision') await _load();
    }
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
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('Nova aula'),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          for (final item in _sessions)
            Card(
              child: ListTile(
                title: Text(item.date.toString().split('-').reversed.join('/')),
                subtitle: Text(
                  '${_label(item.status)}${item.topic == null ? '' : ' · ${item.topic}'}',
                ),
                onTap: () => _open(item),
                trailing:
                    item.status == SessionStatus.open &&
                        widget.classSummary.status == ClassStatus.active
                    ? TextButton(
                        key: Key('cancel-session-${item.id}'),
                        onPressed: _busy ? null : () => _cancel(item),
                        child: const Text('Cancelar aula'),
                      )
                    : null,
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
