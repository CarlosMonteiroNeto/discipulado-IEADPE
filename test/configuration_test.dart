import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/configuration.dart';

void main() {
  test('empty build configuration never supplies a fallback backend', () {
    final configuration = Configuration.fromEnvironment();
    expect(configuration.supabaseUrl, isEmpty);
    expect(configuration.supabasePublishableKey, isEmpty);
    expect(configuration.isValid, isFalse);
  });

  test('rejects malformed keys and secret server credentials', () {
    for (final key in [
      '',
      'invalid',
      'sb_secret_synthetic',
      ' sb_publishable_synthetic',
    ]) {
      expect(
        Configuration(
          supabaseUrl: 'https://synthetic.supabase.co',
          supabasePublishableKey: key,
        ).isValid,
        isFalse,
        reason: key,
      );
    }
  });
}
