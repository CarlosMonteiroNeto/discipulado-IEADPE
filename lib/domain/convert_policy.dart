import 'business_calendar.dart';
import 'models.dart';

enum VisitState { urgent, current, attention }

bool isTerminal(ConvertRecord record) =>
    record.deletedAt != null ||
    record.isDeviated ||
    record.isDiscipleshipCompleted;

bool needsVisit(ConvertRecord record, DateOnly today) {
  if (isTerminal(record)) return false;
  final followUp = record.followUpDate;
  final hasContact = record.wasVisitedOnce || followUp != null;
  final elapsed = today.differenceInDays(followUp ?? record.conversionDate);
  if (!hasContact) return elapsed >= 1;
  if (record.isEffectivelyInDiscipleship) return elapsed >= 30;
  return elapsed >= 7;
}

VisitState visitState(ConvertRecord record, DateOnly today) {
  final due = needsVisit(record, today);
  if (due && !record.isEffectivelyInDiscipleship) return VisitState.urgent;
  if (!due && record.isEffectivelyInDiscipleship) return VisitState.current;
  return VisitState.attention;
}

bool canCompleteDiscipleship(ConvertRecord record, DateOnly today) {
  if (isTerminal(record) || !record.isEffectivelyInDiscipleship) return false;
  final start =
      record.effectiveDiscipleshipStartDate ??
      (record.isInDiscipleship ? record.discipleshipStartDate : null);
  return start != null && today.differenceInDays(start) >= 90;
}

bool canMarkDeviated(ConvertRecord record) =>
    !isTerminal(record) && record.visitCount >= 3;
bool canStartDiscipleship(ConvertRecord record) =>
    !isTerminal(record) && !record.isEffectivelyInDiscipleship;
bool canStopDiscipleship(ConvertRecord record) =>
    !isTerminal(record) && record.isInDiscipleship;
