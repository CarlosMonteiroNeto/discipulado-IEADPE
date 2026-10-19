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

class MinistryPersonSummary {
  const MinistryPersonSummary({
    required this.id,
    required this.congregationId,
    required this.name,
    required this.normalizedName,
    required this.phone,
    required this.birthDate,
    required this.address,
    required this.revision,
  });

  final String id;
  final String congregationId;
  final String name;
  final String normalizedName;
  final String? phone;
  final CalendarDate? birthDate;
  final Address? address;
  final int revision;
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

MinistryPage<MinistryPersonSummary> decodePeoplePage(Object? raw) {
  final json = _object(raw);
  _exactKeys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final people = items
      .map((item) {
        final row = _object(item);
        _exactKeys(row, {
          'id',
          'congregation_id',
          'name',
          'normalized_name',
          'phone',
          'birth_date',
          'address',
          'person_revision',
        });
        final revision = row['person_revision'];
        if (revision is! int || revision < 1) _invalid();
        final rawAddress = row['address'];
        if (rawAddress != null) {
          final address = _object(rawAddress);
          _exactKeys(address, {
            'street',
            'district',
            'city',
            'postal_code',
            'state_code',
          });
        }
        final name = _text(row['name']);
        final normalizedName = _text(row['normalized_name']);
        if (name != name.trim() || normalizedName != name.toLowerCase()) {
          _invalid();
        }
        return MinistryPersonSummary(
          id: _uuid(row['id']),
          congregationId: _uuid(row['congregation_id']),
          name: name,
          normalizedName: normalizedName,
          phone: _optionalPhoneText(row['phone']),
          birthDate: row['birth_date'] == null
              ? null
              : CalendarDate.parse(_text(row['birth_date'])),
          address: rawAddress == null
              ? null
              : Address.fromJson(Map<String, Object?>.from(rawAddress as Map)),
          revision: revision,
        );
      })
      .toList(growable: false);
  final nextCursor = _optionalText(json['next_cursor']);
  if (nextCursor != null && nextCursor.length > 4096) _invalid();
  return MinistryPage(items: List.unmodifiable(people), nextCursor: nextCursor);
}

MinistryRoster decodeRoster(Object? raw) {
  final json = _object(raw);
  _keys(json, {'session', 'roster'});
  final sessionJson = _object(json['session']);
  sessionJson.putIfAbsent('legacy_firebase_id', () => null);
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
          'person_id',
          'revision',
          'person_revision',
          'created_at',
          'updated_at',
          'updated_by',
        });
        studentJson['archived'] = studentJson.remove('archived_at') != null;
        studentJson['legacy_firebase_id'] = null;
        _exactKeys(studentJson, {
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
          'archived',
          'person_id',
          'person_revision',
          'revision',
          'created_at',
          'updated_at',
          'updated_by',
          'legacy_firebase_id',
        });
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

/// Decode the scoped person envelope with every canonical field and its own
/// revision. The result must not be mistaken for an academic revision.
MinistryPerson decodeMinistryPersonDetail(Object? raw) {
  final json = _object(raw);
  _exactKeys(json, {'person', 'person_revision'});
  final revision = json['person_revision'];
  if (revision is! int || revision < 1) _invalid();
  final person = _object(json['person']);
  _exactKeys(person, {
    'id',
    'congregation_id',
    'name',
    'normalized_name',
    'phone',
    'birth_date',
    'address',
    'created_at',
    'updated_at',
    'updated_by',
  });
  final address = person['address'];
  if (address != null) {
    final addressJson = _object(address);
    _exactKeys(addressJson, {
      'street',
      'district',
      'city',
      'postal_code',
      'state_code',
    });
  }
  return MinistryPerson.fromJson(person, revision: revision);
}

/// Decode the explicit identity-link result without collapsing either row's
/// revision into the generic `{id, revision}` command shape.
StudentPersonLinkResult decodeStudentPersonLinkResult(
  Object? raw, {
  required String expectedStudentId,
  required String expectedPersonId,
  required int expectedStudentRevision,
  required int expectedPersonRevision,
}) {
  final json = _object(raw);
  _exactKeys(json, {
    'student_id',
    'person_id',
    'student_revision',
    'person_revision',
  });
  final result = StudentPersonLinkResult.fromJson(json);
  if (result.studentId != expectedStudentId ||
      result.personId != expectedPersonId ||
      result.studentRevision != expectedStudentRevision + 1 ||
      result.personRevision != expectedPersonRevision) {
    _invalid();
  }
  return result;
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
  final revision = json['revision'];
  if (json['id'] != expectedId || revision is! int || revision < 1) {
    _invalid();
  }
  return MinistryCommandResult(
    id: expectedId,
    revision: revision,
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
    return Map<String, Object?>.from(raw);
  } catch (_) {
    _invalid();
  }
}

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) _invalid();
}

void _exactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      !value.keys.toSet().containsAll(expected)) {
    _invalid();
  }
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

String _uuid(Object? value) {
  final text = _text(value);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(text)) {
    _invalid();
  }
  return text;
}

String? _optionalUuid(Object? value) => value == null ? null : _uuid(value);
Never _invalid() =>
    throw const MinistryDataException('Invalid ministry response.');
