import '../data/ministry_codec.dart';

import 'package:flutter/material.dart';

import '../data/ministry_browser_repository.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.onOpenAttendance,
  });
  final MinistryBrowserRepository repository;
  final String congregationId;
  final VoidCallback onOpenAttendance;
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  String? _status = 'active';
  String? _error;
  bool _loading = false;
  MinistryPage<MinistryClassSummary>? _page;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? cursor}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listClasses(
        congregationId: widget.congregationId,
        status: _status,
        cursor: cursor,
      );
      if (mounted) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar as turmas. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Turmas', style: Theme.of(context).textTheme.headlineSmall),
              DropdownButtonFormField<String?>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Ativas')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Concluídas'),
                  ),
                  DropdownMenuItem(
                    value: 'archived',
                    child: Text('Arquivadas'),
                  ),
                  DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value;
                    _page = null;
                  });
                  _load();
                },
              ),
              OutlinedButton(
                onPressed: _loading ? null : () => _load(),
                child: const Text('Atualizar'),
              ),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando turmas',
                  ),
                ),
              if (_error != null)
                Column(
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Text('Nenhuma turma encontrada.'),
              for (final item in _page?.items ?? const <MinistryClassSummary>[])
                Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${_statusLabel(item.status.name)} · ${item.startDate}${item.endDate == null ? ' · em andamento' : ' até ${item.endDate}'}',
                    ),
                    leading: const Icon(Icons.groups_outlined),
                    onTap: widget.onOpenAttendance,
                  ),
                ),
              if (_page?.nextCursor != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => _load(cursor: _page!.nextCursor),
                    child: const Text('Próxima página'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  String _statusLabel(String value) => switch (value) {
    'active' => 'Ativa',
    'completed' => 'Concluída',
    _ => 'Arquivada',
  };
}
