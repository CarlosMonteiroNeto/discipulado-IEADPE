/// Supervisor congregation management screen (S06, S10).
///
/// Staff never receive create/rename/archive controls; a backend denial still
/// surfaces as a safe, actionable failure.
library;

import 'package:flutter/material.dart';

import '../../domain/congregation.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/confirmation_dialog.dart';
import '../../ui/form_fields.dart';
import 'congregation_controller.dart';

class CongregationsPage extends StatefulWidget {
  const CongregationsPage({super.key, required this.controller});

  final CongregationController controller;

  static const Key listKey = Key('congregations-list');
  static const Key createKey = Key('congregations-create');
  static const Key refreshKey = Key('congregations-refresh');
  static const Key explanationKey = Key('congregations-archive-explanation');

  static Key renameKey(String id) => Key('congregation-rename-$id');

  static Key archiveKey(String id) => Key('congregation-archive-$id');

  static Key restoreKey(String id) => Key('congregation-restore-$id');

  @override
  State<CongregationsPage> createState() => _CongregationsPageState();
}

class _CongregationsPageState extends State<CongregationsPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();
  }

  Future<void> _create() async {
    final String? name = await _promptName(
      title: 'Nova congregação',
      confirmLabel: 'Criar',
    );
    if (name != null) {
      await widget.controller.create(name);
    }
  }

  Future<void> _rename(Congregation congregation) async {
    final String? name = await _promptName(
      title: 'Renomear congregação',
      confirmLabel: 'Salvar',
      initial: congregation.name,
    );
    if (name != null && name != congregation.name) {
      await widget.controller.rename(congregation, name);
    }
  }

  Future<void> _archive(Congregation congregation) async {
    final bool confirmed = await showConfirmationDialog(
      context,
      title: 'Arquivar congregação',
      message: 'Arquivar ${congregation.name}?',
      confirmLabel: 'Arquivar',
      destructive: true,
    );
    if (confirmed) {
      await widget.controller.archive(congregation);
    }
  }

  Future<String?> _promptName({
    required String title,
    required String confirmLabel,
    String initial = '',
  }) {
    final TextEditingController controller = TextEditingController(
      text: initial,
    );
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: AppTextField(
          label: 'Nome',
          controller: controller,
          required: true,
        ),
        actions: <Widget>[
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: confirmLabel,
            onPressed: () {
              final String value = controller.text.trim();
              Navigator.of(dialogContext).pop(value.isEmpty ? null : value);
            },
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
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
            builder: (BuildContext context, Widget? _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Congregações',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (widget.controller.isSupervisor)
                      AppButton(
                        key: CongregationsPage.createKey,
                        label: 'Nova congregação',
                        icon: Icons.add,
                        onPressed: _create,
                      ),
                    const SizedBox(width: AppSpacing.x2),
                    AppButton(
                      key: CongregationsPage.refreshKey,
                      label: 'Atualizar',
                      variant: AppButtonVariant.secondary,
                      onPressed: widget.controller.refresh,
                    ),
                  ],
                ),
                if (widget.controller.archiveExplanation != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.x3),
                  Container(
                    key: CongregationsPage.explanationKey,
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant,
                      borderRadius: AppRadii.controlRadius,
                      border: Border.all(color: tokens.error),
                    ),
                    child: Text(
                      widget.controller.archiveExplanation!,
                      style: TextStyle(color: tokens.onSurface),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                Expanded(
                  child: AsyncContent<List<Congregation>>(
                    state: widget.controller.activeState,
                    onRetry: widget.controller.refresh,
                    dataBuilder: _activeList,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                _archivedSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeList(BuildContext context, List<Congregation> items) {
    return ListView.separated(
      key: CongregationsPage.listKey,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
      itemBuilder: (BuildContext context, int index) =>
          _row(context, items[index], archived: false),
    );
  }

  Widget _archivedSection(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        final List<Congregation> archived =
            widget.controller.archivedState.data ?? const <Congregation>[];
        if (archived.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Arquivadas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            for (final Congregation congregation in archived)
              _row(context, congregation, archived: true),
          ],
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    Congregation congregation, {
    required bool archived,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(congregation.name)),
            if (widget.controller.isSupervisor) ...<Widget>[
              if (!archived) ...<Widget>[
                AppButton(
                  key: CongregationsPage.renameKey(congregation.id),
                  label: 'Renomear',
                  variant: AppButtonVariant.text,
                  onPressed: () => _rename(congregation),
                ),
                AppButton(
                  key: CongregationsPage.archiveKey(congregation.id),
                  label: 'Arquivar',
                  variant: AppButtonVariant.danger,
                  onPressed: () => _archive(congregation),
                ),
              ] else
                AppButton(
                  key: CongregationsPage.restoreKey(congregation.id),
                  label: 'Restaurar',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => widget.controller.restore(congregation),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
