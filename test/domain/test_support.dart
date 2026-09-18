import 'package:discipulado_ieadpe/domain/common.dart';

/// Deterministic metadata fixture. Not a production helper: tests only.
CommonMetadata meta({
  String id = 'record-1',
  int revision = 1,
  DateTime? createdAt,
  DateTime? updatedAt,
  String updatedBy = 'uid-supervisor',
}) {
  final stamp = DateTime.utc(2026, 1, 15, 12, 30);
  return CommonMetadata(
    id: id,
    revision: revision,
    createdAt: createdAt ?? stamp,
    updatedAt: updatedAt ?? stamp,
    updatedBy: updatedBy,
  );
}
