import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/reports/reports_repository.dart';

import '../../data/repositories_test.dart' show fixture, respond, id;

void main() {
  test(
    'actual SDK events allowlist traverses 1205 ordered immutable rows',
    () async {
      var calls = 0;
      final gateway = await fixture((r) async {
        calls++;
        expect(r.uri.path, '/rest/v1/convert_events');
        expect(r.uri.queryParameters['limit'], '100');
        expect(r.uri.queryParameters['order'], 'id.asc.nullslast');
        final after = r.uri.queryParameters['id'];
        final first = after == null ? 1 : int.parse(after.split('-').last) + 1;
        await respond(r, [
          for (var i = first; i <= 1205 && i < first + 100; i++)
            {
              'id': id(i),
              'convert_id': id(9999),
              'convert_name': 'João $i',
              'congregation_id': null,
              'event_type': 'visit',
              'event_date': '2026-10-15',
              'done_by_email': 'ação@example.test',
            },
        ]);
      });
      final result = await ReportsRepository(gateway)
          .events(const EventQuery());
      expect(result.length, 1205);
      expect(calls, 13);
      expect(result.last.convertName, 'João 1205');
    },
  );
}
