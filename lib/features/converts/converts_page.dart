import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Page;

import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../data/convert_repository.dart';
import '../../data/supabase_gateway.dart';
import '../photos/photo_repository.dart';
import '../ministry/data/ministry_browser_repository.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
import 'convert_actions.dart';
import 'congregation_order.dart';
import 'convert_card.dart';
import 'edit_page.dart';
import '../intake/pending_banner.dart';
import '../intake/pending_count.dart';

List<ConvertRecord> _appendUnique(
  Iterable<ConvertRecord> existing,
  Iterable<ConvertRecord> incoming,
) {
  final seen = <String>{};
  return [
    for (final record in [...existing, ...incoming])
      if (seen.add(record.id)) record,
  ];
}

/// Root must unmount this complete subtree on protected generation changes.
class ConvertsPage extends StatefulWidget {
  const ConvertsPage({
    super.key,
    required this.scope,
    required this.converts,
    required this.photos,
    this.congregations = const [],
    this.onScopeRefresh,
    this.pickPhoto,
    this.revalidatePhotoAuthority,
    this.loadPending,
    this.onOpenPending,
  });
  final Future<Uint8List?> Function()? pickPhoto;
  final AccessScope scope;
  final ConvertRepository converts;
  final PhotoRepository photos;
  final List<Congregation> congregations;
  final Future<void> Function()? onScopeRefresh;
  final Future<bool> Function(String? congregationId)? revalidatePhotoAuthority;
  final Future<PendingCount> Function()? loadPending;
  final VoidCallback? onOpenPending;
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
  final _pendingStartClass = <String, String>{};
  bool _loading = true, _accessDenied = false;
  List<Congregation> _orderedCongregations = [];
  String? _error, _status;
  ConvertRecord? _editing;
  PendingCount? _pendingCount;
  int _request = 0;
  final _drawerRows = <String, List<ConvertRecord>>{};
  final _drawerCursors = <String, String?>{};
  final _openDrawers = <String>{};
  final _drawerLoading = <String>{};
  Map<String, int> _urgentCounts = {};
  String? _nextCursor;
  bool _urgentView = false;
  bool _loadingMore = false;
  Timer? _searchTimer;
  bool get _drawers =>
      widget.congregations.isNotEmpty &&
      (widget.scope.isGlobalManager || widget.scope.congregationIds.length > 1);
  List<Congregation> get _availableCongregations => _orderedCongregations
      .where((c) => c.archivedAt == null && widget.scope.canAccess(c.id))
      .toList();
  @override
  void initState() {
    super.initState();
    _context = widget.converts.gateway.context;
    _actions = ConvertActions(widget.converts.gateway);
    _load();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final load = widget.loadPending;
    if (load == null) return;
    try {
      final count = await load();
      if (_current()) setState(() => _pendingCount = count);
    } catch (_) {
      // A failed count must not hide the converts list or claim zero pending.
      if (_current()) setState(() => _pendingCount = null);
    }
  }

  void _refresh() {
    _load();
    _loadPending();
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
      _loadingMore = false;
      _error = null;
      _rows = [];
      _drawerLoading.clear();
    });
    try {
      final ordered = await orderCongregations(widget.congregations);
      if (!_current() || request != _request) return;
      final scopes = ordered
          .where((c) => c.archivedAt == null && widget.scope.canAccess(c.id))
          .map((c) => c.id)
          .toList();
      final counts = _drawers
          ? await widget.converts.dashboardCounts(
              scopes,
              search: _search.text.trim().isEmpty ? null : _search.text.trim(),
            )
          : <String, int>{};
      Page<ConvertRecord>? page;
      if (!_drawers || _urgentView || _search.text.trim().isNotEmpty) {
        page = await widget.converts.dashboardPage(
          congregationId: !_drawers && !widget.scope.isGlobalManager
              ? widget.scope.congregationIds.first
              : null,
          congregationIds: widget.scope.isGlobalManager || _drawers
              ? scopes
              : null,
          search: _search.text.trim().isEmpty ? null : _search.text.trim(),
          status: _urgentView ? 'red' : _status,
        );
      }
      if (_current() && request == _request) {
        setState(() {
          _rows = page?.items ?? [];
          _nextCursor = page?.nextCursor;
          _urgentCounts = counts;
          _orderedCongregations = ordered;
          _drawerRows.clear();
          _drawerCursors.clear();
        });
        if (!_urgentView && _search.text.trim().isEmpty) {
          for (final id in _openDrawers.toList()) {
            unawaited(_loadDrawer(id));
          }
        }
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

  Future<void> _loadDrawer(String id, {bool more = false}) async {
    if (!_current() || _drawerLoading.contains(id)) return;
    final request = _request;
    setState(() => _drawerLoading.add(id));
    try {
      final page = await widget.converts.dashboardPage(
        congregationId: id,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status,
        cursor: more ? _drawerCursors[id] : null,
      );
      if (!_current() || request != _request || !_openDrawers.contains(id)) {
        return;
      }
      setState(() {
        _drawerRows[id] = _appendUnique(
          more ? _drawerRows[id] ?? [] : [],
          page.items,
        );
        _drawerCursors[id] = page.nextCursor;
      });
    } catch (error) {
      if (_current() &&
          request == _request &&
          error is DataFailure &&
          error.code == 'permission') {
        _denyAccess();
        await widget.onScopeRefresh?.call();
      } else if (_current() && request == _request) {
        setState(
          () => _error =
              'Não foi possível carregar os convertidos. Tente novamente.',
        );
      }
    } finally {
      if (_current() && request == _request) {
        setState(() => _drawerLoading.remove(id));
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loading || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final scopes = _availableCongregations.map((c) => c.id).toList();
      final page = await widget.converts.dashboardPage(
        congregationId: !_drawers && !widget.scope.isGlobalManager
            ? widget.scope.congregationIds.first
            : null,
        congregationIds: widget.scope.isGlobalManager || _drawers
            ? scopes
            : null,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _urgentView ? 'red' : _status,
        cursor: cursor,
      );
      if (_current() && request == _request) {
        setState(() {
          _rows = _appendUnique(_rows, page.items);
          _nextCursor = page.nextCursor;
        });
      }
    } catch (error) {
      if (_current() &&
          request == _request &&
          error is DataFailure &&
          error.code == 'permission') {
        _denyAccess();
        await widget.onScopeRefresh?.call();
      } else if (_current() && request == _request) {
        setState(() => _error = 'Não foi possível carregar mais convertidos.');
      }
    } finally {
      if (_current() && request == _request) {
        setState(() => _loadingMore = false);
      }
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
      _drawerRows.clear();
      _drawerCursors.clear();
      _openDrawers.clear();
      _urgentCounts.clear();
      _error = 'Seu acesso mudou. Atualize seu acesso para continuar.';
    });
  }

  Future<List<MinistryClassSummary>> _availableClasses(
    String congregationId,
  ) async {
    final gateway = widget.converts.gateway;
    if (gateway is! ReadRpcGateway) throw const DataFailure('unavailable');
    final repository = MinistryBrowserRepository(gateway);
    final classes = <MinistryClassSummary>[];
    String? cursor;
    do {
      final page = await repository.listClasses(
        congregationId: congregationId,
        status: 'active',
        limit: 100,
        cursor: cursor,
      );
      classes.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null);
    return classes;
  }

  Future<String?> _chooseClass(ConvertRecord record) async {
    if (record.personId == null || record.congregationId == null) {
      setState(
        () => _errors[record.id] = 'Este cadastro precisa de uma identidade vinculada antes da matrícula.',
      );
      return null;
    }
    final previous = _pendingStartClass[record.id];
    if (previous != null) return previous;
    final future = _availableClasses(record.congregationId!);
    String? selected;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Selecionar turma'),
          content: FutureBuilder<List<MinistryClassSummary>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Não foi possível carregar as turmas desta congregação. Tente novamente.',
                );
              }
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final classes = snapshot.data!;
              if (classes.isEmpty) {
                return const Text(
                  'Nenhuma turma ativa nesta congregação. Cadastre uma turma antes de iniciar o discipulado.',
                );
              }
              return DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Turma da congregação',
                ),
                items: [
                  for (final item in classes)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => update(() => selected = value),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Matricular e iniciar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _execute(ConvertAction action, ConvertRecord record) async {
    if (!_current() || _accessDenied || _pending.contains(record.id)) return;
    final today = BusinessCalendar().today(DateTime.now());
    if (!widget.scope.canAccess(record.congregationId) ||
        !actionAllowed(action, record, today)) {
      return;
    }
    final classId = action == ConvertAction.start
        ? await _chooseClass(record)
        : null;
    if (!_current() || (action == ConvertAction.start && classId == null)) {
      return;
    }
    if (classId != null) _pendingStartClass[record.id] = classId;
    setState(() {
      _pending.add(record.id);
      _errors.remove(record.id);
    });
    try {
      await _actions.execute(action, record, classId: classId);
      _pendingStartClass.remove(record.id);
      if (_current()) await _load();
    } catch (error) {
      if (!_current()) return;
      final code = error is DataFailure ? error.code : 'backend';
      if (code == 'stale') return;
      if (code == 'permission') {
        _denyAccess();
        await widget.onScopeRefresh?.call();
      } else {
        if (code == 'invalid' || code == 'academic_invalid') {
          _pendingStartClass.remove(record.id);
          await _load();
        }
        if (_current()) {
          setState(
            () => _errors[record.id] =
                code == 'invalid' || code == 'academic_invalid'
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
    _searchTimer?.cancel();
    _request++;
    _rows = [];
    _orderedCongregations = [];
    _editing = null;
    _errors.clear();
    _pending.clear();
    _pendingStartClass.clear();
    _drawerRows.clear();
    _drawerCursors.clear();
    _openDrawers.clear();
    _urgentCounts.clear();
    _actions.clear();
    _pendingCount = null;
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
        scope: widget.scope,
        revalidatePhotoAuthority: widget.revalidatePhotoAuthority,
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
    final rows = _rows;
    final showDrawers = _drawers && !_urgentView && _search.text.trim().isEmpty;
    final congregations = _availableCongregations;
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
        if (_pendingCount != null &&
            _pendingCount!.count > 0 &&
            widget.onOpenPending != null) ...[
          PendingBanner(
            count: _pendingCount!.count,
            capped: _pendingCount!.capped,
            onReview: widget.onOpenPending!,
          ),
          const SizedBox(height: 16),
        ],
        Base44PageHeading(
          title: 'Convertidos',
          icon: Icons.people_outline,
          subtitle: _loading
              ? 'Carregando convertidos…'
              : _error != null
              ? 'Consulta indisponível'
              : showDrawers
              ? 'Selecione uma congregação'
              : '${rows.length} convertidos carregados',
          trailing: IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading || _pending.isNotEmpty ? null : _refresh,
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
                        label: Text(item.label),
                        labelStyle: TextStyle(color: item.color),
                        selected: _status == item.code,
                        backgroundColor: item.tint,
                        selectedColor: item.tint,
                        side: BorderSide(
                          color: _status == item.code
                              ? item.color
                              : item.color.withValues(alpha: .25),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _status = selected ? item.code : null;
                            _urgentView = false;
                          });
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nome',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) {
                    _searchTimer?.cancel();
                    _request++;
                    setState(() {
                      _loading = true;
                      _rows = [];
                      _drawerRows.clear();
                    });
                    _searchTimer = Timer(
                      const Duration(milliseconds: 300),
                      _load,
                    );
                  },
                ),
                if (_drawers)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _urgentView = !_urgentView;
                        _status = null;
                      });
                      _load();
                    },
                    icon: const Icon(Icons.warning_amber_outlined),
                    label: Text(
                      _urgentView
                          ? 'Ver congregações'
                          : 'Ver todas as visitas urgentes',
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _urgentView = false;
                        _search.clear();
                      });
                      _load();
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
        else if (rows.isEmpty && allowed && !showDrawers)
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
                  (_loading || _error != null || !allowed
                      ? 0
                      : showDrawers
                      ? congregations.length
                      : rows.length + (_nextCursor == null ? 0 : 1)),
              itemBuilder: (context, index) {
                if (index == 0) return header;
                if (showDrawers) {
                  final congregation = congregations[index - 1];
                  final id = congregation.id;
                  return ExpansionTile(
                    key: ValueKey('drawer:$id'),
                    title: Text(congregation.name),
                    subtitle: Text(
                      '${_urgentCounts[id] ?? 0} visitas urgentes',
                    ),
                    initiallyExpanded: _openDrawers.contains(id),
                    onExpansionChanged: (open) {
                      if (open) {
                        _openDrawers.add(id);
                        if (!_drawerRows.containsKey(id)) _loadDrawer(id);
                      } else {
                        _openDrawers.remove(id);
                      }
                    },
                    children: [
                      if (_drawerLoading.contains(id))
                        const CircularProgressIndicator(),
                      for (final record in _drawerRows[id] ?? <ConvertRecord>[])
                        _recordCard(record, today),
                      if (_drawerCursors[id] != null)
                        TextButton(
                          onPressed: () => _loadDrawer(id, more: true),
                          child: const Text('Carregar mais'),
                        ),
                    ],
                  );
                }
                if (index > rows.length) {
                  return TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: const Text('Carregar mais'),
                  );
                }
                final record = rows[index - 1];
                return _recordCard(record, today);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordCard(ConvertRecord record, DateOnly today) {
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
  }
}
