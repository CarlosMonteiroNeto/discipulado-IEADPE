/// Task 13 acceptance: the composed shell, router and not-found page consume
/// `app_theme.dart` tokens and `lib/ui` primitives exclusively (S10, S12).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> _composedFiles = <String>[
  'lib/app/app.dart',
  'lib/app/router.dart',
  'lib/app/navigation.dart',
  'lib/app/not_found_page.dart',
];

void main() {
  test('composed presentation has no hardcoded colors or radii', () {
    for (final String path in _composedFiles) {
      final String source = File(path).readAsStringSync();
      expect(source, isNot(contains('Colors.')), reason: path);
      expect(RegExp(r'Color\(0x').hasMatch(source), isFalse, reason: path);
      expect(
        RegExp(r'BorderRadius\.circular\(').hasMatch(source),
        isFalse,
        reason: path,
      );
    }
  });

  test('the composed pages consume the shared theme and UI primitives', () {
    expect(
      File('lib/app/not_found_page.dart').readAsStringSync(),
      contains('AppTheme.tokensOf'),
    );
    expect(
      File('lib/app/navigation.dart').readAsStringSync(),
      contains('responsive_scaffold.dart'),
    );
    expect(
      File('lib/app/app.dart').readAsStringSync(),
      contains('app_theme.dart'),
    );
  });
}
