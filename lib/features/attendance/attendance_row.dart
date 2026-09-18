/// One attendance row exposing Presente, Ausente, Justificado and Não marcado
/// as text, semantics and color (S08, S10).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/attendance.dart';
import '../../ui/app_theme.dart';
import '../classes/academic_repository.dart';

class AttendanceRow extends StatelessWidget {
  const AttendanceRow({
    super.key,
    required this.entry,
    required this.status,
    required this.onChanged,
    this.enabled = true,
    this.autofocusFirstChoice = false,
  });

  final AttendanceRosterEntry entry;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;
  final bool enabled;

  /// Focuses the Presente control when this is the first row, so a keyboard
  /// user can mark without a pointer.
  final bool autofocusFirstChoice;

  static const List<AttendanceStatus> orderedStatuses = <AttendanceStatus>[
    AttendanceStatus.present,
    AttendanceStatus.absent,
    AttendanceStatus.excused,
    AttendanceStatus.unmarked,
  ];

  static const Map<AttendanceStatus, String> labels =
      <AttendanceStatus, String>{
        AttendanceStatus.present: 'Presente',
        AttendanceStatus.absent: 'Ausente',
        AttendanceStatus.excused: 'Justificado',
        AttendanceStatus.unmarked: 'Não marcado',
      };

  static Key rowKey(String enrollmentId) => Key('attendance-row-$enrollmentId');

  static Key choiceKey(String enrollmentId, AttendanceStatus status) =>
      Key('attendance-choice-$enrollmentId-${status.wire}');

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final String statusLabel = labels[status] ?? status.wire;
    return Semantics(
      container: true,
      label: '${entry.studentName}: $statusLabel',
      child: Padding(
        key: rowKey(entry.enrollmentId),
        padding: const EdgeInsets.only(bottom: AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.studentName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: <Widget>[
                for (int index = 0; index < orderedStatuses.length; index++)
                  _AttendanceChoice(
                    key: choiceKey(entry.enrollmentId, orderedStatuses[index]),
                    label: labels[orderedStatuses[index]]!,
                    selected: status == orderedStatuses[index],
                    enabled: enabled,
                    autofocus: autofocusFirstChoice && index == 0,
                    tokens: tokens,
                    onSelect: () => onChanged(orderedStatuses[index]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceChoice extends StatelessWidget {
  const _AttendanceChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.autofocus,
    required this.tokens,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool autofocus;
  final AppTokens tokens;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: autofocus,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            if (enabled) {
              onSelect();
            }
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          canRequestFocus: false,
          onTap: enabled ? onSelect : null,
          borderRadius: AppRadii.controlRadius,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTouchTarget,
              minHeight: AppSizes.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x2,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? tokens.primary : tokens.surface,
              border: Border.all(
                color: selected ? tokens.primary : tokens.outline,
                width: selected ? 2 : 1,
              ),
              borderRadius: AppRadii.controlRadius,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? tokens.onPrimary : tokens.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
