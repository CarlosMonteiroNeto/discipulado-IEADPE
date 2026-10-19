import 'business_calendar.dart';

enum Gender {
  male('male'),
  female('female');

  const Gender(this.wireValue);
  final String wireValue;
  static Gender fromWire(String value) {
    for (final candidate in values) {
      if (candidate.wireValue == value) return candidate;
    }
    throw FormatException('Invalid Gender wire value: $value');
  }
}

enum ConvertEventType {
  visit('visit'),
  discipleshipStarted('discipleship_started'),
  discipleshipCompleted('discipleship_completed'),
  deviated('deviated');

  const ConvertEventType(this.wireValue);
  final String wireValue;
  static ConvertEventType fromWire(String value) {
    for (final candidate in values) {
      if (candidate.wireValue == value) return candidate;
    }
    throw FormatException('Invalid ConvertEventType wire value: $value');
  }
}

enum FeedbackStatus {
  pending('pending'),
  read('read'),
  resolved('resolved');

  const FeedbackStatus(this.wireValue);
  final String wireValue;
  static FeedbackStatus fromWire(String value) {
    for (final candidate in values) {
      if (candidate.wireValue == value) return candidate;
    }
    throw FormatException('Invalid FeedbackStatus wire value: $value');
  }
}

enum AccessRole {
  direction('Membro da direção da campanha'),
  supervision('Membro da supervisão das campanhas');

  const AccessRole(this.wireValue);
  final String wireValue;
  static AccessRole fromWire(String value) {
    for (final candidate in values) {
      if (candidate.wireValue == value) return candidate;
    }
    throw FormatException('Invalid AccessRole wire value: $value');
  }
}

final class ConvertRecord {
  const ConvertRecord({
    required this.id,
    required this.internalId,
    required this.name,
    required this.landmark,
    required this.gender,
    required this.conversionDate,
    required this.worshipType,
    this.congregationId,
    this.photoUrl,
    this.photoAssetId,
    this.address,
    this.phone,
    this.age,
    this.lastVisitDate,
    this.wasVisitedOnce = false,
    this.visitCount = 0,
    this.isInDiscipleship = false,
    this.discipleshipStartDate,
    this.isDiscipleshipCompleted = false,
    this.isDeviated = false,
    this.effectiveIsInDiscipleship,
    this.effectiveDiscipleshipStartDate,
    this.latestQualifyingLessonDate,
    this.effectiveFollowUpDate,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.personId,
    this.personRevision,
    this.convertRevision = 1,
    this.personIdentity,
    this.legacyIdentity,
  });
  final String id;
  final String internalId;
  final String name;
  final String landmark;
  final Gender gender;
  final DateOnly conversionDate;
  final String worshipType;
  final String? congregationId;
  final String? photoUrl;
  final String? photoAssetId;
  final String? address;
  final String? phone;
  final int? age;
  final DateOnly? lastVisitDate;
  final bool wasVisitedOnce;
  final int visitCount;
  final bool isInDiscipleship;
  final DateOnly? discipleshipStartDate;
  final bool isDiscipleshipCompleted;
  final bool isDeviated;

  /// Server-derived active state; null only for non-projection local records.
  final bool? effectiveIsInDiscipleship;
  final DateOnly? effectiveDiscipleshipStartDate;
  final DateOnly? latestQualifyingLessonDate;
  final DateOnly? effectiveFollowUpDate;
  bool get isEffectivelyInDiscipleship =>
      effectiveIsInDiscipleship ?? isInDiscipleship;
  DateOnly? get followUpDate => effectiveFollowUpDate ?? lastVisitDate;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? personId;
  final int? personRevision;
  final int convertRevision;
  final CanonicalPersonIdentity? personIdentity;
  final LegacyConvertIdentity? legacyIdentity;
  factory ConvertRecord.fromJson(Map<String, dynamic> json) => ConvertRecord(
    id: json['id'] as String,
    internalId: json['internal_id'] as String,
    name: json['name'] as String,
    landmark: json['landmark'] as String,
    gender: Gender.fromWire(json['gender'] as String),
    conversionDate: DateOnly.parse(json['conversion_date'] as String),
    worshipType: json['worship_type'] as String,
    congregationId: json['congregation_id'] as String?,
    photoUrl: json['photo_url'] as String?,
    photoAssetId: json['photo_asset_id'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    age: json['age'] as int?,
    lastVisitDate: json['last_visit_date'] == null
        ? null
        : DateOnly.parse(json['last_visit_date'] as String),
    wasVisitedOnce: json['was_visited_once'] as bool? ?? false,
    visitCount: json['visit_count'] as int? ?? 0,
    isInDiscipleship: json['is_in_discipleship'] as bool? ?? false,
    discipleshipStartDate: json['discipleship_start_date'] == null
        ? null
        : DateOnly.parse(json['discipleship_start_date'] as String),
    isDiscipleshipCompleted:
        json['is_discipleship_completed'] as bool? ?? false,
    isDeviated: json['is_deviated'] as bool? ?? false,
    effectiveIsInDiscipleship: json['effective_is_in_discipleship'] as bool?,
    effectiveDiscipleshipStartDate:
        json['effective_discipleship_start_date'] == null
        ? null
        : DateOnly.parse(json['effective_discipleship_start_date'] as String),
    latestQualifyingLessonDate: json['latest_qualifying_lesson_date'] == null
        ? null
        : DateOnly.parse(json['latest_qualifying_lesson_date'] as String),
    effectiveFollowUpDate: json['effective_follow_up_date'] == null
        ? null
        : DateOnly.parse(json['effective_follow_up_date'] as String),
    createdBy: json['created_by'] as String?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
    deletedAt: json['deleted_at'] == null
        ? null
        : DateTime.parse(json['deleted_at'] as String),
    personId: json['person_id'] as String?,
    personRevision: json['person_revision'] as int?,
    convertRevision: json['revision'] as int? ?? 1,
    personIdentity: json['person_identity'] == null
        ? null
        : CanonicalPersonIdentity.fromJson(
            Map<String, dynamic>.from(json['person_identity'] as Map),
          ),
    legacyIdentity: json['legacy_identity'] == null
        ? null
        : LegacyConvertIdentity.fromJson(
            Map<String, dynamic>.from(json['legacy_identity'] as Map),
          ),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'internal_id': internalId,
    'name': name,
    'landmark': landmark,
    'gender': gender.wireValue,
    'conversion_date': conversionDate.toString(),
    'worship_type': worshipType,
    'congregation_id': congregationId,
    'photo_url': photoUrl,
    'photo_asset_id': photoAssetId,
    'address': address,
    'phone': phone,
    'age': age,
    'last_visit_date': lastVisitDate?.toString(),
    'was_visited_once': wasVisitedOnce,
    'visit_count': visitCount,
    'is_in_discipleship': isInDiscipleship,
    'discipleship_start_date': discipleshipStartDate?.toString(),
    'is_discipleship_completed': isDiscipleshipCompleted,
    'is_deviated': isDeviated,
    'effective_is_in_discipleship': effectiveIsInDiscipleship,
    'effective_discipleship_start_date': effectiveDiscipleshipStartDate
        ?.toString(),
    'latest_qualifying_lesson_date': latestQualifyingLessonDate?.toString(),
    'effective_follow_up_date': effectiveFollowUpDate?.toString(),
    'created_by': createdBy,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'person_id': personId,
    'person_revision': personRevision,
    'revision': convertRevision,
    'person_identity': personIdentity?.toJson(),
    'legacy_identity': legacyIdentity?.toJson(),
  };
}

/// The joined canonical fields used to edit a linked convert identity.
final class CanonicalPersonIdentity {
  const CanonicalPersonIdentity({
    required this.name,
    this.phone,
    this.birthDate,
    this.address,
  });

  final String name;
  final String? phone;
  final DateOnly? birthDate;
  final Map<String, Object?>? address;

  factory CanonicalPersonIdentity.fromJson(Map<String, dynamic> json) =>
      CanonicalPersonIdentity(
        name: json['name'] as String,
        phone: json['phone'] as String?,
        birthDate: json['birth_date'] == null
            ? null
            : DateOnly.parse(json['birth_date'] as String),
        address: json['address'] == null
            ? null
            : Map<String, Object?>.unmodifiable(
                Map<String, Object?>.from(json['address'] as Map),
              ),
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'birth_date': birthDate?.toString(),
    'address': address,
  };
}

/// Original snapshot for a convert that has no canonical person link.
final class LegacyConvertIdentity {
  const LegacyConvertIdentity({required this.name, this.phone, this.address});

  final String name;
  final String? phone;
  final String? address;

  factory LegacyConvertIdentity.fromJson(Map<String, dynamic> json) =>
      LegacyConvertIdentity(
        name: json['name'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
  };
}

/// Typed IDs and independent revisions returned by atomic registration RPCs.
final class PersonRegistrationResult {
  const PersonRegistrationResult({
    required this.personId,
    required this.personRevision,
    this.convertId,
    this.studentId,
    this.convertRevision,
    this.studentRevision,
  });

  final String personId;
  final String? convertId;
  final String? studentId;
  final int personRevision;
  final int? convertRevision;
  final int? studentRevision;
}

enum MinistryReturnRoute {
  students('/ministry/students'),
  classes('/ministry/classes'),
  attendance('/ministry/attendance'),
  handoff('/ministry/handoff');

  const MinistryReturnRoute(this.path);
  final String path;
}

/// In-memory only. This object contains IDs and a safe return enum, never PII.
final class MinistryRouteContext {
  const MinistryRouteContext({
    required this.congregationId,
    required this.returnTo,
    this.classId,
    this.personId,
  });

  final String congregationId;
  final MinistryReturnRoute returnTo;
  final String? classId;
  final String? personId;

  bool get hasValidIds =>
      _isUuid(congregationId) &&
      (classId == null || _isUuid(classId!)) &&
      (personId == null || _isUuid(personId!));

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

final class Congregation {
  const Congregation({required this.id, required this.name, this.archivedAt});
  final String id;
  final String name;
  final DateTime? archivedAt;
  factory Congregation.fromJson(Map<String, dynamic> json) => Congregation(
    id: json['id'] as String,
    name: json['name'] as String,
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'archived_at': archivedAt?.toIso8601String(),
  };
}

final class ConvertEvent {
  const ConvertEvent({
    required this.id,
    this.convertId,
    this.legacyConvertId,
    this.convertName,
    this.congregationId,
    required this.eventType,
    required this.eventDate,
    this.doneByEmail,
  });
  final String id;
  final String? convertId;
  final String? legacyConvertId;
  final String? convertName;
  final String? congregationId;
  final ConvertEventType eventType;
  final DateOnly eventDate;
  final String? doneByEmail;
  factory ConvertEvent.fromJson(Map<String, dynamic> json) => ConvertEvent(
    id: json['id'] as String,
    convertId: json['convert_id'] as String?,
    legacyConvertId: json['legacy_convert_id'] as String?,
    convertName: json['convert_name'] as String?,
    congregationId: json['congregation_id'] as String?,
    eventType: ConvertEventType.fromWire(json['event_type'] as String),
    eventDate: DateOnly.parse(json['event_date'] as String),
    doneByEmail: json['done_by_email'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'convert_id': convertId,
    'legacy_convert_id': legacyConvertId,
    'convert_name': convertName,
    'congregation_id': congregationId,
    'event_type': eventType.wireValue,
    'event_date': eventDate.toString(),
    'done_by_email': doneByEmail,
  };
}

final class Feedback {
  const Feedback({
    required this.id,
    required this.message,
    this.userEmail,
    this.userName,
    this.status = FeedbackStatus.pending,
  });
  final String id;
  final String message;
  final String? userEmail;
  final String? userName;
  final FeedbackStatus status;
  factory Feedback.fromJson(Map<String, dynamic> json) => Feedback(
    id: json['id'] as String,
    message: json['message'] as String,
    userEmail: json['user_email'] as String?,
    userName: json['user_name'] as String?,
    status: FeedbackStatus.fromWire(json['status'] as String? ?? 'pending'),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'user_email': userEmail,
    'user_name': userName,
    'status': status.wireValue,
  };
}

final class UserAccess {
  const UserAccess({
    required this.id,
    required this.userEmail,
    required this.role,
    this.congregationId,
    this.userId,
  });
  final String id;
  final String userEmail;
  final AccessRole role;
  final String? congregationId;
  final String? userId;
  factory UserAccess.fromJson(Map<String, dynamic> json) => UserAccess(
    id: json['id'] as String,
    userEmail: json['user_email'] as String,
    role: AccessRole.fromWire(json['role'] as String),
    congregationId: json['congregation_id'] as String?,
    userId: json['user_id'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_email': userEmail,
    'role': role.wireValue,
    'congregation_id': congregationId,
    'user_id': userId,
  };
}

final class WeeklyReport {
  const WeeklyReport({
    required this.id,
    required this.congregationId,
    required this.weekStart,
    required this.confirmedByEmail,
    this.confirmedByName,
  });
  final String id;
  final String congregationId;
  final DateOnly weekStart;
  final String confirmedByEmail;
  final String? confirmedByName;
  factory WeeklyReport.fromJson(Map<String, dynamic> json) => WeeklyReport(
    id: json['id'] as String,
    congregationId: json['congregation_id'] as String,
    weekStart: DateOnly.parse(json['week_start'] as String),
    confirmedByEmail: json['confirmed_by_email'] as String,
    confirmedByName: json['confirmed_by_name'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'congregation_id': congregationId,
    'week_start': weekStart.toString(),
    'confirmed_by_email': confirmedByEmail,
    'confirmed_by_name': confirmedByName,
  };
}

final class Page<T> {
  Page({required Iterable<T> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
}

/// Scope is a server-derived snapshot; SQL remains authoritative.
final class AccessScope {
  AccessScope({
    this.isAdmin = false,
    this.isSupervision = false,
    Iterable<String> congregationIds = const [],
    this.isMinistrySupervision = false,
    Iterable<String> ministryCongregationIds = const [],
  }) : congregationIds = Set.unmodifiable(congregationIds),
       ministryCongregationIds = Set.unmodifiable(ministryCongregationIds);
  final bool isAdmin, isSupervision;
  final Set<String> congregationIds;
  final bool isMinistrySupervision;
  final Set<String> ministryCongregationIds;
  bool get isGlobalManager => isAdmin || isSupervision;
  bool get hasMinistryAccess =>
      isMinistrySupervision || ministryCongregationIds.isNotEmpty;
  bool canAccess(String? congregationId) {
    if (isGlobalManager) return true;
    return congregationId != null && congregationIds.contains(congregationId);
  }

  bool canAccessMinistry(String? congregationId) =>
      isMinistrySupervision ||
      (congregationId != null &&
          ministryCongregationIds.contains(congregationId));

  @override
  bool operator ==(Object other) =>
      other is AccessScope &&
      isAdmin == other.isAdmin &&
      isSupervision == other.isSupervision &&
      isMinistrySupervision == other.isMinistrySupervision &&
      _sameIds(congregationIds, other.congregationIds) &&
      _sameIds(ministryCongregationIds, other.ministryCongregationIds);

  @override
  int get hashCode => Object.hash(
    isAdmin,
    isSupervision,
    isMinistrySupervision,
    Object.hashAll(congregationIds.toList()..sort()),
    Object.hashAll(ministryCongregationIds.toList()..sort()),
  );

  static bool _sameIds(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

enum MutationStatus { applied, rejected }

final class MutationResult<T> {
  const MutationResult.applied({required this.operationId, this.value})
    : status = MutationStatus.applied,
      errorCode = null;
  const MutationResult.rejected({
    required this.operationId,
    required this.errorCode,
  }) : status = MutationStatus.rejected,
       value = null;
  final String operationId;
  final MutationStatus status;
  final T? value;
  final String? errorCode;
}
