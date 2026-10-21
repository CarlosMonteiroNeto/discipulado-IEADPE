import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/auth/session_display_name.dart';

void main() {
  test('uses trimmed full name before trimmed name', () {
    expect(
      sessionDisplayName({'full_name': '  Maria Silva  ', 'name': 'Maria'}),
      'Maria Silva',
    );
    expect(sessionDisplayName({'full_name': '  ', 'name': ' Maria '}), 'Maria');
  });

  test('uses neutral greeting for absent, malformed, or blank metadata', () {
    expect(sessionDisplayName(null), isNull);
    expect(sessionDisplayName({'full_name': 42, 'name': false}), isNull);
    expect(sessionDisplayName({'full_name': ' ', 'name': null}), isNull);
  });
}
