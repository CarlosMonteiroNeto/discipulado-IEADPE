import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('import and zero serialize in both transaction orders', () async {
    await runDatabaseScenario(
      'import_test.sql',
      extraArguments: ['--import-concurrency'],
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('authorized resumable import preserves history and guards', () async {
    await runDatabaseScenario('import_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
