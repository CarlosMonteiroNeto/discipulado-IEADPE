import 'package:flutter/material.dart';

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
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Discipulado · ${widget.scopeName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.scopeError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.scopeError!,
                      semanticsLabel: 'Falha ao carregar congregações',
                    ),
                    TextButton(
                      onPressed: widget.onRetryScope,
                      child: const Text('Tentar carregar novamente'),
                    ),
                  ],
                ),
              if (widget.scopeLoading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Carregando congregações autorizadas',
                ),
              if (widget.availableCongregationIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('ministry-congregation-scope'),
                  initialValue: widget.selectedCongregationId,
                  decoration: const InputDecoration(labelText: 'Congregação'),
                  hint: const Text('Selecione uma congregação'),
                  items: [
                    for (final id in widget.availableCongregationIds)
                      DropdownMenuItem(
                        value: id,
                        child: Text(widget.congregationNames[id] ?? id),
                      ),
                  ],
                  onChanged: widget.onSelectCongregation,
                ),
              ] else if (!widget.scopedActionsEnabled)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhuma congregação autorizada está disponível para esta sessão.',
                  ),
                ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, Object?>>(
                future: _overview,
                builder: (context, snapshot) {
                  if (widget.scopeRequired) {
                    return const Text(
                      'Selecione uma congregação para ver os dados.',
                    );
                  }
                  if (snapshot.hasError) return _ErrorRetry(onRetry: _refresh);
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
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
                        onTap: widget.onOpenStudents,
                      ),
                      _CountTile(
                        label: 'Turmas',
                        value: data['classes'],
                        onTap: widget.onOpenClasses,
                      ),
                      _CountTile(
                        label: 'Chamadas abertas',
                        value: data['open_sessions'],
                        onTap: widget.onOpenAttendance,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
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
        ),
      ),
    ),
  );
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final Object? value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text('${value ?? '—'}'),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
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
      const Text('Não foi possível carregar o resumo.'),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
    ],
  );
}
