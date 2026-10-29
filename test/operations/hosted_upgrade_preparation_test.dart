import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activation package records the exact forward sequence and verified production activation', () {
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
      'inventory_performed': true,
      'migration_applied': true,
      'ledger_repaired': true,
    });
    expect(package['hosted_activation'], 'APPLIED_AND_VERIFIED');
    expect(package['backup_restore']['status'], 'PASS');
    expect(package['production_activation']['ledger_last'], '202610200006');
    expect(package['production_activation']['forward_migrations_applied'], 16);
    expect(package['production_activation']['errors'], 0);
    expect(
      package['legacy_firebase']['status'],
      'OUT_OF_SCOPE_OWNER_ATTESTED_ABSENCE',
    );
    expect(
      package['legacy_firebase']['owner_attestation']['attested_at'],
      '2026-10-22',
    );
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
  }, timeout: Timeout(Duration(minutes: 2)));
}
