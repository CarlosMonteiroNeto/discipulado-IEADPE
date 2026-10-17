import 'browser_route_history_stub.dart'
    if (dart.library.html) 'browser_route_history_web.dart'
    as platform;

abstract interface class BrowserRouteHistory {
  String? get currentPath;
  void listen(void Function(String path) onPop);
  void push(String path);
  void replace(String path);
  void dispose();
}

BrowserRouteHistory createBrowserRouteHistory() =>
    platform.createBrowserRouteHistory();
