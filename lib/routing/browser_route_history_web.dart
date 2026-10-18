import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_route_history.dart';

BrowserRouteHistory createBrowserRouteHistory() => _WebBrowserRouteHistory();

class _WebBrowserRouteHistory implements BrowserRouteHistory {
  void Function(String path)? _onPop;
  web.EventListener? _listener;

  @override
  String? get currentPath => web.window.location.pathname;

  @override
  void listen(void Function(String path) onPop) {
    _onPop = onPop;
    _listener ??= ((web.Event _) {
      _onPop?.call(web.window.location.pathname);
    }).toJS;
    web.window.addEventListener('popstate', _listener);
  }

  @override
  void push(String path) => web.window.history.pushState(null, '', path);

  @override
  void replace(String path) => web.window.history.replaceState(null, '', path);

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) {
      web.window.removeEventListener('popstate', listener);
    }
    _onPop = null;
    _listener = null;
  }
}
