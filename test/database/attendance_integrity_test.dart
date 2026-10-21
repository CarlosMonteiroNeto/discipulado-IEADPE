import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test(
    'finalized attendance is immutable and replacements are linked',
    () async {
      await runDatabaseScenario('attendance_integrity_test.sql');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
