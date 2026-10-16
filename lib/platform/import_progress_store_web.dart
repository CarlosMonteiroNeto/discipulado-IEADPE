import 'dart:js_interop';

import '../features/backup/backup_repository.dart';
import '../data/supabase_gateway.dart';

@JS('localStorage')
external _Storage get _storage;

@JS()
extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

class PlatformImportProgressStore implements ImportProgressStore {
  String _key(String key) => 'ieadpe.import.v1.$key';
  @override
  Future<String?> read(String key) async {
    try {
      return _storage.getItem(_key(key));
    } catch (_) {
      throw const DataFailure('unavailable');
    }
  }

  @override
  Future<void> write(String key, String operationId) async {
    try {
      _storage.setItem(_key(key), operationId);
    } catch (_) {
      throw const DataFailure('unavailable');
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      _storage.removeItem(_key(key));
    } catch (_) {
      throw const DataFailure('unavailable');
    }
  }
}
