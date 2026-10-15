import 'dart:convert';

import '../domain/models.dart';
import '../domain/business_calendar.dart';
import 'supabase_gateway.dart';

class ConvertQuery {
  const ConvertQuery({this.congregationId, this.name = ''});
  final String? congregationId;
  final String name;
  String get key => jsonEncode([congregationId, name]);
}

class ConvertRepository {
  ConvertRepository(this.gateway);
  final Gateway gateway;
  Future<Page<ConvertRecord>> list(ConvertQuery query, String? cursor) async {
    final token = gateway.context;
    if (query.congregationId != null) validateUuid(query.congregationId);
    final after = decodeCursor(cursor, token, query.key);
    final rows = await gateway.read(
      'converts',
      context: token,
      afterId: after,
      equals: {
        if (query.congregationId != null)
          'congregation_id': query.congregationId!,
      },
      name: query.name,
      excludeDeleted: true,
    );
    gateway.ensureCurrent(token);
    validatePageOrder(rows, after);
    final records = rows.map(decodeConvert).toList(growable: false);
    return Page(
      items: records,
      nextCursor: rows.length == 100
          ? encodeCursor(token, query.key, records.last.id)
          : null,
    );
  }
}

ConvertRecord decodeConvert(Map<String, dynamic> row) {
  try {
    validateUuid(row['id']);
    for (final key in ['internal_id', 'name', 'landmark', 'worship_type']) {
      if (row[key] is! String || (row[key] as String).trim().isEmpty) {
        throw const FormatException();
      }
    }
    for (final key in [
      'was_visited_once',
      'is_in_discipleship',
      'is_discipleship_completed',
      'is_deviated',
    ]) {
      if (row[key] is! bool) throw const FormatException();
    }
    if (row['visit_count'] is! int || (row['visit_count'] as int) < 0) {
      throw const FormatException();
    }
    if (row['age'] != null &&
        (row['age'] is! int ||
            (row['age'] as int) < 0 ||
            (row['age'] as int) > 150)) {
      throw const FormatException();
    }
    for (final key in ['congregation_id', 'photo_asset_id', 'created_by']) {
      if (row[key] != null) validateUuid(row[key]);
    }
    for (final key in ['created_at', 'updated_at', 'deleted_at']) {
      final value = row[key];
      if (key == 'deleted_at' && value == null) continue;
      if (value is! String ||
          !RegExp(
            r'^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d{1,6})?(Z|[+-]([01]\d|2[0-3]):[0-5]\d)$',
          ).hasMatch(value)) {
        throw const FormatException();
      }
      DateOnly.parse(value.substring(0, 10));
    }
    return ConvertRecord.fromJson(row);
  } catch (_) {
    throw const DataFailure('invalid_response');
  }
}
