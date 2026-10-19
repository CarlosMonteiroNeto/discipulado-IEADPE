import '../../../data/supabase_gateway.dart';
import '../domain/ministry_models.dart';

class ConvertReferral {
  const ConvertReferral({
    required this.convertId,
    required this.congregationId,
    required this.name,
    required this.phone,
    required this.address,
    required this.conversionDate,
  });

  final String convertId;
  final String congregationId;
  final String name;
  final String? phone;
  final String? address;
  final String conversionDate;
}

class HandoffStudentCandidate {
  const HandoffStudentCandidate({
    required this.studentId,
    required this.name,
    required this.phone,
    required this.address,
  });

  final String studentId;
  final String name;
  final String? phone;
  final Address? address;
}

class ConvertPromotionResult {
  const ConvertPromotionResult({
    required this.convertId,
    required this.studentId,
    required this.personId,
    required this.congregationId,
    required this.status,
  });

  final String convertId;
  final String studentId;
  final String personId;
  final String congregationId;
  final String status;
}

class HandoffPage<T> {
  const HandoffPage({required this.items, required this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

/// Typed, bounded RPC adapter for convert referral review and promotion.
class MinistryHandoffRepository {
  MinistryHandoffRepository(this.gateway);
  final ReadRpcGateway gateway;

  Future<HandoffPage<ConvertReferral>> listConvertReferrals({
    required String congregationId,
    int limit = 50,
    String? cursor,
  }) async {
    _checkUuid(congregationId);
    _page(limit, cursor);
    final token = gateway.context;
    final raw = await gateway.readRpc(
      'ministry_list_convert_referrals',
      context: token,
      parameters: {
        'congregation_id': congregationId,
        'limit': limit,
        'cursor': cursor,
      },
    );
    gateway.ensureCurrent(token);
    try {
      return decodeConvertReferralPage(raw);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<HandoffPage<HandoffStudentCandidate>> listStudentCandidates({
    required String congregationId,
    required String namePrefix,
    int limit = 50,
    String? cursor,
  }) async {
    _checkUuid(congregationId);
    if (namePrefix.trim().isEmpty || namePrefix != namePrefix.trim()) {
      throw const DataFailure('invalid');
    }
    _page(limit, cursor);
    final token = gateway.context;
    final raw = await gateway.readRpc(
      'ministry_list_convert_student_candidates',
      context: token,
      parameters: {
        'congregation_id': congregationId,
        'name_prefix': namePrefix,
        'limit': limit,
        'cursor': cursor,
      },
    );
    gateway.ensureCurrent(token);
    try {
      return decodeHandoffCandidatePage(raw);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<ConvertPromotionResult> promote({
    required String operationId,
    required String convertId,
    required String congregationId,
    String? studentId,
    int? expectedStudentRevision,
  }) async {
    _checkUuid(operationId);
    _checkUuid(convertId);
    _checkUuid(congregationId);
    if (studentId != null) _checkUuid(studentId);
    if ((studentId == null) != (expectedStudentRevision == null) ||
        (expectedStudentRevision != null && expectedStudentRevision < 1)) {
      throw const DataFailure('invalid');
    }
    final commandGateway = gateway;
    if (commandGateway is! HandoffCommandGateway) {
      throw const DataFailure('unavailable');
    }
    try {
      return decodePromotionResult(
        await (commandGateway as HandoffCommandGateway).promoteConvertToStudent(
          operationId,
          {
            'convert_id': convertId,
            'congregation_id': congregationId,
            'student_id': studentId,
            if (expectedStudentRevision != null)
              'expected_student_revision': expectedStudentRevision,
          },
        ),
      );
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }
}

HandoffPage<ConvertReferral> decodeConvertReferralPage(Object? raw) {
  final json = _object(raw, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final entries = items
      .map((item) {
        final row = _object(item, {
          'convert_id',
          'congregation_id',
          'name',
          'phone',
          'address',
          'conversion_date',
        });
        final date = _text(row['conversion_date']);
        final parsed = DateTime.tryParse(date);
        if (parsed == null ||
            date.length != 10 ||
            '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
                date) {
          _invalid();
        }
        return ConvertReferral(
          convertId: _parseUuid(row['convert_id']),
          congregationId: _parseUuid(row['congregation_id']),
          name: _text(row['name']),
          phone: _optionalText(row['phone']),
          address: _optionalText(row['address']),
          conversionDate: date,
        );
      })
      .toList(growable: false);
  return HandoffPage(
    items: List.unmodifiable(entries),
    nextCursor: _cursor(json['next_cursor']),
  );
}

HandoffPage<HandoffStudentCandidate> decodeHandoffCandidatePage(Object? raw) {
  final json = _object(raw, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final entries = items
      .map((item) {
        final row = _object(item, {'student_id', 'name', 'phone', 'address'});
        final address = row['address'];
        if (address != null && address is! Map) _invalid();
        return HandoffStudentCandidate(
          studentId: _parseUuid(row['student_id']),
          name: _text(row['name']),
          phone: _optionalText(row['phone']),
          address: address == null
              ? null
              : Address.fromJson(Map<String, Object?>.from(address as Map)),
        );
      })
      .toList(growable: false);
  return HandoffPage(
    items: List.unmodifiable(entries),
    nextCursor: _cursor(json['next_cursor']),
  );
}

ConvertPromotionResult decodePromotionResult(Object? raw) {
  final json = _object(raw, {
    'convert_id',
    'student_id',
    'person_id',
    'congregation_id',
    'status',
  });
  final status = _text(json['status']);
  if (status != 'linked') _invalid();
  return ConvertPromotionResult(
    convertId: _parseUuid(json['convert_id']),
    studentId: _parseUuid(json['student_id']),
    personId: _parseUuid(json['person_id']),
    congregationId: _parseUuid(json['congregation_id']),
    status: status,
  );
}

Map<String, Object?> _object(Object? raw, Set<String> keys) {
  if (raw is! Map) _invalid();
  final value = Map<String, Object?>.from(raw);
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      !value.keys.toSet().containsAll(keys)) {
    _invalid();
  }
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) _invalid();
  return value;
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  return _text(value);
}

String _parseUuid(Object? value) {
  final text = _text(value);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(text)) {
    _invalid();
  }
  return text;
}

String? _cursor(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 4096) _invalid();
  return value;
}

void _checkUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    throw const DataFailure('invalid');
  }
}

void _page(int limit, String? cursor) {
  if (limit < 1 || limit > 100 || (cursor?.length ?? 0) > 4096) {
    throw const DataFailure('invalid');
  }
}

Never _invalid() =>
    throw const MinistryDataException('Invalid handoff response.');
