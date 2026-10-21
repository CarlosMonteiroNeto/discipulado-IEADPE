import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('first attendance read previews eligible rows without freezing and first save freezes them', () async {
    await runDatabaseScenario('attendance_roster_preview_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
