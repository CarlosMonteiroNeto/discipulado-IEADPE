import 'dart:js_interop';
import 'dart:typed_data';

import 'file_exporter.dart';

@JS('window.showSaveFilePicker')
external JSFunction? get _picker;
@JS('window.showSaveFilePicker')
external JSPromise<_Handle> _showPicker(JSObject options);

@JS()
extension type _Handle(JSObject _) implements JSObject {
  external JSPromise<_Writable> createWritable();
}

@JS()
extension type _Writable(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSUint8Array bytes);
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> abort();
}

@JS()
extension type _Failure(JSObject _) implements JSObject {
  external String get name;
}

class PlatformFileExporter implements FileExporter {
  @override
  Future<SaveOutcome> save(
    String filename,
    Uint8List bytes, {
    void Function()? ensureCurrent,
  }) async {
    // Invoke the picker synchronously within the user's click activation.
    if (_picker == null) return SaveOutcome.failed;
    _Writable? stream;
    var destinationChosen = false;
    try {
      ensureCurrent?.call();
      final handle = await _showPicker(
        ({'suggestedName': filename}).jsify()! as JSObject,
      ).toDart;
      destinationChosen = true;
      ensureCurrent?.call();
      stream = await handle.createWritable().toDart;
      ensureCurrent?.call();
      await stream.write(bytes.toJS).toDart;
      ensureCurrent?.call();
      await stream.close().toDart;
      ensureCurrent?.call();
      return SaveOutcome.saved;
    } catch (error) {
      if (stream != null) {
        try {
          await stream.abort().toDart;
        } catch (_) {}
      }
      if (!destinationChosen &&
          error.isA<JSObject>() &&
          _Failure(error as JSObject).name == 'AbortError' &&
          stream == null) {
        return SaveOutcome.cancelled;
      }
      return SaveOutcome.failed;
    }
  }
}
