import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test(
    'student enrollment history is bounded, scoped, and strictly typed',
    () async {
      await runDatabaseScenario('student_enrollment_history_test.sql');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
