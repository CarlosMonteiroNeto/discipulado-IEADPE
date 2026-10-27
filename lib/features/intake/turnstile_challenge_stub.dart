import 'package:flutter/widgets.dart';

import 'turnstile_challenge.dart';

TurnstileChallenge createTurnstileChallenge(String siteKey) =>
    UnsupportedTurnstileChallenge();

final class UnsupportedTurnstileChallenge implements TurnstileChallenge {
  @override
  Widget get view => const Text(
    'A verificação de segurança não está disponível neste dispositivo.',
  );

  @override
  bool get isSupported => false;

  @override
  Future<String> acquireToken() => Future.error(
    UnsupportedError('Turnstile is unsupported on this platform'),
  );

  @override
  void reset() {}

  @override
  void dispose() {}
}
