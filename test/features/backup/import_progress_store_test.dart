import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/platform/import_progress_store_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native progress transport retains identifiers only across write read and remove', () async {
    const channel = MethodChannel('br.org.ieadpe/import-progress');
    final values = <String, String>{};
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final args = Map<String, dynamic>.from(call.arguments as Map);
          expect(args.keys, everyElement(isIn(['key', 'value'])));
          if (call.method == 'read') return values[args['key']];
          if (call.method == 'write') {
            values[args['key'] as String] = args['value'] as String;
            return true;
          }
          values.remove(args['key']);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const key =
        '11111111-1111-1111-1111-111111111111:22222222-2222-2222-2222-222222222222';
    const operation = '33333333-3333-3333-3333-333333333333';
    await PlatformImportProgressStore().write(key, operation);
    expect(await PlatformImportProgressStore().read(key), operation);
    await PlatformImportProgressStore().remove(key);
    expect(await PlatformImportProgressStore().read(key), isNull);
    expect(calls.length, 4);
  });
}
