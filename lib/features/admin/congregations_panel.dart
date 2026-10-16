import 'package:flutter/material.dart';

import '../../domain/models.dart';

class CongregationsPanel extends StatefulWidget {
  const CongregationsPanel({
    super.key,
    required this.items,
    required this.busy,
    required this.onSave,
    required this.onArchive,
  });
  final List<Congregation> items;
  final bool busy;
  final Future<bool> Function(String name, String? id) onSave;
  final Future<bool> Function(String id) onArchive;
  @override
  State<CongregationsPanel> createState() => _CongregationsPanelState();
}

class _CongregationsPanelState extends State<CongregationsPanel> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _editing;
  Congregation? _confirmArchive;
  bool _show = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _edit([Congregation? item]) => setState(() {
    _editing = item?.id;
    _name.text = item?.name ?? '';
    _show = true;
  });
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final applied = await widget.onSave(_name.text.trim(), _editing);
    if (mounted && applied) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_confirmArchive != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arquivar congregação?'),
                Text(
                  '${_confirmArchive!.name} deixará de aparecer em novos cadastros. Os registros existentes serão preservados.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: widget.busy
                          ? null
                          : () => setState(() => _confirmArchive = null),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: widget.busy
                          ? null
                          : () => widget.onArchive(_confirmArchive!.id),
                      child: const Text('Arquivar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (!_show)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Nova congregação'),
          ),
        ),
      if (_show)
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                enabled: !widget.busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Nome da congregação',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o nome.'
                    : null,
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: widget.busy ? null : _save,
                    child: const Text('Salvar congregação'),
                  ),
                  TextButton(
                    onPressed: widget.busy
                        ? null
                        : () => setState(() => _show = false),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (widget.items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhuma congregação cadastrada.'),
        ),
      for (final item in widget.items)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                if (item.archivedAt != null) const Text('Arquivada'),
                if (item.archivedAt == null)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: widget.busy ? null : () => _edit(item),
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: widget.busy
                            ? null
                            : () => setState(() => _confirmArchive = item),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Arquivar'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
