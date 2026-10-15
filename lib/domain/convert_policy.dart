import 'business_calendar.dart';
import 'models.dart';

enum VisitState { urgent, current, attention }

bool isTerminal(ConvertRecord record) =>
    record.isDiscipleshipCompleted ||
    record.isDeviated ||
    record.deletedAt != null;
bool needsVisit(ConvertRecord record, DateOnly today) {
  if (isTerminal(record)) return false;
  final days = today.differenceInDays(
    record.lastVisitDate ?? record.conversionDate,
  );
  return days >=
      (!record.wasVisitedOnce
          ? 1
          : record.isInDiscipleship
          ? 30
          : 7);
}

VisitState visitState(ConvertRecord record, DateOnly today) =>
    needsVisit(record, today) && !record.isInDiscipleship
    ? VisitState.urgent
    : !needsVisit(record, today) && record.isInDiscipleship
    ? VisitState.current
    : VisitState.attention;
bool canCompleteDiscipleship(ConvertRecord record, DateOnly today) =>
    !isTerminal(record) &&
    record.isInDiscipleship &&
    record.discipleshipStartDate != null &&
    today.differenceInDays(record.discipleshipStartDate!) >= 90;
bool canMarkDeviated(ConvertRecord record) =>
    !isTerminal(record) && record.visitCount >= 3;
bool canStartDiscipleship(ConvertRecord record) =>
    !isTerminal(record) && !record.isInDiscipleship;
bool canStopDiscipleship(ConvertRecord record) =>
    !isTerminal(record) && record.isInDiscipleship;
