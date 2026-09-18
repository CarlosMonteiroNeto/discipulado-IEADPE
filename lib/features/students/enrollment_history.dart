/// Enrollment history view models and rendering for a student (S07, S08).
///
/// Progress comes exclusively from the authoritative `getEnrollmentProgress`
/// result; this file never infers a percentage or a graduation outcome.
library;

import 'package:flutter/material.dart';

import '../../domain/common.dart';
import '../../domain/enrollment.dart';
import '../../ui/app_theme.dart';

/// Authoritative per-enrollment progress returned by `getEnrollmentProgress`
/// (S08): counts plus a nullable whole-percent value. A null percentage means
/// no countable class, rendered as `Sem aulas contabilizadas`.
class EnrollmentProgressView {
  const EnrollmentProgressView({
    required this.enrollmentId,
    required this.classId,
    required this.present,
    required this.absent,
    required this.excused,
    required this.percentage,
  });

  final String enrollmentId;
  final String classId;
  final int present;
  final int absent;
  final int excused;
  final int? percentage;

  String get countsLabel =>
      '$present presenças · $absent falta · $excused justificadas';

  String get percentageLabel =>
      percentage == null ? 'Sem aulas contabilizadas' : '$percentage%';

  factory EnrollmentProgressView.fromJson(JsonMap json) =>
      EnrollmentProgressView(
        enrollmentId: requireString(json, 'enrollmentId'),
        classId: requireString(json, 'classId'),
        present: requireInt(json, 'present'),
        absent: requireInt(json, 'absent'),
        excused: requireInt(json, 'excused'),
        percentage: json['percentage'] is int
            ? json['percentage'] as int
            : null,
      );
}

/// One immutable enrollment row plus its resolved class name and progress.
class EnrollmentHistoryEntry {
  const EnrollmentHistoryEntry({
    required this.enrollment,
    required this.className,
    required this.progress,
  });

  final Enrollment enrollment;
  final String? className;
  final EnrollmentProgressView? progress;
}

String enrollmentStatusLabel(EnrollmentStatus status) => switch (status) {
  EnrollmentStatus.active => 'Ativa',
  EnrollmentStatus.completed => 'Concluída',
  EnrollmentStatus.withdrawn => 'Cancelada',
};

/// Renders an immutable enrollment history, including the S08 counts and the
/// `Sem aulas contabilizadas` copy for a zero denominator.
class EnrollmentHistoryView extends StatelessWidget {
  const EnrollmentHistoryView({super.key, required this.entries});

  final List<EnrollmentHistoryEntry> entries;

  static const Key emptyKey = Key('enrollment-history-empty');

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'Nenhuma matrícula registrada.',
        key: emptyKey,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final EnrollmentHistoryEntry entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: _EnrollmentHistoryCard(entry: entry),
          ),
      ],
    );
  }
}

class _EnrollmentHistoryCard extends StatelessWidget {
  const _EnrollmentHistoryCard({required this.entry});

  final EnrollmentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTheme.tokensOf(context);
    final Enrollment enrollment = entry.enrollment;
    final String period = enrollment.endDate == null
        ? '${formatBrazilianDate(enrollment.startDate)} – em andamento'
        : '${formatBrazilianDate(enrollment.startDate)} – '
              '${formatBrazilianDate(enrollment.endDate!)}';
    final EnrollmentProgressView? progress = entry.progress;
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.className ?? 'Turma',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  enrollmentStatusLabel(enrollment.status),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: tokens.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              period,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.onSurfaceVariant),
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              Text(
                progress.countsLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                progress.percentageLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Parses a pt-BR `dd/MM/yyyy` input. Returns null for a malformed string or an
/// impossible calendar day (for example 29/02 in a non-leap year).
CalendarDate? parseBrazilianDateInput(String raw) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final int day = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int year = int.parse(match.group(3)!);
  if (!CalendarDate.isValid(year, month, day)) {
    return null;
  }
  return CalendarDate(year, month, day);
}

/// Formats a calendar date as pt-BR `dd/MM/yyyy`.
String formatBrazilianDate(CalendarDate date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
