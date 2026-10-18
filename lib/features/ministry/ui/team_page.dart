import 'package:flutter/material.dart';

import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.repository,
    this.congregationId,
    this.supervision = false,
  });
  final MinistryRepository repository;
  final String? congregationId;
  final bool supervision;
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
        scope: widget.supervision ? 'supervision' : 'congregation',
        congregationId: widget.congregationId,
        namePrefix: _search.text.trim().isEmpty ? null : _search.text.trim(),
        limit: 50,
        cursor: cursor,
      );
      if (mounted) {
        setState(() {
          _page = page;
          _cursor = cursor;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar a equipe. Tente novamente.';
        });
      }
    }
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
              Base44PageHeading(
                title: 'Equipe de discipulado',
                icon: Icons.groups_outlined,
                subtitle: widget.supervision
                    ? 'Diretório de supervisão'
                    : 'Diretório da congregação',
              ),
              const SizedBox(height: 16),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loading ? null : () => _load(),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : () => _load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Base44Panel(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando equipe',
                    ),
                  ),
                ),
              if (_error != null)
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _load(cursor: _cursor),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Base44Panel(child: Text('Nenhuma pessoa encontrada.')),
              for (final item
                  in _page?.items ?? const <MinistryDirectoryEntry>[])
                Card(
                  child: ListTile(
                    title: Text(item.name, softWrap: true),
                    subtitle: Text(
                      item.roleCode ?? 'Sem função atribuída',
                      softWrap: true,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: UnifiedColors.pageTint,
                      foregroundColor: UnifiedColors.brandNavy,
                      child: Icon(Icons.person_outline),
                    ),
                    minVerticalPadding: 12,
                  ),
                ),
              if (_page?.nextCursor != null)
                Base44Panel(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _load(cursor: _page!.nextCursor),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próxima página'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
