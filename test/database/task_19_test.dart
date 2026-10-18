import 'package:flutter_test/flutter_test.dart';
import 'database_harness.dart';
void main() {
 test('archive and create/grant serialize and revalidate in both orders', () async {
  await runDatabaseScenario('catalog_test.sql', extraArguments: ['--catalog-concurrency']);
 }, timeout: const Timeout(Duration(minutes: 3)));
}
