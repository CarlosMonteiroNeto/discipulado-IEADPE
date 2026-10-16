import 'dart:io';

import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/backup/backup_codec.dart';
import 'package:ieadpe_converts/features/backup/backup_models.dart';

const headers = [
  'id_interno',
  'nome',
  'congregacao',
  'endereco',
  'ponto_referencia',
  'telefone',
  'idade',
  'genero',
  'data_conversao',
  'tipo_culto',
  'visitas',
  'em_discipulado',
  'discipulado_concluido',
  'se_desviou',
];
Uint8List fixture(
  List<List<String>> rows, {
  String? cell,
  String? version,
  bool directories = false,
}) {
  final a = Archive();
  if (directories) a.addFile(ArchiveFile.directory("xl/"));
  void add(String p, String s) =>
      a.addFile(ArchiveFile.bytes(p, utf8.encode(s)));
  add('[Content_Types].xml', '<Types/>');
  add(
    'xl/workbook.xml',
    '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Convertidos" r:id="rId1"/></sheets>${version == null ? '' : '<definedNames><definedName name="ieadpe_backup_version">$version</definedName></definedNames>'}</workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
  );
  add(
    'xl/worksheets/sheet1.xml',
    '<worksheet><sheetData>${rows.map((r) => '<row>${r.map((v) => '<c t="inlineStr"><is><t>${const HtmlEscape().convert(v)}</t></is></c>').join()}</row>').join()}${cell ?? ''}</sheetData></worksheet>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

List<String> row() => [
  'legacy-1',
  '=literal',
  'Central',
  '',
  '',
  '00123',
  '0',
  'Masculino',
  '2026-01-01',
  'Culto',
  '2',
  'Sim',
  'Não',
  'Não',
];
void main() {
  for (final relationship in [
    '<Relationships><Relationship Id="rId1" Target="../outside.xml"/></Relationships>',
    '<Relationships><Relationship Id="rId1" TargetMode="External" Target="https://invalid.example/file"/></Relationships>',
    '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
  ]) {
    test(
      'malformed worksheet relationship rejects without following targets ${relationship.length}',
      () {
        final archive = ZipDecoder().decodeBytes(fixture([headers, row()]));
        archive.removeFile(archive.findFile('xl/_rels/workbook.xml.rels')!);
        archive.addFile(
          ArchiveFile.bytes(
            'xl/_rels/workbook.xml.rels',
            utf8.encode(relationship),
          ),
        );
        expect(
          () => BackupCodec().decode(
            Uint8List.fromList(ZipEncoder().encode(archive)),
          ),
          throwsA(isA<BackupFormatException>()),
        );
      },
    );
  }
  test('locked archive stops an understated bomb before forwarding oversized output', () {
    final decoder = ZipDecoder();
    decoder.decodeBytes(
      File('test/features/backup/fixtures/understated-bomb.zip')
          .readAsBytesSync(),
    );
    final output = OutputMemoryStream(size: 1);
    expect(
      () => decoder.directory.fileHeaders.single.file!.decompress(output),
      throwsA(isA<ArchiveException>()),
    );
    expect(output.length, lessThanOrEqualTo(1));
  });
  test('duplicate ZIP paths reject deterministically', () {
    expect(
      () => BackupCodec().decode(
        File('test/features/backup/fixtures/duplicate-entry.zip')
            .readAsBytesSync(),
      ),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.code,
          'code',
          'invalid_zip',
        ),
      ),
    );
  });
  test('supports standard XLSX directory entries', () {
    expect(
      BackupCodec().decode(fixture([headers, row()], directories: true)).rows,
      hasLength(1),
    );
  });
  test(
    'rejects ZIP comments to keep one authoritative directory interpretation',
    () {
      final b = fixture([headers, row()]);
      final withComment = Uint8List.fromList([...b, ...List.filled(24, 65)]);
      ByteData.sublistView(withComment)
          .setUint16(b.length - 2, 24, Endian.little);
      expect(() => BackupCodec().decode(withComment), throwsFormatException);
    },
  );
  test('legacy data cannot silently discard v2 columns', () {
    expect(
      () => BackupCodec().decode(
        fixture([
          headers,
          [...row(), '2026-02-01'],
        ]),
      ),
      throwsFormatException,
    );
  });
  test('parses independently generated openpyxl v2 dates and numeric zero', () {
    final p = BackupCodec().decode(
      File('test/features/backup/fixtures/openpyxl-v2.xlsx').readAsBytesSync(),
    );
    expect(p.version, 2);
    expect(p.diagnostics, isEmpty);
    expect(p.rows.single.record.age, 0);
    expect(p.rows.single.record.gender, Gender.female);
    expect(p.rows.single.record.lastVisitDate, DateOnly(2026, 2, 1));
    expect(p.rows.single.record.discipleshipStartDate, DateOnly(2026, 1, 5));
    expect(p.rows.single.record.wasVisitedOnce, isTrue);
  });
  for (final name in [
    'expanded-bomb',
    'declared-bomb',
    'aggregate-bomb',
    'understated-bomb',
  ]) {
    test('rejects independent $name before unbounded inflation', () {
      expect(
        () => BackupCodec().decode(
          File('test/features/backup/fixtures/$name.zip').readAsBytesSync(),
        ),
        throwsFormatException,
      );
    });
  }
  test(
    'exports typed text with v2 metadata and dates without binary photos',
    () {
      final codec = BackupCodec(congregationNames: {'cat-id': 'Central'});
      final r = ConvertRecord(
        id: 'db-id',
        internalId: 'source-key',
        name: '=1+1',
        landmark: 'Reference',
        gender: Gender.male,
        conversionDate: DateOnly(2026, 1, 1),
        worshipType: 'Culto',
        age: 0,
        phone: '00123',
        congregationId: 'cat-id',
        lastVisitDate: DateOnly(2026, 2, 1),
        discipleshipStartDate: DateOnly(2026, 1, 5),
        wasVisitedOnce: true,
        photoUrl: 'private-photo',
      );
      final bytes = codec.encode([r]);
      final p = codec.decode(bytes);
      expect(p.version, 2);
      expect(p.rows.single.record.age, 0);
      expect(p.rows.single.record.name, '=1+1');
      expect(p.rows.single.record.phone, '00123');
      expect(p.rows.single.record.internalId, 'source-key');
      expect(p.rows.single.record.discipleshipStartDate, DateOnly(2026, 1, 5));
      expect(p.rows.single.record.photoUrl, isNull);
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        archive.findFile('xl/worksheets/sheet1.xml')!.readBytes()!,
      );
      expect(xml, contains('t="inlineStr"'));
      expect(xml, isNot(contains('<f>')));
      expect(xml, isNot(contains('private-photo')));
      final exportPath = Platform.environment['BACKUP_CODEC_EXPORT_PATH'];
      if (exportPath != null) File(exportPath).writeAsBytesSync(bytes);
      expect(() => BackupCodec().encode([r]), throwsFormatException);
    },
  );
  test('does not silently overwrite duplicate coordinates', () {
    expect(
      () => BackupCodec().decode(
        fixture(
          [headers],
          cell: '<row><c r="A2" t="inlineStr"><is><t>one</t></is></c><c r="A2" t="inlineStr"><is><t>two</t></is></c></row>',
        ),
      ),
      throwsFormatException,
    );
  });
  test('age matches backend accepted range', () {
    final r = row()..[6] = '151';
    final p = BackupCodec().decode(fixture([headers, r]));
    expect(p.rows, isEmpty);
    expect(p.diagnostics.single.column, 'idade');
  });
  test('rejects malformed ZIP and OLE xls', () {
    for (final b in [
      Uint8List.fromList([80, 75, 3, 4]),
      Uint8List.fromList([208, 207, 17, 224]),
    ]) {
      expect(() => BackupCodec().decode(b), throwsFormatException);
    }
  });
  test(
    'reads independent legacy14 workbook preserving zero and missing start',
    () {
      final p = BackupCodec().decode(fixture([headers, row()]));
      expect(p.rows, hasLength(1));
      expect(p.rows.single.record.age, 0);
      expect(p.rows.single.record.internalId, 'legacy-1');
      expect(p.rows.single.record.lastVisitDate.toString(), '2026-01-01');
      expect(p.rows.single.record.discipleshipStartDate, isNull);
      expect(p.rows.single.congregationName, 'Central');
    },
  );
  test('rejects formulas anywhere including nondata rows', () {
    expect(
      () => BackupCodec().decode(
        fixture([headers, row()], cell: '<row><c><f>1+1</f><v>2</v></c></row>'),
      ),
      throwsFormatException,
    );
  });
  test('rejects 10001 rows', () {
    expect(
      () => BackupCodec().decode(
        fixture([headers, ...List.generate(10001, (_) => row())]),
      ),
      throwsFormatException,
    );
  });
  test('rejects compressed size before parsing', () {
    expect(
      () => BackupCodec().decode(Uint8List(10 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });
  test('reports invalid fields without echoing personal data', () {
    final r = row()..[6] = 'secret';
    final p = BackupCodec().decode(fixture([headers, r]));
    expect(p.rows, isEmpty);
    expect(p.diagnostics.single.rowNumber, 2);
    expect(p.diagnostics.single.column, 'idade');
    expect(p.diagnostics.single.code, 'invalid_integer');
  });
  test('rejects unsupported metadata version', () {
    expect(
      () => BackupCodec().decode(fixture([headers, row()], version: '3')),
      throwsFormatException,
    );
  });
}
