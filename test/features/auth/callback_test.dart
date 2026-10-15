import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/auth/auth_repository.dart';

void main() {
  test('trusted callback configuration requires a real host', () {
    expect(
      () => AuthRedirectPolicy(Uri.parse('https:/auth/callback')),
      throwsArgumentError,
    );
  });
  test(
    'callback rejects wrong origin, token fragments and duplicate codes',
    () {
      final policy = AuthRedirectPolicy(
        Uri.parse('https://app.test/auth/callback'),
      );
      expect(
        policy.accepts(Uri.parse('https://app.test/auth/callback?code=abc')),
        isTrue,
      );
      for (final value in [
        'https://evil.test/auth/callback?code=abc',
        'https://app.test/other?code=abc',
        'https://app.test/auth/callback#access_token=abc',
        'https://app.test/auth/callback?code=a&code=b',
        'https://app.test/auth/callback?code=',
      ]) {
        expect(policy.accepts(Uri.parse(value)), isFalse, reason: value);
      }
    },
  );
}
