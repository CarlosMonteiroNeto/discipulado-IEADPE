import 'package:flutter/material.dart';

import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.repository,
    required this.congregationId,
  });
  final MinistryRepository repository;
  final String congregationId;
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final _search = TextEditingController();
  MinistryPage<MinistryDirectoryEntry>? _page;
  String? _cursor;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? cursor}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listDirectory(
        scope: 'congregation',
        congregationId: widget.congregationId,
        namePrefix: _search.text.trim().isEmpty ? null : _search.text.trim(),
        limit: 50,
        cursor: cursor,
      );
      if (mounted)
        setState(() {
          _page = page;
          _cursor = cursor;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar a equipe. Tente novamente.';
        });
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
              Text(
                'Equipe de discipulado',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(labelText: 'Buscar por nome'),
                onSubmitted: (_) => _load(),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _loading ? null : () => _load(),
                    child: const Text('Buscar'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: const Text('Atualizar'),
                  ),
                ],
              ),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando equipe',
                  ),
                ),
              if (_error != null)
                Column(
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: () => _load(cursor: _cursor),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Text('Nenhuma pessoa encontrada.'),
              for (final item
                  in _page?.items ?? const <MinistryDirectoryEntry>[])
                Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(item.roleCode ?? 'Sem função atribuída'),
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
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
}
