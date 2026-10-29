import 'package:flutter/material.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';

/// Includes older assignments which have no corresponding team contact.
class AccessPanel extends StatefulWidget {
  const AccessPanel({
    super.key,
    required this.canOpenTeam,
    required this.onOpenTeam,
    required this.onScopeRefresh,
    required this.gateway,
    required this.congregations,
  });
  final bool canOpenTeam;
  final VoidCallback onOpenTeam;
  final Future<void> Function() onScopeRefresh;
  final Gateway gateway;
  final List<Congregation> congregations;
  @override
  State<AccessPanel> createState() => _AccessPanelState();
}

class _AccessPanelState extends State<AccessPanel> {
  final _filter = TextEditingController();
  List<UserAccess>? _access;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final token = widget.gateway.context;
    setState(() {
      _error = null;
      _access = null;
    });
    try {
      final rows = <UserAccess>[];
      String? cursor;
      while (true) {
        final page = await widget.gateway.read(
          'user_access',
          context: token,
          afterId: cursor,
        );
        widget.gateway.ensureCurrent(token);
        rows.addAll(page.map(UserAccess.fromJson));
        if (page.length < 100) break;
        final next = page.last['id'] as String;
        if (next == cursor) throw const DataFailure('invalid_response');
        cursor = next;
      }
      rows.sort((a, b) => a.userEmail.compareTo(b.userEmail));
      if (mounted && generation == _generation) setState(() => _access = rows);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Não foi possível carregar os acessos.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = {for (final c in widget.congregations) c.id: c.name};
    final query = _filter.text.trim().toLowerCase();
    final rows = _access
        ?.where((a) => a.userEmail.toLowerCase().contains(query))
        .toList();
    return Base44Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Base44PageHeading(
            title: 'Acessos da equipe',
            icon: Icons.people_outline,
            subtitle: 'Todos os acessos, inclusive os registros anteriores sem contato vinculado.',
          ),
          const SizedBox(height: UnifiedSpace.x3),
          TextField(
            controller: _filter,
            decoration: const InputDecoration(labelText: 'Buscar por email'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: UnifiedSpace.x3),
          if (_error != null)
            Text(_error!)
          else if (rows == null)
            const Center(child: CircularProgressIndicator())
          else if (rows.isEmpty)
            const Text('Nenhum acesso encontrado.')
          else
            for (final access in rows)
              ListTile(
                title: Text(access.userEmail),
                subtitle: Text(
                  access.role == AccessRole.supervision
                      ? 'Supervisão geral'
                      : 'Direção · ${names[access.congregationId] ?? 'Congregação indisponível'}',
                ),
              ),
          const SizedBox(height: UnifiedSpace.x3),
          const Text(
            'Para vincular um acesso anterior, cadastre um contato na mesma congregação com o mesmo email.',
          ),
          if (widget.canOpenTeam)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: widget.onOpenTeam,
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Abrir equipe'),
              ),
            )
          else ...[
            const Text(
              'O servidor não confirmou acesso à equipe. Atualize seu acesso para tentar novamente.',
            ),
            TextButton(
              onPressed: widget.onScopeRefresh,
              child: const Text('Atualizar acesso'),
            ),
          ],
        ],
      ),
    );
  }
}
