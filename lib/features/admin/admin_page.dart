import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../../ui/base44_widgets.dart';
import '../../ui/unified_theme.dart';
import 'congregation_repository.dart';
import 'congregations_panel.dart';

/// The root supplies SessionRouter.refresh and replaces protected owners on invalidation.
/// Later tasks inject their real report, event, backup and feedback features.
class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.scope,
    required this.gateway,
    required this.onScopeRefresh,
    this.reportBuilder,
    this.eventsBuilder,
    this.backupBuilder,
    this.onFeedback,
  });
  final AccessScope scope;
  final Gateway gateway;
  final Future<void> Function() onScopeRefresh;
  final WidgetBuilder? reportBuilder, eventsBuilder, backupBuilder;
  final VoidCallback? onFeedback;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late String _token;
  int _request = 0, _selected = 0, _owner = 0;
  List<Congregation>? _catalog;
  String? _error;
  bool _busy = false, _denied = false, _refreshing = false;
  String? _operation;
  Future<MutationResult<String>> Function(String)? _retry;
  @override
  void initState() {
    super.initState();
    _token = widget.gateway.context;
    _load();
  }

  bool get _current {
    if (!mounted) return false;
    try {
      widget.gateway.ensureCurrent(_token);
      return true;
    } on DataFailure {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway != widget.gateway ||
        _token != widget.gateway.context ||
        oldWidget.scope.isAdmin != widget.scope.isAdmin ||
        oldWidget.scope.isSupervision != widget.scope.isSupervision ||
        oldWidget.scope.congregationIds.length !=
            widget.scope.congregationIds.length ||
        !oldWidget.scope.congregationIds.containsAll(
          widget.scope.congregationIds,
        )) {
      _request++;
      _owner++;
      _token = widget.gateway.context;
      _catalog = null;
      _denied = false;
      _refreshing = false;
      _busy = false;
      _operation = null;
      _retry = null;
      _load();
    }
  }

  Future<void> _deny() async {
    if (!_current) return;
    setState(() {
      _denied = true;
      _catalog = null;
      _retry = null;
      _operation = null;
      _request++;
    });
    widget.gateway.boundary.invalidate();
    await _refreshScope();
  }

  Future<void> _refreshScope() async {
    final owner = _owner;
    final token = _token;
    final gateway = widget.gateway;
    try {
      await widget.onScopeRefresh();
    } catch (_) {
      if (mounted &&
          owner == _owner &&
          token == _token &&
          gateway == widget.gateway) {
        setState(
          () => _error =
              'Não foi possível atualizar seu acesso. Tente novamente.',
        );
      }
    }
  }

  Future<void> _load() async {
    if (!_current || _denied || _refreshing || !widget.scope.isGlobalManager) {
      return;
    }
    final request = ++_request;
    final gateway = widget.gateway;
    final token = _token;
    setState(() {
      _catalog = null;
      _error = null;
    });
    try {
      final catalog = await CongregationRepository(gateway).list();
      gateway.ensureCurrent(token);
      if (!_current || request != _request || gateway != widget.gateway) return;
      if (_current && request == _request) {
        setState(() => _catalog = catalog);
      }
    } catch (error) {
      if (!_current || request != _request) return;
      if (error is DataFailure && error.code == 'permission') {
        await _deny();
      } else {
        setState(
          () => _error =
              'Não foi possível carregar a administração. Tente novamente.',
        );
      }
    }
  }

  Future<bool> _mutate(
    Future<MutationResult<String>> Function(String) action,
  ) async {
    if (!_current ||
        _busy ||
        _denied ||
        _refreshing ||
        !widget.scope.isGlobalManager) {
      return false;
    }
    // An uncertain request owns the editor until its exact snapshot is resolved.
    if (_retry != null && !identical(_retry, action)) return false;
    _retry = action;
    _operation ??= const Uuid().v4();
    final owner = _owner;
    final token = _token;
    final gateway = widget.gateway;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action(_operation!);
      if (!_current ||
          owner != _owner ||
          token != _token ||
          gateway != widget.gateway) {
        return false;
      }
      if (result.status == MutationStatus.applied) {
        setState(() {
          _retry = null;
          _operation = null;
          _catalog = null;
          _refreshing = true;
          _request++;
        });
        // Invalidate synchronously before the first await, including self revocation.
        gateway.boundary.invalidate();
        await _refreshScope();
        return true;
      }
      if (result.errorCode == 'permission') {
        await _deny();
        return false;
      }
      final uncertain = {
        'unavailable',
        'backend',
        'invalid_response',
      }.contains(result.errorCode);
      setState(() {
        if (!uncertain) {
          _retry = null;
          _operation = null;
        }
        _error = uncertain
            ? 'Não foi possível confirmar a alteração. Tente a mesma alteração novamente.'
            : 'Não foi possível salvar. Confira os dados e tente novamente.';
      });
    } catch (error) {
      if (!_current ||
          owner != _owner ||
          token != _token ||
          gateway != widget.gateway) {
        return false;
      }
      if (error is DataFailure && error.code == 'permission') {
        await _deny();
      } else {
        setState(
          () => _error = 'Não foi possível confirmar a alteração. Tente a mesma alteração novamente.',
        );
      }
    } finally {
      if (mounted &&
          owner == _owner &&
          token == _token &&
          gateway == widget.gateway) {
        setState(() => _busy = false);
      }
    }
    return false;
  }

  Widget _later(WidgetBuilder? builder, String feature) =>
      builder?.call(context) ??
      Text(
        '$feature ainda não está disponível. Procure a liderança para orientações.',
      );
  @override
  Widget build(BuildContext context) {
    if (!widget.scope.isGlobalManager || _denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Base44Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: UnifiedColors.brandNavy,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Seu acesso mudou. Atualize seu acesso para continuar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _refreshScope,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar acesso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_refreshing || !_current) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Base44Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sync_outlined,
                    size: 40,
                    color: UnifiedColors.brandNavy,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error ?? 'Atualizando seu acesso…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _refreshScope,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar acesso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final locked = _busy || _retry != null;
    final repository = CongregationRepository(widget.gateway);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Base44PageHeading(
                title: 'Administração',
                icon: Icons.settings_outlined,
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Atualizar administração',
                      onPressed: locked ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                    if (widget.onFeedback != null)
                      IconButton(
                        tooltip: 'Gerenciar mensagens',
                        onPressed: widget.onFeedback,
                        icon: const Icon(Icons.feedback_outlined),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Base44Panel(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in const [
                      ('Congregações', Icons.church_outlined),
                      ('Relatório', Icons.bar_chart_outlined),
                      ('Eventos', Icons.event_note_outlined),
                      ('Backup', Icons.backup_outlined),
                    ].indexed)
                      ChoiceChip(
                        avatar: Icon(
                          entry.$2.$2,
                          size: 18,
                          color: _selected == entry.$1
                              ? Colors.white
                              : UnifiedColors.brandNavy,
                        ),
                        label: Text(entry.$2.$1),
                        selected: _selected == entry.$1,
                        showCheckmark: false,
                        selectedColor: UnifiedColors.brandNavy,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _selected == entry.$1
                              ? Colors.white
                              : UnifiedColors.brandNavy,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: _selected == entry.$1
                              ? UnifiedColors.brandNavy
                              : UnifiedColors.border,
                        ),
                        onSelected: locked
                            ? null
                            : (_) => setState(() => _selected = entry.$1),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                Semantics(
                  liveRegion: true,
                  child: const Text('Salvando alteração…'),
                ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff7f7),
                      border: Border.all(color: const Color(0xfffecaca)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.error_outline,
                            size: 20,
                            color: UnifiedColors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: UnifiedColors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_retry != null && !_busy)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => _mutate(_retry!),
                    child: const Text(
                      'Tentar a mesma alteração novamente',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_selected == 0 && _catalog == null) ...[
                Base44Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error == null)
                        const Text('Carregando administração…'),
                      if (_error != null && _retry == null)
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                    ],
                  ),
                ),
              ] else if (_selected == 0)
                CongregationsPanel(
                  key: ValueKey('catalog-$_token'),
                  items: _catalog!,
                  busy: locked,
                  onSave: (name, id) =>
                      _mutate((op) => repository.save(op, name, id: id)),
                  onArchive: (id) =>
                      _mutate((op) => repository.archive(op, id)),
                )
              else if (_selected == 1)
                _later(widget.reportBuilder, 'O relatório')
              else if (_selected == 2)
                _later(widget.eventsBuilder, 'O histórico de eventos')
              else
                _later(widget.backupBuilder, 'O backup'),
            ],
          ),
        ),
      ),
    );
  }
}
