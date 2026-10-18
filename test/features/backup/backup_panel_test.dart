import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:ieadpe_converts/features/backup/backup_codec.dart';

import 'import_test.dart' show sample;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/backup/backup_panel.dart';
import 'package:ieadpe_converts/features/backup/backup_repository.dart';
import 'package:ieadpe_converts/platform/file_exporter.dart';

import 'import_test.dart' show ImportTransport, MemoryProgress;

class Exporter implements FileExporter {
  Uint8List? retained;
  void Function()? guard;
  Completer<SaveOutcome>? pending;
  @override
  Future<SaveOutcome> save(
    String name,
    Uint8List bytes, {
    void Function()? ensureCurrent,
  }) async {
    retained = bytes;
    guard = ensureCurrent;
    return pending == null ? SaveOutcome.saved : pending!.future;
  }
}

final class Picked extends PlatformFile {
  Picked(this.bytes);
  final Uint8List bytes;
  @override
  String get name => 'synthetic.xlsx';
  @override
  Uri get uri => Uri.parse('file:///synthetic.xlsx');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield bytes;
  }
}

class Picker extends FilePickerPlatform {
  PlatformFile? selected;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => selected;
}

class ExportRepository extends BackupRepository {
  ExportRepository(super.gateway, super.store);
  final bytes = Uint8List.fromList([1, 2, 3]);
  @override
  Future<Uint8List> exportBytes() async => bytes;
}

void main() {
  testWidgets(
    'actual codec picker preview requires confirmation before import',
    (tester) async {
      final old = FilePickerPlatform.instance, picker = Picker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = old);
      picker.selected = Picked(
        BackupCodec().encode([sample().rows.first.record]),
      );
      final transport = ImportTransport()..fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupPanel(
              repository: BackupRepository(transport, MemoryProgress()),
              exporter: Exporter(),
              onScopeRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Selecionar arquivo .xlsx'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Synthetic'), findsOneWidget);
      expect(transport.operations, isEmpty);
      await tester.ensureVisible(find.text('Revisar e importar'));
      await tester.tap(find.text('Revisar e importar'));
      await tester.pumpAndSettle();
      expect(transport.operations, isEmpty);
      await tester.ensureVisible(find.text('Confirmar importação'));
      await tester.tap(find.text('Confirmar importação'));
      await tester.pumpAndSettle();
      expect(transport.operations, hasLength(1));
      expect(find.textContaining('Concluído.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unmount clears retained export bytes and rejects chooser write guard',
    (tester) async {
      final saver = Exporter()..pending = Completer<SaveOutcome>();
      final repository = ExportRepository(ImportTransport(), MemoryProgress());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupPanel(
              repository: repository,
              exporter: saver,
              onScopeRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preparar backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Baixar backup'));
      await tester.pump();
      expect(saver.retained, [1, 2, 3]);
      await tester.pumpWidget(const SizedBox());
      expect(saver.retained, [0, 0, 0]);
      expect(saver.guard, throwsA(isA<Exception>()));
      saver.pending!.complete(SaveOutcome.saved);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'backup offers explicit select and prepare actions at 200% text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: BackupPanel(
                repository: BackupRepository(
                  ImportTransport(),
                  MemoryProgress(),
                ),
                exporter: Exporter(),
                onScopeRefresh: () async {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Selecionar arquivo .xlsx'), findsOneWidget);
      expect(find.text('Preparar backup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
