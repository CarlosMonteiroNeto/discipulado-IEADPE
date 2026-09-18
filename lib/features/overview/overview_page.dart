/// Visão geral: authoritative counts and the paginated pending-attendance
/// section, with scope-carrying links (S09, S10).
///
/// The page consumes `app_theme.dart` tokens and `lib/ui` primitives only; it
/// never re-themes a control and never computes a count on the client.
library;

import 'package:flutter/material.dart';

import '../../domain/class_group.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/form_fields.dart';
import '../classes/academic_repository.dart';
import 'overview_controller.dart';
import 'overview_repository.dart';

/// Navigation contract for the `Turmas ativas` link: the target `/turmas`
/// route must carry both the scope and the explicit status filter (S09).
class ClassesLinkTarget {
  const ClassesLinkTarget({required this.congregationId, this.status});

  final String? congregationId;
  final ClassStatus? status;
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.controller,
    this.onOpenStudents,
    this.onOpenClasses,
    this.onOpenSession,
  });

  final OverviewController controller;

  /// Links carry the current scope, so the target list keeps the same filter.
  final ValueChanged<String?>? onOpenStudents;

  /// The classes link also carries the active status filter (S09).
  final ValueChanged<ClassesLinkTarget>? onOpenClasses;

  /// Opens the exact class/session of a pending attendance call (S09).
  final ValueChanged<PendingSessionEntry>? onOpenSession;

  static const Key countsStudentsKey = Key('overview-count-students');
  static const Key countsClassesKey = Key('overview-count-classes');
  static const Key countsOpenSessionsKey = Key('overview-count-open-sessions');
  static const Key openStudentsKey = Key('overview-open-students');
  static const Key openClassesKey = Key('overview-open-classes');
  static const Key openPendingKey = Key('overview-open-pending');
  static const Key refreshKey = Key('overview-refresh');
  static const Key congregationFilterKey = Key('overview-congregation-filter');
  static const Key pendingListKey = Key('overview-pending-list');
  static const Key pendingNextPageKey = Key('overview-pending-next');
  static const Key pendingPreviousPageKey = Key('overview-pending-previous');

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.invalidate();
  }

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
            builder: (BuildContext context, Widget? _) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _toolbar(context),
                  const SizedBox(height: AppSpacing.x4),
                  AsyncContent<OverviewCounts>(
                    state: widget.controller.counts,
                    onRetry: widget.controller.invalidate,
                    dataBuilder: _counts,
                  ),
                  if (widget.controller.pendingVisible) ...<Widget>[
                    const SizedBox(height: AppSpacing.x6),
                    _pendingSection(context),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final String? selected = widget.controller.congregationId;
    final bool selectedMissing =
        selected != null &&
        !widget.controller.congregations.any(
          (congregation) => congregation.id == selected,
        );
    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (widget.controller.isSupervisor)
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              key: OverviewPage.congregationFilterKey,
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Congregação'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas'),
                ),
                for (final congregation in widget.controller.congregations)
                  DropdownMenuItem<String?>(
                    value: congregation.id,
                    child: Text(congregation.name),
                  ),
                if (selectedMissing)
                  DropdownMenuItem<String?>(
                    value: selected,
                    child: const Text('Congregação selecionada'),
                  ),
              ],
              onChanged: widget.controller.setCongregation,
            ),
          ),
        AppButton(
          key: OverviewPage.refreshKey,
          label: 'Atualizar',
          variant: AppButtonVariant.secondary,
          onPressed: widget.controller.invalidate,
        ),
      ],
    );
  }

  Widget _counts(BuildContext context, OverviewCounts counts) {
    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x4,
      children: <Widget>[
        _CountCard(
          key: OverviewPage.countsStudentsKey,
          label: 'Alunos não arquivados',
          value: counts.students,
          linkKey: OverviewPage.openStudentsKey,
          linkLabel: 'Ver alunos',
          onOpen: () =>
              widget.onOpenStudents?.call(widget.controller.congregationId),
        ),
        _CountCard(
          key: OverviewPage.countsClassesKey,
          label: 'Turmas ativas',
          value: counts.classes,
          linkKey: OverviewPage.openClassesKey,
          linkLabel: 'Ver turmas',
          onOpen: () => widget.onOpenClasses?.call(
            ClassesLinkTarget(
              congregationId: widget.controller.congregationId,
              status: ClassStatus.active,
            ),
          ),
        ),
        _CountCard(
          key: OverviewPage.countsOpenSessionsKey,
          label: 'Chamadas em aberto',
          value: counts.openSessions,
          linkKey: OverviewPage.openPendingKey,
          linkLabel: 'Ver chamadas pendentes',
          onOpen: widget.controller.togglePending,
        ),
      ],
    );
  }

  Widget _pendingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Chamadas pendentes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.x3),
        AsyncContent<List<PendingSessionEntry>>(
          key: OverviewPage.pendingListKey,
          state: widget.controller.pending,
          onRetry: widget.controller.refreshPending,
          dataBuilder: _pendingList,
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            AppButton(
              key: OverviewPage.pendingPreviousPageKey,
              label: 'Anterior',
              variant: AppButtonVariant.text,
              onPressed: widget.controller.hasPreviousPage
                  ? widget.controller.previousPendingPage
                  : null,
            ),
            const SizedBox(width: AppSpacing.x2),
            AppButton(
              key: OverviewPage.pendingNextPageKey,
              label: 'Próxima',
              variant: AppButtonVariant.text,
              onPressed: widget.controller.hasNextPage
                  ? widget.controller.nextPendingPage
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pendingList(BuildContext context, List<PendingSessionEntry> items) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final PendingSessionEntry entry in items)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.x3),
            color: tokens.surfaceVariant,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.cardRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.className ?? entry.classId,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          '${formatBrazilianDate(entry.date)} · ${entry.congregationId}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    key: Key('overview-pending-open-${entry.id}'),
                    label: 'Abrir chamada',
                    variant: AppButtonVariant.text,
                    onPressed: () => widget.onOpenSession?.call(entry),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A labelled count with an explicit, keyboard-reachable link (S09, S10).
class _CountCard extends StatelessWidget {
  const _CountCard({
    super.key,
    required this.label,
    required this.value,
    required this.linkKey,
    required this.linkLabel,
    required this.onOpen,
  });

  final String label;
  final int value;
  final Key linkKey;
  final String linkLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Card(
      margin: EdgeInsets.zero,
      color: tokens.surfaceVariant,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.x2),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: tokens.onSurface),
            ),
            const SizedBox(height: AppSpacing.x2),
            AppButton(
              key: linkKey,
              label: linkLabel,
              variant: AppButtonVariant.text,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}
