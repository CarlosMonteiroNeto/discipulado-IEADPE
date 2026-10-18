import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../data/convert_repository.dart';
import '../admin/congregation_repository.dart';
import 'backup_codec.dart';
import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import 'backup_models.dart';

abstract interface class ImportProgressStore {
  Future<String?> read(String key);
  Future<void> write(String key, String operationId);
  Future<void> remove(String key);
}

final class ImportProgress {
  const ImportProgress({
    required this.processed,
    required this.created,
    required this.skipped,
    required this.errors,
    this.warning,
    this.errorCode,
    this.done = false,
    this.diagnostics = const [],
  });
  final int processed, created, skipped, errors;
  final String? warning, errorCode;
  final bool done;
  final List<ImportDiagnostic> diagnostics;
}

class BackupRepository {
  BackupRepository(this.gateway, this.store);
  final Gateway gateway;
  final ImportProgressStore store;
  Map<String, Object?> _payload(BackupRow row) {
    final record = row.record;
    return {
      for (final entry in record.toJson().entries)
        if ({
          'internal_id',
          'name',
          'landmark',
          'gender',
          'conversion_date',
          'worship_type',
          'address',
          'phone',
          'age',
          'last_visit_date',
          'was_visited_once',
          'visit_count',
          'is_in_discipleship',
          'discipleship_start_date',
          'is_discipleship_completed',
          'is_deviated',
        }.contains(entry.key))
          entry.key: entry.value,
      'congregation_name': row.congregationName,
    };
  }

  Stream<ImportProgress> importRows(ImportPreview preview) async* {
    final token = gateway.context;
    final owner = token.split(':').last;
    validateUuid(owner);
    final transport = gateway;
    if (transport is! ImportRpcGateway) throw const DataFailure('unavailable');
    final payloads = preview.rows.map(_payload).toList(growable: false);
    final fingerprint = const Uuid().v5(
      Namespace.url.value,
      jsonEncode([
        preview.version,
        [
          for (var i = 0; i < payloads.length; i++)
            [preview.rows[i].rowNumber, payloads[i]],
        ],
        preview.diagnostics
            .map((d) => [d.rowNumber, d.column, d.code])
            .toList(),
      ]),
    );
    final key = '$owner:$fingerprint';
    var seed = await store.read(key);
    gateway.ensureCurrent(token);
    if (seed == null) {
      seed = const Uuid().v4();
      await store.write(key, seed);
      gateway.ensureCurrent(token);
    }
    validateUuid(seed);
    String? warning;
    final diagnostics = <ImportDiagnostic>[];
    final invalidRows = preview.diagnostics
        .where((d) => d.code != 'duplicate_id')
        .map((d) => d.rowNumber)
        .toSet();
    final duplicateRows = preview.diagnostics
        .where((d) => d.code == 'duplicate_id')
        .map((d) => d.rowNumber)
        .toSet()
        .difference(invalidRows);
    var errors = invalidRows.length, skipped = duplicateRows.length;
    var processed = errors + skipped, created = 0;
    for (var i = 0; i < payloads.length; i++) {
      gateway.ensureCurrent(token);
      final operation = const Uuid().v5(seed, '${preview.rows[i].rowNumber}');
      try {
        final result = await transport.importRow(operation, payloads[i]);
        gateway.ensureCurrent(token);
        warning = result['warning'] as String? ?? warning;
        if (result['status'] == 'created') {
          created++;
        } else {
          skipped++;
        }
        processed++;
        yield ImportProgress(
          processed: processed,
          created: created,
          skipped: skipped,
          errors: errors,
          diagnostics: List.unmodifiable(diagnostics),
          warning: warning,
        );
      } on DataFailure catch (error) {
        gateway.ensureCurrent(token);
        if (error.code == 'invalid') {
          errors++;
          processed++;
          diagnostics.add(
            ImportDiagnostic(preview.rows[i].rowNumber, 'registro', error.code),
          );
          yield ImportProgress(
            processed: processed,
            created: created,
            skipped: skipped,
            errors: errors,
            diagnostics: List.unmodifiable(diagnostics),
            errorCode: 'invalid',
          );
          continue;
        }
        yield ImportProgress(
          processed: processed,
          created: created,
          skipped: skipped,
          errors: errors,
          diagnostics: List.unmodifiable(diagnostics),
          errorCode: error.code,
        );
        return;
      }
    }
    gateway.ensureCurrent(token);
    await store.remove(key);
    gateway.ensureCurrent(token);
    yield ImportProgress(
      processed: processed,
      created: created,
      skipped: skipped,
      errors: errors,
      diagnostics: List.unmodifiable(diagnostics),
      warning: warning,
      done: true,
    );
  }

  Future<Uint8List> exportBytes() async {
    final token = gateway.context;
    final congregations = await CongregationRepository(gateway).list();
    gateway.ensureCurrent(token);
    final converts = ConvertRepository(gateway);
    final records = <ConvertRecord>[];
    String? cursor;
    do {
      final page = await converts.list(ConvertQuery(), cursor);
      gateway.ensureCurrent(token);
      records.addAll(page.items);
      if (records.length > BackupCodec.maxRows) {
        throw const BackupFormatException('row_limit');
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    final bytes = BackupCodec(
      congregationNames: {for (final c in congregations) c.id: c.name},
    ).encode(records);
    gateway.ensureCurrent(token);
    return bytes;
  }
}
