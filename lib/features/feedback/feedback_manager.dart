import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart' as domain;
import 'feedback_repository.dart';
import 'feedback_dialog.dart';

/// Inline manager panel owned and removed by the authenticated root.
class FeedbackManager extends StatefulWidget {
  const FeedbackManager({
    super.key,
    required this.repository,
    required this.onClose,
    required this.onScopeRefresh,
  });
  final FeedbackRepository repository;
  final VoidCallback onClose;
  final Future<void> Function() onScopeRefresh;
  @override
  State<FeedbackManager> createState() => _FeedbackManagerState();
}

class _FeedbackManagerState extends State<FeedbackManager> {
  List<domain.Feedback>? _rows;
  bool _busy = false;
  String? _notice, _operation, _id;
  domain.FeedbackStatus? _status;
  int _request = 0;
  late String _token;
  @override
  void initState() {
    super.initState();
    _token = widget.repository.gateway.context;
    _load();
  }

  @override
  void didUpdateWidget(covariant FeedbackManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_token != widget.repository.gateway.context) {
      _request++;
      _rows = null;
      _operation = null;
      _id = null;
      _status = null;
      _notice = null;
      _busy = false;
      _token = widget.repository.gateway.context;
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _rows = null;
    super.dispose();
  }

  bool _current(int request, String token) =>
      mounted &&
      request == _request &&
      token == widget.repository.gateway.context;
  Future<void> _load() async {
    if (_busy) return;
    final request = ++_request, token = _token;
    setState(() => _busy = true);
    try {
      final rows = await widget.repository.list();
      if (!_current(request, token)) return;
      setState(() {
        _rows = rows;
        _notice = null;
        _busy = false;
      });
    } catch (error) {
      if (!_current(request, token)) return;
      setState(() {
        _rows = null;
        _busy = false;
        _notice = feedbackFailure(error is DataFailure ? error.code : null);
      });
    }
  }

  Future<void> _update(String id, domain.FeedbackStatus status) async {
    if (_busy) return;
    _id ??= id;
    _status ??= status;
    _operation ??= const Uuid().v4();
    final request = ++_request, token = _token;
    setState(() => _busy = true);
    try {
      final result = await widget.repository.update(
        _id!,
        _status!,
        _operation!,
      );
      if (!_current(request, token)) return;
      setState(() {
        _busy = false;
        _notice = feedbackFailure(result.errorCode);
        if (result.errorCode == 'permission' || result.errorCode == 'stale') {
          _rows = null;
        }
      });
      if (result.status == domain.MutationStatus.applied) {
        _operation = null;
        _id = null;
        _status = null;
        await _load();
      } else if (!uncertainFeedback(result.errorCode)) {
        setState(() {
          _operation = null;
          _id = null;
          _status = null;
        });
      }
    } catch (error) {
      if (!_current(request, token)) return;
      setState(() {
        _busy = false;
        _notice = feedbackFailure(error is DataFailure ? error.code : null);
      });
    }
  }

  Future<void> _refreshScope() async {
    if (_busy) return;
    final request = ++_request, token = _token;
    setState(() => _busy = true);
    try {
      widget.repository.gateway.ensureCurrent(token);
      await widget.onScopeRefresh();
      if (!mounted || request != _request) return;
      widget.repository.gateway.ensureCurrent(token);
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _busy = false;
        _notice = feedbackFailure(error is DataFailure ? error.code : null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dúvidas e sugestões',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _refreshScope,
                    child: const Text('Atualizar acesso'),
                  ),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Fechar'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Atualizar'),
                  ),
                ],
              ),
              if (_busy) const Text('Carregando…'),
              if (_notice != null) Text(_notice!),
              if (_operation != null)
                FilledButton(
                  onPressed: _busy ? null : () => _update(_id!, _status!),
                  child: const Text('Tentar novamente'),
                ),
              if (_rows?.isEmpty ?? false)
                const Text('Nenhum feedback recebido.'),
              for (final row in _rows ?? <domain.Feedback>[])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(row.userName ?? row.userEmail ?? 'Usuário'),
                        Text(row.message),
                        Text(switch (row.status) {
                          domain.FeedbackStatus.pending => 'Novo',
                          domain.FeedbackStatus.read => 'Lido',
                          domain.FeedbackStatus.resolved => 'Resolvido',
                        }),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final status in domain.FeedbackStatus.values)
                              TextButton(
                                onPressed:
                                    _busy ||
                                        _operation != null ||
                                        status == row.status
                                    ? null
                                    : () => _update(row.id, status),
                                child: Text(switch (status) {
                                  domain.FeedbackStatus.pending =>
                                    'Marcar como novo',
                                  domain.FeedbackStatus.read =>
                                    'Marcar como lido',
                                  domain.FeedbackStatus.resolved => 'Resolver',
                                }),
                              ),
                          ],
                        ),
                      ],
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
