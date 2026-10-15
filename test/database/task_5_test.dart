import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('convert commands enforce transactional registration and scope', () async {
    await runDatabaseScenario('convert_commands_test.sql');
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('create and zero confirmation serialize in both commit orders', () async {
    await runDatabaseScenario(
      'convert_commands_test.sql',
      extraArguments: ['--convert-concurrency'],
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
