import 'package:flutter/material.dart';

import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';

class MinistryHomePage extends StatefulWidget {
  const MinistryHomePage({
    super.key,
    required this.loadOverview,
    required this.scopeName,
    required this.onOpenStudents,
    required this.onOpenClasses,
    required this.onOpenAttendance,
    this.availableCongregationIds = const [],
    this.selectedCongregationId,
    this.onSelectCongregation,
    this.scopedActionsEnabled = true,
    this.scopeRequired = false,
    this.congregationNames = const {},
    this.scopeError,
    this.onRetryScope,
    this.scopeLoading = false,
    this.hasPreviousCongregationPage = false,
    this.hasNextCongregationPage = false,
    this.congregationPageNumber = 1,
    this.onPreviousCongregationPage,
    this.onNextCongregationPage,
  });
  final Future<Map<String, Object?>> Function() loadOverview;
  final String scopeName;
  final VoidCallback? onOpenStudents, onOpenClasses, onOpenAttendance;
  final List<String> availableCongregationIds;
  final String? selectedCongregationId;
  final ValueChanged<String?>? onSelectCongregation;
  final bool scopedActionsEnabled;
  final bool scopeRequired;
  final Map<String, String> congregationNames;
  final String? scopeError;
  final VoidCallback? onRetryScope;
  final bool scopeLoading;
  final bool hasPreviousCongregationPage;
  final bool hasNextCongregationPage;
  final int congregationPageNumber;
  final VoidCallback? onPreviousCongregationPage;
  final VoidCallback? onNextCongregationPage;
  @override
  State<MinistryHomePage> createState() => _MinistryHomePageState();
}

class _MinistryHomePageState extends State<MinistryHomePage> {
  late Future<Map<String, Object?>> _overview;
  @override
  void initState() {
    super.initState();
    _overview = widget.scopeRequired
        ? Future<Map<String, Object?>>.value(const {})
        : widget.loadOverview();
  }

  void _refresh() {
    if (widget.scopeRequired) return;
    setState(() => _overview = widget.loadOverview());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Base44Hero(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0x33ffffff),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discipulado',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.scopeName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xffdbeafe)),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.scopeError != null)
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.scopeError!,
                        semanticsLabel: 'Falha ao carregar congregações',
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: widget.onRetryScope,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar carregar novamente'),
                      ),
                    ],
                  ),
                ),
              if (widget.scopeLoading)
                const Base44Panel(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Carregando congregações autorizadas',
                  ),
                ),
              if (widget.availableCongregationIds.isNotEmpty) ...[
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Congregação',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: UnifiedColors.brandNavy),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'ministry-congregation-scope:${widget.congregationPageNumber}:${widget.selectedCongregationId}',
                        ),
                        initialValue: widget.selectedCongregationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Congregação autorizada',
                          prefixIcon: Icon(Icons.church_outlined),
                        ),
                        hint: const Text('Selecione uma congregação'),
                        items: [
                          for (final id in widget.availableCongregationIds)
                            DropdownMenuItem(
                              value: id,
                              child: Text(
                                widget.congregationNames[id] ?? id,
                                softWrap: true,
                              ),
                            ),
                        ],
                        onChanged: widget.onSelectCongregation,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: widget.hasPreviousCongregationPage
                                ? widget.onPreviousCongregationPage
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Anterior'),
                          ),
                          Text(
                            'Página ${widget.congregationPageNumber}',
                            textAlign: TextAlign.center,
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.hasNextCongregationPage
                                ? widget.onNextCongregationPage
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Próxima'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (!widget.scopedActionsEnabled)
                const Base44Panel(
                  child: Text(
                    'Nenhuma congregação autorizada está disponível para esta sessão.',
                  ),
                ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, Object?>>(
                future: _overview,
                builder: (context, snapshot) {
                  if (widget.scopeRequired) {
                    return const Base44Panel(
                      child: Text(
                        'Selecione uma congregação para ver os dados.',
                      ),
                    );
                  }
                  if (snapshot.hasError) return _ErrorRetry(onRetry: _refresh);
                  if (!snapshot.hasData) {
                    return const Base44Panel(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Carregando resumo',
                        ),
                      ),
                    );
                  }
                  final data = snapshot.data!;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _CountTile(
                        label: 'Alunos',
                        value: data['students'],
                        icon: Icons.school_outlined,
                        iconColor: UnifiedColors.brandNavy,
                        onTap: widget.onOpenStudents,
                      ),
                      _CountTile(
                        label: 'Turmas',
                        value: data['classes'],
                        icon: Icons.groups_outlined,
                        iconColor: UnifiedColors.brandBlue,
                        onTap: widget.onOpenClasses,
                      ),
                      _CountTile(
                        label: 'Chamadas abertas',
                        value: data['open_sessions'],
                        icon: Icons.fact_check_outlined,
                        iconColor: const Color(0xff15803d),
                        onTap: widget.onOpenAttendance,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: widget.scopedActionsEnabled
                        ? widget.onOpenStudents
                        : null,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Alunos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.scopedActionsEnabled
                        ? widget.onOpenClasses
                        : null,
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Turmas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenAttendance,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Frequência'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final String label;
  final Object? value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                '${value ?? '—'}',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: iconColor, fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Base44Panel(child: Text('Não foi possível carregar o resumo.')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Tentar novamente'),
      ),
    ],
  );
}
