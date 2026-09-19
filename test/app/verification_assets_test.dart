/// Task 13 acceptance: the reproducible verification entry points, browser
/// metadata, runbook and verification report (S01, S12, S13, S14).
///
/// These are artifact contracts: they fail when a required entry point, its
/// cross-ecosystem commands, or the documented evidence is missing or emptied.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

const List<String> _verifyCommands = <String>[
  'flutter analyze',
  'flutter test',
  'flutter build web',
  'npm run build',
  'npm run test',
  'test:emulator',
];

void main() {
  test('tool/verify.sh runs both ecosystems and fails fast', () {
    final String script = _read('tool/verify.sh');
    expect(script, contains('set -e'));
    for (final String command in _verifyCommands) {
      expect(script, contains(command), reason: command);
    }
  });

  test('tool/verify.ps1 runs both ecosystems and fails fast', () {
    final String script = _read('tool/verify.ps1');
    expect(script, contains('ErrorActionPreference'));
    for (final String command in _verifyCommands) {
      expect(script, contains(command), reason: command);
    }
  });

  test('CI invokes the same verification entry point', () {
    final String workflow = _read('.github/workflows/verify.yml');
    expect(workflow, contains('tool/verify'));
    expect(workflow, contains('flutter'));
    expect(workflow, contains('functions'));
  });

  test('local run entry points start emulators explicitly', () {
    for (final String path in <String>[
      'tool/run-local.sh',
      'tool/run-local.ps1',
    ]) {
      final String script = _read(path);
      expect(script, contains('emulators:start'), reason: path);
      expect(script, contains('flutter run'), reason: path);
    }
  });

  test('web shell is pt-BR, noindex and carries the product identity', () {
    final String html = _read('web/index.html');
    expect(html, contains('lang="pt-BR"'));
    expect(html.toLowerCase(), contains('noindex'));
    expect(html, contains('Discipulado IEADPE'));
    expect(html, isNot(contains('A new Flutter project')));
    expect(html, isNot(contains('apiKey')));

    final String manifest = _read('web/manifest.json');
    expect(manifest, contains('Discipulado IEADPE'));
    expect(manifest, contains('#002060'));
    expect(manifest, isNot(contains('A new Flutter project')));
  });

  test('browser integration suite covers the S13 end-to-end flow', () {
    final String test = _read('integration_test/browser_flow_test.dart');
    for (final String topic in <String>[
      'sign-in',
      'homonym',
      'rename',
      'replaceRoleHolder',
      'saveStudent',
      'saveClass',
      'enrollStudent',
      'saveAttendance',
      'getEnrollmentProgress',
      'reload',
      'sign-out',
      'congregation',
    ]) {
      expect(test, contains(topic), reason: topic);
    }
  });

  test(
    'README documents the reproducible runbook without production claims',
    () {
      final String readme = _read('README.md');
      for (final String topic in <String>[
        'emulators:start',
        'first supervisor',
        'synthetic',
        'flutter build web',
        'SPA rewrite',
        'capacity',
        'progress',
        'not deploy',
      ]) {
        expect(readme, contains(topic), reason: topic);
      }
    },
  );

  test('verification report records commands, versions and blocked checks', () {
    final String report = _read('docs/verification.md');
    for (final String topic in <String>[
      'flutter analyze',
      'flutter test',
      'flutter build web',
      'npm run',
      'exit code',
      'Chromium',
      'Firefox',
      'WebKit',
      '360',
      '768',
      '1440',
      '200%',
      'reduced motion',
      'blocked',
    ]) {
      expect(report, contains(topic), reason: topic);
    }
  });
}
