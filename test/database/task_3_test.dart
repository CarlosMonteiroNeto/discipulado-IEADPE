import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('native PostgreSQL enforces identity and access boundaries', () async {
    await runDatabaseScenario('access_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
