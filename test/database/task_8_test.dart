import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('private photo protocol and Storage RLS', () async {
    await runDatabaseScenario('photos_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
