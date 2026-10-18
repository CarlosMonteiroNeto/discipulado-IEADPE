import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/reports/reports_repository.dart';

import '../../data/repositories_test.dart' show fixture, respond, row;

void main() {
  test('conversion grouping traverses all rows includes endpoints and sorts descending', () async {
    final g = await fixture((r) async {
      final after = r.uri.queryParameters['id'];
      final start = after == null ? 1 : int.parse(after.split('-').last) + 1;
      await respond(r, [
        for (var i = start; i <= 1205 && i < start + 100; i++)
          {
            ...row(i),
            'conversion_date': i == 1
                ? '2026-10-01'
                : i == 1205
                ? '2026-10-31'
                : '2026-10-15',
            'worship_type': i.isEven ? 'Culto de ação' : 'Culto de oração',
          },
      ]);
    });
    final data = await ReportsRepository(g).conversions(
      DateRange(start: DateOnly(2026, 10, 1), end: DateOnly(2026, 10, 31)),
    );
    expect(data.map((e) => e.count), [603, 602]);
    expect(data.first.name, 'Culto de oração');
  });
}
