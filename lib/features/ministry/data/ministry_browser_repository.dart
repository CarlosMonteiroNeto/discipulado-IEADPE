import '../../../data/supabase_gateway.dart';
import '../domain/ministry_models.dart';
import 'ministry_codec.dart';

class MinistryStudentSummary {
  const MinistryStudentSummary({
    required this.id,
    required this.name,
    required this.phoneE164,
    required this.convertId,
    required this.revision,
  });
  final String id;
  final String name;
  final String? phoneE164;
  final String? convertId;
  final int revision;
}

class MinistryClassSummary {
  const MinistryClassSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.revision,
  });
  final String id;
  final String name;
  final ClassStatus status;
  final String startDate;
  final String? endDate;
  final int revision;
}

class MinistryCongregationChoice {
  const MinistryCongregationChoice({required this.id, required this.name});
  final String id;
  final String name;
}

/// Bounded congregation-specific pages used by ministry browse and enrollment UI.
class MinistryBrowserRepository {
  MinistryBrowserRepository(this.gateway);
  final ReadRpcGateway gateway;

  Future<MinistryPage<MinistryCongregationChoice>> listCongregations({
    int limit = 100,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 100 || (cursor?.length ?? 0) > 64) {
      throw const DataFailure('invalid');
    }
    final raw = await _read('ministry_list_congregations', {
      'limit': limit,
      'cursor': cursor,
    });
    try {
      final page = _pageObject(raw);
      final items = page['items'];
      if (items is! List || items.length > 100) _invalid();
      final choices = items
          .map((item) {
            final row = _row(item, {'id', 'name'});
            return MinistryCongregationChoice(
              id: _uuidValue(row['id']),
              name: _text(row['name']),
            );
          })
          .toList(growable: false);
      final next = _cursor(page['next_cursor']);
      if (next != null) _uuid(next);
      return MinistryPage(items: List.unmodifiable(choices), nextCursor: next);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryPage<MinistryStudentSummary>> listStudents({
    required String congregationId,
    String? namePrefix,
    int limit = 50,
    String? cursor,
  }) async {
    _uuid(congregationId);
    _validatePage(limit, cursor);
    if (namePrefix != null &&
        (namePrefix.trim().isEmpty ||
            namePrefix != namePrefix.trim() ||
            namePrefix.length > 200)) {
      throw const DataFailure('invalid');
    }
    final raw = await _read('ministry_list_students', {
      'congregation_id': congregationId,
      'name_prefix': namePrefix,
      'limit': limit,
      'cursor': cursor,
    });
    try {
      return _studentPage(raw);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryPage<MinistryClassSummary>> listClasses({
    required String congregationId,
    String? status,
    int limit = 50,
    String? cursor,
  }) async {
    _uuid(congregationId);
    _validatePage(limit, cursor);
    if (status != null &&
        !{'active', 'completed', 'archived'}.contains(status)) {
      throw const DataFailure('invalid');
    }
    final raw = await _read('ministry_list_classes', {
      'congregation_id': congregationId,
      'status': status,
      'limit': limit,
      'cursor': cursor,
    });
    try {
      return _classPage(raw);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<Map<String, dynamic>> _read(
    String rpc,
    Map<String, Object?> request,
  ) async {
    final token = gateway.context;
    final result = await gateway.readRpc(
      rpc,
      context: token,
      parameters: request,
    );
    gateway.ensureCurrent(token);
    return result;
  }
}

/// Holds one directory page at a time and fetches adjacent pages on demand.
class MinistryCongregationDirectoryPager {
  MinistryCongregationDirectoryPager(this.repository);
  final MinistryBrowserRepository repository;

  MinistryPage<MinistryCongregationChoice>? page;
  String? _currentCursor;
  final List<String?> _previousCursors = [];

  bool get hasPrevious => _previousCursors.isNotEmpty;
  bool get hasNext => page?.nextCursor != null;
  int get pageNumber => _previousCursors.length + 1;

  Future<MinistryPage<MinistryCongregationChoice>> loadFirst() async {
    final nextPage = await repository.listCongregations();
    page = nextPage;
    _currentCursor = null;
    _previousCursors.clear();
    return nextPage;
  }

  Future<MinistryPage<MinistryCongregationChoice>?> next() async {
    final cursor = page?.nextCursor;
    if (cursor == null) return null;
    final nextPage = await repository.listCongregations(cursor: cursor);
    _previousCursors.add(_currentCursor);
    _currentCursor = cursor;
    page = nextPage;
    return nextPage;
  }

  Future<MinistryPage<MinistryCongregationChoice>?> previous() async {
    if (_previousCursors.isEmpty) return null;
    final cursor = _previousCursors.last;
    final previousPage = await repository.listCongregations(cursor: cursor);
    _previousCursors.removeLast();
    _currentCursor = cursor;
    page = previousPage;
    return previousPage;
  }
}

MinistryPage<MinistryStudentSummary> _studentPage(Object? raw) {
  final page = _pageObject(raw);
  final items = page['items'];
  if (items is! List || items.length > 100) _invalid();
  final rows = items
      .map((item) {
        final row = _row(item, {
          'id',
          'name',
          'phone_e164',
          'convert_id',
          'revision',
        });
        final revision = row['revision'];
        if (revision is! int || revision < 1) _invalid();
        final phone = _optionalText(row['phone_e164']);
        if (phone != null && !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phone))
          _invalid();
        return MinistryStudentSummary(
          id: _uuidValue(row['id']),
          name: _text(row['name']),
          phoneE164: phone,
          convertId: _optionalUuidValue(row['convert_id']),
          revision: revision,
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(rows),
    nextCursor: _cursor(page['next_cursor']),
  );
}

MinistryPage<MinistryClassSummary> _classPage(Object? raw) {
  final page = _pageObject(raw);
  final items = page['items'];
  if (items is! List || items.length > 100) _invalid();
  final rows = items
      .map((item) {
        final row = _row(item, {
          'id',
          'name',
          'status',
          'start_date',
          'end_date',
          'revision',
        });
        final revision = row['revision'];
        if (revision is! int || revision < 1) _invalid();
        final start = _date(row['start_date']);
        final end = row['end_date'] == null ? null : _date(row['end_date']);
        return MinistryClassSummary(
          id: _uuidValue(row['id']),
          name: _text(row['name']),
          status: ClassStatus.fromWire(_text(row['status'])),
          startDate: start,
          endDate: end,
          revision: revision,
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(rows),
    nextCursor: _cursor(page['next_cursor']),
  );
}

Map<String, Object?> _pageObject(Object? raw) =>
    _row(raw, {'items', 'next_cursor'});
Map<String, Object?> _row(Object? raw, Set<String> keys) {
  if (raw is! Map) _invalid();
  final row = Map<String, Object?>.from(raw);
  if (row.keys.toSet().difference(keys).isNotEmpty ||
      !row.keys.toSet().containsAll(keys))
    _invalid();
  return row;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) _invalid();
  return value;
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  return _text(value);
}

String _uuidValue(Object? value) {
  final text = _text(value);
  if (!_isUuid(text)) _invalid();
  return text;
}

String? _optionalUuidValue(Object? value) =>
    value == null ? null : _uuidValue(value);
bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
String _date(Object? value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null ||
      text.length != 10 ||
      '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
          text)
    _invalid();
  return text;
}

String? _cursor(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 4096) _invalid();
  return value;
}

void _uuid(String value) {
  if (!_isUuid(value)) throw const DataFailure('invalid');
}

void _validatePage(int limit, String? cursor) {
  if (limit < 1 || limit > 100 || (cursor?.length ?? 0) > 4096)
    throw const DataFailure('invalid');
}

Never _invalid() =>
    throw const MinistryDataException('Invalid ministry browse response.');
