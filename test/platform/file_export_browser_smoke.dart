import 'dart:js_interop';
import 'dart:typed_data';

import 'package:ieadpe_converts/platform/file_exporter.dart';
import 'package:ieadpe_converts/platform/file_exporter_web.dart';

@JS('eval')
external JSAny? evaluate(JSString source);
void js(String source) => evaluate(source.toJS);

@JS('document.body.textContent')
external set resultText(JSString value);
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  try {
    final saver = PlatformFileExporter();
    js('delete window.showSaveFilePicker;');
    check(
      await saver.save('a.xlsx', Uint8List(1)) == SaveOutcome.failed,
      'unsupported',
    );
    js(
      'window.showSaveFilePicker = async () => { throw new DOMException("Cancelled", "AbortError"); };',
    );
    check(
      await saver.save('a.xlsx', Uint8List(1)) == SaveOutcome.cancelled,
      'cancelled',
    );
    js(
      'window.showSaveFilePicker = async () => ({createWritable: async () => {throw new DOMException("Writable aborted", "AbortError");}});',
    );
    check(
      await saver.save('a.xlsx', Uint8List(1)) == SaveOutcome.failed,
      'writable AbortError must fail, not mean picker cancellation',
    );
    js(
      'window.savedBytes = []; window.saveClosed = false; window.showSaveFilePicker = async () => ({createWritable: async () => ({write: async bytes => {window.savedBytes = Array.from(bytes);},close: async () => {window.saveClosed=true;},abort: async () => {}})});',
    );
    check(
      await saver.save('ação.xlsx', Uint8List.fromList([65, 66])) ==
          SaveOutcome.saved,
      'saved',
    );
    check(
      evaluate('JSON.stringify(window.savedBytes)'.toJS).dartify() == '[65,66]',
      'bytes',
    );
    check(evaluate('window.saveClosed'.toJS).dartify() == true, 'close');
    js(
      'window.showSaveFilePicker = async () => ({createWritable: async () => ({write: async bytes => {throw Error("write failure");},close: async () => {},abort: async () => {}})});',
    );
    check(
      await saver.save('a.xlsx', Uint8List(1)) == SaveOutcome.failed,
      'write failure',
    );
    js(
      'window.showSaveFilePicker = async () => ({createWritable: async () => ({write: async bytes => {},close: async () => {throw Error("close failure");},abort: async () => {}})});',
    );
    check(
      await saver.save('a.xlsx', Uint8List(1)) == SaveOutcome.failed,
      'close failure',
    );
    var calls = 0;
    js(
      'window.writes=0;window.showSaveFilePicker = async () => ({createWritable: async () => ({write: async bytes => {window.writes++;},close: async () => {},abort: async () => {}})});',
    );
    final outcome = await saver.save(
      'a.xlsx',
      Uint8List(1),
      ensureCurrent: () {
        calls++;
        if (calls > 1) throw StateError('stale');
      },
    );
    check(
      outcome == SaveOutcome.failed &&
          calls == 2 &&
          evaluate('window.writes'.toJS).dartify() == 0,
      'protected chooser',
    );
    calls = 0;
    js(
      'window.saveClosed=false;window.aborted=false;window.showSaveFilePicker=async()=>({createWritable:async()=>({write:async bytes=>{},close:async()=>{window.saveClosed=true;},abort:async()=>{window.aborted=true;}})});',
    );
    final afterWrite = await saver.save(
      'a.xlsx',
      Uint8List(1),
      ensureCurrent: () {
        calls++;
        if (calls >= 4) throw StateError('stale after write');
      },
    );
    check(
      afterWrite == SaveOutcome.failed &&
          evaluate('window.saveClosed'.toJS).dartify() == false &&
          evaluate('window.aborted'.toJS).dartify() == true,
      'invalidation after write must abort before close',
    );
    resultText = 'PASS: production web export adapter protocol; picker and writable fixtures only'
        .toJS;
  } catch (error) {
    resultText = 'FAIL: $error'.toJS;
  }
}
