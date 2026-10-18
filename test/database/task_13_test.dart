import 'package:flutter_test/flutter_test.dart';

import 'database_harness.dart';

void main() {
  test(
    'catalog commands preserve references and enforce current authority',
    () async {
      await runDatabaseScenario('catalog_test.sql');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
