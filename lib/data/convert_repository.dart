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
    if (query.name.trim().isEmpty && query.name.isNotEmpty ||
        query.name.length > 200) {
      throw const DataFailure('invalid');
    }
    final transport = gateway;
    if (transport is! ReadRpcGateway) throw const DataFailure('unavailable');
    final result = await transport.readRpc(
      'ministry_list_converts',
      context: token,
      parameters: {
        'congregation_id': query.congregationId,
        'name_prefix': query.name.isEmpty ? null : query.name,
        'limit': 100,
        'cursor': cursor,
      },
    );
    gateway.ensureCurrent(token);
    try {
      final nextCursor = result['next_cursor'];
      if (!_hasOnly(result, {'items', 'next_cursor'}) ||
          result['items'] is! List ||
          (result['items'] as List).length > 100 ||
          (nextCursor != null && nextCursor is! String) ||
          (nextCursor is String && nextCursor.length > 4096)) {
        throw const FormatException();
      }
      final projections = (result['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
      final records = projections
          .map(decodeConvertProjection)
          .toList(growable: false);
      validatePageOrder(
        projections
            .map((item) => Map<String, dynamic>.from(item['convert'] as Map))
            .toList(),
        null,
      );
      return Page(items: records, nextCursor: nextCursor as String?);
    } catch (_) {
      throw const DataFailure('invalid_response');
    }
  }

  Future<ConvertRecord> get({
    required String? congregationId,
    required String convertId,
  }) async {
    if (congregationId != null) validateUuid(congregationId);
    validateUuid(convertId);
    final token = gateway.context;
    final transport = gateway;
    if (transport is! ReadRpcGateway) throw const DataFailure('unavailable');
    final result = await transport.readRpc(
      'ministry_get_convert',
      context: token,
      parameters: {'congregation_id': congregationId, 'convert_id': convertId},
    );
    gateway.ensureCurrent(token);
    try {
      final record = decodeConvertProjection(result);
      if (record.id != convertId || record.congregationId != congregationId) {
        throw const FormatException();
      }
      return record;
    } catch (_) {
      throw const DataFailure('invalid_response');
    }
  }
}

ConvertRecord decodeConvertProjection(Map<String, dynamic> row) {
  const projectionKeys = {
    'convert',
    'person',
    'person_revision',
    'legacy_identity',
  };
  if (!_hasOnly(row, projectionKeys) ||
      !row.keys.toSet().containsAll(projectionKeys) ||
      row['convert'] is! Map) {
    throw const FormatException();
  }
  final convert = Map<String, dynamic>.from(row['convert'] as Map);
  const convertKeys = {
    'id',
    'internal_id',
    'person_id',
    'congregation_id',
    'landmark',
    'gender',
    'conversion_date',
    'worship_type',
    'photo_url',
    'photo_asset_id',
    'age',
    'last_visit_date',
    'was_visited_once',
    'visit_count',
    'is_in_discipleship',
    'discipleship_start_date',
    'is_discipleship_completed',
    'is_deviated',
    'effective_is_in_discipleship',
    'effective_discipleship_start_date',
    'latest_qualifying_lesson_date',
    'effective_follow_up_date',
    'created_by',
    'created_at',
    'updated_at',
    'deleted_at',
    'revision',
  };
  if (!_hasOnly(convert, convertKeys) ||
      !convert.keys.toSet().containsAll(convertKeys) ||
      convert['effective_is_in_discipleship'] is! bool) {
    throw const FormatException();
  }
  final personId = convert['person_id'];
  final personRevision = row['person_revision'];
  final rawPerson = row['person'];
  final rawLegacy = row['legacy_identity'];
  CanonicalPersonIdentity? person;
  LegacyConvertIdentity? legacy;
  String name;
  String? phone;
  String? address;
  if (personId == null) {
    if (rawPerson != null || personRevision != null || rawLegacy is! Map) {
      throw const FormatException();
    }
    final legacyJson = Map<String, dynamic>.from(rawLegacy);
    const legacyKeys = {'name', 'phone', 'address'};
    if (!_hasOnly(legacyJson, legacyKeys) ||
        !legacyJson.keys.toSet().containsAll(legacyKeys)) {
      throw const FormatException();
    }
    legacy = LegacyConvertIdentity.fromJson(legacyJson);
    if (legacy.name.trim().isEmpty) throw const FormatException();
    name = legacy.name;
    phone = legacy.phone;
    address = legacy.address;
  } else {
    validateUuid(personId);
    if (rawPerson is! Map ||
        rawLegacy != null ||
        personRevision is! int ||
        personRevision < 1) {
      throw const FormatException();
    }
    final personJson = Map<String, dynamic>.from(rawPerson);
    const personKeys = {
      'id',
      'congregation_id',
      'name',
      'normalized_name',
      'phone',
      'birth_date',
      'address',
    };
    if (!_hasOnly(personJson, personKeys) ||
        !personJson.keys.toSet().containsAll(personKeys) ||
        personJson['id'] != personId ||
        personJson['congregation_id'] != convert['congregation_id']) {
      throw const FormatException();
    }
    final normalizedName = personJson['normalized_name'];
    if (normalizedName is! String ||
        normalizedName != (personJson['name'] as String).trim().toLowerCase()) {
      throw const FormatException();
    }
    if (personJson['address'] != null) {
      if (personJson['address'] is! Map ||
          !_hasOnly(
            Map<String, dynamic>.from(personJson['address'] as Map),
            const {'street', 'district', 'city', 'postal_code', 'state_code'},
          ) ||
          !Map<String, dynamic>.from(personJson['address'] as Map).keys
              .toSet()
              .containsAll(const {
                'street',
                'district',
                'city',
                'postal_code',
                'state_code',
              }) ||
          Map<String, dynamic>.from(personJson['address'] as Map).values
              .any((value) => value != null && value is! String)) {
        throw const FormatException();
      }
    }
    person = CanonicalPersonIdentity.fromJson(personJson);
    if (person.name.trim().isEmpty) throw const FormatException();
    name = person.name;
    phone = person.phone;
    address = person.address?['street'] as String?;
  }
  if (convert['person_id'] != null) validateUuid(convert['person_id']);
  final merged = <String, dynamic>{
    ...convert,
    'name': name,
    'phone': phone,
    'address': address,
    'person_id': personId,
    'person_revision': personRevision,
    'person_identity': person?.toJson(),
    'legacy_identity': legacy?.toJson(),
  };
  return decodeConvert(merged);
}

bool _hasOnly(Map<String, dynamic> json, Set<String> allowed) =>
    json.keys.every(allowed.contains);

ConvertRecord decodeConvert(Map<String, dynamic> row) {
  try {
    validateUuid(row['id']);
    for (final key in ['internal_id', 'name', 'landmark']) {
      if (row[key] is! String || (row[key] as String).trim().isEmpty) {
        throw const FormatException();
      }
    }
    final worshipType = row['worship_type'];
    if (worshipType != null &&
        (worshipType is! String ||
            worshipType.trim().isEmpty ||
            worshipType != worshipType.trim())) {
      throw const FormatException();
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
    if (row['revision'] != null &&
        (row['revision'] is! int || (row['revision'] as int) < 1)) {
      throw const FormatException();
    }
    if (row['person_revision'] != null &&
        (row['person_revision'] is! int ||
            (row['person_revision'] as int) < 1)) {
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
    final record = ConvertRecord.fromJson(row);
    if ((record.personId == null) != (record.personRevision == null) ||
        (record.personId == null) != (record.personIdentity == null) ||
        (record.personId == null) != (record.legacyIdentity != null)) {
      throw const FormatException();
    }
    return record;
  } catch (_) {
    throw const DataFailure('invalid_response');
  }
}
