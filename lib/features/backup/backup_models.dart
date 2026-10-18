import '../../domain/models.dart';

/// Parsed source values. record.id is empty; internalId is the source key.
/// The congregation name must be resolved by the authorized import flow.
final class BackupRow {
  const BackupRow(this.rowNumber, this.record, this.congregationName);
  final int rowNumber;
  final ConvertRecord record;
  final String congregationName;
}

final class ImportDiagnostic {
  const ImportDiagnostic(this.rowNumber, this.column, this.code);
  final int rowNumber;
  final String column, code;
}

final class ImportPreview {
  ImportPreview({
    required this.version,
    required Iterable<BackupRow> rows,
    required Iterable<ImportDiagnostic> diagnostics,
  }) : rows = List.unmodifiable(rows),
       diagnostics = List.unmodifiable(diagnostics);
  final int version;
  final List<BackupRow> rows;
  final List<ImportDiagnostic> diagnostics;
}

/// Stable machine-readable errors; never retains workbook contents.
final class BackupFormatException extends FormatException {
  const BackupFormatException(this.code) : super(code);
  final String code;
}
