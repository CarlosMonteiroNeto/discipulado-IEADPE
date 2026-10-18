import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test('convert promotion races create one student/link in either commit order', () async {
    await runDatabaseScenario(
      'convert_student_link_test.sql',
      extraArguments: ['--convert-student-concurrency'],
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
