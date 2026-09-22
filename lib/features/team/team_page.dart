/// Team directory list with prefix search, scope/role filters, explicit
/// pagination and refresh (S06, S09, S10).
library;

import 'package:flutter/material.dart';

import '../../domain/contact.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/filter_bar.dart';
import '../../ui/filter_field.dart';
import '../../ui/form_fields.dart';
import '../../ui/record_list.dart';
import 'team_controller.dart';
import 'team_repository.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.controller,
    this.onOpenContact,
    this.onCreate,
  });

  final TeamController controller;
  final ValueChanged<DirectoryEntry>? onOpenContact;
  final VoidCallback? onCreate;

  static const Key searchFieldKey = Key('team-search');
  static const Key scopeFilterKey = Key('team-scope-filter');
  static const Key roleFilterKey = Key('team-role-filter');
  static const Key archivedFilterKey = Key('team-archived-filter');
  static const Key refreshKey = Key('team-refresh');
  static const Key nextPageKey = Key('team-next-page');
  static const Key previousPageKey = Key('team-previous-page');
  static const Key createKey = Key('team-create');

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query.search,
  );

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    widget.controller.refresh();
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() => widget.controller.setSearch(_search.text);

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      backgroundColor: tokens.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (BuildContext context, Widget? _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _filters(context),
                const SizedBox(height: AppSpacing.x4),
                Expanded(
                  child: AsyncContent<List<DirectoryEntry>>(
                    state: widget.controller.state,
                    onRetry: widget.controller.refresh,
                    dataBuilder: _list,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final TeamQuery query = widget.controller.query;
    final List<RoleCode> roles = RoleCode.values
        .where(
          (RoleCode role) => query.scope == null || role.scope == query.scope,
        )
        .toList(growable: false);
    final bool canArchive = query.congregationId != null;
    return AppFilterBar(
      fields: <Widget>[
        AppTextField(
          key: TeamPage.searchFieldKey,
          label: 'Buscar por nome',
          controller: _search,
          caption: true,
        ),
        AppFilterField<ContactScope>(
          fieldKey: TeamPage.scopeFilterKey,
          label: 'Escopo',
          value: query.scope,
          nullLabel: 'Todos',
          options: const <AppFilterOption<ContactScope>>[
            AppFilterOption<ContactScope>(
              value: ContactScope.congregation,
              label: 'Congregação',
            ),
            AppFilterOption<ContactScope>(
              value: ContactScope.supervision,
              label: 'Supervisão',
            ),
          ],
          onChanged: widget.controller.setScopeFilter,
        ),
        AppFilterField<RoleCode>(
          fieldKey: TeamPage.roleFilterKey,
          label: 'Papel',
          value: query.roleCode,
          nullLabel: 'Todos os papéis',
          options: <AppFilterOption<RoleCode>>[
            for (final RoleCode role in roles)
              AppFilterOption<RoleCode>(value: role, label: role.label),
          ],
          onChanged: widget.controller.setRoleFilter,
        ),
      ],
      actions: <Widget>[
        FilterChip(
          key: TeamPage.archivedFilterKey,
          label: const Text('Arquivados'),
          selected: query.archived,
          onSelected: canArchive ? widget.controller.setArchived : null,
        ),
        AppButton(
          key: TeamPage.refreshKey,
          label: 'Atualizar',
          variant: AppButtonVariant.secondary,
          onPressed: widget.controller.refresh,
        ),
        if (widget.onCreate != null && widget.controller.canManageCurrentScope)
          AppButton(
            key: TeamPage.createKey,
            label: 'Novo contato',
            icon: Icons.person_add_alt,
            onPressed: widget.onCreate,
          ),
      ],
    );
  }

  Widget _list(BuildContext context, List<DirectoryEntry> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: AppRecordList<DirectoryEntry>(
            items: items,
            onOpen: widget.onOpenContact,
            columns: <AppRecordColumn<DirectoryEntry>>[
              AppRecordColumn<DirectoryEntry>(
                label: 'Nome',
                cell: (_, DirectoryEntry entry) => Text(entry.name),
              ),
              AppRecordColumn<DirectoryEntry>(
                label: 'Papel',
                cell: (_, DirectoryEntry entry) =>
                    Text(entry.roleLabel ?? 'Sem papel'),
              ),
              AppRecordColumn<DirectoryEntry>(
                label: 'Congregação',
                cell: (_, DirectoryEntry entry) => Text(
                  entry.scope == ContactScope.supervision
                      ? 'Supervisão'
                      : widget.controller.congregationNameFor(
                          entry.congregationId,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: <Widget>[
            AppButton(
              key: TeamPage.previousPageKey,
              label: 'Anterior',
              variant: AppButtonVariant.text,
              onPressed: widget.controller.hasPreviousPage
                  ? widget.controller.previousPage
                  : null,
            ),
            AppButton(
              key: TeamPage.nextPageKey,
              label: 'Próxima',
              variant: AppButtonVariant.text,
              onPressed: widget.controller.hasNextPage
                  ? widget.controller.nextPage
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
