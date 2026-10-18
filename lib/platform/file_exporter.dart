import 'dart:typed_data';

import 'file_exporter_native.dart'
    if (dart.library.js_interop) 'file_exporter_web.dart'
    as platform;

enum SaveOutcome { saved, cancelled, failed }

abstract interface class FileExporter {
  Future<SaveOutcome> save(
    String filename,
    Uint8List bytes, {
    void Function()? ensureCurrent,
  });
}

FileExporter createFileExporter({Future<void> Function()? beforeWrite}) =>
    platform.PlatformFileExporter(beforeWrite: beforeWrite);
