import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activation package records the exact forward sequence and no hosted effects', () {
    final package = jsonDecode(
      File('docs/verification/ministry-corrective-activation-package.md')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(package['target_project_ref'], isNotEmpty);
    expect(package['migration_sequence'], hasLength(16));
    expect(
      package['migration_sequence'].last['filename'],
      '202610200006_attendance_roster_preview.sql',
    );
    expect(package['hosted_effects'], {
      'inventory_performed': false,
      'migration_applied': false,
      'ledger_repaired': false,
    });
    expect(package['legacy_firebase']['status'], 'BLOCKED');
    expect(package['android_artifact']['status'], 'BLOCKED');
  });

  test('Python CLI contracts pass', () async {
    final result = await Process.run('python3', [
      '-m',
      'unittest',
      'discover',
      '-s',
      'scripts',
      '-p',
      'test_hosted_upgrade.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
