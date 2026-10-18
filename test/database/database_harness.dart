import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<void> runDatabaseScenario(
  String scenario, {
  List<String> extraArguments = const [],
}) async {
  final result = await Process.run(Platform.environment['PYTHON'] ?? 'python', [
    'scripts/test_database.py',
    scenario,
    ...extraArguments,
  ]);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}
