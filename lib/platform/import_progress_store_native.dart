import 'package:flutter/services.dart';

import '../features/backup/backup_repository.dart';
import '../data/supabase_gateway.dart';

class PlatformImportProgressStore implements ImportProgressStore {
  static const channel = MethodChannel('br.org.ieadpe/import-progress');
  Future<T?> _call<T>(String method, String key, [String? value]) async {
    try {
      return await channel.invokeMethod<T>(method, {
        'key': key,
        'value': ?value,
      });
    } catch (_) {
      throw const DataFailure('unavailable');
    }
  }

  @override
  Future<String?> read(String key) => _call<String>('read', key);
  @override
  Future<void> write(String key, String operationId) async {
    await _call<bool>('write', key, operationId);
  }

  @override
  Future<void> remove(String key) async {
    await _call<bool>('remove', key);
  }
}
