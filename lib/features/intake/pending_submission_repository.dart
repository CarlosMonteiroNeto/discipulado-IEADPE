import '../../data/supabase_gateway.dart';
import '../../domain/business_calendar.dart';
import '../../domain/models.dart';
import '../../domain/uuid_shape.dart';

const _reviewPageSize = 50;
const _summaryKeys = {
  'id',
  'congregation_id',
  'congregation_name',
  'submitted_at',
  'expires_at',
  'name',
  'revision',
};

final class PendingSubmissionSummary {
  const PendingSubmissionSummary({
    required this.id,
    required this.congregationId,
    required this.congregationName,
    required this.submittedAt,
    required this.expiresAt,
    required this.name,
    required this.revision,
  });

  final String id;
  final String congregationId;
  final String congregationName;
  final DateTime submittedAt;
  final DateTime expiresAt;
  final String name;
  final int revision;

  factory PendingSubmissionSummary.fromJson(Map<String, dynamic> json) {
    if (!_hasExactKeys(json, _summaryKeys) ||
        json['id'] is! String ||
        json['congregation_id'] is! String ||
        json['congregation_name'] is! String ||
        json['submitted_at'] is! String ||
        json['expires_at'] is! String ||
        json['name'] is! String ||
        json['revision'] is! int) {
      throw const DataFailure('invalid_response');
    }
    final id = json['id'] as String;
    final congregationId = json['congregation_id'] as String;
    final congregationName = json['congregation_name'] as String;
    final name = json['name'] as String;
    final submittedAt = DateTime.tryParse(json['submitted_at'] as String);
    final expiresAt = DateTime.tryParse(json['expires_at'] as String);
    final revision = json['revision'] as int;
    if (!isUuidShape(id) ||
        !isUuidShape(congregationId) ||
        congregationName.trim().isEmpty ||
        name.trim().isEmpty ||
        name.length > 200 ||
        submittedAt == null ||
        expiresAt == null ||
        revision < 1) {
      throw const DataFailure('invalid_response');
    }
    return PendingSubmissionSummary(
      id: id,
      congregationId: congregationId,
      congregationName: congregationName,
      submittedAt: submittedAt,
      expiresAt: expiresAt,
      name: name,
      revision: revision,
    );
  }
}

final class PendingSubmissionDetail {
  const PendingSubmissionDetail({required this.summary, required this.draft});

  final PendingSubmissionSummary summary;
  final Map<String, Object?> draft;
}

final class PendingReviewResult {
  const PendingReviewResult({
    required this.id,
    required this.status,
    required this.officialConvertId,
  });

  final String id;
  final String status;
  final String? officialConvertId;
}

enum PendingReviewDecision { approve, reject }

final class PendingReviewFailure implements Exception {
  const PendingReviewFailure(this.code, {this.outcomeUnknown = false});

  final String code;
  final bool outcomeUnknown;

  @override
  String toString() => 'PendingReviewFailure($code)';
}

/// Authenticated, exact-projection access to T5's scoped review RPCs.
final class PendingSubmissionRepository {
  PendingSubmissionRepository(this.gateway);

  final PendingReviewGateway gateway;

  Future<Page<PendingSubmissionSummary>> list({
    required String? congregationId,
    String? cursor,
  }) async {
    if ((congregationId != null && !isUuidShape(congregationId)) ||
        (cursor != null && !_validCursor(cursor))) {
      throw const DataFailure('invalid');
    }
    final token = gateway.context;
    final raw = await gateway.readRpc(
      'list_pending_intake',
      context: token,
      parameters: {
        'congregation_id': congregationId,
        'limit': _reviewPageSize,
        'cursor': cursor,
      },
    );
    gateway.ensureCurrent(token);
    if (!_hasExactKeys(raw, {'items', 'next_cursor'}) ||
        raw['items'] is! List) {
      throw const DataFailure('invalid_response');
    }
    final rawItems = raw['items'] as List;
    if (rawItems.length > _reviewPageSize) {
      throw const DataFailure('invalid_response');
    }
    final items = <PendingSubmissionSummary>[];
    final ids = <String>{};
    for (final value in rawItems) {
      if (value is! Map) throw const DataFailure('invalid_response');
      final item = PendingSubmissionSummary.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (!ids.add(item.id) ||
          (congregationId != null && item.congregationId != congregationId)) {
        throw const DataFailure('invalid_response');
      }
      items.add(item);
    }
    final rawCursor = raw['next_cursor'];
    if (rawCursor != null &&
        (rawCursor is! String ||
            !_validCursor(rawCursor) ||
            items.length != _reviewPageSize)) {
      throw const DataFailure('invalid_response');
    }
    gateway.ensureCurrent(token);
    return Page(items: items, nextCursor: rawCursor as String?);
  }

  Future<PendingSubmissionDetail> get(String id) async {
    if (!isUuidShape(id)) throw const DataFailure('invalid');
    final token = gateway.context;
    final raw = await gateway.readRpc(
      'get_pending_intake',
      context: token,
      parameters: {'id': id},
    );
    gateway.ensureCurrent(token);
    if (!_hasExactKeys(raw, {..._summaryKeys, 'draft'}) ||
        raw['draft'] is! Map) {
      throw const DataFailure('invalid_response');
    }
    final summary = PendingSubmissionSummary.fromJson({
      for (final entry in raw.entries)
        if (_summaryKeys.contains(entry.key)) entry.key: entry.value,
    });
    if (summary.id != id) throw const DataFailure('invalid_response');
    final draft = _validateDraft(
      Map<String, Object?>.from(raw['draft'] as Map),
    );
    if (draft['congregation_id'] != summary.congregationId) {
      throw const DataFailure('invalid_response');
    }
    gateway.ensureCurrent(token);
    return PendingSubmissionDetail(summary: summary, draft: draft);
  }

  Future<PendingReviewResult> review({
    required String operationId,
    required String id,
    required int expectedRevision,
    required PendingReviewDecision decision,
    Map<String, Object?>? draft,
  }) async {
    if (!isUuidShape(operationId) ||
        !isUuidShape(id) ||
        expectedRevision < 1 ||
        (decision == PendingReviewDecision.approve && draft == null) ||
        (decision == PendingReviewDecision.reject && draft != null)) {
      throw const PendingReviewFailure('invalid');
    }
    final payload = <String, Object?>{
      'id': id,
      'expected_revision': expectedRevision,
      'decision': decision.name,
      if (draft != null) 'draft': _validateDraft(draft),
    };
    final token = gateway.context;
    try {
      final raw = await gateway.reviewPendingIntake(operationId, payload);
      gateway.ensureCurrent(token);
      if (!_hasExactKeys(raw, {'id', 'status', 'official_convert_id'}) ||
          raw['id'] != id ||
          raw['status'] !=
              (decision == PendingReviewDecision.approve
                  ? 'approved'
                  : 'rejected') ||
          (raw['status'] == 'approved' &&
              (raw['official_convert_id'] is! String ||
                  !isUuidShape(raw['official_convert_id'] as String))) ||
          (raw['status'] == 'rejected' && raw['official_convert_id'] != null)) {
        throw const PendingReviewFailure(
          'invalid_response',
          outcomeUnknown: true,
        );
      }
      gateway.ensureCurrent(token);
      return PendingReviewResult(
        id: id,
        status: raw['status'] as String,
        officialConvertId: raw['official_convert_id'] as String?,
      );
    } on DataFailure catch (error) {
      throw PendingReviewFailure(
        error.code,
        outcomeUnknown:
            error.code == 'unavailable' || error.code == 'invalid_response',
      );
    }
  }
}

Map<String, Object?> _validateDraft(Map<String, Object?> source) {
  if (!_hasExactKeys(source, {'congregation_id', 'person', 'convert'}) ||
      source['congregation_id'] is! String ||
      source['person'] is! Map ||
      source['convert'] is! Map) {
    throw const DataFailure('invalid_response');
  }
  final congregationId = source['congregation_id'] as String;
  final person = Map<String, Object?>.from(source['person'] as Map);
  final convert = Map<String, Object?>.from(source['convert'] as Map);
  if (!isUuidShape(congregationId) ||
      !_hasExactKeys(person, {'name', 'phone', 'birth_date', 'address'}) ||
      !_hasExactKeys(convert, {
        'landmark',
        'gender',
        'conversion_date',
        'worship_type',
        'age',
      }) ||
      person['name'] is! String ||
      (person['phone'] != null && person['phone'] is! String) ||
      (person['birth_date'] != null && person['birth_date'] is! String) ||
      (person['address'] != null && person['address'] is! Map) ||
      convert['landmark'] is! String ||
      !{'male', 'female'}.contains(convert['gender']) ||
      convert['conversion_date'] is! String ||
      convert['worship_type'] is! String ||
      (convert['age'] != null && convert['age'] is! int)) {
    throw const DataFailure('invalid_response');
  }
  if (person['address'] is Map) {
    final address = Map<String, Object?>.from(person['address'] as Map);
    if (!_hasExactKeys(address, {
      'street',
      'district',
      'city',
      'postal_code',
      'state_code',
    })) {
      throw const DataFailure('invalid_response');
    }
    for (final value in address.values) {
      if (value != null && value is! String) {
        throw const DataFailure('invalid_response');
      }
    }
    person['address'] = Map<String, Object?>.unmodifiable(address);
  }
  final birthDate = person['birth_date'] as String?;
  final conversionDate = convert['conversion_date'] as String;
  try {
    if (birthDate != null) DateOnly.parse(birthDate);
    DateOnly.parse(conversionDate);
  } on FormatException {
    throw const DataFailure('invalid_response');
  }
  return Map<String, Object?>.unmodifiable({
    'congregation_id': congregationId,
    'person': Map<String, Object?>.unmodifiable(person),
    'convert': Map<String, Object?>.unmodifiable(convert),
  });
}

bool _validCursor(String value) =>
    value.length <= 512 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

bool _hasExactKeys(Map value, Set<String> expected) =>
    value.length == expected.length && value.keys.toSet().containsAll(expected);
