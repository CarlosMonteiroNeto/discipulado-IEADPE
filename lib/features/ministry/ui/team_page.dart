import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../converts/convert_actions.dart';

import '../../../data/access_repository.dart';
import '../../../data/supabase_gateway.dart';
import '../../../ui/base44_widgets.dart';
import '../../../ui/unified_theme.dart';
import '../data/ministry_codec.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import 'team_contact_form.dart';
import 'team_role_labels.dart';

/// Scoped directory for local and supervision ministry contacts.
class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.repository,
    this.congregationId,
    this.congregationName,
    this.supervision = false,
    this.canManageAccess = false,
    this.onScopeRefresh,
  });

  final MinistryRepository repository;
  final String? congregationId;
  final String? congregationName;
  final bool supervision;
  final bool canManageAccess;
  final Future<void> Function()? onScopeRefresh;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final _uuid = const Uuid();
  final _search = TextEditingController();
  MinistryPage<MinistryDirectoryEntry>? _page;
  String? _cursor;
  String? _error;
  bool _loading = false;
  bool _detailLoading = false;
  BuildContext? _dialogContext;
  int _loadGeneration = 0;

  ContactScope get _scope =>
      widget.supervision ? ContactScope.supervision : ContactScope.congregation;

  bool _isScopeCurrent(ContactScope scope, String? congregationId) =>
      mounted &&
      scope == _scope &&
      congregationId == (widget.supervision ? null : widget.congregationId) &&
      (scope == ContactScope.supervision || congregationId != null);

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

  @override
  void didUpdateWidget(covariant TeamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.congregationId != widget.congregationId ||
        oldWidget.supervision != widget.supervision ||
        oldWidget.canManageAccess != widget.canManageAccess) {
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
      _load();
    }
  }

  Future<void> _load({String? cursor}) async {
    if (!widget.supervision && widget.congregationId == null) {
      setState(() {
        _page = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    final generation = ++_loadGeneration;
    final congregationId = widget.congregationId;
    final supervision = widget.supervision;
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
      if (mounted &&
          generation == _loadGeneration &&
          congregationId == widget.congregationId &&
          supervision == widget.supervision) {
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
              ? 'Você não tem acesso a este diretório.'
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
    if (item.email == null) return 'Sem acesso ao aplicativo';
    if (!widget.canManageAccess) return 'Email cadastrado';
    if (item.userAccessId != null) return 'Acesso vinculado';
    return 'Email cadastrado · sem vínculo';
  }

  Future<void> _openContact([MinistryDirectoryEntry? item]) async {
    if (_detailLoading ||
        (!widget.supervision && widget.congregationId == null)) {
      return;
    }
    final scope = _scope;
    final congregationId = widget.supervision ? null : widget.congregationId;
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
        if (mounted) {
          setState(() {
            _detailLoading = false;
            _error = error is DataFailure && error.code == 'permission'
                ? 'Você não tem acesso a este contato.'
                : 'Não foi possível carregar os dados do contato.';
          });
        }
        return;
      }
      if (!_isScopeCurrent(scope, congregationId)) return;
      setState(() => _detailLoading = false);
    }
    if (!_isScopeCurrent(scope, congregationId)) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return TeamContactForm(
          repository: widget.repository,
          accessRepository: AccessRepository(widget.repository.gateway),
          scope: scope,
          congregationId: congregationId,
          congregationName: widget.congregationName,
          current: detail,
          directory: _page?.items ?? const <MinistryDirectoryEntry>[],
          canManageAccess: widget.canManageAccess,
          createId: _uuid.v4,
          isScopeCurrent: () => _isScopeCurrent(scope, congregationId),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Base44PageContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: UnifiedSpace.x4),
          children: [
            Base44PageHeading(
              title: 'Equipe de discipulado',
              icon: Icons.groups_outlined,
              subtitle: widget.supervision
                  ? 'Diretório da supervisão'
                  : 'Diretório da congregação',
              trailing: widget.supervision || widget.congregationId != null
                  ? FilledButton.icon(
                      onPressed: _loading || _detailLoading
                          ? null
                          : () => _openContact(),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Adicionar contato'),
                    )
                  : null,
            ),
            const SizedBox(height: UnifiedSpace.x4),
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
            if (widget.supervision == false && widget.congregationId == null)
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
              Semantics(liveRegion: true, child: LinearProgressIndicator()),
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
              const Base44Panel(child: Text('Nenhuma pessoa encontrada.')),
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
                        if (item.archivedAt != null)
                          const Text('Contato arquivado'),
                      ],
                    ),
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: UnifiedColors.pageTint,
                    foregroundColor: UnifiedColors.brandNavy,
                    child: Icon(Icons.person_outline),
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
                        tooltip: 'Editar contato',
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
