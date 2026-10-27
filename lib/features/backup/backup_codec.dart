import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../domain/business_calendar.dart';
import '../../domain/models.dart';
import '../../platform/table_workbook.dart';
import 'backup_models.dart';

final class BackupCodec {
  BackupCodec({Map<String, String> congregationNames = const {}})
    : congregationNames = Map.unmodifiable(congregationNames);
  final Map<String, String> congregationNames;
  static const legacyHeaders = [
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
  static const headers = [
    ...legacyHeaders,
    'data_ultima_visita',
    'data_inicio_discipulado',
    'visitado_ao_menos_uma_vez',
  ];
  static const maxCompressed = 10 * 1024 * 1024,
      maxExpanded = 50 * 1024 * 1024,
      maxRows = 10000;
  Never _bad(String code) => throw BackupFormatException(code);
  Uint8List encode(List<ConvertRecord> records) {
    if (records.length > maxRows) _bad('row_limit');
    String yes(bool b) => b ? 'Sim' : 'Não';
    final rows = <List<String>>[headers];
    for (final r in records) {
      final congregation = r.congregationId == null
          ? ''
          : congregationNames[r.congregationId];
      if (congregation == null) _bad('unresolved_congregation');
      rows.add([
        r.internalId,
        r.name,
        congregation,
        r.address ?? '',
        r.landmark,
        r.phone ?? '',
        r.age?.toString() ?? '',
        r.gender == Gender.male ? 'Masculino' : 'Feminino',
        r.conversionDate.toString(),
        r.worshipType ?? '',
        r.visitCount.toString(),
        yes(r.isInDiscipleship),
        yes(r.isDiscipleshipCompleted),
        yes(r.isDeviated),
        r.lastVisitDate?.toString() ?? '',
        r.discipleshipStartDate?.toString() ?? '',
        yes(r.wasVisitedOnce),
      ]);
    }
    final bytes = tableWorkbook(
      'Convertidos',
      rows,
      definedNames: const {'ieadpe_backup_version': '2'},
    );
    _preflight(bytes);
    return bytes;
  }

  // Inspect every central-directory entry before archive APIs can decompress even
  // symlinks. ZIP64, encryption and exotic compression are outside this format.
  void _preflight(Uint8List bytes) {
    if (bytes.length > maxCompressed) _bad('compressed_limit');
    if (bytes.length < 22) _bad('invalid_zip');
    final b = ByteData.sublistView(bytes);
    int u16(int p) => b.getUint16(p, Endian.little);
    int u32(int p) => b.getUint32(p, Endian.little);
    void validateExtra(int offset, int length) {
      final end = offset + length;
      while (offset < end) {
        if (offset + 4 > end) _bad('invalid_zip');
        final id = u16(offset), size = u16(offset + 2);
        // The locked reader selects 64-bit descriptor widths from this field.
        if (id == 1 || offset + 4 + size > end) _bad('invalid_zip');
        offset += 4 + size;
      }
    }

    var end = -1;
    for (var p = bytes.length - 22; p >= 0 && p >= bytes.length - 65557; p--) {
      if (u32(p) == 0x06054b50 && p + 22 + u16(p + 20) == bytes.length) {
        end = p;
        break;
      }
    }
    if (end < 0 ||
        u16(end + 20) != 0 ||
        (end >= 20 && u32(end - 20) == 0x07064b50) ||
        u16(end + 4) != 0 ||
        u16(end + 6) != 0 ||
        u16(end + 8) != u16(end + 10)) {
      _bad('invalid_zip');
    }
    final count = u16(end + 10), start = u32(end + 16), size = u32(end + 12);
    if (count == 0 || count > 256 || start + size != end) _bad('invalid_zip');
    var p = start, total = 0;
    final names = <String>{};
    for (var i = 0; i < count; i++) {
      if (p + 46 > end || u32(p) != 0x02014b50) _bad('invalid_zip');
      final flags = u16(p + 8),
          method = u16(p + 10),
          crc = u32(p + 16),
          compressed = u32(p + 20),
          expanded = u32(p + 24),
          n = u16(p + 28),
          extra = u16(p + 30),
          comment = u16(p + 32),
          local = u32(p + 42);
      total += expanded;
      if (total > maxExpanded) _bad('expanded_limit');
      if (flags & 1 != 0 ||
          (method != 0 && method != 8) ||
          u16(p + 34) != 0 ||
          u32(p + 38) >> 16 & 0xf000 == 0xa000 ||
          p + 46 + n + extra + comment > end ||
          local + 30 > start) {
        _bad('invalid_zip');
      }
      validateExtra(p + 46 + n, extra);
      final name = utf8.decode(bytes.sublist(p + 46, p + 46 + n));
      if (!names.add(name) ||
          name.contains('..') ||
          name.contains('\\') ||
          name.startsWith('/')) {
        _bad('invalid_zip');
      }
      if (u32(local) != 0x04034b50 ||
          u16(local + 6) != flags ||
          u16(local + 8) != method) {
        _bad('invalid_zip');
      }
      final ln = u16(local + 26), le = u16(local + 28);
      if (local + 30 + ln + le + compressed > start ||
          utf8.decode(bytes.sublist(local + 30, local + 30 + ln)) != name ||
          (method == 0 && compressed != expanded)) {
        _bad('invalid_zip');
      }
      validateExtra(local + 30 + ln, le);
      final localCrc = u32(local + 14),
          localCompressed = u32(local + 18),
          localExpanded = u32(local + 22);
      if (flags & 8 == 0) {
        if (localCrc != crc ||
            localCompressed != compressed ||
            localExpanded != expanded) {
          _bad('invalid_zip');
        }
      } else {
        // Streamed members may leave zero placeholders or repeat known values.
        if ((localCrc != 0 && localCrc != crc) ||
            (localCompressed != 0 && localCompressed != compressed) ||
            (localExpanded != 0 && localExpanded != expanded)) {
          _bad('invalid_zip');
        }
        var descriptor = local + 30 + ln + le + compressed;
        if (descriptor + 12 > start) _bad('invalid_zip');
        if (u32(descriptor) == 0x08074b50) descriptor += 4;
        if (descriptor + 12 > start ||
            u32(descriptor) != crc ||
            u32(descriptor + 4) != compressed ||
            u32(descriptor + 8) != expanded) {
          _bad('invalid_zip');
        }
      }
      p += 46 + n + extra + comment;
    }
    if (p != end) _bad('invalid_zip');
  }

  ImportPreview decode(Uint8List bytes) {
    try {
      return _decode(bytes);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      return _bad('invalid_workbook');
    }
  }

  ImportPreview _decode(Uint8List bytes) {
    _preflight(bytes);
    final decoder = ZipDecoder()..decodeBytes(bytes);
    final documents = <String, XmlDocument>{};
    for (final f in decoder.directory.fileHeaders) {
      final content = f.file!.getStream().toUint8List();
      if (content.length != f.uncompressedSize ||
          getCrc32(content) != f.crc32) {
        _bad('invalid_zip');
      }
      if (f.filename.endsWith('.xml') || f.filename.endsWith('.rels')) {
        final text = utf8.decode(content);
        if (text.contains('<!DOCTYPE') || text.contains('<!ENTITY')) {
          _bad('invalid_xml');
        }
        final doc = XmlDocument.parse(text);
        if (doc.descendants.whereType<XmlElement>().any(
          (e) => e.name.local == 'f',
        )) {
          _bad('formula_cell');
        }
        documents[f.filename] = doc;
      }
    }
    const spreadsheet =
        'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    const relationships =
        'http://schemas.openxmlformats.org/package/2006/relationships';
    const officeRelationships =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    XmlDocument document(String path, String root, String namespace) {
      final doc = documents[path] ?? _bad('invalid_workbook');
      if (doc.rootElement.name.local != root ||
          doc.rootElement.namespaceUri != namespace ||
          doc.descendants.whereType<XmlElement>().any(
            (e) => e.namespaceUri != namespace,
          )) {
        _bad('invalid_xml');
      }
      return doc;
    }

    Iterable<XmlElement> elements(XmlNode d, String name) => d.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == name);
    final workbook = document('xl/workbook.xml', 'workbook', spreadsheet);
    final versions = elements(
      workbook,
      'definedName',
    ).where((e) => e.getAttribute('name') == 'ieadpe_backup_version').toList();
    final version = versions.isEmpty
        ? 1
        : versions.length == 1 && versions.single.innerText == '2'
        ? 2
        : _bad('unsupported_version');
    final sheets = elements(
      workbook,
      'sheet',
    ).where((e) => e.getAttribute('name') == 'Convertidos').toList();
    if (sheets.length != 1) _bad('missing_sheet');
    final id = sheets.single.attributes
        .where(
          (a) => a.name.local == 'id' && a.namespaceUri == officeRelationships,
        )
        .single
        .value;
    final rel = elements(
      document('xl/_rels/workbook.xml.rels', 'Relationships', relationships),
      'Relationship',
    ).where((e) => e.getAttribute('Id') == id).single;
    if (rel.getAttribute('Type') != '$officeRelationships/worksheet') {
      _bad('invalid_relationship');
    }
    final target = rel.getAttribute('Target') ?? '';
    if (rel.getAttribute('TargetMode') == 'External' || target.contains('..')) {
      _bad('invalid_relationship');
    }
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final sheet = document(path, 'worksheet', spreadsheet);
    final strings = documents.containsKey('xl/sharedStrings.xml')
        ? document('xl/sharedStrings.xml', 'sst', spreadsheet)
        : null;
    final shared = strings == null
        ? <String>[]
        : elements(strings, 'si')
              .map((e) => elements(e, 't').map((t) => t.innerText).join())
              .toList();
    final xmlRows = elements(sheet, 'row').toList();
    if (xmlRows.length > maxRows + 1) _bad('row_limit');
    List<String> values(XmlElement row) {
      final cells = List.filled(headers.length, '');
      var index = 0;
      final occupied = <int>{};
      for (final c in row.childElements.where((e) => e.name.local == 'c')) {
        final ref = c.getAttribute('r');
        if (ref != null) {
          final match = RegExp(r'^([A-Z]+)[1-9][0-9]*$').firstMatch(ref);
          if (match == null) _bad('invalid_cell');
          index = 0;
          for (final char in match.group(1)!.codeUnits) {
            index = index * 26 + char - 64;
          }
          index--;
        }
        if (index >= headers.length || index < 0 || !occupied.add(index)) {
          _bad('invalid_cell');
        }
        final type = c.getAttribute('t');
        var value = type == 'inlineStr'
            ? elements(c, 't').map((t) => t.innerText).join()
            : elements(c, 'v').map((v) => v.innerText).join();
        if (type == 's') {
          final n = int.tryParse(value);
          if (n == null || n < 0 || n >= shared.length) {
            _bad('invalid_shared_string');
          }
          value = shared[n];
        } else if (type != null &&
            type != 'inlineStr' &&
            type != 'n' &&
            type != 'str') {
          _bad('invalid_cell_type');
        }
        cells[index++] = value;
      }
      return cells;
    }

    if (xmlRows.isEmpty) _bad('invalid_headers');
    final expected = version == 1 ? legacyHeaders : headers,
        heading = values(xmlRows.first);
    if (List.generate(
          expected.length,
          (i) => heading[i] == expected[i],
        ).contains(false) ||
        heading.skip(expected.length).any((v) => v.isNotEmpty)) {
      _bad('invalid_headers');
    }
    final rows = <BackupRow>[], diagnostics = <ImportDiagnostic>[];
    final ids = <String>{};
    for (var i = 1; i < xmlRows.length; i++) {
      final v = values(xmlRows[i]);
      if (v.skip(expected.length).any((value) => value.isNotEmpty)) {
        _bad('invalid_columns');
      }
      if (v.every((s) => s.isEmpty)) continue;
      final rowNumber =
          int.tryParse(xmlRows[i].getAttribute('r') ?? '') ?? i + 1;
      final before = diagnostics.length;
      void error(int col, String code) =>
          diagnostics.add(ImportDiagnostic(rowNumber, headers[col], code));
      int? integer(int col, {bool optional = false}) {
        if (optional && v[col].isEmpty) return null;
        final n = int.tryParse(v[col]);
        if (n == null || n < 0 || n > 2147483647 || (col == 6 && n > 150)) {
          error(col, 'invalid_integer');
          return null;
        }
        return n;
      }

      DateOnly? date(int col, {bool optional = false}) {
        if (optional && v[col].isEmpty) return null;
        try {
          return DateOnly.parse(v[col]);
        } catch (_) {
          error(col, 'invalid_date');
          return null;
        }
      }

      bool flag(int col) {
        if (v[col] != 'Sim' && v[col] != 'Não') error(col, 'invalid_boolean');
        return v[col] == 'Sim';
      }

      if (v[0].trim().isEmpty) {
        error(0, 'required');
      } else if (!ids.add(v[0])) {
        error(0, 'duplicate_id');
      }
      if (v[1].trim().isEmpty) error(1, 'required');
      if (v[9].isNotEmpty && (v[9].trim().isEmpty || v[9] != v[9].trim())) {
        error(9, 'invalid_worship_type');
      }
      final age = integer(6, optional: true), visits = integer(10);
      if (v[7] != 'Masculino' && v[7] != 'Feminino') error(7, 'invalid_gender');
      final conversion = date(8),
          inDs = flag(11),
          complete = flag(12),
          deviated = flag(13);
      final last = version == 2 ? date(14, optional: true) : conversion;
      final start = version == 2 ? date(15, optional: true) : null;
      final visited = version == 2 ? flag(16) : (visits ?? 0) > 0;
      if (before != diagnostics.length) continue;
      rows.add(
        BackupRow(
          rowNumber,
          ConvertRecord(
            id: '',
            internalId: v[0],
            name: v[1],
            congregationId: null,
            address: v[3],
            landmark: v[4],
            phone: v[5],
            age: age,
            gender: v[7] == 'Masculino' ? Gender.male : Gender.female,
            conversionDate: conversion!,
            worshipType: v[9].isEmpty ? null : v[9],
            visitCount: visits!,
            lastVisitDate: last,
            discipleshipStartDate: start,
            wasVisitedOnce: visited,
            isInDiscipleship: inDs,
            isDiscipleshipCompleted: complete,
            isDeviated: deviated,
          ),
          v[2],
        ),
      );
    }
    return ImportPreview(
      version: version,
      rows: rows,
      diagnostics: diagnostics,
    );
  }
}
