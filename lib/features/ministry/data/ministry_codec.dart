import '../domain/ministry_models.dart';

/// Safe, transport-independent values returned by ministry read RPCs.
class MinistryDirectoryEntry {
  const MinistryDirectoryEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.scope,
    required this.congregationId,
    required this.roleCode,
    required this.phoneE164,
  });
  final String id, name, normalizedName, scope;
  final String? congregationId, roleCode, phoneE164;
}

class MinistryPage<T> {
  const MinistryPage({required this.items, required this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

class MinistryCommandResult {
  const MinistryCommandResult({
    required this.id,
    required this.revision,
    required this.fields,
  });
  final String id;
  final int revision;
  final Map<String, Object?> fields;
}

class MinistryRoster {
  const MinistryRoster({required this.session, required this.marks});
  final Session session;
  final List<AttendanceMark> marks;
}

class ClassStudentEntry {
  const ClassStudentEntry({required this.student, required this.enrollment});
  final Student student;
  final Enrollment enrollment;
}

class PendingMinistrySession {
  const PendingMinistrySession({
    required this.id,
    required this.classId,
    required this.className,
    required this.congregationId,
    required this.date,
    required this.topic,
  });
  final String id, classId, className, congregationId;
  final CalendarDate date;
  final String? topic;
}

MinistryPage<MinistryDirectoryEntry> decodeDirectoryPage(Object? raw) {
  final json = _object(raw);
  _keys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final decoded = items
      .map((item) {
        final row = _object(item);
        _keys(row, {
          'id',
          'name',
          'normalized_name',
          'scope',
          'congregation_id',
          'role_code',
          'phone_e164',
        });
        final id = _uuid(row['id']);
        final scope = _text(row['scope']);
        if (!{'congregation', 'supervision'}.contains(scope)) _invalid();
        final congregation = _optionalUuid(row['congregation_id']);
        if ((scope == 'congregation') != (congregation != null)) _invalid();
        final roleCode = _optionalText(row['role_code']);
        if (roleCode != null) {
          try {
            if (RoleCode.fromWire(roleCode).scope !=
                ContactScope.fromWire(scope)) {
              _invalid();
            }
          } on MinistryDataException {
            _invalid();
          }
        }
        return MinistryDirectoryEntry(
          id: id,
          name: _text(row['name']),
          normalizedName: _text(row['normalized_name']),
          scope: scope,
          congregationId: congregation,
          roleCode: roleCode,
          phoneE164: _optionalText(row['phone_e164']),
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(decoded),
    nextCursor: _optionalText(json['next_cursor']),
  );
}

MinistryPage<Map<String, Object?>> decodeObjectPage(
  Object? raw, {
  required Set<String> itemKeys,
}) {
  final json = _object(raw);
  _keys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final decoded = items
      .map((item) {
        final row = _object(item);
        _keys(row, itemKeys);
        return Map<String, Object?>.unmodifiable(row);
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(decoded),
    nextCursor: _optionalText(json['next_cursor']),
  );
}

MinistryRoster decodeRoster(Object? raw) {
  final json = _object(raw);
  _keys(json, {'session', 'roster'});
  final sessionJson = _object(json['session']);
  sessionJson['legacy_firebase_id'] ??= null;
  final session = Session.fromJson(sessionJson);
  final roster = json['roster'];
  if (roster is! List || roster.length > 100) _invalid();
  final marks = roster
      .map(
        (row) => AttendanceMark.fromJson({
          ..._object(row),
          'session_id': session.id,
        }),
      )
      .toList(growable: false);
  if (marks.any((mark) => mark.sessionId != session.id)) _invalid();
  return MinistryRoster(session: session, marks: List.unmodifiable(marks));
}

MinistryPage<ClassStudentEntry> decodeClassStudents(Object? raw) {
  final json = _object(raw);
  _keys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final decoded = items
      .map((item) {
        final pair = _object(item);
        _keys(pair, {'student', 'enrollment'});
        final studentJson = _object(pair['student']);
        _keys(studentJson, {
          'id',
          'congregation_id',
          'name',
          'normalized_name',
          'phone_e164',
          'birth_date',
          'address',
          'education',
          'marital_status',
          'new_convert',
          'water_baptized',
          'wants_baptism',
          'archived_at',
          'revision',
          'created_at',
          'updated_at',
          'updated_by',
        });
        studentJson['archived'] = studentJson.remove('archived_at') == null;
        studentJson['legacy_firebase_id'] = null;
        final enrollmentJson = _object(pair['enrollment']);
        enrollmentJson['legacy_firebase_id'] = null;
        return ClassStudentEntry(
          student: Student.fromJson(studentJson),
          enrollment: Enrollment.fromJson(enrollmentJson),
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(decoded),
    nextCursor: _optionalText(json['next_cursor']),
  );
}

MinistryPage<PendingMinistrySession> decodePendingSessions(Object? raw) {
  final json = _object(raw);
  _keys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final decoded = items
      .map((item) {
        final row = _object(item);
        _keys(row, {
          'id',
          'class_id',
          'class_name',
          'congregation_id',
          'date',
          'topic',
          'status',
        });
        if (row['status'] != 'open') _invalid();
        return PendingMinistrySession(
          id: _uuid(row['id']),
          classId: _uuid(row['class_id']),
          className: _text(row['class_name']),
          congregationId: _uuid(row['congregation_id']),
          date: CalendarDate.parse(_text(row['date'])),
          topic: _optionalText(row['topic']),
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(decoded),
    nextCursor: _optionalText(json['next_cursor']),
  );
}

EnrollmentProgress decodeProgress(Object? raw) =>
    EnrollmentProgress.fromJson(_object(raw));

MinistryCommandResult decodeCommandResult(
  Object? raw, {
  required String expectedId,
}) {
  final json = _object(raw);
  if (json['id'] != expectedId ||
      json['revision'] is! int ||
      (json['revision'] as int) < 1)
    _invalid();
  return MinistryCommandResult(
    id: expectedId,
    revision: json['revision'] as int,
    fields: Map.unmodifiable(
      {...json}
        ..remove('id')
        ..remove('revision'),
    ),
  );
}

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map) _invalid();
  try {
    return Map<String, Object?>.from(raw as Map);
  } catch (_) {
    _invalid();
  }
}

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) _invalid();
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) _invalid();
  return value as String;
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  return _text(value);
}

String _uuid(Object? value) {
  final text = _text(value);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(text))
    _invalid();
  return text;
}

String? _optionalUuid(Object? value) => value == null ? null : _uuid(value);
Never _invalid() =>
    throw const MinistryDataException('Invalid ministry response.');
