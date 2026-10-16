import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release artifact limits and local static deep-link refresh', () async {
    final result = await Process.run('python', [
      '-m',
      'unittest',
      'discover',
      '-s',
      'scripts',
      '-p',
      'test_release_operations.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test(
    'maintenance eligibility, dry-run and Storage failure contracts',
    () async {
      final result = await Process.run('python', [
        '-m',
        'unittest',
        'discover',
        '-s',
        'scripts',
        '-p',
        'test_photo_cleanup.py',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test(
    'missing operator configuration fails before starting cleanup',
    () async {
      final result = await Process.run(
        'pwsh',
        ['-NoProfile', '-File', 'scripts/maintenance_photos.ps1'],
        environment: {'SUPABASE_URL': '', 'SUPABASE_SERVICE_ROLE_KEY': ''},
      );
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('No request was sent'));
    },
  );
}
