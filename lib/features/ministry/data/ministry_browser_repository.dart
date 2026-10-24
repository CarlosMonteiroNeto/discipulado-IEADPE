import '../../../data/supabase_gateway.dart';
import '../../../domain/uuid_shape.dart';
import '../domain/ministry_models.dart';
import 'ministry_codec.dart';

class MinistryStudentSummary {
  const MinistryStudentSummary({
    required this.id,
    required this.personId,
    required this.congregationId,
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.address,
    required this.education,
    required this.maritalStatus,
    required this.newConvert,
    required this.waterBaptized,
    required this.wantsBaptism,
    required this.archivedAt,
    required this.revision,
    required this.personRevision,
    required this.linkState,
  });
  final String id;
  final String? personId;
  final String congregationId;
  final String name;
  final String? phone;
  final CalendarDate? birthDate;
  final Address? address;
  final String? education;
  final String? maritalStatus;
  final bool? newConvert;
  final bool? waterBaptized;
  final bool? wantsBaptism;
  final DateTime? archivedAt;
  final int revision;
  final int? personRevision;
  final PersonLinkState linkState;
}

class MinistryClassSummary {
  const MinistryClassSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.revision,
    required this.teacherContactId,
  });
  final String id;
  final String name;
  final ClassStatus status;
  final String startDate;
  final String? endDate;
  final int revision;
  final String? teacherContactId;
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
  static const pageSize = 99;
  MinistryCongregationDirectoryPager(this.repository);
  final MinistryBrowserRepository repository;

  MinistryPage<MinistryCongregationChoice>? page;
  String? _currentCursor;
  final List<String?> _previousCursors = [];

  bool get hasPrevious => _previousCursors.isNotEmpty;
  bool get hasNext => page?.nextCursor != null;
  int get pageNumber => _previousCursors.length + 1;

  Future<MinistryPage<MinistryCongregationChoice>> loadFirst() async {
    final nextPage = await repository.listCongregations(limit: pageSize);
    page = nextPage;
    _currentCursor = null;
    _previousCursors.clear();
    return nextPage;
  }

  Future<MinistryPage<MinistryCongregationChoice>?> next() async {
    final cursor = page?.nextCursor;
    if (cursor == null) return null;
    final nextPage = await repository.listCongregations(
      limit: pageSize,
      cursor: cursor,
    );
    _previousCursors.add(_currentCursor);
    _currentCursor = cursor;
    page = nextPage;
    return nextPage;
  }

  Future<MinistryPage<MinistryCongregationChoice>?> previous() async {
    if (_previousCursors.isEmpty) return null;
    final cursor = _previousCursors.last;
    final previousPage = await repository.listCongregations(
      limit: pageSize,
      cursor: cursor,
    );
    _previousCursors.removeLast();
    _currentCursor = cursor;
    page = previousPage;
    return previousPage;
  }
}

/// Adds the active option beside the current page without exceeding 100 items.
List<MinistryCongregationChoice> visibleCongregationChoices({
  required List<MinistryCongregationChoice> page,
  required String? selectedId,
  required String? selectedName,
}) {
  if (selectedId == null ||
      selectedName == null ||
      page.any((item) => item.id == selectedId)) {
    return List.unmodifiable(page);
  }
  return List.unmodifiable([
    MinistryCongregationChoice(id: selectedId, name: selectedName),
    ...page,
  ]);
}

MinistryPage<MinistryStudentSummary> _studentPage(Object? raw) {
  final page = _pageObject(raw);
  final items = page['items'];
  if (items is! List || items.length > 100) _invalid();
  final rows = items
      .map((item) {
        final row = _row(item, {
          'id',
          'person_id',
          'congregation_id',
          'name',
          'phone',
          'birth_date',
          'address',
          'education',
          'marital_status',
          'new_convert',
          'water_baptized',
          'wants_baptism',
          'archived_at',
          'revision',
          'person_revision',
          'link_state',
        });
        final revision = row['revision'];
        if (revision is! int || revision < 1) {
          _invalid();
        }
        final personId = _optionalUuidValue(row['person_id']);
        final personRevision = row['person_revision'];
        if (personRevision != null &&
            (personRevision is! int || personRevision < 1)) {
          _invalid();
        }
        final linkState = switch (_text(row['link_state'])) {
          'linked' => PersonLinkState.linked,
          'unlinked' => PersonLinkState.unlinked,
          _ => _invalid(),
        };
        if ((personId != null) != (linkState == PersonLinkState.linked) ||
            (personId == null) != (personRevision == null)) {
          _invalid();
        }
        final congregationId = _uuidValue(row['congregation_id']);
        final rawAddress = row['address'];
        if (rawAddress != null && rawAddress is! Map) _invalid();
        final rawBirthDate = row['birth_date'];
        final rawArchivedAt = row['archived_at'];
        final rawNewConvert = row['new_convert'];
        final rawWaterBaptized = row['water_baptized'];
        final rawWantsBaptism = row['wants_baptism'];
        for (final answer in [
          rawNewConvert,
          rawWaterBaptized,
          rawWantsBaptism,
        ]) {
          if (answer != null && answer is! bool) _invalid();
        }
        final waterBaptized = rawWaterBaptized as bool?;
        final wantsBaptism = rawWantsBaptism as bool?;
        if (waterBaptized == true && wantsBaptism == true) _invalid();
        return MinistryStudentSummary(
          id: _uuidValue(row['id']),
          personId: personId,
          congregationId: congregationId,
          name: _text(row['name']),
          phone: _optionalPhoneText(row['phone']),
          birthDate: rawBirthDate == null
              ? null
              : CalendarDate.parse(_date(rawBirthDate)),
          address: rawAddress == null
              ? null
              : Address.fromJson(Map<String, Object?>.from(rawAddress as Map)),
          education: _optionalText(row['education']),
          maritalStatus: _optionalText(row['marital_status']),
          newConvert: rawNewConvert as bool?,
          waterBaptized: waterBaptized,
          wantsBaptism: wantsBaptism,
          archivedAt: rawArchivedAt == null ? null : _timestamp(rawArchivedAt),
          revision: revision,
          personRevision: personRevision as int?,
          linkState: linkState,
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(rows),
    nextCursor: _cursor(page['next_cursor']),
  );
}

DateTime _timestamp(Object? value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !text.contains('T')) _invalid();
  return parsed.toUtc();
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
          'teacher_contact_id',
        });
        final revision = row['revision'];
        if (revision is! int || revision < 1) {
          _invalid();
        }
        final start = _date(row['start_date']);
        final end = row['end_date'] == null ? null : _date(row['end_date']);
        return MinistryClassSummary(
          id: _uuidValue(row['id']),
          name: _text(row['name']),
          status: ClassStatus.fromWire(_text(row['status'])),
          startDate: start,
          endDate: end,
          revision: revision,
          teacherContactId: _optionalUuidValue(row['teacher_contact_id']),
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
      !row.keys.toSet().containsAll(keys)) {
    _invalid();
  }
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

String? _optionalPhoneText(Object? value) {
  if (value == null) return null;
  if (value is! String) _invalid();
  return value;
}

String _uuidValue(Object? value) {
  final text = _text(value);
  if (!_isUuid(text)) _invalid();
  return text;
}

String? _optionalUuidValue(Object? value) =>
    value == null ? null : _uuidValue(value);
bool _isUuid(String value) => isUuidShape(value);
String _date(Object? value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null ||
      text.length != 10 ||
      '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
          text) {
    _invalid();
  }
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
  if (limit < 1 || limit > 100 || (cursor?.length ?? 0) > 4096) {
    throw const DataFailure('invalid');
  }
}

Never _invalid() =>
    throw const MinistryDataException('Invalid ministry browse response.');
