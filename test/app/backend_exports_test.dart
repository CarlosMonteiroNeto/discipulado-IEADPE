/// Task 13 acceptance: the backend composition point exports the complete S11
/// callable set exactly once and never exposes a trusted provisioning endpoint
/// (S04, S11).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The exact S11 callable names.
const List<String> _s11Callables = <String>[
  'saveCongregation',
  'setCongregationArchived',
  'saveContact',
  'replaceRoleHolder',
  'setContactArchived',
  'saveStudent',
  'setStudentArchived',
  'saveClass',
  'setClassStatus',
  'enrollStudent',
  'closeEnrollment',
  'createSession',
  'saveAttendance',
  'cancelSession',
  'listClassStudents',
  'getSessionAttendance',
  'getEnrollmentProgress',
  'getOverview',
  'listPendingSessions',
];

String _indexSource() => File('functions/src/index.ts').readAsStringSync();

void main() {
  test('backend index exports the S11 callable set exactly once', () {
    final String source = _indexSource();
    final List<String> exported = RegExp(r'export const (\w+)\s*=')
        .allMatches(source)
        .map((RegExpMatch match) => match.group(1)!)
        .toList(growable: false);

    expect(exported.toSet(), _s11Callables.toSet());
    expect(exported.length, _s11Callables.length);
  });

  test('backend index registers handlers on the callable factory', () {
    final String source = _indexSource();
    for (final String operation in _s11Callables) {
      expect(source, contains('export const $operation ='), reason: operation);
    }
    // Every export is the result of calling its feature handler factory.
    final int registered = RegExp(r'export const \w+ = \w+Callable\(')
        .allMatches(source)
        .length;
    expect(registered, _s11Callables.length);
  });

  test('backend index exposes no provisioning endpoint', () {
    final String source = _indexSource();
    expect(source.toLowerCase(), isNot(contains('provisionaccess')));
    expect(source.toLowerCase(), isNot(contains('provision-access')));
    expect(RegExp('export const \\w*[Pp]rovision').hasMatch(source), isFalse);
  });
}
