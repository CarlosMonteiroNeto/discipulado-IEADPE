import 'package:flutter/material.dart';

import '../weekly/weekly_repository.dart';
import 'home_repository.dart';
import '../../data/supabase_gateway.dart';
import '../../widgets/brand_header.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Base44Hero(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandHeader(subtitle: 'Gestão de Novos Convertidos'),
                    const SizedBox(height: 16),
                    Text(
                      'Olá, ${widget.name}!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Base44PageHeading(
                title: 'Visão Geral',
                icon: Icons.dashboard_outlined,
                trailing: IconButton(
                  tooltip: 'Atualizar início',
                  onPressed: _denied ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(liveRegion: true, child: Text(_error!)),
                      TextButton.icon(
                        onPressed: _denied ? widget.onScopeRefresh : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _denied ? 'Atualizar acesso' : 'Tentar novamente',
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (summary == null)
                const Base44Panel(
                  child: Center(child: Text('Carregando início…')),
                )
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
                          color: UnifiedColors.brandNavy,
                          icon: Icons.people_outline,
                        ),
                        (
                          label: 'Visitas Urgentes',
                          value: summary.urgentVisits,
                          color: UnifiedColors.red,
                          icon: Icons.warning_amber_outlined,
                        ),
                        (
                          label: 'Em Discipulado',
                          value: summary.inDiscipleship,
                          color: UnifiedColors.green,
                          icon: Icons.menu_book_outlined,
                        ),
                      ])
                        SizedBox(
                          width:
                              constraints.maxWidth < 500 ||
                                  MediaQuery.textScalerOf(context).scale(16) >
                                      24
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3,
                          child: Base44Panel(
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: metric.color.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(metric.icon, color: metric.color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${metric.value}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: metric.color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(metric.label),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (!_denied) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            UnifiedColors.brandNavy,
                            UnifiedColors.brandBlue,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                        ),
                        onPressed: () => widget.onNavigate('/register'),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Novo Cadastro'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.onNavigate('/converts'),
                      icon: const Icon(Icons.people_outline),
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
                  const Base44PageHeading(
                    title: 'Convertidos Recentes',
                    icon: Icons.trending_up,
                  ),
                  const SizedBox(height: 8),
                  if (summary.recent.isEmpty)
                    const Base44Panel(
                      child: Text('Nenhuma conversão nos últimos sete dias.'),
                    ),
                  for (final row in summary.recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Base44Panel(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: UnifiedColors.selected,
                              foregroundColor: UnifiedColors.brandNavy,
                              child: Icon(Icons.person_outline),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    '${row.conversionDate.day.toString().padLeft(2, '0')}/${row.conversionDate.month.toString().padLeft(2, '0')}/${row.conversionDate.year}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (widget.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Base44Panel(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(
                          Icons.settings_outlined,
                          color: UnifiedColors.brandNavy,
                        ),
                        title: const Text('Administração'),
                        subtitle: const Text('Congregações e acessos'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => widget.onNavigate('/admin'),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
