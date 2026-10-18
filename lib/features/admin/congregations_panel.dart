import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';

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
  Widget build(BuildContext context) => Base44Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Base44PageHeading(
          title: 'Congregações',
          icon: Icons.church_outlined,
          trailing: !_show
              ? FilledButton.icon(
                  onPressed: widget.busy ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova congregação'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        if (_confirmArchive != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfffffbeb),
              border: Border.all(color: const Color(0xfffde68a)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.archive_outlined,
                      size: 20,
                      color: Color(0xff92400e),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Arquivar congregação?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_confirmArchive!.name} deixará de aparecer em novos cadastros. Os registros existentes serão preservados.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
        if (_show)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: UnifiedColors.page,
              border: Border.all(color: UnifiedColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.busy ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar congregação'),
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
          ),
        if (widget.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Nenhuma congregação cadastrada.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final item in widget.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: UnifiedColors.page,
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: UnifiedColors.brandNavy),
                    ),
                    if (item.archivedAt != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Arquivada'),
                      ),
                    if (item.archivedAt == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: widget.busy ? null : () => _edit(item),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                            TextButton.icon(
                              onPressed: widget.busy
                                  ? null
                                  : () =>
                                        setState(() => _confirmArchive = item),
                              icon: const Icon(Icons.archive_outlined),
                              label: const Text('Arquivar'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
