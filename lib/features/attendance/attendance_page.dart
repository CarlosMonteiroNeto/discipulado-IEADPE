/// Explicit four-state attendance editor for one session (S08, S09, S10).
///
/// The page is deep-linkable with class and session IDs and distinguishes
/// saving from finalizing. Unsaved choices survive a conflict or timeout and
/// the stale server copy is shown next to them; nothing is announced as
/// success until the backend acknowledges it.
library;

import 'package:flutter/material.dart';

import '../../domain/attendance.dart';
import '../../domain/session.dart';
import '../../ui/app_theme.dart';
import '../../ui/async_content.dart';
import '../../ui/confirmation_dialog.dart';
import '../../ui/form_fields.dart';
import '../classes/academic_repository.dart';
import 'attendance_controller.dart';
import 'attendance_row.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.controller, this.onCanceled});

  final AttendanceController controller;
  final VoidCallback? onCanceled;

  static const Key markAllKey = Key('attendance-mark-all');
  static const Key saveKey = Key('attendance-save');
  static const Key finalizeKey = Key('attendance-finalize');
  static const Key cancelKey = Key('attendance-cancel-session');
  static const Key reloadKey = Key('attendance-reload');
  static const Key retryKey = Key('attendance-retry');
  static const Key conflictKey = Key('attendance-conflict');
  static const Key comparisonKey = Key('attendance-comparison');
  static const Key validationKey = Key('attendance-validation');
  static const Key errorKey = Key('attendance-error');
  static const Key concludedKey = Key('attendance-lesson-concluded');

  /// Deep-linkable route using the class and session IDs (S10).
  static String routePath(String classId, String sessionId) =>
      '/turmas/$classId/chamadas/$sessionId';

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(title: const Text('Chamada')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (BuildContext context, Widget? _) =>
                AsyncContent<List<AttendanceRosterEntry>>(
                  state: widget.controller.state,
                  onRetry: widget.controller.load,
                  dataBuilder: _editor,
                ),
          ),
        ),
      ),
    );
  }

  Widget _editor(BuildContext context, List<AttendanceRosterEntry> roster) {
    final AttendanceController controller = widget.controller;
    final Session? session = controller.session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (session != null) _header(context, session),
        if (controller.validationMessage != null)
          _message(
            context,
            AttendancePage.validationKey,
            controller.validationMessage!,
          ),
        if (controller.errorMessage != null) ...<Widget>[
          _message(context, AttendancePage.errorKey, controller.errorMessage!),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: AttendancePage.retryKey,
              label: 'Tentar novamente',
              variant: AppButtonVariant.secondary,
              onPressed: () => controller.retry(),
            ),
          ),
        ],
        if (controller.hasConflict || controller.serverMarks != null)
          _conflict(context),
        const SizedBox(height: AppSpacing.x4),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (int index = 0; index < roster.length; index++)
                AttendanceRow(
                  entry: roster[index],
                  status: controller.statusOf(roster[index].enrollmentId),
                  enabled: !controller.isReadOnly && !controller.isSubmitting,
                  autofocusFirstChoice: index == 0,
                  onChanged: (AttendanceStatus status) =>
                      controller.mark(roster[index].enrollmentId, status),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        _actions(context, roster),
      ],
    );
  }

  Widget _header(BuildContext context, Session session) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final AttendanceController controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            session.topic ?? 'Chamada',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            formatBrazilianDate(session.date),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.onSurfaceVariant),
          ),
          Text(
            _sessionStatusLabel(session.status),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.x2),
          CheckboxListTile(
            key: AttendancePage.concludedKey,
            value: controller.lessonFinished,
            onChanged: controller.isReadOnly || controller.isSubmitting
                ? null
                : (bool? value) =>
                    controller.setLessonFinished(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text('Aula concluída?'),
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, Key key, String message) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Text(
        message,
        key: key,
        style: TextStyle(color: tokens.error),
      ),
    );
  }

  Widget _conflict(BuildContext context) {
    final AttendanceController controller = widget.controller;
    final AppTokens tokens = AppTheme.tokensOf(context);
    final Map<String, AttendanceStatus>? server = controller.serverMarks;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (controller.hasConflict) ...<Widget>[
            Text(
              controller.conflictMessage ?? 'A chamada foi alterada.',
              key: AttendancePage.conflictKey,
              style: TextStyle(color: tokens.error),
            ),
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                key: AttendancePage.reloadKey,
                label: 'Recarregar chamada',
                variant: AppButtonVariant.secondary,
                onPressed: controller.reloadAfterConflict,
              ),
            ),
          ],
          if (server != null)
            Padding(
              key: AttendancePage.comparisonKey,
              padding: const EdgeInsets.only(top: AppSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Comparação de chamadas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final AttendanceRosterEntry entry in controller.roster)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.x1),
                      child: Text(
                        '${entry.studentName} — não salvo: '
                        '${AttendanceRow.labels[controller.statusOf(entry.enrollmentId)]} · '
                        'no servidor: '
                        '${AttendanceRow.labels[server[entry.enrollmentId] ?? AttendanceStatus.unmarked]}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, List<AttendanceRosterEntry> roster) {
    final AttendanceController controller = widget.controller;
    final bool busy = controller.isSubmitting;
    final bool readOnly = controller.isReadOnly;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: <Widget>[
        AppButton(
          key: AttendancePage.markAllKey,
          label: 'Marcar todos presentes',
          variant: AppButtonVariant.secondary,
          onPressed: busy || readOnly || roster.isEmpty
              ? null
              : controller.markAllPresent,
        ),
        AppButton(
          key: AttendancePage.cancelKey,
          label: 'Cancelar chamada',
          variant: AppButtonVariant.text,
          onPressed: busy || readOnly ? null : _cancelSession,
        ),
        AppButton(
          key: AttendancePage.saveKey,
          label: 'Salvar chamada',
          isSubmitting: busy,
          onPressed: readOnly ? null : () => controller.save(finalize: false),
        ),
        AppButton(
          key: AttendancePage.finalizeKey,
          label: 'Salvar e finalizar',
          onPressed: busy || readOnly
              ? null
              : () => controller.save(finalize: true),
        ),
      ],
    );
  }

  Future<void> _cancelSession() async {
    final bool confirmed = await showConfirmationDialog(
      context,
      title: 'Cancelar chamada',
      message:
          'Cancelar esta chamada? O histórico é preservado, mas ela deixa de '
          'contar para o progresso.',
      confirmLabel: 'Cancelar chamada',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final bool canceled = await widget.controller.cancelSession();
    if (canceled) {
      widget.onCanceled?.call();
    }
  }
}

String _sessionStatusLabel(SessionStatus status) => switch (status) {
  SessionStatus.open => 'Aberta',
  SessionStatus.finalized => 'Finalizada',
  SessionStatus.canceled => 'Cancelada',
};
