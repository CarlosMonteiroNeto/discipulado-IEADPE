import '../domain/ministry_models.dart';
import '../../../domain/models.dart' show AccessRole;

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
    required this.birthDate,
    required this.archivedAt,
    required this.revision,
    required this.email,
    required this.userAccessId,
  });
  final String id, name, normalizedName, scope;
  final String? congregationId, roleCode, phoneE164;
  final CalendarDate? birthDate;
  final DateTime? archivedAt;
  final int revision;
  final String? email, userAccessId;
}

class MinistryPage<T> {
  const MinistryPage({required this.items, required this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

/// Existing user-access rows that are not linked to a ministry contact.
/// The projection intentionally excludes the bound Auth user ID.
class TeamAccessCandidate {
  const TeamAccessCandidate({
    required this.id,
    required this.email,
    required this.role,
    required this.scope,
    required this.congregationId,
  });

  final String id;
  final String email;
  final AccessRole role;
  final ContactScope scope;
  final String? congregationId;
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

class MinistryContactDetail {
  const MinistryContactDetail({required this.contact, required this.access});

  final MinistryContact contact;
  final TeamAccessAssignment? access;
}

class MinistryContactAccessResult {
  const MinistryContactAccessResult({
    required this.id,
    required this.revision,
    required this.accessId,
  });

  final String id;
  final int revision;
  final String accessId;
}

class MinistryContactAccessRevocationResult {
  const MinistryContactAccessRevocationResult({
    required this.id,
    required this.revision,
    required this.revokedAccessId,
  });

  final String id;
  final int revision;
  final String revokedAccessId;
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

class MinistrySessionSummary {
  const MinistrySessionSummary({
    required this.id,
    required this.classId,
    required this.congregationId,
    required this.date,
    required this.topic,
    required this.status,
    required this.revision,
  });

  final String id;
  final String classId;
  final String congregationId;
  final CalendarDate date;
  final String? topic;
  final SessionStatus status;
  final int revision;
}

MinistryPage<MinistryDirectoryEntry> decodeDirectoryPage(Object? raw) {
  final json = _object(raw);
  _keys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final decoded = items
      .map((item) {
        final row = _object(item);
        _exactKeys(row, {
          'id',
          'name',
          'normalized_name',
          'scope',
          'congregation_id',
          'role_code',
          'phone_e164',
          'birth_date',
          'email',
          'archived_at',
          'revision',
          'user_access_id',
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
        final revision = row['revision'];
        if (revision is! int || revision < 1) _invalid();
        return MinistryDirectoryEntry(
          id: id,
          name: _text(row['name']),
          normalizedName: _text(row['normalized_name']),
          scope: scope,
          congregationId: congregation,
          roleCode: roleCode,
          phoneE164: _optionalText(row['phone_e164']),
          birthDate: row['birth_date'] == null
              ? null
              : CalendarDate.parse(_text(row['birth_date'])),
          archivedAt: _optionalTimestamp(row['archived_at']),
          revision: revision,
          email: _optionalNormalizedEmail(row['email']),
          userAccessId: _optionalUuid(row['user_access_id']),
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(decoded),
    nextCursor: _optionalText(json['next_cursor']),
  );
}

MinistryPage<TeamAccessCandidate> decodeAccessCandidatePage(Object? raw) {
  final json = _object(raw);
  _exactKeys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  String? previousId;
  final candidates = items
      .map((item) {
        final row = _object(item);
        _exactKeys(row, {'id', 'email', 'role', 'scope', 'congregation_id'});
        final id = _uuid(row['id']);
        if (previousId != null && id.compareTo(previousId!) <= 0) _invalid();
        previousId = id;
        final email = _optionalNormalizedEmail(row['email']);
        if (email == null) _invalid();
        late final AccessRole role;
        try {
          role = AccessRole.fromWire(_text(row['role']));
        } on FormatException {
          _invalid();
        }
        final scope = ContactScope.fromWire(_text(row['scope']));
        final congregationId = _optionalUuid(row['congregation_id']);
        if ((scope == ContactScope.congregation) != (congregationId != null) ||
            (role == AccessRole.direction) !=
                (scope == ContactScope.congregation)) {
          _invalid();
        }
        return TeamAccessCandidate(
          id: id,
          email: email,
          role: role,
          scope: scope,
          congregationId: congregationId,
        );
      })
      .toList(growable: false);
  return MinistryPage(
    items: List.unmodifiable(candidates),
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

MinistryStudentDetail decodeMinistryStudentDetail(Object? raw) {
  final envelope = _object(raw);
  _exactKeys(envelope, {'student'});
  final row = _object(envelope['student']);
  _exactKeys(row, {
    'id',
    'person_id',
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
    'person_revision',
    'link_state',
    'created_at',
    'updated_at',
    'updated_by',
  });
  final revision = row['revision'];
  final rawPersonRevision = row['person_revision'];
  if (revision is! int ||
      revision < 1 ||
      (rawPersonRevision != null &&
          (rawPersonRevision is! int || rawPersonRevision < 1))) {
    _invalid();
  }
  final personId = _optionalUuid(row['person_id']);
  final personRevision = rawPersonRevision as int?;
  final linkState = switch (_text(row['link_state'])) {
    'linked' => PersonLinkState.linked,
    'unlinked' => PersonLinkState.unlinked,
    _ => _invalid(),
  };
  if ((personId != null) != (linkState == PersonLinkState.linked) ||
      (personId == null) != (personRevision == null)) {
    _invalid();
  }
  final name = _text(row['name']);
  final normalizedName = _text(row['normalized_name']);
  if (name != name.trim() || normalizedName != name.toLowerCase()) _invalid();
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
  final waterBaptized = _nullableBool(row['water_baptized']);
  final wantsBaptism = _nullableBool(row['wants_baptism']);
  final newConvert = _nullableBool(row['new_convert']);
  if (waterBaptized == true && wantsBaptism == true) _invalid();
  return MinistryStudentDetail(
    id: _uuid(row['id']),
    personId: personId,
    congregationId: _uuid(row['congregation_id']),
    name: name,
    normalizedName: normalizedName,
    phoneE164: _optionalPhoneText(row['phone_e164']),
    birthDate: row['birth_date'] == null
        ? null
        : CalendarDate.parse(_text(row['birth_date'])),
    address: rawAddress == null
        ? null
        : Address.fromJson(Map<String, Object?>.from(rawAddress as Map)),
    education: _optionalText(row['education']),
    maritalStatus: _optionalText(row['marital_status']),
    newConvert: newConvert,
    waterBaptized: waterBaptized,
    wantsBaptism: wantsBaptism,
    archivedAt: _optionalTimestamp(row['archived_at']),
    revision: revision,
    personRevision: personRevision,
    linkState: linkState,
    createdAt: _requiredTimestamp(row['created_at']),
    updatedAt: _requiredTimestamp(row['updated_at']),
    updatedBy: _optionalUuid(row['updated_by']),
  );
}

MinistryTeacherContactDetail decodeTeacherContactDetail(Object? raw) {
  final envelope = _object(raw);
  _exactKeys(envelope, {'contact'});
  final row = _object(envelope['contact']);
  _exactKeys(row, {
    'id',
    'congregation_id',
    'name',
    'phone_e164',
    'birth_date',
    'revision',
  });
  final revision = row['revision'];
  if (revision is! int || revision < 1) _invalid();
  return MinistryTeacherContactDetail(
    id: _uuid(row['id']),
    congregationId: _uuid(row['congregation_id']),
    name: _text(row['name']),
    phoneE164: _optionalPhoneText(row['phone_e164']),
    birthDate: row['birth_date'] == null
        ? null
        : CalendarDate.parse(_text(row['birth_date'])),
    revision: revision,
  );
}

MinistryContactDetail decodeMinistryContactDetail(Object? raw) {
  final envelope = _object(raw);
  _exactKeys(envelope, {'contact', 'access'});
  final contactJson = _object(envelope['contact']);
  _exactKeys(contactJson, {
    'id',
    'name',
    'normalized_name',
    'scope',
    'congregation_id',
    'role_code',
    'phone_e164',
    'birth_date',
    'email',
    'archived_at',
    'revision',
    'user_access_id',
    'access_linked',
    'created_at',
    'updated_at',
    'updated_by',
  });
  final archivedAt = _optionalTimestamp(contactJson['archived_at']);
  final modelJson = <String, Object?>{
    ...contactJson,
    'archived': archivedAt != null,
  }..remove('archived_at');
  final contact = MinistryContact.fromJson(modelJson);
  final rawAccess = envelope['access'];
  final access = rawAccess == null
      ? null
      : TeamAccessAssignment.fromJson(_object(rawAccess));
  if ((contact.userAccessId == null) != (access == null) ||
      (access != null &&
          (access.id != contact.userAccessId ||
              access.userEmail != contact.email ||
              (contact.scope == ContactScope.congregation) !=
                  (access.role == AccessRole.direction) ||
              access.congregationId != contact.congregationId))) {
    _invalid();
  }
  return MinistryContactDetail(contact: contact, access: access);
}

MinistryContactAccessResult decodeMinistryContactAccessResult(
  Object? raw, {
  String? expectedId,
  int? expectedRevision,
}) {
  final json = _object(raw);
  _exactKeys(json, {'id', 'revision', 'access_id'});
  final revision = json['revision'];
  if (revision is! int ||
      revision < 1 ||
      (expectedId != null && json['id'] != expectedId) ||
      (expectedRevision != null && revision != expectedRevision)) {
    _invalid();
  }
  return MinistryContactAccessResult(
    id: _uuid(json['id']),
    revision: revision,
    accessId: _uuid(json['access_id']),
  );
}

MinistryContactAccessRevocationResult
decodeMinistryContactAccessRevocationResult(
  Object? raw, {
  required String expectedId,
  required int expectedRevision,
}) {
  final json = _object(raw);
  _exactKeys(json, {'id', 'revision', 'revoked_access_id'});
  final revision = json['revision'];
  if (json['id'] != expectedId ||
      revision is! int ||
      revision != expectedRevision) {
    _invalid();
  }
  return MinistryContactAccessRevocationResult(
    id: _uuid(json['id']),
    revision: revision,
    revokedAccessId: _uuid(json['revoked_access_id']),
  );
}

MinistryEnrollmentResult decodeMinistryEnrollmentResult(
  Object? raw, {
  required String expectedId,
  required String expectedPersonId,
}) {
  final row = _object(raw);
  _exactKeys(row, {
    'id',
    'student_id',
    'person_id',
    'revision',
    'student_revision',
  });
  final revision = row['revision'];
  final studentRevision = row['student_revision'];
  if (revision is! int ||
      revision < 1 ||
      studentRevision is! int ||
      studentRevision < 1 ||
      row['id'] != expectedId ||
      row['person_id'] != expectedPersonId) {
    _invalid();
  }
  return MinistryEnrollmentResult(
    id: _uuid(row['id']),
    studentId: _uuid(row['student_id']),
    personId: _uuid(row['person_id']),
    revision: revision,
    studentRevision: studentRevision,
  );
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

MinistryPage<MinistrySessionSummary> decodeClassSessions(
  Map<String, dynamic> json, {
  required String congregationId,
  required String classId,
}) {
  _exactKeys(json, {'items', 'next_cursor'});
  final items = json['items'];
  if (items is! List || items.length > 100) _invalid();
  final decoded = items
      .map((item) {
        final row = _object(item);
        _exactKeys(row, {
          'id',
          'class_id',
          'congregation_id',
          'date',
          'topic',
          'status',
          'revision',
        });
        final rowClassId = _uuid(row['class_id']);
        final rowCongregationId = _uuid(row['congregation_id']);
        final revision = row['revision'];
        if (rowClassId != classId ||
            rowCongregationId != congregationId ||
            revision is! int ||
            revision < 1) {
          _invalid();
        }
        final status = _text(row['status']);
        final rawTopic = row['topic'];
        if (rawTopic != null && rawTopic is! String) _invalid();
        final topic = rawTopic as String?;
        try {
          return MinistrySessionSummary(
            id: _uuid(row['id']),
            classId: rowClassId,
            congregationId: rowCongregationId,
            date: CalendarDate.parse(_text(row['date'])),
            topic: topic,
            status: SessionStatus.fromWire(status),
            revision: revision,
          );
        } on MinistryDataException {
          _invalid();
        }
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

String? _optionalNormalizedEmail(Object? value) {
  final email = _optionalText(value);
  if (email != null &&
      (email != email.trim().toLowerCase() || !email.contains('@'))) {
    _invalid();
  }
  return email;
}

String? _optionalPhoneText(Object? value) {
  if (value == null) return null;
  if (value is! String) _invalid();
  return value;
}

bool? _nullableBool(Object? value) {
  if (value == null) return null;
  if (value is! bool) _invalid();
  return value;
}

DateTime? _optionalTimestamp(Object? value) =>
    value == null ? null : _requiredTimestamp(value);

DateTime _requiredTimestamp(Object? value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !text.contains('T')) _invalid();
  return parsed.toUtc();
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
