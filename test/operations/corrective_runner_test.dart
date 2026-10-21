import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _runRunnerContracts() async {
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
        'test_unified_*.py',
      ]);
    } on ProcessException catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? const ProcessException('python3', []);
}

void main() {
  // Windows runs both shell-gate harnesses serially and takes over two minutes.
  test('portable browser runner and gate contracts pass', () async {
    final result = await _runRunnerContracts();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, timeout: Timeout(Duration(minutes: 5)));
}
