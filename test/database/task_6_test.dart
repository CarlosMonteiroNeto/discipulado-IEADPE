import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test(
    'lifecycle commands enforce current policy and immutable snapshots',
    () async {
      await runDatabaseScenario('lifecycle_test.sql');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'lifecycle retries, terminals and revocation serialize across sessions',
    () async {
      await runDatabaseScenario(
        'lifecycle_test.sql',
        extraArguments: ['--lifecycle-concurrency'],
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
