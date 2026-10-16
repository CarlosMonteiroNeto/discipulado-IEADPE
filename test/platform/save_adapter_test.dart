import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:ieadpe_converts/platform/file_exporter.dart';
import 'package:ieadpe_converts/platform/file_exporter_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('br.org.ieadpe/export');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('native chooser waits for fresh scope before writing and retains original token', () async {
    final validation = Completer<void>();
    final writes = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      writes.add(call.method);
      return call.method == 'choose' ? 'content://documents/synthetic' : true;
    });
    final save = PlatformFileExporter(beforeWrite: () => validation.future)
        .save('synthetic.xlsx', Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);
    expect(writes, ['choose']);
    validation.complete();
    expect(await save, SaveOutcome.saved);
    expect(writes, ['choose', 'write']);
  });
  test(
    'save separates chooser cancellation completed write and failure',
    () async {
      Object? response;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        if (call.method == 'choose') {
          expect((call.arguments as Map).containsKey('bytes'), isFalse);
          return response;
        }
        if (response is PlatformException) throw response;
        return true;
      });
      final exporter = PlatformFileExporter();
      expect(
        await exporter.save('ação.xlsx', Uint8List.fromList([1])),
        SaveOutcome.cancelled,
      );
      response = 'content://documents/ação.xlsx';
      expect(
        await exporter.save('ação.xlsx', Uint8List.fromList([1])),
        SaveOutcome.saved,
      );
      expect(methods, ['choose', 'choose', 'write']);
      response = PlatformException(code: 'write_failed');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'choose') return 'content://documents/2';
        throw response!;
      });
      expect(
        await exporter.save('ação.xlsx', Uint8List.fromList([1])),
        SaveOutcome.failed,
      );
    },
  );
  test(
    'invalidation while chooser open prevents handing bytes to native writer',
    () async {
      var current = true;
      var writes = 0;
      var chose = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'choose') {
          chose = true;
          current = false;
          return 'content://documents/3';
        }
        if (call.method == 'write') writes++;
        return true;
      });
      final outcome = await PlatformFileExporter().save(
        'a.xlsx',
        Uint8List.fromList([1, 2]),
        ensureCurrent: () {
          if (!current) throw StateError('obsolete');
        },
      );
      expect(chose, isTrue);
      expect(writes, 0);
      expect(outcome, SaveOutcome.failed);
    },
  );
}
