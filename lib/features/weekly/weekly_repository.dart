import '../../data/supabase_gateway.dart';
import '../../domain/business_calendar.dart';
import '../../domain/models.dart';
import '../../platform/portuguese_sort.dart';
import '../converts/congregation_order.dart';

class WeeklyEntry {
  const WeeklyEntry(this.id, this.name, this.confirmed);
  final String id, name;
  final bool confirmed;
}

class WeeklyOverview {
  WeeklyOverview({
    required this.visible,
    required this.isGlobal,
    this.weekStart,
    List<WeeklyEntry> entries = const [],
  }) : entries = List.unmodifiable(entries);
  final bool visible, isGlobal;
  final DateOnly? weekStart;
  final List<WeeklyEntry> entries;
}

class WeeklyRepository {
  WeeklyRepository(this.gateway, {this.sortNames = sortPortugueseNames});
  final Future<List<String>> Function(List<String>) sortNames;
  final Gateway gateway;
  Future<WeeklyOverview> overview() async {
    final token = gateway.context;
    final transport = gateway;
    if (transport is! ReadRpcGateway) throw const DataFailure('unavailable');
    final entries = <WeeklyEntry>[];
    String? after;
    DateOnly? week;
    bool? isGlobal;
    do {
      gateway.ensureCurrent(token);
      final response = await transport.readRpc(
        'weekly_overview',
        context: token,
        parameters: {'after_id': after, 'expected_week': week?.toString()},
      );
      gateway.ensureCurrent(token);
      try {
        if (response['visible'] is! bool ||
            response['global'] is! bool ||
            response['rows'] is! List) {
          throw const FormatException();
        }
        final rows = (response['rows'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (rows.length > 100) throw const FormatException();
        if (isGlobal != null && isGlobal != response['global']) {
          throw const DataFailure('invalid');
        }
        isGlobal = response['global'] as bool;
        if (!(response['visible'] as bool)) {
          if (after != null ||
              rows.isNotEmpty ||
              response['week_start'] != null) {
            throw const FormatException();
          }
          return WeeklyOverview(visible: false, isGlobal: isGlobal);
        }
        final date = DateOnly.parse(response['week_start'] as String);
        if (date.weekday != DateTime.monday || (week != null && date != week)) {
          throw const DataFailure('invalid');
        }
        week = date;
        validatePageOrder(rows, after);
        for (final row in rows) {
          if (row['name'] is! String ||
              (row['name'] as String).trim().isEmpty ||
              row['confirmed'] is! bool) {
            throw const FormatException();
          }
          entries.add(
            WeeklyEntry(
              row['id'] as String,
              row['name'] as String,
              row['confirmed'] as bool,
            ),
          );
        }
        if (rows.length < 100) break;
        after = rows.last['id'] as String;
      } on DataFailure {
        rethrow;
      } catch (_) {
        throw const DataFailure('invalid_response');
      }
    } while (true);
    final ordered = await orderCongregations(
      entries.map((e) => Congregation(id: e.id, name: e.name)).toList(),
      sortNames: sortNames,
    );
    gateway.ensureCurrent(token);
    final byId = {for (final e in entries) e.id: e};
    return WeeklyOverview(
      visible: true,
      isGlobal: isGlobal,
      weekStart: week,
      entries: ordered.map((c) => byId[c.id]!).toList(),
    );
  }

  Future<MutationResult<String>> confirmZero(
    String congregationId,
    String operationId,
  ) => gateway.command('confirm_zero', operationId, {
    'congregation_id': congregationId,
  });
}
