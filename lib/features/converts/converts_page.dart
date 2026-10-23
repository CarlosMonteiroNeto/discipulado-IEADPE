import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'convert_form.dart';

import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../data/convert_repository.dart';
import '../../data/supabase_gateway.dart';
import '../photos/photo_repository.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
import 'convert_actions.dart';
import 'congregation_order.dart';
import 'convert_card.dart';
import 'edit_page.dart';

/// Root must unmount this complete subtree on protected generation changes.
class ConvertsPage extends StatefulWidget {
  const ConvertsPage({
    super.key,
    required this.scope,
    required this.converts,
    required this.photos,
    this.congregations = const [],
    this.onScopeRefresh,
    this.pickPhoto = pickConvertPhoto,
  });
  final Future<Uint8List?> Function() pickPhoto;
  final AccessScope scope;
  final ConvertRepository converts;
  final PhotoRepository photos;
  final List<Congregation> congregations;
  final Future<void> Function()? onScopeRefresh;
  @override
  State<ConvertsPage> createState() => _ConvertsPageState();
}

class _ConvertsPageState extends State<ConvertsPage> {
  final _search = TextEditingController();
  late final ConvertActions _actions;
  late final String _context;
  List<ConvertRecord> _rows = [];
  final _pending = <String>{};
  final _errors = <String, String>{};
  bool _loading = true, _accessDenied = false;
  List<Congregation> _orderedCongregations = [];
  String? _error, _status, _congregation;
  ConvertRecord? _editing;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _context = widget.converts.gateway.context;
    _actions = ConvertActions(widget.converts.gateway);
    _load();
  }

  bool _current() {
    if (!mounted) return false;
    try {
      widget.converts.gateway.ensureCurrent(_context);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    if (!_current() || _accessDenied) return;
    if (!widget.scope.isGlobalManager && widget.scope.congregationIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
    });
    try {
      final ordered = await orderCongregations(widget.congregations);
      if (!_current() || request != _request) return;
      final rows = <ConvertRecord>[];
      final scopes = widget.scope.isGlobalManager
          ? <String?>[null]
          : ordered
                .where(
                  (congregation) =>
                      congregation.archivedAt == null &&
                      widget.scope.congregationIds.contains(congregation.id),
                )
                .map((congregation) => congregation.id)
                .toList(growable: false);
      for (final scopeId in scopes) {
        String? cursor;
        do {
          final page = await widget.converts.list(
            ConvertQuery(congregationId: scopeId),
            cursor,
          );
          if (!_current() || request != _request) return;
          rows.addAll(page.items);
          cursor = page.nextCursor;
        } while (cursor != null);
      }
      if (_current() && request == _request) {
        setState(() {
          _rows = rows;
          _orderedCongregations = ordered;
        });
      }
    } catch (error) {
      if (_current() && request == _request) {
        setState(
          () => _error = error is DataFailure && error.code == 'permission'
              ? 'Seu acesso mudou. Atualize seu acesso para continuar.'
              : 'Não foi possível carregar os convertidos. Tente novamente.',
        );
        if (error is DataFailure && error.code == 'permission') {
          _denyAccess();
          await widget.onScopeRefresh?.call();
        }
      }
    } finally {
      if (_current() && request == _request) setState(() => _loading = false);
    }
  }

  void _denyAccess() {
    _request++;
    setState(() {
      _accessDenied = true;
      _loading = false;
      _rows = [];
      _editing = null;
      _errors.clear();
      _error = 'Seu acesso mudou. Atualize seu acesso para continuar.';
    });
  }

  Future<void> _execute(ConvertAction action, ConvertRecord record) async {
    if (!_current() || _accessDenied || _pending.contains(record.id)) return;
    final today = BusinessCalendar().today(DateTime.now());
    if (!widget.scope.canAccess(record.congregationId) ||
        !actionAllowed(action, record, today)) {
      return;
    }
    setState(() {
      _pending.add(record.id);
      _errors.remove(record.id);
    });
    try {
      await _actions.execute(action, record);
      if (_current()) await _load();
    } catch (error) {
      if (!_current()) return;
      final code = error is DataFailure ? error.code : 'backend';
      if (code == 'stale') return;
      if (code == 'permission') {
        _denyAccess();
        await widget.onScopeRefresh?.call();
      } else {
        if (code == 'invalid') await _load();
        if (_current()) {
          setState(
            () => _errors[record.id] = code == 'invalid'
                ? 'O cadastro mudou. Confira os dados atualizados antes de tentar novamente.'
                : 'Não foi possível salvar. Tente novamente a mesma ação.',
          );
        }
      }
    } finally {
      if (_current()) setState(() => _pending.remove(record.id));
    }
  }

  @override
  void dispose() {
    _request++;
    _rows = [];
    _orderedCongregations = [];
    _editing = null;
    _errors.clear();
    _pending.clear();
    _actions.clear();
    _search.clear();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_current()) return const SizedBox.shrink();
    if (_editing != null) {
      return EditPage(
        key: ValueKey('edit:${_editing!.id}:$_context'),
        initial: _editing!,
        pickPhoto: widget.pickPhoto,
        converts: widget.converts,
        photos: widget.photos,
        congregations: widget.congregations
            .where((c) => c.archivedAt == null)
            .toList(),
        onCancel: () => setState(() => _editing = null),
        onSaved: (_) {
          if (_current()) {
            setState(() => _editing = null);
            _load();
          }
        },
      );
    }
    final today = BusinessCalendar().today(DateTime.now());
    final rows = visibleConverts(
      _rows,
      _orderedCongregations,
      widget.scope,
      today,
      name: _search.text,
      congregationId: _congregation,
      status: _status,
    );
    final congregations = _orderedCongregations
        .where((c) => widget.scope.canAccess(c.id))
        .toList();
    final allowed =
        widget.scope.isGlobalManager || widget.scope.congregationIds.isNotEmpty;
    final statusFilters =
        <({String code, String label, Color color, Color tint, IconData icon})>[
          (
            code: 'red',
            label: 'Visita Urgente',
            color: UnifiedColors.red,
            tint: const Color(0xfffef2f2),
            icon: Icons.warning_amber_outlined,
          ),
          (
            code: 'yellow',
            label: 'Atenção',
            color: const Color(0xffa16207),
            tint: const Color(0xfffffbeb),
            icon: Icons.schedule_outlined,
          ),
          (
            code: 'green',
            label: 'Em dia',
            color: const Color(0xff166534),
            tint: const Color(0xfff0fdf4),
            icon: Icons.check_circle_outline,
          ),
        ];
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Base44PageHeading(
          title: 'Convertidos',
          icon: Icons.people_outline,
          subtitle: _loading
              ? 'Carregando convertidos…'
              : _error != null
              ? 'Consulta indisponível'
              : '${rows.length} convertidos encontrados',
          trailing: IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading || _pending.isNotEmpty ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SizedBox(height: 16),
        if (allowed)
          Base44Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in statusFilters)
                      FilterChip(
                        avatar: Icon(item.icon, size: 18, color: item.color),
                        label: Text(
                          _loading || _error != null
                              ? item.label
                              : '${item.label} (${rows.where((r) => statusCode(r, today) == item.code).length})',
                        ),
                        labelStyle: TextStyle(color: item.color),
                        selected: _status == item.code,
                        backgroundColor: item.tint,
                        selectedColor: item.tint,
                        side: BorderSide(
                          color: _status == item.code
                              ? item.color
                              : item.color.withValues(alpha: .25),
                        ),
                        onSelected: (selected) => setState(
                          () => _status = selected ? item.code : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nome',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_congregation),
                  initialValue: _congregation ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Congregação',
                    prefixIcon: Icon(Icons.church_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Todas as congregações'),
                    ),
                    ...congregations.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _congregation = value == '' ? null : value,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _congregation = null;
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Limpar filtros'),
                  ),
                ),
              ],
            ),
          )
        else
          const Base44Panel(
            child: Text(
              'Você precisa de acesso a uma congregação para consultar convertidos.',
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: Text(_error!)),
          TextButton(
            onPressed: _accessDenied ? widget.onScopeRefresh : _load,
            child: const Text('Tentar novamente'),
          ),
        ] else if (_loading && allowed)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Base44Panel(child: Text('Carregando…')),
          )
        else if (rows.isEmpty && allowed)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Base44Panel(child: Text('Nenhum convertido encontrado')),
          ),
      ],
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 896),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount:
                  1 +
                  (_loading || _error != null || !allowed ? 0 : rows.length),
              itemBuilder: (context, index) {
                if (index == 0) return header;
                final record = rows[index - 1];
                Congregation? congregation;
                for (final candidate in widget.congregations) {
                  if (candidate.id == record.congregationId) {
                    congregation = candidate;
                    break;
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (record.legacyIdentity != null)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
                        child: Text(
                          'Identidade legada original · somente leitura',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ConvertCard(
                      key: ValueKey('${record.id}:$_context'),
                      record: record,
                      today: today,
                      congregation: congregation,
                      gateway: widget.converts.gateway,
                      photos: widget.photos,
                      busy: _pending.contains(record.id),
                      error: _errors[record.id],
                      onAction: (action) => _execute(action, record),
                      onEdit: _pending.isNotEmpty || record.personId == null
                          ? null
                          : () => setState(() => _editing = record),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
