import '../data/ministry_codec.dart';

import 'package:flutter/material.dart';

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
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Alunos', style: Theme.of(context).textTheme.headlineSmall),
              const Text(
                'Os dados escolares pertencem ao cadastro do aluno. O vínculo com o convertido mantém a referência de origem separada.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onOpenHandoff,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Revisar novos convertidos'),
              ),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Buscar aluno pelo nome',
                ),
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
                    semanticsLabel: 'Carregando alunos',
                  ),
                ),
              if (_error != null)
                Column(
                  children: [
                    Text(_error!, semanticsLabel: 'Falha ao carregar alunos'),
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              if (!_loading && _error == null && _page?.items.isEmpty == true)
                const Text('Nenhum aluno encontrado.'),
              for (final student
                  in _page?.items ?? const <MinistryStudentSummary>[])
                Card(
                  child: ListTile(
                    title: Text(student.name),
                    subtitle: Text(
                      student.convertId == null
                          ? 'Cadastro do discipulado'
                          : 'Vinculado ao cadastro de convertidos',
                    ),
                    leading: Icon(
                      student.convertId == null
                          ? Icons.school_outlined
                          : Icons.link,
                    ),
                    trailing: student.phoneE164 == null
                        ? null
                        : const Tooltip(
                            message: 'Telefone cadastrado',
                            child: Icon(Icons.phone_outlined),
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
