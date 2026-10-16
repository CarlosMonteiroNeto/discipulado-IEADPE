import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/access_repository.dart';
import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import 'access_panel.dart';
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
  List<UserAccess>? _access;
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
      _access = null;
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
      _access = null;
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
      _access = null;
      _error = null;
    });
    try {
      final catalog = await CongregationRepository(gateway).list();
      gateway.ensureCurrent(token);
      if (!_current || request != _request || gateway != widget.gateway) return;
      final access = <UserAccess>[];
      String? cursor;
      do {
        final page = await AccessRepository(gateway).list(cursor);
        gateway.ensureCurrent(token);
        access.addAll(page.items);
        cursor = page.nextCursor;
      } while (cursor != null);
      if (_current && request == _request) {
        setState(() {
          _catalog = catalog;
          _access = List.unmodifiable(access);
        });
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
          _access = null;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seu acesso mudou. Atualize seu acesso para continuar.'),
            TextButton(
              onPressed: _refreshScope,
              child: const Text('Atualizar acesso'),
            ),
          ],
        ),
      );
    }
    if (_refreshing || !_current) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Atualizando seu acesso…'),
            TextButton(
              onPressed: _refreshScope,
              child: const Text('Atualizar acesso'),
            ),
          ],
        ),
      );
    }
    final locked = _busy || _retry != null;
    final repository = CongregationRepository(widget.gateway);
    final accessRepository = AccessRepository(widget.gateway);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Administração',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in const [
                    'Congregações',
                    'Acessos',
                    'Relatório',
                    'Eventos',
                    'Backup',
                  ].indexed)
                    ChoiceChip(
                      label: Text(entry.$2),
                      selected: _selected == entry.$1,
                      onSelected: locked
                          ? null
                          : (_) => setState(() => _selected = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_busy)
                Semantics(
                  liveRegion: true,
                  child: const Text('Salvando alteração…'),
                ),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              if (_retry != null && !_busy)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => _mutate(_retry!),
                    child: const Text('Tentar a mesma alteração novamente'),
                  ),
                ),
              if (_selected < 2 && (_catalog == null || _access == null)) ...[
                if (_error == null) const Text('Carregando administração…'),
                if (_error != null && _retry == null)
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
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
                AccessPanel(
                  key: ValueKey('access-$_token'),
                  items: _access!,
                  congregations: _catalog!,
                  busy: locked,
                  onSave: (id, email, role, congregationId) => _mutate(
                    (op) => accessRepository.save(
                      op,
                      id: id,
                      email: email,
                      role: role,
                      congregationId: congregationId,
                    ),
                  ),
                  onRevoke: (id) =>
                      _mutate((op) => accessRepository.revoke(op, id)),
                )
              else if (_selected == 2)
                _later(widget.reportBuilder, 'O relatório')
              else if (_selected == 3)
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
