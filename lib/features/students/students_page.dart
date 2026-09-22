/// Student list with scope, prefix search, archived/active-class filters,
/// pagination, refresh and URL-state hooks (S07, S09, S10).
library;

import 'package:flutter/material.dart';

import '../../domain/class_group.dart';
import '../../domain/congregation.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/filter_field.dart';
import '../../ui/form_fields.dart';
import '../../ui/record_list.dart';
import 'student_controller.dart';
import 'student_repository.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.controller,
    this.onOpenStudent,
    this.onCreate,
  });

  final StudentController controller;
  final ValueChanged<StudentListEntry>? onOpenStudent;
  final VoidCallback? onCreate;

  static const Key searchFieldKey = Key('students-search');
  static const Key archivedFilterKey = Key('students-archived-filter');
  static const Key classFilterKey = Key('students-class-filter');
  static const Key congregationFilterKey = Key('students-congregation-filter');
  static const Key refreshKey = Key('students-refresh');
  static const Key nextPageKey = Key('students-next-page');
  static const Key previousPageKey = Key('students-previous-page');
  static const Key createKey = Key('students-create');

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
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
                  child: AsyncContent<List<StudentListEntry>>(
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
    final StudentQuery query = widget.controller.query;
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
            width: AppSizes.filterControlWidth,
            child: AppFilterField<String>(
              fieldKey: StudentsPage.congregationFilterKey,
              label: 'Congregação',
              value: query.congregationId,
              nullLabel: 'Selecione uma congregação',
              options: <AppFilterOption<String>>[
                for (final Congregation congregation in congregations)
                  AppFilterOption<String>(
                    value: congregation.id,
                    label: congregation.name,
                  ),
              ],
              fallback: selectedMissing
                  ? AppFilterOption<String>(
                      value: query.congregationId!,
                      label: 'Congregação selecionada',
                    )
                  : null,
              onChanged: widget.controller.setCongregation,
            ),
          ),
        SizedBox(
          width: AppSizes.searchControlWidth,
          child: AppTextField(
            key: StudentsPage.searchFieldKey,
            label: 'Buscar por nome',
            controller: _search,
            helperText: 'Busca por prefixo do nome.',
          ),
        ),
        SizedBox(
          width: AppSizes.filterControlWidth,
          child: AppFilterField<String>(
            fieldKey: StudentsPage.classFilterKey,
            label: 'Turma ativa',
            value: query.classId,
            nullLabel: 'Todas as turmas',
            options: <AppFilterOption<String>>[
              for (final ClassGroup classGroup in widget.controller.classes)
                AppFilterOption<String>(
                  value: classGroup.id,
                  label: classGroup.name,
                ),
            ],
            enabled: scoped,
            onChanged: widget.controller.setClassFilter,
          ),
        ),
        FilterChip(
          key: StudentsPage.archivedFilterKey,
          label: const Text('Arquivados'),
          selected: query.archived,
          onSelected: scoped
              ? (bool selected) => widget.controller.setArchived(selected)
              : null,
        ),
        AppButton(
          key: StudentsPage.refreshKey,
          label: 'Atualizar',
          variant: AppButtonVariant.secondary,
          onPressed: widget.controller.refresh,
        ),
        if (widget.onCreate != null && widget.controller.canCreate)
          AppButton(
            key: StudentsPage.createKey,
            label: 'Novo aluno',
            icon: Icons.person_add_alt,
            onPressed: widget.onCreate,
          ),
      ],
    );
  }

  Widget _list(BuildContext context, List<StudentListEntry> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: AppRecordList<StudentListEntry>(
            items: items,
            onOpen: widget.onOpenStudent,
            columns: <AppRecordColumn<StudentListEntry>>[
              AppRecordColumn<StudentListEntry>(
                label: 'Nome',
                cell: (_, StudentListEntry entry) => Text(entry.name),
              ),
              AppRecordColumn<StudentListEntry>(
                label: 'Situação',
                cell: (_, StudentListEntry entry) =>
                    Text(entry.archived ? 'Arquivado' : 'Ativo'),
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
              key: StudentsPage.previousPageKey,
              label: 'Anterior',
              variant: AppButtonVariant.text,
              onPressed: widget.controller.hasPreviousPage
                  ? widget.controller.previousPage
                  : null,
            ),
            AppButton(
              key: StudentsPage.nextPageKey,
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
