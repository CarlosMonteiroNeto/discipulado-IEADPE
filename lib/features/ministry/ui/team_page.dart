import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../converts/convert_actions.dart';

import '../../../data/supabase_gateway.dart';
import '../../../domain/models.dart' show Congregation;
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import 'team_contact_form.dart';
import 'team_role_labels.dart';

/// Scoped directory for local and supervision ministry teams. Membership is
/// the access grant: an active member with an e-mail can sign in.
class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.repository,
    this.congregations = const [],
    this.canSelectSupervision = false,
    this.onScopeRefresh,
  });

  final MinistryRepository repository;
  final List<Congregation> congregations;
  final bool canSelectSupervision;
  final Future<void> Function()? onScopeRefresh;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  static const _supervisionKey = 'supervision';

  final _uuid = const Uuid();
  final _search = TextEditingController();
  MinistryPage<MinistryDirectoryEntry>? _page;
  String? _cursor;
  String? _error;
  bool _loading = false;
  bool _detailLoading = false;
  BuildContext? _dialogContext;
  int _loadGeneration = 0;
  String? _scopeKey;

  bool get _supervision =>
      widget.canSelectSupervision && _scopeKey == _supervisionKey;

  String? get _congregationId =>
      _scopeKey == null || _scopeKey == _supervisionKey ? null : _scopeKey;

  Congregation? get _selectedCongregation => widget.congregations
      .where((item) => item.id == _congregationId)
      .firstOrNull;

  String get _initialScopeKey {
    if (widget.canSelectSupervision) return _supervisionKey;
    return widget.congregations.isEmpty
        ? _supervisionKey
        : widget.congregations.first.id;
  }

  bool _hasScope() => _supervision || _congregationId != null;

  @override
  void initState() {
    super.initState();
    _scopeKey = _initialScopeKey;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TeamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scopeChanged =
        oldWidget.canSelectSupervision != widget.canSelectSupervision ||
        oldWidget.congregations.length != widget.congregations.length ||
        !oldWidget.congregations.every(
          (item) => widget.congregations.any((next) => next.id == item.id),
        );
    if (scopeChanged) {
      _scopeKey = _initialScopeKey;
      _resetDirectory();
      _load();
    }
  }

  void _resetDirectory() {
    _search.clear();
    _page = null;
    _detailLoading = false;
    _loadGeneration++;
    final dialogContext = _dialogContext;
    if (dialogContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      });
    }
  }

  Future<void> _load({String? cursor}) async {
    if (!_hasScope()) {
      setState(() {
        _page = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    final generation = ++_loadGeneration;
    final scopeKey = _scopeKey;
    final supervision = _supervision;
    final congregationId = _congregationId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listDirectory(
        scope: supervision ? 'supervision' : 'congregation',
        congregationId: supervision ? null : congregationId,
        namePrefix: _search.text.trim().isEmpty ? null : _search.text.trim(),
        limit: 50,
        cursor: cursor,
      );
      if (mounted && generation == _loadGeneration && scopeKey == _scopeKey) {
        setState(() {
          _page = page;
          _cursor = cursor;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error = error is DataFailure && error.code == 'permission'
              ? 'Você não tem acesso a esta equipe.'
              : 'Não foi possível carregar a equipe. Tente novamente.';
        });
      }
    }
  }

  Future<void> _openWhatsApp(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o WhatsApp. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  String _accessStatus(MinistryDirectoryEntry item) {
    if (item.archivedAt != null) return 'Membro inativo';
    if (item.email == null) return 'Sem acesso ao app';
    return 'Acesso ao app pelo e-mail';
  }

  Future<void> _openContact([MinistryDirectoryEntry? item]) async {
    if (_detailLoading || !_hasScope()) return;
    final scope = _supervision
        ? ContactScope.supervision
        : ContactScope.congregation;
    final congregationId = _congregationId;
    final scopeKey = _scopeKey;
    final generation = _loadGeneration;
    bool isScopeCurrent() =>
        mounted &&
        scopeKey == _scopeKey &&
        generation == _loadGeneration &&
        _hasScope();
    MinistryContactDetail? detail;
    if (item != null) {
      setState(() {
        _detailLoading = true;
        _error = null;
      });
      try {
        detail = await widget.repository.getContact(
          scope: scope,
          congregationId: congregationId,
          contactId: item.id,
        );
      } catch (error) {
        if (isScopeCurrent()) {
          setState(() {
            _detailLoading = false;
            _error = error is DataFailure && error.code == 'permission'
                ? 'Você não tem acesso a este membro.'
                : 'Não foi possível carregar os dados do membro.';
          });
        }
        return;
      }
      if (!isScopeCurrent()) return;
      setState(() => _detailLoading = false);
    }
    if (!isScopeCurrent() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return TeamContactForm(
          repository: widget.repository,
          scope: scope,
          congregationId: congregationId,
          congregationName: _selectedCongregation?.name,
          current: detail,
          directory: _page?.items ?? const <MinistryDirectoryEntry>[],
          createId: _uuid.v4,
          isScopeCurrent: isScopeCurrent,
          onScopeRefresh: widget.onScopeRefresh,
          onSaved: () {
            Navigator.of(dialogContext).pop();
            _dialogContext = null;
            if (mounted) _load();
          },
        );
      },
    );
    _dialogContext = null;
  }

  Widget _scopeSelector() {
    final options = <(String, String)>[
      if (widget.canSelectSupervision)
        (_supervisionKey, 'Equipe da supervisão'),
      for (final congregation in widget.congregations)
        (congregation.id, 'Equipe local · ${congregation.name}'),
    ];
    if (options.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: UnifiedSpace.x2),
      child: Base44Panel(
        child: DropdownButtonFormField<String>(
          key: const ValueKey('team-scope-selector'),
          initialValue: _scopeKey,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(
            labelText: 'Equipe',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          items: [
            for (final (value, label) in options)
              DropdownMenuItem(value: value, child: Text(label)),
          ],
          onChanged: _loading || _detailLoading
              ? null
              : (value) {
                  if (value == null || value == _scopeKey) return;
                  setState(() => _scopeKey = value);
                  _resetDirectory();
                  _load();
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Base44PageContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: UnifiedSpace.x4),
          children: [
            Base44PageHeading(
              title: 'Equipe',
              icon: Icons.groups_outlined,
              subtitle: _supervision ? 'Equipe da supervisão' : 'Equipe local',
              trailing: _hasScope()
                  ? FilledButton.icon(
                      onPressed: _loading || _detailLoading
                          ? null
                          : () => _openContact(),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Adicionar membro'),
                    )
                  : null,
            ),
            const SizedBox(height: UnifiedSpace.x4),
            _scopeSelector(),
            Base44Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                  const SizedBox(height: UnifiedSpace.x2),
                  Wrap(
                    spacing: UnifiedSpace.x2,
                    runSpacing: UnifiedSpace.x2,
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
            const SizedBox(height: UnifiedSpace.x2),
            if (!_hasScope())
              const Base44Panel(
                child: Text(
                  'Selecione uma congregação autorizada para abrir a equipe.',
                ),
              ),
            if (_loading)
              const Base44Panel(
                padding: EdgeInsets.all(UnifiedSpace.x6),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando equipe',
                  ),
                ),
              ),
            if (_detailLoading)
              Semantics(
                liveRegion: true,
                child: const LinearProgressIndicator(),
              ),
            if (_error != null)
              Base44Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!),
                    const SizedBox(height: UnifiedSpace.x2),
                    TextButton.icon(
                      onPressed: () => _load(cursor: _cursor),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            if (!_loading && _error == null && _page?.items.isEmpty == true)
              const Base44Panel(child: Text('Nenhum membro nesta equipe.')),
            for (final item in _page?.items ?? const <MinistryDirectoryEntry>[])
              Card(
                child: ListTile(
                  key: ValueKey('team-contact-${item.id}'),
                  title: Text(item.name, softWrap: true),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: UnifiedSpace.x1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(teamRoleLabel(item.roleCode)),
                        Text(_accessStatus(item)),
                      ],
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: item.archivedAt == null
                        ? UnifiedColors.pageTint
                        : UnifiedColors.border,
                    foregroundColor: item.archivedAt == null
                        ? UnifiedColors.brandNavy
                        : UnifiedColors.muted,
                    child: Icon(
                      item.archivedAt == null
                          ? Icons.person_outline
                          : Icons.person_off_outlined,
                    ),
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Abrir WhatsApp',
                        onPressed: brazilWhatsApp(item.phoneE164) == null
                            ? null
                            : () => _openWhatsApp(
                                brazilWhatsApp(item.phoneE164)!,
                              ),
                        icon: const Icon(Icons.chat_outlined),
                        color: UnifiedColors.whatsapp,
                      ),
                      IconButton(
                        tooltip: 'Editar membro',
                        onPressed: _detailLoading
                            ? null
                            : () => _openContact(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  minVerticalPadding: UnifiedSize.minTouchTarget / 4,
                  onTap: _detailLoading ? null : () => _openContact(item),
                ),
              ),
            if (_page?.nextCursor != null)
              Base44Panel(
                padding: const EdgeInsets.all(UnifiedSpace.x2),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _load(cursor: _page!.nextCursor),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Próxima página'),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
