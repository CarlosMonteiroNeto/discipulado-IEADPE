import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('weekly server window, scopes and counter integrity', () async {
    await runDatabaseScenario('weekly_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
