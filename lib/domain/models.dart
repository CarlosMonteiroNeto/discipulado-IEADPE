import 'business_calendar.dart';

enum Gender {
  male('male'),
  female('female');

  const Gender(this.wireValue);
  final String wireValue;
  static Gender fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown Gender: $value'),
  );
}

enum ConvertEventType {
  visit('visit'),
  discipleshipStarted('discipleship_started'),
  discipleshipCompleted('discipleship_completed'),
  deviated('deviated');

  const ConvertEventType(this.wireValue);
  final String wireValue;
  static ConvertEventType fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown ConvertEventType: $value'),
  );
}

enum FeedbackStatus {
  pending('pending'),
  read('read'),
  resolved('resolved');

  const FeedbackStatus(this.wireValue);
  final String wireValue;
  static FeedbackStatus fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown FeedbackStatus: $value'),
  );
}

enum AccessRole {
  direction('Membro da direção da campanha'),
  supervision('Membro da supervisão das campanhas');

  const AccessRole(this.wireValue);
  final String wireValue;
  static AccessRole fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown AccessRole: $value'),
  );
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
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
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
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
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
    'created_by': createdBy,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };
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
    required this.convertId,
    this.convertName,
    this.congregationId,
    required this.eventType,
    required this.eventDate,
    this.doneByEmail,
  });
  final String id;
  final String convertId;
  final String? convertName;
  final String? congregationId;
  final ConvertEventType eventType;
  final DateOnly eventDate;
  final String? doneByEmail;
  factory ConvertEvent.fromJson(Map<String, dynamic> json) => ConvertEvent(
    id: json['id'] as String,
    convertId: json['convert_id'] as String,
    convertName: json['convert_name'] as String?,
    congregationId: json['congregation_id'] as String?,
    eventType: ConvertEventType.fromWire(json['event_type'] as String),
    eventDate: DateOnly.parse(json['event_date'] as String),
    doneByEmail: json['done_by_email'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'convert_id': convertId,
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
    status: FeedbackStatus.fromWire(json['status'] as String),
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
  }) : congregationIds = Set.unmodifiable(congregationIds);
  final bool isAdmin, isSupervision;
  final Set<String> congregationIds;
  bool get isGlobalManager => isAdmin || isSupervision;
  bool canAccess(String? congregationId) =>
      isGlobalManager ||
      (congregationId != null && congregationIds.contains(congregationId));
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
