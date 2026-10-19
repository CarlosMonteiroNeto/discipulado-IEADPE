/// Pure domain values for the ministry Supabase boundary.
library;

import '../../../domain/models.dart' show AccessRole;

typedef MinistryJson = Map<String, Object?>;

class MinistryDataException implements Exception {
  const MinistryDataException(this.message);

  final String message;

  @override
  String toString() => 'MinistryDataException: $message';
}

/// A date without a time zone. It is transported only as `yyyy-MM-dd`.
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory CalendarDate(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw const MinistryDataException('Invalid calendar date.');
    }
    final days = switch (month) {
      2 => _isLeapYear(year) ? 29 : 28,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };
    if (day < 1 || day > days) {
      throw const MinistryDataException('Invalid calendar date.');
    }
    return CalendarDate._(year, month, day);
  }

  factory CalendarDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const MinistryDataException('Expected date in yyyy-MM-dd format.');
    }
    return CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static bool _isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  @override
  int compareTo(CalendarDate other) => (year * 10000 + month * 100 + day)
      .compareTo(other.year * 10000 + other.month * 100 + other.day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Shared persisted metadata. Legacy Firebase IDs remain source lineage only.
class CommonMetadata {
  const CommonMetadata({
    required this.id,
    required this.congregationId,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
    required this.legacyFirebaseId,
  });

  final String id;
  final String? congregationId;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedBy;
  final String? legacyFirebaseId;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'congregation_id': congregationId,
    'revision': revision,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'updated_by': updatedBy,
    'legacy_firebase_id': legacyFirebaseId,
  };

  factory CommonMetadata.fromJson(MinistryJson json) => CommonMetadata(
    id: _uuid(json, 'id'),
    congregationId: _optionalUuid(json, 'congregation_id'),
    revision: _positiveInt(json, 'revision'),
    createdAt: _timestamp(json, 'created_at'),
    updatedAt: _timestamp(json, 'updated_at'),
    updatedBy: _uuid(json, 'updated_by'),
    legacyFirebaseId: _optionalText(json, 'legacy_firebase_id'),
  );
}

/// Every ministry record composes the stable UUID and server metadata.
class MinistryRecord {
  const MinistryRecord({required this.metadata});

  final CommonMetadata metadata;

  String get id => metadata.id;
  String? get congregationId => metadata.congregationId;
  int get revision => metadata.revision;
  DateTime get createdAt => metadata.createdAt;
  DateTime get updatedAt => metadata.updatedAt;
  String get updatedBy => metadata.updatedBy;
  String? get legacyFirebaseId => metadata.legacyFirebaseId;
}

enum ContactScope {
  congregation('congregation'),
  supervision('supervision');

  const ContactScope(this.wire);
  final String wire;

  static ContactScope fromWire(String wire) => _enumByWire(values, wire);
}

enum RoleCode {
  campaignSupervisor('campaignSupervisor', ContactScope.supervision),
  campaignDeputy('campaignDeputy', ContactScope.supervision),
  discipleshipCoordinator('discipleshipCoordinator', ContactScope.supervision),
  discipleshipDeputy('discipleshipDeputy', ContactScope.supervision),
  coordinationSecretary('coordinationSecretary', ContactScope.supervision),
  coordinationDeputySecretary(
    'coordinationDeputySecretary',
    ContactScope.supervision,
  ),
  congregationAssistant('congregationAssistant', ContactScope.congregation),
  campaignLeader('campaignLeader', ContactScope.congregation),
  campaignDeputyLeader('campaignDeputyLeader', ContactScope.congregation),
  teacher('teacher', ContactScope.congregation),
  discipleshipSecretary('discipleshipSecretary', ContactScope.congregation),
  discipleshipDeputySecretary(
    'discipleshipDeputySecretary',
    ContactScope.congregation,
  );

  const RoleCode(this.wire, this.scope);
  final String wire;
  final ContactScope scope;

  static RoleCode fromWire(String wire) => _enumByWire(values, wire);
}

class MinistryContact extends MinistryRecord {
  const MinistryContact({
    required super.metadata,
    required this.name,
    required this.normalizedName,
    required this.scope,
    required this.roleCode,
    required this.phoneE164,
    required this.birthDate,
    required this.archived,
    required this.email,
    required this.accessLinked,
    required this.userAccessId,
  });

  final String name;
  final String normalizedName;
  final ContactScope scope;
  final RoleCode? roleCode;
  final String? phoneE164;
  final CalendarDate? birthDate;
  final bool archived;
  final String? email;
  final bool accessLinked;
  final String? userAccessId;

  factory MinistryContact.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      ..._metadataKeys,
      'scope',
      'name',
      'normalized_name',
      'role_code',
      'phone_e164',
      'birth_date',
      'archived',
      'email',
      'access_linked',
      'user_access_id',
    });
    final metadata = CommonMetadata.fromJson(json);
    final accessLinked = _requiredBool(json, 'access_linked');
    final userAccessId = _optionalUuid(json, 'user_access_id');
    if (userAccessId != null && !accessLinked) {
      throw const MinistryDataException('Contact access link state disagrees.');
    }
    final scope = ContactScope.fromWire(_requiredText(json, 'scope'));
    final congregationId = metadata.congregationId;
    if ((scope == ContactScope.congregation) != (congregationId != null)) {
      throw const MinistryDataException(
        'Contact scope and congregation disagree.',
      );
    }
    final roleCode = _optionalText(json, 'role_code');
    final parsedRole = roleCode == null ? null : RoleCode.fromWire(roleCode);
    if (parsedRole != null && parsedRole.scope != scope) {
      throw const MinistryDataException('Contact role and scope disagree.');
    }
    return MinistryContact(
      metadata: metadata,
      name: _requiredText(json, 'name'),
      normalizedName: _requiredText(json, 'normalized_name'),
      scope: scope,
      roleCode: parsedRole,
      phoneE164: _optionalText(json, 'phone_e164'),
      birthDate: _optionalDate(json, 'birth_date'),
      archived: _requiredBool(json, 'archived'),
      email: _optionalNormalizedEmail(json, 'email'),
      accessLinked: accessLinked,
      userAccessId: userAccessId,
    );
  }
}

/// Login authority remains distinct from a ministry contact's directory role.
class TeamAccessAssignment {
  const TeamAccessAssignment({
    required this.id,
    required this.userEmail,
    required this.role,
    required this.congregationId,
    required this.boundUserId,
  });

  final String id;
  final String userEmail;
  final AccessRole role;
  final String? congregationId;
  final String? boundUserId;

  factory TeamAccessAssignment.fromJson(MinistryJson json) {
    _checkExactKeys(json, const <String>{
      'id',
      'user_email',
      'role',
      'congregation_id',
      'user_id',
    });
    late final AccessRole role;
    try {
      role = AccessRole.fromWire(_requiredText(json, 'role'));
    } on FormatException {
      throw const MinistryDataException('Unknown access role.');
    }
    final congregationId = _optionalUuid(json, 'congregation_id');
    if ((role == AccessRole.direction) != (congregationId != null)) {
      throw const MinistryDataException('Access role and scope disagree.');
    }
    final email = _requiredText(json, 'user_email');
    if (email != email.trim().toLowerCase() || !email.contains('@')) {
      throw const MinistryDataException('Access email is not normalized.');
    }
    return TeamAccessAssignment(
      id: _uuid(json, 'id'),
      userEmail: email,
      role: role,
      congregationId: congregationId,
      boundUserId: _optionalUuid(json, 'user_id'),
    );
  }
}

class Address {
  const Address({
    required this.street,
    required this.district,
    required this.city,
    required this.postalCode,
    required this.stateCode,
  });

  final String? street;
  final String? district;
  final String? city;
  final String? postalCode;
  final String? stateCode;

  factory Address.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      'street',
      'district',
      'city',
      'postal_code',
      'state_code',
    });
    return Address(
      street: _optionalText(json, 'street'),
      district: _optionalText(json, 'district'),
      city: _optionalText(json, 'city'),
      postalCode: _optionalText(json, 'postal_code'),
      stateCode: _optionalText(json, 'state_code'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'street': street,
    'district': district,
    'city': city,
    'postal_code': postalCode,
    'state_code': stateCode,
  };
}

enum PersonLinkState { linked, unlinked }

/// Canonical, congregation-scoped identity and contact fields.
class MinistryPerson {
  const MinistryPerson({
    required this.id,
    required this.congregationId,
    required this.name,
    required this.normalizedName,
    required this.phone,
    required this.birthDate,
    required this.address,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String congregationId;
  final String name;
  final String normalizedName;
  final String? phone;
  final CalendarDate? birthDate;
  final Address? address;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;

  factory MinistryPerson.fromJson(MinistryJson json, {required int revision}) {
    _checkExactKeys(json, const <String>{
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
    if (revision < 1) {
      throw const MinistryDataException('Revision must be positive.');
    }
    final name = _requiredText(json, 'name');
    final normalizedName = _requiredText(json, 'normalized_name');
    if (name != name.trim() || normalizedName != name.toLowerCase()) {
      throw const MinistryDataException('Person name is not normalized.');
    }
    final rawAddress = json['address'];
    if (rawAddress != null && rawAddress is! Map) {
      throw const MinistryDataException('Address must be an object or null.');
    }
    return MinistryPerson(
      id: _uuid(json, 'id'),
      congregationId: _uuid(json, 'congregation_id'),
      name: name,
      normalizedName: normalizedName,
      phone: _optionalText(json, 'phone'),
      birthDate: _optionalDate(json, 'birth_date'),
      address: rawAddress == null
          ? null
          : Address.fromJson(Map<String, Object?>.from(rawAddress as Map)),
      revision: revision,
      createdAt: _timestamp(json, 'created_at'),
      updatedAt: _timestamp(json, 'updated_at'),
      updatedBy: _optionalUuid(json, 'updated_by'),
    );
  }
}

class MinistryPersonDraft {
  const MinistryPersonDraft({
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.address,
  });

  final String name;
  final String? phone;
  final CalendarDate? birthDate;
  final Address? address;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'phone': phone,
    'birth_date': birthDate?.toString(),
    'address': address?.toJson(),
  };
}

/// Full scoped student projection. Canonical identity and academic state keep
/// separate revisions so either edit path can detect stale writes safely.
class MinistryStudentDetail {
  const MinistryStudentDetail({
    required this.id,
    required this.personId,
    required this.congregationId,
    required this.name,
    required this.normalizedName,
    required this.phoneE164,
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
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String? personId;
  final String congregationId;
  final String name;
  final String normalizedName;
  final String? phoneE164;
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
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
}

/// The minimal teacher contact projection returned to the editor.
class MinistryTeacherContactDetail {
  const MinistryTeacherContactDetail({
    required this.id,
    required this.congregationId,
    required this.name,
    required this.phoneE164,
    required this.birthDate,
    required this.revision,
  });

  final String id;
  final String congregationId;
  final String name;
  final String? phoneE164;
  final CalendarDate? birthDate;
  final int revision;
}

class MinistryEnrollmentResult {
  const MinistryEnrollmentResult({
    required this.id,
    required this.studentId,
    required this.personId,
    required this.revision,
    required this.studentRevision,
  });

  final String id;
  final String studentId;
  final String personId;
  final int revision;
  final int studentRevision;
}

class StudentPersonLinkResult {
  const StudentPersonLinkResult({
    required this.studentId,
    required this.personId,
    required this.studentRevision,
    required this.personRevision,
  });

  final String studentId;
  final String personId;
  final int studentRevision;
  final int personRevision;

  factory StudentPersonLinkResult.fromJson(MinistryJson json) {
    _checkExactKeys(json, const <String>{
      'student_id',
      'person_id',
      'student_revision',
      'person_revision',
    });
    return StudentPersonLinkResult(
      studentId: _uuid(json, 'student_id'),
      personId: _uuid(json, 'person_id'),
      studentRevision: _positiveInt(json, 'student_revision'),
      personRevision: _positiveInt(json, 'person_revision'),
    );
  }
}

class Student extends MinistryRecord {
  const Student({
    required super.metadata,
    required this.name,
    required this.normalizedName,
    required this.phoneE164,
    required this.birthDate,
    required this.address,
    required this.education,
    required this.maritalStatus,
    required this.newConvert,
    required this.waterBaptized,
    required this.wantsBaptism,
    required this.archived,
    required this.personId,
    required this.personRevision,
  });

  final String name;
  final String normalizedName;
  final String? phoneE164;
  final CalendarDate? birthDate;
  final Address? address;
  final String? education;
  final String? maritalStatus;
  final bool? newConvert;
  final bool? waterBaptized;
  final bool? wantsBaptism;
  final bool archived;
  final String? personId;
  final int? personRevision;

  factory Student.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      ..._metadataKeys,
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
    });
    final metadata = CommonMetadata.fromJson(json);
    if (metadata.congregationId == null) {
      throw const MinistryDataException('Student congregation is required.');
    }
    final waterBaptized = _optionalBool(json, 'water_baptized');
    final wantsBaptism = _optionalBool(json, 'wants_baptism');
    if (waterBaptized == true && wantsBaptism == true) {
      throw const MinistryDataException('Baptism answers contradict.');
    }
    final rawAddress = json['address'];
    if (rawAddress != null && rawAddress is! Map) {
      throw const MinistryDataException('Address must be an object or null.');
    }
    final personId = _optionalUuid(json, 'person_id');
    final personRevision = _optionalPositiveInt(json, 'person_revision');
    if ((personId == null) != (personRevision == null)) {
      throw const MinistryDataException(
        'Student person ID and revision disagree.',
      );
    }
    return Student(
      metadata: metadata,
      name: _requiredText(json, 'name'),
      normalizedName: _requiredText(json, 'normalized_name'),
      phoneE164: _optionalText(json, 'phone_e164'),
      birthDate: _optionalDate(json, 'birth_date'),
      address: rawAddress == null
          ? null
          : Address.fromJson(Map<String, Object?>.from(rawAddress as Map)),
      education: _optionalText(json, 'education'),
      maritalStatus: _optionalText(json, 'marital_status'),
      newConvert: _optionalBool(json, 'new_convert'),
      waterBaptized: waterBaptized,
      wantsBaptism: wantsBaptism,
      archived: _requiredBool(json, 'archived'),
      personId: personId,
      personRevision: personRevision,
    );
  }
}

enum ClassStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const ClassStatus(this.wire);
  final String wire;
  static ClassStatus fromWire(String wire) => _enumByWire(values, wire);
}

enum EnrollmentStatus {
  active('active'),
  completed('completed'),
  withdrawn('withdrawn');

  const EnrollmentStatus(this.wire);
  final String wire;
  static EnrollmentStatus fromWire(String wire) => _enumByWire(values, wire);
}

enum SessionStatus {
  open('open'),
  finalized('finalized'),
  canceled('canceled');

  const SessionStatus(this.wire);
  final String wire;
  static SessionStatus fromWire(String wire) => _enumByWire(values, wire);
}

enum AttendanceStatus {
  present('present'),
  absent('absent'),
  excused('excused'),
  unmarked('unmarked');

  const AttendanceStatus(this.wire);
  final String wire;
  static AttendanceStatus fromWire(String wire) => _enumByWire(values, wire);
}

class ClassGroup extends MinistryRecord {
  const ClassGroup({
    required super.metadata,
    required this.name,
    required this.normalizedName,
    required this.teacherContactId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String name;
  final String normalizedName;
  final String? teacherContactId;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final ClassStatus status;

  factory ClassGroup.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      ..._metadataKeys,
      'name',
      'normalized_name',
      'teacher_contact_id',
      'start_date',
      'end_date',
      'status',
    });
    final metadata = CommonMetadata.fromJson(json);
    if (metadata.congregationId == null) {
      throw const MinistryDataException('Class congregation is required.');
    }
    return ClassGroup(
      metadata: metadata,
      name: _requiredText(json, 'name'),
      normalizedName: _requiredText(json, 'normalized_name'),
      teacherContactId: _optionalUuid(json, 'teacher_contact_id'),
      startDate: _requiredDate(json, 'start_date'),
      endDate: _optionalDate(json, 'end_date'),
      status: ClassStatus.fromWire(_requiredText(json, 'status')),
    );
  }
}

class Enrollment extends MinistryRecord {
  const Enrollment({
    required super.metadata,
    required this.studentId,
    required this.classId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String studentId;
  final String classId;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final EnrollmentStatus status;

  factory Enrollment.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      ..._metadataKeys,
      'student_id',
      'class_id',
      'start_date',
      'end_date',
      'status',
    });
    final metadata = CommonMetadata.fromJson(json);
    if (metadata.congregationId == null) {
      throw const MinistryDataException('Enrollment congregation is required.');
    }
    return Enrollment(
      metadata: metadata,
      studentId: _uuid(json, 'student_id'),
      classId: _uuid(json, 'class_id'),
      startDate: _requiredDate(json, 'start_date'),
      endDate: _optionalDate(json, 'end_date'),
      status: EnrollmentStatus.fromWire(_requiredText(json, 'status')),
    );
  }
}

class Session extends MinistryRecord {
  const Session({
    required super.metadata,
    required this.classId,
    required this.date,
    required this.topic,
    required this.status,
    required this.rosterFrozen,
    required this.lessonIndex,
    required this.lessonPart,
    required this.lessonFinished,
  });

  final String classId;
  final CalendarDate date;
  final String? topic;
  final SessionStatus status;
  final bool rosterFrozen;
  final int? lessonIndex;
  final int? lessonPart;
  final bool lessonFinished;

  factory Session.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      ..._metadataKeys,
      'class_id',
      'date',
      'topic',
      'status',
      'roster_frozen',
      'lesson_index',
      'lesson_part',
      'lesson_finished',
    });
    final metadata = CommonMetadata.fromJson(json);
    if (metadata.congregationId == null) {
      throw const MinistryDataException('Session congregation is required.');
    }
    final lessonIndex = _optionalNonNegativeInt(json, 'lesson_index');
    final lessonPart = _optionalPositiveInt(json, 'lesson_part');
    return Session(
      metadata: metadata,
      classId: _uuid(json, 'class_id'),
      date: _requiredDate(json, 'date'),
      topic: _optionalText(json, 'topic'),
      status: SessionStatus.fromWire(_requiredText(json, 'status')),
      rosterFrozen: _requiredBool(json, 'roster_frozen'),
      lessonIndex: lessonIndex,
      lessonPart: lessonPart,
      lessonFinished: _optionalBool(json, 'lesson_finished') ?? false,
    );
  }
}

class AttendanceMark {
  const AttendanceMark({
    required this.sessionId,
    required this.enrollmentId,
    required this.studentId,
    required this.status,
    required this.studentName,
  });

  final String sessionId;
  final String enrollmentId;
  final String studentId;
  final AttendanceStatus status;
  final String studentName;

  factory AttendanceMark.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      'session_id',
      'enrollment_id',
      'student_id',
      'status',
      'student_name',
    });
    return AttendanceMark(
      sessionId: _uuid(json, 'session_id'),
      enrollmentId: _uuid(json, 'enrollment_id'),
      studentId: _uuid(json, 'student_id'),
      status: AttendanceStatus.fromWire(_requiredText(json, 'status')),
      studentName: _requiredText(json, 'student_name'),
    );
  }
}

class EnrollmentProgress {
  const EnrollmentProgress({
    required this.present,
    required this.absent,
    required this.excused,
  }) : assert(present >= 0 && absent >= 0 && excused >= 0);

  final int present;
  final int absent;
  final int excused;

  int get denominator => present + absent;
  double? get percentage => denominator == 0 ? null : present / denominator;
  int? get roundedPercentage =>
      percentage == null ? null : (percentage! * 100).round();

  factory EnrollmentProgress.fromJson(MinistryJson json) {
    _checkKeys(json, const <String>{
      'present',
      'absent',
      'excused',
      'denominator',
      'percentage',
      'rounded_percentage',
      'enrollment_id',
    });
    final present = _nonNegativeInt(json, 'present');
    final absent = _nonNegativeInt(json, 'absent');
    final excused = _nonNegativeInt(json, 'excused');
    final progress = EnrollmentProgress(
      present: present,
      absent: absent,
      excused: excused,
    );
    if (json.containsKey('denominator') &&
        json['denominator'] != progress.denominator) {
      throw const MinistryDataException(
        'Progress denominator is inconsistent.',
      );
    }
    final rawPercentage = json['percentage'];
    if (json.containsKey('percentage') &&
        rawPercentage != progress.percentage) {
      throw const MinistryDataException('Progress percentage is inconsistent.');
    }
    if (json.containsKey('rounded_percentage') &&
        json['rounded_percentage'] != progress.roundedPercentage) {
      throw const MinistryDataException('Rounded progress is inconsistent.');
    }
    if (json.containsKey('enrollment_id')) _uuid(json, 'enrollment_id');
    return progress;
  }
}

T _enumByWire<T extends Enum>(List<T> values, String wire) {
  for (final value in values) {
    if (value.name == wire) return value;
  }
  throw MinistryDataException('Unknown enum value: $wire');
}

const _uuidPattern =
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';

const _metadataKeys = <String>{
  'id',
  'congregation_id',
  'revision',
  'created_at',
  'updated_at',
  'updated_by',
  'legacy_firebase_id',
};

void _checkKeys(MinistryJson json, Set<String> allowed) {
  final unknown = json.keys.where((key) => !allowed.contains(key));
  if (unknown.isNotEmpty) {
    throw MinistryDataException('Unknown field: ${unknown.first}.');
  }
}

void _checkExactKeys(MinistryJson json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.difference(expected).isNotEmpty || !actual.containsAll(expected)) {
    throw const MinistryDataException('Response fields do not match contract.');
  }
}

String _uuid(MinistryJson json, String key) {
  final value = _requiredText(json, key);
  if (!RegExp(_uuidPattern).hasMatch(value)) {
    throw MinistryDataException('Invalid UUID field: $key.');
  }
  return value;
}

String? _optionalUuid(MinistryJson json, String key) {
  final value = _optionalText(json, key);
  if (value != null && !RegExp(_uuidPattern).hasMatch(value)) {
    throw MinistryDataException('Invalid UUID field: $key.');
  }
  return value;
}

String _requiredText(MinistryJson json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw MinistryDataException('Missing or invalid text field: $key.');
  }
  return value;
}

String? _optionalText(MinistryJson json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw MinistryDataException('Invalid optional text field: $key.');
}

String? _optionalNormalizedEmail(MinistryJson json, String key) {
  final value = _optionalText(json, key);
  if (value != null &&
      (value != value.trim().toLowerCase() || !value.contains('@'))) {
    throw MinistryDataException('Invalid normalized email field: $key.');
  }
  return value;
}

bool _requiredBool(MinistryJson json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw MinistryDataException('Missing or invalid boolean field: $key.');
}

bool? _optionalBool(MinistryJson json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw MinistryDataException('Invalid optional boolean field: $key.');
}

DateTime _timestamp(MinistryJson json, String key) {
  final value = json[key];
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw MinistryDataException('Invalid timestamp field: $key.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw MinistryDataException('Invalid timestamp field: $key.');
  }
  return parsed.toUtc();
}

CalendarDate? _optionalDate(MinistryJson json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw MinistryDataException('Invalid date field: $key.');
  }
  return CalendarDate.parse(value);
}

CalendarDate _requiredDate(MinistryJson json, String key) =>
    _optionalDate(json, key) ??
    (throw MinistryDataException('Missing date field: $key.'));

int _positiveInt(MinistryJson json, String key) {
  final value = json[key];
  if (value is int && value > 0) return value;
  throw MinistryDataException('Invalid positive integer field: $key.');
}

int _nonNegativeInt(MinistryJson json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw MinistryDataException('Invalid nonnegative integer field: $key.');
}

int? _optionalNonNegativeInt(MinistryJson json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _nonNegativeInt(json, key);
}

int? _optionalPositiveInt(MinistryJson json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _positiveInt(json, key);
}
