import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'actual Android writer rejects null streams and write or close failures',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'ieadpe-export-writer-',
      );
      try {
        final compile = await Process.run('javac', [
          '-d',
          dir.path,
          'android/app/src/main/java/br/org/ieadpe/ieadpe_converts/ExportWriter.java',
          'test/platform/fixtures/ExportWriterHarness.java',
        ]);
        expect(
          compile.exitCode,
          0,
          reason: '${compile.stdout}\n${compile.stderr}',
        );
        final run = await Process.run('java', [
          '-cp',
          dir.path,
          'ExportWriterHarness',
        ]);
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
