import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('legacy import initializes revision without resetting existing rows',
      () async {
    await runDatabaseScenario('import_revision_compatibility_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
