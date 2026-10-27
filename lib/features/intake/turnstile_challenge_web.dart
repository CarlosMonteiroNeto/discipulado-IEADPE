import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import 'turnstile_challenge.dart';

@JS('window.turnstile')
external _TurnstileApi? get _turnstile;

@JS()
@staticInterop
class _TurnstileApi {}

extension _TurnstileApiOperations on _TurnstileApi {
  external JSString render(
    web.HTMLElement container,
    _TurnstileOptions options,
  );
  external void reset(JSString widgetId);
  external void remove(JSString widgetId);
}

@JS()
@anonymous
extension type _TurnstileOptions._(JSObject _) implements JSObject {
  external factory _TurnstileOptions({
    required String sitekey,
    required String action,
    required JSFunction callback,
    required String theme,
  });
}

TurnstileChallenge createTurnstileChallenge(String siteKey) =>
    TurnstileChallengeWeb(siteKey);

final class TurnstileChallengeWeb implements TurnstileChallenge {
  TurnstileChallengeWeb(this.siteKey) {
    _viewType = 'public-intake-turnstile-${const Uuid().v4()}';
    final registered = ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) {
        final element = web.HTMLDivElement();
        unawaited(_render(element));
        return element;
      },
    );
    if (!registered) _renderFailure = StateError('Turnstile view unavailable');
  }

  final String siteKey;
  late final String _viewType;
  String? _widgetId;
  String? _token;
  StateError? _renderFailure;
  Completer<String>? _pending;
  bool _disposed = false;

  @override
  bool get isSupported => siteKey.trim().isNotEmpty;

  @override
  Widget get view => isSupported
      ? SizedBox(
          width: 320,
          height: 78,
          child: HtmlElementView(viewType: _viewType),
        )
      : const Text('A verificação de segurança não foi configurada.');

  Future<void> _ensureApi() async {
    if (_turnstile != null) return;
    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
      ..async = true;
    script.addEventListener(
      'load',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('Turnstile script unavailable'));
        }
      }).toJS,
    );
    web.document.head!.appendChild(script);
    await completer.future.timeout(const Duration(seconds: 20));
    if (_turnstile == null) throw StateError('Turnstile API unavailable');
  }

  Future<void> _render(web.HTMLDivElement element) async {
    try {
      if (!isSupported) throw StateError('Turnstile site key unavailable');
      await _ensureApi();
      if (_disposed) return;
      final callback = ((JSString value) => _deliverToken(value.toDart)).toJS;
      _widgetId = _turnstile!
          .render(
            element,
            _TurnstileOptions(
              sitekey: siteKey,
              action: 'public_intake',
              callback: callback,
              theme: 'light',
            ),
          )
          .toDart;
    } catch (_) {
      _renderFailure = StateError('Turnstile could not be loaded');
      final pending = _pending;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(_renderFailure!);
      }
    }
  }

  void _deliverToken(String value) {
    if (_disposed || value.trim().isEmpty) return;
    final pending = _pending;
    if (pending == null) {
      _token = value;
    } else if (!pending.isCompleted) {
      _pending = null;
      pending.complete(value);
    }
  }

  @override
  Future<String> acquireToken() async {
    if (!isSupported) {
      throw UnsupportedError('Turnstile is not configured');
    }
    if (_disposed) throw StateError('Turnstile challenge was disposed');
    if (_renderFailure != null) throw _renderFailure!;
    final token = _token;
    if (token != null) {
      _token = null;
      return token;
    }
    final pending = Completer<String>();
    _pending = pending;
    return pending.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        if (identical(_pending, pending)) _pending = null;
        throw TimeoutException('Turnstile verification timed out');
      },
    );
  }

  @override
  void reset() {
    _token = null;
    final widgetId = _widgetId;
    final api = _turnstile;
    if (widgetId != null && api != null && !_disposed) {
      api.reset(widgetId.toJS);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Turnstile challenge was disposed'));
    }
    final widgetId = _widgetId;
    final api = _turnstile;
    if (widgetId != null && api != null) api.remove(widgetId.toJS);
    _token = null;
  }
}
