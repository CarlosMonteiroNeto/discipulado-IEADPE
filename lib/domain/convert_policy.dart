import 'business_calendar.dart';
import 'models.dart';

enum VisitState { urgent, current, attention }

bool isTerminal(ConvertRecord record) =>
    record.deletedAt != null ||
    record.isDeviated ||
    record.isDiscipleshipCompleted;

bool needsVisit(ConvertRecord record, DateOnly today) {
  if (isTerminal(record)) return false;
  final elapsed = today.differenceInDays(
    record.lastVisitDate ?? record.conversionDate,
  );
  if (!record.wasVisitedOnce) return elapsed >= 1;
  if (record.isInDiscipleship) return elapsed >= 30;
  return elapsed >= 7;
}

VisitState visitState(ConvertRecord record, DateOnly today) {
  final due = needsVisit(record, today);
  if (due && !record.isInDiscipleship) return VisitState.urgent;
  if (!due && record.isInDiscipleship) return VisitState.current;
  return VisitState.attention;
}

bool canCompleteDiscipleship(ConvertRecord record, DateOnly today) {
  if (isTerminal(record) || !record.isInDiscipleship) return false;
  final start = record.discipleshipStartDate;
  return start != null && today.differenceInDays(start) >= 90;
}

bool canMarkDeviated(ConvertRecord record) =>
    !isTerminal(record) && record.visitCount >= 3;
bool canStartDiscipleship(ConvertRecord record) =>
    !isTerminal(record) && !record.isInDiscipleship;
bool canStopDiscipleship(ConvertRecord record) =>
    !isTerminal(record) && record.isInDiscipleship;
