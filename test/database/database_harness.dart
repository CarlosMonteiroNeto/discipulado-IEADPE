import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<void> runDatabaseScenario(String scenario) async {
  final result = await Process.run(Platform.environment['PYTHON'] ?? 'python', [
    'scripts/test_database.py',
    scenario,
  ]);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}
