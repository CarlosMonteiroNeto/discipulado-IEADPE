import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/reports/reports_repository.dart';

String id(int n) => '10000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';

class RowsGateway implements Gateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  final calls = <String>[];
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async {
    ensureCurrent(context);
    calls.add(table);
    final rows = List.generate(
      1205,
      (i) => <String, dynamic>{
        'id': id(i + 1),
        'convert_id': id(9999),
        'convert_name': 'João $i',
        'congregation_id': id(i.isEven ? 9998 : 9997),
        'event_type': 'visit',
        'event_date': i == 0
            ? '2026-10-01'
            : i == 1204
            ? '2026-10-31'
            : '2026-10-15',
        'done_by_email': 'ação@example.test',
      },
    );
    return rows
        .where(
          (r) =>
              (afterId == null || (r['id'] as String).compareTo(afterId) > 0) &&
              equals.entries.every((e) => r[e.key] == e.value),
        )
        .take(100)
        .toList();
  }

  @override
  Future<MutationResult<String>> command(
    String c,
    String o,
    Map<String, Object?> p,
  ) => throw UnimplementedError();
}

void main() {
  test(
    'events traverses 1205 rows without a 1000 cap and applies inclusive dates',
    () async {
      final g = RowsGateway();
      final r = ReportsRepository(g);
      final all = await r.events(
        EventQuery(
          range: DateRange(
            start: DateOnly(2026, 10, 1),
            end: DateOnly(2026, 10, 31),
          ),
        ),
      );
      expect(all.length, 1205);
      expect(g.calls.length, 13);
      expect(all.first.convertName, 'João 0');
      final narrowed = await r.events(
        EventQuery(
          range: DateRange(
            start: DateOnly(2026, 10, 15),
            end: DateOnly(2026, 10, 15),
          ),
          congregationId: id(9998),
        ),
      );
      expect(narrowed.length, 601);
      expect(narrowed.every((e) => e.congregationId == id(9998)), isTrue);
    },
  );
}
