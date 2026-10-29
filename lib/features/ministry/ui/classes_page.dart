import '../data/ministry_codec.dart';

import 'package:flutter/material.dart';

import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_browser_repository.dart';
import '../data/ministry_repository.dart';
import 'class_detail_page.dart';
import 'class_form.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({
    super.key,
    required this.repository,
    required this.congregationId,
    this.congregationName,
    this.onOpenAttendance,
  });
  final MinistryBrowserRepository repository;
  final String congregationId;
  final String? congregationName;
  // Kept as an optional source-compatibility argument for direct embeddings.
  // The class detail flow no longer forwards global pending-queue navigation.
  final VoidCallback? onOpenAttendance;
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  String? _status = 'active';
  String? _error;
  bool _loading = false;
  MinistryPage<MinistryClassSummary>? _page;
  late MinistryRepository _commandRepository;
  @override
  void initState() {
    super.initState();
    _commandRepository = MinistryRepository(widget.repository.gateway);
    _load();
  }

  @override
  void didUpdateWidget(covariant ClassesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.gateway != widget.repository.gateway) {
      _commandRepository = MinistryRepository(widget.repository.gateway);
    }
    if (oldWidget.congregationId != widget.congregationId) {
      _page = null;
      _load();
    }
  }

  Future<void> _createClass() async {
    final saved = await Navigator.of(context).push<MinistryClassSummary>(
      MaterialPageRoute(
        builder: (_) => ClassForm(
          repository: _commandRepository,
          congregationId: widget.congregationId,
          congregationName: widget.congregationName,
          onCancel: () => Navigator.of(context).pop(),
          onSaved: (summary) => Navigator.of(context).pop(summary),
        ),
      ),
    );
    if (!mounted || saved == null) return;
    await _load();
  }

  Future<void> _openDetails(MinistryClassSummary summary) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ClassDetailPage(
          repository: _commandRepository,
          congregationId: widget.congregationId,
          congregationName: widget.congregationName,
          classSummary: summary,
          onChanged: () => _load(),
        ),
      ),
    );
    if (mounted) await _load();
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
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Base44PageHeading(
                title: 'Turmas',
                icon: Icons.groups_outlined,
                trailing: FilledButton.icon(
                  onPressed: _loading ? null : _createClass,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova turma'),
                ),
              ),
              const SizedBox(height: 16),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Situação',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Ativas'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Concluídas'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Arquivadas'),
                        ),
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todas'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value;
                          _page = null;
                        });
                        _load();
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Base44Panel(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando turmas',
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
                        onPressed: () => _load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Base44Panel(child: Text('Nenhuma turma encontrada.')),
              for (final item in _page?.items ?? const <MinistryClassSummary>[])
                Card(
                  child: ListTile(
                    title: Text(item.name, softWrap: true),
                    subtitle: Text(
                      '${_statusLabel(item.status.name)} · ${item.startDate}${item.endDate == null ? ' · em andamento' : ' até ${item.endDate}'}',
                      softWrap: true,
                    ),
                    leading: const Icon(
                      Icons.groups_outlined,
                      color: UnifiedColors.brandNavy,
                    ),
                    onTap: () => _openDetails(item),
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
  String _statusLabel(String value) => switch (value) {
    'active' => 'Ativa',
    'completed' => 'Concluída',
    _ => 'Arquivada',
  };
}
