import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import 'weekly_repository.dart';

/// Task 19 must key/unmount this entire owner on boundary or identity changes.
/// It retains protected records, inline confirmation and logical retry IDs.
class WeeklyPanel extends StatefulWidget {
  const WeeklyPanel({super.key, required this.repository, this.onScopeRefresh});
  final WeeklyRepository repository;
  final Future<void> Function()? onScopeRefresh;
  @override
  State<WeeklyPanel> createState() => _WeeklyPanelState();
}

class _WeeklyPanelState extends State<WeeklyPanel> {
  late String _token;
  WeeklyOverview? _overview;
  WeeklyEntry? _confirming;
  final _operations = <String, String>{};
  String? _error;
  bool _loading = true, _busy = false, _denied = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _token = widget.repository.gateway.context;
    _load();
  }

  @override
  void didUpdateWidget(covariant WeeklyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.gateway != widget.repository.gateway ||
        _token != widget.repository.gateway.context) {
      _clear();
      _token = widget.repository.gateway.context;
      _denied = false;
      _load();
    }
  }

  bool get _current {
    if (!mounted) return false;
    try {
      widget.repository.gateway.ensureCurrent(_token);
      return true;
    } on DataFailure {
      return false;
    }
  }

  void _clear() {
    _request++;
    _overview = null;
    _confirming = null;
    _operations.clear();
    _error = null;
    _busy = false;
  }

  Future<void> _deny() async {
    setState(() {
      _clear();
      _denied = true;
      _loading = false;
      _error = 'Seu acesso mudou. Atualize seu acesso para continuar.';
    });
    await widget.onScopeRefresh?.call();
  }

  Future<void> _load() async {
    if (!_current || _denied) return;
    final request = ++_request;
    final previousWeek = _overview?.weekStart;
    setState(() {
      _loading = true;
      _error = null;
      _overview = null;
    });
    try {
      final result = await widget.repository.overview();
      if (!_current || request != _request) return;
      setState(() {
        if (previousWeek != result.weekStart) _operations.clear();
        _overview = result;
        _confirming = null;
      });
    } catch (error) {
      if (!_current || request != _request) return;
      if (error is DataFailure && error.code == 'stale') return;
      if (error is DataFailure && error.code == 'permission') {
        await _deny();
      } else {
        setState(
          () => _error =
              'Não foi possível carregar o relatório. Tente novamente.',
        );
      }
    } finally {
      if (_current && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (!_current || _denied || _busy || _confirming == null) return;
    final entry = _confirming!;
    final owner = widget.repository.gateway;
    final token = _token;
    final request = _request;
    bool ownsResult() =>
        _current && owner == widget.repository.gateway && token == _token;
    final key = '${_overview!.weekStart}:${entry.id}';
    final operation = _operations.putIfAbsent(key, () => const Uuid().v4());
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.confirmZero(entry.id, operation);
    if (!_current ||
        owner != widget.repository.gateway ||
        token != _token ||
        request != _request) {
      return;
    }
    if (result.errorCode == 'stale') return;
    if (result.errorCode == 'permission') {
      await _deny();
      return;
    }
    if (result.errorCode == null) {
      _operations.remove(key);
      await _load();
    } else if (result.errorCode == 'invalid') {
      _operations.remove(key);
      await _load();
      if (ownsResult()) {
        setState(
          () => _error =
              'O período ou os dados mudaram. Confira o relatório atualizado.',
        );
      }
    } else {
      setState(
        () => _error =
            'Não foi possível confirmar. Tente novamente a mesma ação.',
      );
    }
    if (ownsResult()) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  String _date(Object date) {
    final parts = date.toString().split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) return const SizedBox.shrink();
    final overview = _overview;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Carregando relatório semanal…'),
      );
    }
    if (_denied) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!, semanticsLabel: _error),
          if (widget.onScopeRefresh != null)
            TextButton(
              onPressed: widget.onScopeRefresh,
              child: const Text('Atualizar acesso'),
            ),
        ],
      );
    }
    if (overview == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error ?? 'Não foi possível carregar o relatório.'),
          TextButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      );
    }
    if (!overview.visible || overview.entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sem Conversões na Última Semana',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xff1e3a5f),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_date(overview.weekStart!)} a ${_date(overview.weekStart!.addDays(6))}',
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xff9a3412)),
              ),
            ),
          for (final entry in overview.entries)
            Card(
              color: overview.isGlobal ? Colors.white : const Color(0xfffff7ed),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overview.isGlobal) ...[
                      Text(
                        entry.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        entry.confirmed ? 'Confirmado' : 'Aguardando',
                        style: TextStyle(
                          color: entry.confirmed
                              ? const Color(0xff2563eb)
                              : const Color(0xff9a3412),
                        ),
                      ),
                    ] else if (entry.confirmed) ...[
                      const Text(
                        'Relatório confirmado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xff166534),
                        ),
                      ),
                      Text(
                        'Você confirmou que não houve conversões em ${entry.name} na última semana.',
                      ),
                    ] else ...[
                      Text(
                        'Não houve conversões em ${entry.name} na última semana',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xff9a3412),
                        ),
                      ),
                      if (_confirming?.id != entry.id)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _confirming = entry;
                                  _error = null;
                                }),
                          child: const Text('Confirmar sem conversões'),
                        )
                      else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Você confirma que não houve conversões em ${entry.name} neste período?',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _confirming = null;
                                      _error = null;
                                    }),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: _busy ? null : _confirm,
                              child: Text(_busy ? 'Confirmando…' : 'Confirmar'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Atualizar relatório'),
          ),
        ],
      ),
    );
  }
}
