import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('ministry academic races preserve capacity and frozen roster order', () async {
    await runDatabaseScenario(
      'ministry_academic_test.sql',
      extraArguments: ['--ministry-academic-concurrency'],
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
