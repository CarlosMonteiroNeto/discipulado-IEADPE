import 'package:flutter/widgets.dart';

import 'turnstile_challenge_stub.dart'
    if (dart.library.js_interop) 'turnstile_challenge_web.dart'
    as platform;

const publicTurnstileSiteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');

typedef TurnstileChallengeFactory = TurnstileChallenge Function();

abstract interface class TurnstileChallenge {
  Widget get view;
  bool get isSupported;
  Future<String> acquireToken();
  void reset();
  void dispose();
}

TurnstileChallenge createTurnstileChallenge({
  String siteKey = publicTurnstileSiteKey,
}) => platform.createTurnstileChallenge(siteKey);
