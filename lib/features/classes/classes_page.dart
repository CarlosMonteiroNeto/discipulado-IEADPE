/// Scoped class list with filters, paging, refresh and a create hook
/// (S08, S09, S10).
library;

import 'package:flutter/material.dart';

import '../../domain/class_group.dart';
import '../../domain/congregation.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/form_fields.dart';
import '../../ui/record_list.dart';
import 'academic_repository.dart';
import 'class_controller.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({
    super.key,
    required this.controller,
    this.onOpenClass,
    this.onCreate,
  });

  final ClassController controller;
  final ValueChanged<ClassListEntry>? onOpenClass;
  final VoidCallback? onCreate;

  static const Key searchFieldKey = Key('classes-search');
  static const Key statusFilterKey = Key('classes-status-filter');
  static const Key congregationFilterKey = Key('classes-congregation-filter');
  static const Key refreshKey = Key('classes-refresh');
  static const Key createKey = Key('classes-create');
  static const Key nextPageKey = Key('classes-next-page');
  static const Key previousPageKey = Key('classes-previous-page');

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
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
                  child: AsyncContent<List<ClassListEntry>>(
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
    final ClassQuery query = widget.controller.query;
    final bool scoped = query.congregationId != null;
    final List<Congregation> congregations = widget.controller.congregations;
    final bool selectedMissing =
        query.congregationId != null &&
        !congregations.any(
          (Congregation congregation) =>
              congregation.id == query.congregationId,
        );
    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (widget.controller.isSupervisor)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              key: ClassesPage.congregationFilterKey,
              initialValue: query.congregationId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Congregação'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  child: Text('Selecione uma congregação'),
                ),
                for (final Congregation congregation in congregations)
                  DropdownMenuItem<String?>(
                    value: congregation.id,
                    child: Text(congregation.name),
                  ),
                if (selectedMissing)
                  DropdownMenuItem<String?>(
                    value: query.congregationId,
                    child: const Text('Congregação selecionada'),
                  ),
              ],
              onChanged: widget.controller.setCongregation,
            ),
          ),
        SizedBox(
          width: 280,
          child: AppTextField(
            key: ClassesPage.searchFieldKey,
            label: 'Buscar por nome',
            controller: _search,
            helperText: 'Busca por prefixo do nome.',
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<ClassStatus?>(
            key: ClassesPage.statusFilterKey,
            initialValue: query.status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Situação'),
            items: <DropdownMenuItem<ClassStatus?>>[
              const DropdownMenuItem<ClassStatus?>(
                child: Text('Todas as situações'),
              ),
              for (final ClassStatus status in ClassStatus.values)
                DropdownMenuItem<ClassStatus?>(
                  value: status,
                  child: Text(classStatusLabel(status)),
                ),
            ],
            onChanged: scoped ? widget.controller.setStatus : null,
          ),
        ),
        AppButton(
          key: ClassesPage.refreshKey,
          label: 'Atualizar',
          variant: AppButtonVariant.secondary,
          onPressed: widget.controller.refresh,
        ),
        if (widget.onCreate != null && widget.controller.canCreate)
          AppButton(
            key: ClassesPage.createKey,
            label: 'Nova turma',
            icon: Icons.group_add_outlined,
            onPressed: widget.onCreate,
          ),
      ],
    );
  }

  Widget _list(BuildContext context, List<ClassListEntry> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: AppRecordList<ClassListEntry>(
            items: items,
            onOpen: widget.onOpenClass,
            columns: <AppRecordColumn<ClassListEntry>>[
              AppRecordColumn<ClassListEntry>(
                label: 'Nome',
                cell: (_, ClassListEntry entry) => Text(entry.name),
              ),
              AppRecordColumn<ClassListEntry>(
                label: 'Situação',
                cell: (_, ClassListEntry entry) =>
                    Text(classStatusLabel(entry.status)),
              ),
              AppRecordColumn<ClassListEntry>(
                label: 'Período',
                cell: (_, ClassListEntry entry) => Text(
                  entry.endDate == null
                      ? '${formatBrazilianDate(entry.startDate)} – em andamento'
                      : '${formatBrazilianDate(entry.startDate)} – '
                            '${formatBrazilianDate(entry.endDate!)}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            AppButton(
              key: ClassesPage.previousPageKey,
              label: 'Anterior',
              variant: AppButtonVariant.text,
              onPressed: widget.controller.hasPreviousPage
                  ? widget.controller.previousPage
                  : null,
            ),
            const SizedBox(width: AppSpacing.x2),
            AppButton(
              key: ClassesPage.nextPageKey,
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
