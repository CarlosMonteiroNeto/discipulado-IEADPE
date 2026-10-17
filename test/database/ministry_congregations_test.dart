import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test(
    'ministry supervisors receive only a bounded active congregation picker',
    () async {
      await runDatabaseScenario('ministry_congregations_test.sql');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
