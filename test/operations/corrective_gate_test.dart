import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runPythonSuite(String pattern) async {
  ProcessException? lastError;
  for (final executable in ['python3', 'python']) {
    try {
      return await Process.run(executable, [
        '-m',
        'unittest',
        'discover',
        '-s',
        'scripts',
        '-p',
        pattern,
      ]);
    } on ProcessException catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? const ProcessException('python3', []);
}

void main() {
  test('shared verification manifest validation contracts pass', () async {
    final result = await _runPythonSuite('test_verification_cases.py');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  // Serial Bash and PowerShell gate harnesses exceed the default test timeout.
  test('portable unified gate contracts pass', () async {
    final result = await _runPythonSuite('test_unified_gate.py');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, timeout: Timeout(Duration(minutes: 5)));
}
