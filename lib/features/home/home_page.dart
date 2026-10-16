import 'package:flutter/material.dart';

import '../weekly/weekly_repository.dart';
import 'home_repository.dart';
import '../../data/supabase_gateway.dart';
import '../../widgets/brand_header.dart';
import '../weekly/weekly_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.weekly,
    required this.onNavigate,
    this.name = 'Visitante',
    this.isAdmin = false,
    this.onScopeRefresh,
    this.refreshRevision = 0,
  });
  final HomeRepository repository;
  final WeeklyRepository weekly;
  final ValueChanged<String> onNavigate;
  final String name;
  final bool isAdmin;
  final Future<void> Function()? onScopeRefresh;

  /// Refreshes summaries and the existing weekly owner, preserving write retries.
  final int refreshRevision;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _token;
  HomeSummary? _summary;
  String? _error;
  int _request = 0, _weeklyRevision = 0;
  bool _denied = false;
  @override
  void initState() {
    super.initState();
    _token = widget.repository.converts.gateway.context;
    _load();
  }

  bool get _current {
    if (!mounted) return false;
    try {
      widget.repository.converts.gateway.ensureCurrent(_token);
      return true;
    } on DataFailure {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.weekly != widget.weekly ||
        _token != widget.repository.converts.gateway.context) {
      _token = widget.repository.converts.gateway.context;
      _denied = false;
      _weeklyRevision++;
      _load();
    } else if (oldWidget.refreshRevision != widget.refreshRevision) {
      _weeklyRevision++;
      _load();
    }
  }

  Future<void> _deny() async {
    if (!_current) return;
    setState(() {
      _request++;
      _denied = true;
      _summary = null;
      _error = 'Seu acesso mudou. Atualize seu acesso para continuar.';
    });
    await widget.onScopeRefresh?.call();
  }

  Future<void> _load() async {
    if (!_current || _denied) return;
    final request = ++_request;
    setState(() {
      _summary = null;
      _error = null;
    });
    try {
      final summary = await widget.repository.summary();
      if (_current && request == _request) setState(() => _summary = summary);
    } catch (error) {
      if (!_current || request != _request) return;
      if (error is DataFailure && error.code == 'permission') {
        await _deny();
      } else {
        setState(
          () => _error = 'Não foi possível carregar o início. Tente novamente.',
        );
      }
    }
  }

  Future<void> _refresh() async {
    if (!_current || _denied) return;
    setState(() => _weeklyRevision++);
    await _load();
  }

  @override
  void dispose() {
    _request++;
    _summary = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) return const SizedBox.shrink();
    final summary = _summary;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandHeader(subtitle: 'Gestão de Novos Convertidos'),
                const SizedBox(height: 16),
                Text(
                  'Olá, ${widget.name}!',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Atualizar início',
              onPressed: _denied ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_error != null) ...[
            Semantics(liveRegion: true, child: Text(_error!)),
            TextButton(
              onPressed: _denied ? widget.onScopeRefresh : _refresh,
              child: Text(_denied ? 'Atualizar acesso' : 'Tentar novamente'),
            ),
          ] else if (summary == null)
            const Text('Carregando início…')
          else ...[
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final metric in [
                    (
                      label: 'Total',
                      value: summary.total,
                      color: const Color(0xff1e3a5f),
                    ),
                    (
                      label: 'Visitas Urgentes',
                      value: summary.urgentVisits,
                      color: const Color(0xffb91c1c),
                    ),
                    (
                      label: 'Em Discipulado',
                      value: summary.inDiscipleship,
                      color: const Color(0xff166534),
                    ),
                  ])
                    SizedBox(
                      width:
                          constraints.maxWidth < 500 ||
                              MediaQuery.textScalerOf(context).scale(16) > 24
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 24) / 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                '${metric.value}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: metric.color,
                                ),
                              ),
                              Text(metric.label),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (!_denied) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => widget.onNavigate('/register'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Novo Cadastro'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigate('/converts'),
                  icon: const Icon(Icons.people),
                  label: const Text('Ver Convertidos'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            WeeklyPanel(
              key: ValueKey('weekly:$_token'),
              repository: widget.weekly,
              refreshRevision: _weeklyRevision,
              onScopeRefresh: _deny,
            ),
            const SizedBox(height: 24),
            if (summary != null) ...[
              const Text(
                'Convertidos Recentes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1e3a5f),
                ),
              ),
              if (summary.recent.isEmpty)
                const Text('Nenhuma conversão nos últimos sete dias.'),
              for (final row in summary.recent)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(row.name),
                    subtitle: Text(
                      '${row.conversionDate.day.toString().padLeft(2, '0')}/${row.conversionDate.month.toString().padLeft(2, '0')}/${row.conversionDate.year}',
                    ),
                  ),
                ),
            ],
            if (widget.isAdmin)
              TextButton.icon(
                onPressed: () => widget.onNavigate('/admin'),
                icon: const Icon(Icons.settings),
                label: const Text('Administração'),
              ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
