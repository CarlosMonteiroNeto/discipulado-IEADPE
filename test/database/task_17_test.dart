import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('feedback enforces current authorization and receipts', () async {
    await runDatabaseScenario('feedback_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
