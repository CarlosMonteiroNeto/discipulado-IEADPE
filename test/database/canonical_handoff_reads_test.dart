import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test(
    'bounded handoff reads follow canonical identity after person edits',
    () async {
      await runDatabaseScenario('canonical_handoff_reads_test.sql');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
