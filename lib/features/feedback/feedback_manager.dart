import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart' as domain;
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
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
    color: Theme.of(context).colorScheme.surface,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Base44PageHeading(
                title: 'Dúvidas e sugestões',
                icon: Icons.forum_outlined,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _refreshScope,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar acesso'),
                  ),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Fechar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Carregando…'),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff7f7),
                        border: Border.all(color: const Color(0xfffecaca)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _notice!,
                        style: const TextStyle(color: UnifiedColors.red),
                      ),
                    ),
                  ),
                ),
              if (_operation != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _update(_id!, _status!),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ),
                ),
              if (_rows?.isEmpty ?? false)
                const Base44Panel(
                  child: Text(
                    'Nenhum feedback recebido.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final row in _rows ?? <domain.Feedback>[])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Base44Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.account_circle_outlined,
                                color: UnifiedColors.muted,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.userName ?? row.userEmail ?? 'Usuário',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: UnifiedColors.brandNavy),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: UnifiedColors.page,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(row.message),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: Icon(switch (row.status) {
                              domain.FeedbackStatus.pending =>
                                Icons.fiber_new_outlined,
                              domain.FeedbackStatus.read =>
                                Icons.mark_email_read_outlined,
                              domain.FeedbackStatus.resolved =>
                                Icons.check_circle_outline,
                            }, size: 18),
                            label: Text(switch (row.status) {
                              domain.FeedbackStatus.pending => 'Novo',
                              domain.FeedbackStatus.read => 'Lido',
                              domain.FeedbackStatus.resolved => 'Resolvido',
                            }),
                            backgroundColor: switch (row.status) {
                              domain.FeedbackStatus.pending => const Color(
                                0xfffff7ed,
                              ),
                              domain.FeedbackStatus.read =>
                                UnifiedColors.pageTint,
                              domain.FeedbackStatus.resolved => const Color(
                                0xfff0fdf4,
                              ),
                            },
                          ),
                        ),
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
