import 'browser_route_history.dart';

BrowserRouteHistory createBrowserRouteHistory() => _NoopBrowserRouteHistory();

class _NoopBrowserRouteHistory implements BrowserRouteHistory {
  @override
  String? get currentPath => null;

  @override
  void listen(void Function(String path) onPop) {}
  @override
  void push(String path) {}
  @override
  void replace(String path) {}
  @override
  void dispose() {}
}
