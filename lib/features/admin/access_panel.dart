import 'package:flutter/material.dart';

import '../../domain/models.dart';

class AccessPanel extends StatefulWidget {
  const AccessPanel({
    super.key,
    required this.items,
    required this.congregations,
    required this.busy,
    required this.onSave,
    required this.onRevoke,
  });
  final List<UserAccess> items;
  final List<Congregation> congregations;
  final bool busy;
  final Future<bool> Function(
    String? id,
    String email,
    AccessRole role,
    String? congregationId,
  )
  onSave;
  final Future<bool> Function(String id) onRevoke;
  @override
  State<AccessPanel> createState() => _AccessPanelState();
}

class _AccessPanelState extends State<AccessPanel> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  AccessRole _role = AccessRole.direction;
  String? _congregation, _editing;
  UserAccess? _confirmRevoke;
  String? _error;
  bool _show = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _edit([UserAccess? item]) => setState(() {
    _editing = item?.id;
    _email.text = item?.userEmail ?? '';
    _role = item?.role ?? AccessRole.direction;
    _congregation =
        widget.congregations.any(
          (c) => c.id == item?.congregationId && c.archivedAt == null,
        )
        ? item?.congregationId
        : null;
    _show = true;
    _error = null;
  });
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final email = _email.text.trim().toLowerCase();
    final congregation = _role == AccessRole.direction ? _congregation : null;
    if (widget.items.any(
      (item) =>
          item.id != _editing &&
          item.userEmail == email &&
          item.role == _role &&
          item.congregationId == congregation,
    )) {
      setState(
        () => _error = 'Este usuário já possui este acesso. Confira o cargo e a congregação.',
      );
      return;
    }
    setState(() => _error = null);
    final applied = await widget.onSave(_editing, email, _role, congregation);
    if (mounted && applied) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    final names = {for (final c in widget.congregations) c.id: c.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_confirmRevoke != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Remover acesso?'),
                  Text('Remover este acesso de ${_confirmRevoke!.userEmail}?'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: widget.busy
                            ? null
                            : () => setState(() => _confirmRevoke = null),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: widget.busy
                            ? null
                            : () => widget.onRevoke(_confirmRevoke!.id),
                        child: const Text('Remover'),
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
              label: const Text('Novo acesso'),
            ),
          ),
        if (_show)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !widget.busy && _editing == null,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email do usuário',
                  ),
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? 'Informe um email válido.'
                      : null,
                ),
                DropdownButtonFormField<AccessRole>(
                  key: ValueKey('role-$_editing'),
                  initialValue: _role,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Cargo'),
                  items: [
                    for (final role in AccessRole.values)
                      DropdownMenuItem(
                        value: role,
                        child: Text(role.wireValue),
                      ),
                  ],
                  onChanged: widget.busy
                      ? null
                      : (role) => setState(() {
                          _role = role!;
                          _congregation = null;
                        }),
                ),
                if (_role == AccessRole.direction)
                  DropdownButtonFormField<String>(
                    key: ValueKey('congregation-$_editing-$_role'),
                    initialValue: _congregation,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(labelText: 'Congregação'),
                    items: [
                      for (final c in widget.congregations.where(
                        (c) => c.archivedAt == null,
                      ))
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: widget.busy
                        ? null
                        : (value) => setState(() => _congregation = value),
                    validator: (value) => value == null
                        ? 'Selecione uma congregação ativa.'
                        : null,
                  ),
                if (_role == AccessRole.direction &&
                    !widget.congregations.any((c) => c.archivedAt == null))
                  const Text('Cadastre uma congregação ativa primeiro.'),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: widget.busy ? null : _save,
                      child: const Text('Salvar acesso'),
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
            child: Text('Nenhum acesso configurado.'),
          ),
        for (final item in widget.items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.userEmail,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(item.role.wireValue),
                  Text(
                    item.congregationId == null
                        ? 'Todas as congregações'
                        : names[item.congregationId] ?? 'Congregação anterior',
                  ),
                  Text(
                    item.userId == null
                        ? 'Aguardando email verificado'
                        : 'Acesso vinculado',
                  ),
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
                            : () => setState(() => _confirmRevoke = item),
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('Remover'),
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
}
