import 'dart:async';
import 'dart:html' as html;

import 'browser_route_history.dart';

BrowserRouteHistory createBrowserRouteHistory() => _WebBrowserRouteHistory();

class _WebBrowserRouteHistory implements BrowserRouteHistory {
  StreamSubscription<html.PopStateEvent>? _subscription;
  void Function(String path)? _onPop;

  @override
  String? get currentPath => html.window.location.pathname;

  @override
  void listen(void Function(String path) onPop) {
    _onPop = onPop;
    _subscription ??= html.window.onPopState.listen((_) {
      _onPop?.call(html.window.location.pathname ?? '/');
    });
  }

  @override
  void push(String path) => html.window.history.pushState(null, '', path);

  @override
  void replace(String path) => html.window.history.replaceState(null, '', path);

  @override
  void dispose() {
    _onPop = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
