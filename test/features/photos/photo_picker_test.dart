import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/features/photos/photo_picker.dart';

const MethodChannel _pickerChannel = MethodChannel(
  'plugins.flutter.io/image_picker',
);

class _Harness extends StatefulWidget {
  const _Harness({super.key});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  ImageSource? selected;
  bool completed = false;

  Future<void> _choose() async {
    selected = await chooseProfilePhotoSource(context);
    completed = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('choose-source'),
        onPressed: _choose,
        child: const Text('Escolher imagem'),
      ),
    ),
  );
}

Future<(_HarnessState, GlobalKey<_HarnessState>)> _openChooser(
  WidgetTester tester,
) async {
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(MaterialApp(home: _Harness(key: key)));
  await tester.tap(find.byKey(const ValueKey('choose-source')));
  await tester.pumpAndSettle();
  return (key.currentState!, key);
}

Future<Directory> _tempFile(Uint8List bytes) async {
  final directory = await Directory.systemTemp.createTemp('photo-picker-');
  await File('${directory.path}/source.jpg').writeAsBytes(bytes);
  return directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('source chooser distinguishes camera and gallery', (
    tester,
  ) async {
    final (camera, _) = await _openChooser(tester);
    await tester.tap(find.text('Tirar foto com a câmera'));
    await tester.pumpAndSettle();
    expect(camera.completed, isTrue);
    expect(camera.selected, ImageSource.camera);

    final (gallery, _) = await _openChooser(tester);
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();
    expect(gallery.selected, ImageSource.gallery);
  });

  testWidgets('canceling the source chooser returns no selection', (
    tester,
  ) async {
    final (harness, _) = await _openChooser(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(harness.completed, isTrue);
    expect(harness.selected, isNull);
  });

  test(
    'camera and gallery acquisition preserve the selected source bytes',
    () async {
      final directory = await _tempFile(Uint8List.fromList([255, 216, 1, 2]));
      addTearDown(() => directory.delete(recursive: true));
      final sources = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pickerChannel, (call) async {
            if (call.method == 'retrieve') return null;
            sources.add((call.arguments as Map)['source'] as int);
            return '${directory.path}/source.jpg';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_pickerChannel, null),
      );

      expect(await pickProfilePhoto(ImageSource.camera), [255, 216, 1, 2]);
      expect(await pickProfilePhoto(ImageSource.gallery), [255, 216, 1, 2]);
      expect(sources, [ImageSource.camera.index, ImageSource.gallery.index]);
    },
  );

  test('cancel and picker permission denial are safe outcomes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, (call) async {
          if (call.method == 'retrieve') return null;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pickerChannel, null),
    );
    expect(await pickProfilePhoto(ImageSource.gallery), isNull);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, (call) async {
          if (call.method == 'retrieve') return null;
          throw PlatformException(code: 'camera_access_denied');
        });
    await expectLater(
      pickProfilePhoto(ImageSource.camera),
      throwsA(
        isA<DataFailure>().having((error) => error.code, 'code', 'unavailable'),
      ),
    );
  });

  test('picker enforces the existing 20 MiB input ceiling', () async {
    final bytes = Uint8List(20 * 1024 * 1024 + 1);
    final directory = await _tempFile(bytes);
    addTearDown(() => directory.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _pickerChannel,
          (call) async =>
              call.method == 'retrieve' ? null : '${directory.path}/source.jpg',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pickerChannel, null),
    );
    await expectLater(
      pickProfilePhoto(ImageSource.gallery),
      throwsA(
        isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
      ),
    );
  });

  test(
    'Android lost picker data is recovered once before opening a new picker',
    () async {
      final directory = await _tempFile(Uint8List.fromList([255, 216, 7, 8]));
      addTearDown(() => directory.delete(recursive: true));
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var newPickerCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pickerChannel, (call) async {
            if (call.method == 'retrieve') {
              return {'path': '${directory.path}/source.jpg', 'type': 'image'};
            }
            if (call.method == 'pickImage') newPickerCalls++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_pickerChannel, null),
      );

      expect(await pickProfilePhoto(ImageSource.camera), [255, 216, 7, 8]);
      expect(newPickerCalls, 0);
    },
  );
}
