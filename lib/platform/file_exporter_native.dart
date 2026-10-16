import 'package:flutter/services.dart';

import 'file_exporter.dart';

class PlatformFileExporter implements FileExporter {
  static const _channel = MethodChannel('br.org.ieadpe/export');
  @override
  Future<SaveOutcome> save(
    String filename,
    Uint8List bytes, {
    void Function()? ensureCurrent,
  }) async {
    try {
      ensureCurrent?.call();
      final uri = await _channel.invokeMethod<String>('choose', {
        'filename': filename,
      });
      ensureCurrent?.call();
      if (uri == null) return SaveOutcome.cancelled;
      final saved = await _channel.invokeMethod<bool>('write', {
        'uri': uri,
        'bytes': bytes,
      });
      ensureCurrent?.call();
      return saved == true ? SaveOutcome.saved : SaveOutcome.failed;
    } catch (_) {
      try {
        await _channel.invokeMethod<void>('discard');
      } catch (_) {}
      return SaveOutcome.failed;
    }
  }
}
