import 'package:flutter/material.dart';

class MinistryHomePage extends StatefulWidget {
  const MinistryHomePage({
    super.key,
    required this.loadOverview,
    required this.scopeName,
    required this.onOpenStudents,
    required this.onOpenClasses,
    required this.onOpenAttendance,
  });
  final Future<Map<String, Object?>> Function() loadOverview;
  final String scopeName;
  final VoidCallback onOpenStudents, onOpenClasses, onOpenAttendance;
  @override
  State<MinistryHomePage> createState() => _MinistryHomePageState();
}

class _MinistryHomePageState extends State<MinistryHomePage> {
  late Future<Map<String, Object?>> _overview;
  @override
  void initState() {
    super.initState();
    _overview = widget.loadOverview();
  }

  void _refresh() => setState(() => _overview = widget.loadOverview());
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
              const SizedBox(height: 12),
              FutureBuilder<Map<String, Object?>>(
                future: _overview,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _ErrorRetry(onRetry: _refresh);
                  if (!snapshot.hasData)
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Carregando resumo',
                        ),
                      ),
                    );
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
                onPressed: widget.onOpenStudents,
                icon: const Icon(Icons.school_outlined),
                label: const Text('Alunos'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenClasses,
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
  final VoidCallback onTap;
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
