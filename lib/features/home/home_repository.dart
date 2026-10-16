import '../../data/convert_repository.dart';
import '../../domain/models.dart';
import '../../domain/business_calendar.dart';
import '../../domain/convert_policy.dart';

class HomeSummary {
  HomeSummary({
    required this.total,
    required this.urgentVisits,
    required this.inDiscipleship,
    required List<ConvertRecord> recent,
  }) : recent = List.unmodifiable(recent);
  final int total, urgentVisits, inDiscipleship;
  final List<ConvertRecord> recent;
}

class HomeRepository {
  HomeRepository(this.converts, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final ConvertRepository converts;
  final DateTime Function() now;
  Future<HomeSummary> summary() async {
    final token = converts.gateway.context;
    final today = BusinessCalendar().today(now());
    final rows = <ConvertRecord>[];
    String? cursor;
    do {
      converts.gateway.ensureCurrent(token);
      final page = await converts.list(const ConvertQuery(), cursor);
      converts.gateway.ensureCurrent(token);
      rows.addAll(page.items.where((r) => r.deletedAt == null));
      cursor = page.nextCursor;
    } while (cursor != null);
    final recent =
        rows.where((r) {
          final age = today.differenceInDays(r.conversionDate);
          return age >= 0 && age < 7;
        }).toList()..sort((a, b) {
          final date = b.conversionDate.compareTo(a.conversionDate);
          if (date != 0) return date;
          final created = (b.createdAt ?? DateTime.utc(1)).compareTo(
            a.createdAt ?? DateTime.utc(1),
          );
          return created != 0 ? created : a.id.compareTo(b.id);
        });
    return HomeSummary(
      total: rows.length,
      urgentVisits: rows
          .where((r) => visitState(r, today) == VisitState.urgent)
          .length,
      inDiscipleship: rows.where((r) => r.isInDiscipleship).length,
      recent: recent.take(5).toList(),
    );
  }
}
