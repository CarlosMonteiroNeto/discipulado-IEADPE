import '../../data/supabase_gateway.dart';
import '../../domain/business_calendar.dart';
import '../../domain/models.dart';

class DateRange {
  const DateRange({this.start, this.end});
  final DateOnly? start, end;
  bool contains(DateOnly date) =>
      (start == null || date.compareTo(start!) >= 0) &&
      (end == null || date.compareTo(end!) <= 0);
  bool get valid => start == null || end == null || start!.compareTo(end!) <= 0;
}

class EventQuery {
  const EventQuery({this.range = const DateRange(), this.congregationId});
  final DateRange range;
  final String? congregationId;
}

class WorshipCount {
  const WorshipCount(this.name, this.count);
  final String name;
  final int count;
}

class ReportsRepository {
  ReportsRepository(this.gateway);
  final Gateway gateway;
  Future<List<ConvertEvent>> events(EventQuery query) async {
    if (!query.range.valid) throw const DataFailure('invalid');
    if (query.congregationId != null) validateUuid(query.congregationId);
    final token = gateway.context;
    final result = <ConvertEvent>[];
    String? after;
    while (true) {
      final rows = await gateway.read(
        'convert_events',
        context: token,
        afterId: after,
        equals: {
          if (query.congregationId != null)
            'congregation_id': query.congregationId!,
        },
      );
      gateway.ensureCurrent(token);
      validatePageOrder(rows, after);
      for (final row in rows) {
        try {
          validateUuid(row['convert_id']);
          if (row['congregation_id'] != null) {
            validateUuid(row['congregation_id']);
          }
          final item = ConvertEvent.fromJson(row);
          if (query.range.contains(item.eventDate)) result.add(item);
        } catch (_) {
          throw const DataFailure('invalid_response');
        }
      }
      if (rows.length < 100) break;
      after = rows.last['id'] as String;
    }
    gateway.ensureCurrent(token);
    return List.unmodifiable(result);
  }

  Future<List<WorshipCount>> conversions(DateRange range) async {
    if (!range.valid) throw const DataFailure('invalid');
    final token = gateway.context;
    final counts = <String, int>{};
    String? after;
    while (true) {
      final rows = await gateway.read(
        'converts',
        context: token,
        afterId: after,
        excludeDeleted: true,
      );
      gateway.ensureCurrent(token);
      validatePageOrder(rows, after);
      for (final row in rows) {
        try {
          final date = DateOnly.parse(row['conversion_date'] as String);
          final type = row['worship_type'] as String?;
          if (range.contains(date)) {
            final name = type == null || type.isEmpty ? 'Não informado' : type;
            counts[name] = (counts[name] ?? 0) + 1;
          }
        } catch (_) {
          throw const DataFailure('invalid_response');
        }
      }
      if (rows.length < 100) break;
      after = rows.last['id'] as String;
    }
    final result = counts.entries
        .map((e) => WorshipCount(e.key, e.value))
        .toList();
    result.sort((a, b) => b.count.compareTo(a.count));
    gateway.ensureCurrent(token);
    return List.unmodifiable(result);
  }
}
