import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:ieadpe_converts/platform/table_workbook.dart';

void main() {
  test(
    'real XLSX preserves headers accents and formula-like text as string cells',
    () {
      final bytes = tableWorkbook('Eventos', [
        ['Congregação', 'Evento'],
        ['São José', '=1+2'],
      ]);
      expect(bytes.take(2), [80, 75]);
      final archive = ZipDecoder().decodeBytes(bytes);
      final workbook = XmlDocument.parse(
        utf8.decode(archive.findFile('xl/workbook.xml')!.content),
      );
      expect(
        workbook.rootElement.namespaceUri,
        'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
      );
      final xml = XmlDocument.parse(
        utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content),
      );
      expect(
        xml.rootElement.namespaceUri,
        'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
      );
      expect(xml.findAllElements('f'), isEmpty);
      expect(
        xml
            .findAllElements('c')
            .every((e) => e.getAttribute('t') == 'inlineStr'),
        isTrue,
      );
      expect(xml.findAllElements('t').map((e) => e.innerText), [
        'Congregação',
        'Evento',
        'São José',
        '=1+2',
      ]);
    },
  );
}
