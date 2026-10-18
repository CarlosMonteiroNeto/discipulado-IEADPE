import '../data/ministry_codec.dart';

import 'package:flutter/material.dart';

import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_browser_repository.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.repository,
    required this.congregationId,
    required this.onOpenHandoff,
  });
  final MinistryBrowserRepository repository;
  final String congregationId;
  final VoidCallback onOpenHandoff;
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _search = TextEditingController();
  MinistryPage<MinistryStudentSummary>? _page;
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
      final result = await widget.repository.listStudents(
        congregationId: widget.congregationId,
        namePrefix: _search.text.trim().isEmpty ? null : _search.text.trim(),
        cursor: cursor,
      );
      if (mounted) {
        setState(() {
          _page = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar os alunos. Tente novamente.';
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
              const Base44PageHeading(
                title: 'Alunos',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Os dados escolares pertencem ao cadastro do aluno. O vínculo com o convertido mantém a referência de origem separada.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: widget.onOpenHandoff,
                      icon: const Icon(Icons.move_to_inbox_outlined),
                      label: const Text('Revisar novos convertidos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar aluno pelo nome',
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
                      semanticsLabel: 'Carregando alunos',
                    ),
                  ),
                ),
              if (_error != null)
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, semanticsLabel: 'Falha ao carregar alunos'),
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
                const Base44Panel(child: Text('Nenhum aluno encontrado.')),
              for (final student
                  in _page?.items ?? const <MinistryStudentSummary>[])
                Card(
                  child: ListTile(
                    title: Text(student.name, softWrap: true),
                    subtitle: Text(
                      student.convertId == null
                          ? 'Cadastro do discipulado'
                          : 'Vinculado ao cadastro de convertidos',
                      softWrap: true,
                    ),
                    leading: Icon(
                      student.convertId == null
                          ? Icons.school_outlined
                          : Icons.link,
                      color: UnifiedColors.brandNavy,
                    ),
                    trailing: student.phoneE164 == null
                        ? null
                        : const Tooltip(
                            message: 'Telefone cadastrado',
                            child: Icon(Icons.phone_outlined),
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
