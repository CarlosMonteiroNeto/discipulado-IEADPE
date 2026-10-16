import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A minimal OOXML workbook. All values are strings, including formula-like text.
Uint8List tableWorkbook(String sheet, List<List<String>> rows) {
  final archive = Archive();
  void add(String path, String text) {
    archive.addFile(ArchiveFile.bytes(path, utf8.encode(text)));
  }

  add(
    '[Content_Types].xml',
    '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
  );
  add(
    '_rels/.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  final workbook = XmlBuilder()
    ..element(
      'workbook',
      namespaceUris: {
        null: 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
        'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      },
      nest: () {},
    );
  // Construct attributes through the XML API so user supplied names are escaped.
  final root = workbook.buildDocument().rootElement;
  root.children.add(
    XmlElement(XmlName.parts('sheets'), [], [
      XmlElement(XmlName.parts('sheet'), [
        XmlAttribute(XmlName.parts('name'), sheet),
        XmlAttribute(XmlName.parts('sheetId'), '1'),
        XmlAttribute(XmlName.parts('id', prefix: 'r'), 'rId1'),
      ]),
    ]),
  );
  add('xl/workbook.xml', root.toXmlString());
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
  );
  final builder = XmlBuilder();
  builder.element(
    'worksheet',
    namespaceUris: {
      null: 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
    },
    nest: () {
      builder.element(
        'sheetData',
        nest: () {
          for (final row in rows) {
            builder.element(
              'row',
              nest: () {
                for (final value in row) {
                  builder.element(
                    'c',
                    attributes: {'t': 'inlineStr'},
                    nest: () {
                      builder.element(
                        'is',
                        nest: () {
                          builder.element(
                            't',
                            attributes: {'xml:space': 'preserve'},
                            nest: value,
                          );
                        },
                      );
                    },
                  );
                }
              },
            );
          }
        },
      );
    },
  );
  add('xl/worksheets/sheet1.xml', builder.buildDocument().toXmlString());
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
