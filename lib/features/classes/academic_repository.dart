/// Typed class, enrollment, session and attendance contracts shared by the
/// classes and attendance features (S05, S07, S08, S09, S11).
///
/// The repository is a thin typed facade over [BackendGateway]: every mutation
/// carries a requestId for explicit retry, and attendance is always submitted
/// as the exact complete roster map with the expected session revision.
library;

import 'package:uuid/uuid.dart';

import '../../data/query_codec.dart';
import '../../domain/attendance.dart';
import '../../domain/class_group.dart';
import '../../domain/common.dart';
import '../../domain/contact.dart';
import '../../domain/enrollment.dart';
import '../../domain/ports.dart';
import '../../domain/session.dart';

/// The S08 class-size limit: total enrollment records, including closed ones.
const int maxEnrollmentRecords = 100;

/// pt-BR label for a class lifecycle status (S08).
String classStatusLabel(ClassStatus status) => switch (status) {
  ClassStatus.active => 'Ativa',
  ClassStatus.completed => 'Concluída',
  ClassStatus.archived => 'Arquivada',
};

/// Formats a calendar date as pt-BR `dd/MM/yyyy`.
String formatBrazilianDate(CalendarDate date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Parses a pt-BR `dd/MM/yyyy` input. Returns null for a malformed string or
/// an impossible calendar day (for example 29/02 in a non-leap year).
CalendarDate? parseBrazilianDate(String raw) {
  final RegExpMatch? match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$')
      .firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final int day = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int year = int.parse(match.group(3)!);
  if (!CalendarDate.isValid(year, month, day)) {
    return null;
  }
  return CalendarDate(year, month, day);
}

/// A class list row. Comparable fields only; the detail resolves the record.
class ClassListEntry {
  const ClassListEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.congregationId,
    required this.teacherContactId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.revision,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String congregationId;
  final String? teacherContactId;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final ClassStatus status;
  final int revision;

  factory ClassListEntry.fromJson(JsonMap json) {
    final CalendarDate? startDate = decodeCalendarDate(json['startDate']);
    if (startDate == null) {
      throw const DataFormatException('Missing class start date.');
    }
    return ClassListEntry(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      normalizedName: requireString(json, 'normalizedName'),
      congregationId: requireString(json, 'congregationId'),
      teacherContactId: optionalString(json, 'teacherContactId'),
      startDate: startDate,
      endDate: decodeCalendarDate(json['endDate']),
      status: ClassStatus.fromWire(requireString(json, 'status')),
      revision: requireInt(json, 'revision'),
    );
  }
}

/// Immutable class list state, including the URL-addressable filters (S09,
/// S10). The pagination cursor stays session-local and is not route state.
class ClassQuery {
  const ClassQuery({
    this.search = '',
    this.status,
    this.congregationId,
    this.cursor,
    this.limit = defaultPageSize,
  });

  final String search;
  final ClassStatus? status;
  final String? congregationId;
  final String? cursor;
  final int limit;

  bool get hasSearch => search.trim().isNotEmpty;

  ClassQuery copyWith({
    String? search,
    ClassStatus? status,
    bool clearStatus = false,
    String? congregationId,
    bool clearCongregation = false,
    String? cursor,
    bool clearCursor = false,
    int? limit,
  }) {
    return ClassQuery(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      congregationId: clearCongregation
          ? null
          : (congregationId ?? this.congregationId),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      limit: limit ?? this.limit,
    );
  }

  Map<String, String> toQueryParameters() => <String, String>{
    if (hasSearch) 'busca': search.trim(),
    if (status != null) 'situacao': status!.wire,
    if (congregationId != null && congregationId!.isNotEmpty)
      'congregacao': congregationId!,
  };

  factory ClassQuery.fromQueryParameters(Map<String, String> parameters) {
    final String? rawStatus = parameters['situacao'];
    return ClassQuery(
      search: parameters['busca'] ?? '',
      status: rawStatus == null ? null : ClassStatus.fromWire(rawStatus),
      congregationId: parameters['congregacao'],
    );
  }
}

/// Editable class fields for create and edit (S05, S08).
class ClassDraft {
  const ClassDraft({
    required this.name,
    required this.startDate,
    this.teacherContactId,
    this.endDate,
  });

  final String name;
  final CalendarDate startDate;
  final String? teacherContactId;
  final CalendarDate? endDate;

  ClassDraft copyWith({
    String? name,
    CalendarDate? startDate,
    String? teacherContactId,
    bool clearTeacher = false,
    CalendarDate? endDate,
    bool clearEndDate = false,
  }) {
    return ClassDraft(
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      teacherContactId: clearTeacher
          ? null
          : (teacherContactId ?? this.teacherContactId),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

/// The `{id, revision}` acknowledgement returned by every class/enrollment/
/// session/attendance mutation (S11).
class AcademicMutationResult {
  const AcademicMutationResult({required this.id, required this.revision});

  final String id;
  final int revision;

  factory AcademicMutationResult.fromJson(JsonMap json) =>
      AcademicMutationResult(
        id: requireString(json, 'id'),
        revision: requireInt(json, 'revision'),
      );
}

/// A selectable student for enrollment. Only list-safe fields.
class StudentOption {
  const StudentOption({required this.id, required this.name});

  final String id;
  final String name;

  factory StudentOption.fromJson(JsonMap json) => StudentOption(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
  );
}

/// One frozen (or currently eligible) roster row returned by
/// `getSessionAttendance`. [studentName] is the historical name captured when
/// the roster was frozen, so a later rename never rewrites past attendance.
class AttendanceRosterEntry {
  const AttendanceRosterEntry({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.status,
  });

  final String enrollmentId;
  final String studentId;
  final String studentName;
  final AttendanceStatus status;

  factory AttendanceRosterEntry.fromJson(JsonMap json) => AttendanceRosterEntry(
    enrollmentId: requireString(json, 'enrollmentId'),
    studentId: requireString(json, 'studentId'),
    studentName: requireString(json, 'studentName'),
    status: json['status'] is String
        ? AttendanceStatus.fromWire(json['status']! as String)
        : AttendanceStatus.unmarked,
  );
}

/// Session plus its complete roster, as returned by `getSessionAttendance`.
class AttendanceView {
  const AttendanceView({required this.session, required this.entries});

  final Session session;
  final List<AttendanceRosterEntry> entries;

  factory AttendanceView.fromJson(JsonMap json) {
    final JsonMap session = json['session'] is Map
        ? Map<String, Object?>.from(json['session']! as Map)
        : throw const DataFormatException('Missing session.');
    final Object? rawRoster = json['roster'] ?? json['entries'];
    if (rawRoster is! List) {
      throw const DataFormatException('Missing attendance roster.');
    }
    return AttendanceView(
      session: Session.fromJson(session),
      entries: rawRoster
          .map((Object? item) {
            if (item is! Map) {
              throw const DataFormatException('Invalid roster entry.');
            }
            return AttendanceRosterEntry.fromJson(
              Map<String, Object?>.from(item),
            );
          })
          .toList(growable: false),
    );
  }
}

class AcademicRepository {
  AcademicRepository({
    required this.gateway,
    Uuid? uuid,
    this.requestIdFactory,
    this.recordIdFactory,
  }) : _uuid = uuid ?? const Uuid();

  final BackendGateway gateway;
  final Uuid _uuid;
  final String Function()? requestIdFactory;
  final String Function()? recordIdFactory;

  String newRequestId() => requestIdFactory?.call() ?? _uuid.v4();

  String newRecordId() => recordIdFactory?.call() ?? _uuid.v4();

  /// Lists classes in the caller's scope with the active/completed/archived
  /// status filter and normalized name-prefix search (S08, S09).
  Future<PageResult> listClasses(ClassQuery query) {
    final Map<String, Object?> filters = <String, Object?>{
      if (query.status != null) 'status': query.status!.wire,
    };
    return gateway.query(
      QueryRequest(
        resource: QueryResource.classes,
        congregationId: query.congregationId,
        equalityFilters: filters.isEmpty ? null : filters,
        namePrefix: query.hasSearch ? query.search.trim() : null,
        limit: query.limit,
        cursor: query.cursor,
      ),
    );
  }

  Future<ClassGroup?> getClass({
    required String id,
    required String congregationId,
  }) async {
    final JsonMap? json = await gateway.get(
      RecordLocator(
        resource: QueryResource.classes,
        id: id,
        congregationId: congregationId,
      ),
    );
    return json == null ? null : ClassGroup.fromJson(json);
  }

  /// S08 create (fresh stable UUID) and edit (ID plus expected revision).
  Future<AcademicMutationResult> saveClass({
    required ClassDraft draft,
    required String congregationId,
    String? id,
    int? expectedRevision,
    String? requestId,
  }) async {
    final String recordId = id ?? newRecordId();
    final Map<String, Object?> payload = <String, Object?>{
      'id': recordId,
      'congregationId': congregationId,
      'name': draft.name.trim(),
      'teacherContactId': draft.teacherContactId,
      'startDate': draft.startDate.toIso8601String(),
      'endDate': draft.endDate?.toIso8601String(),
      'requestId': requestId ?? newRequestId(),
    };
    if (expectedRevision != null) {
      payload['expectedRevision'] = expectedRevision;
    }
    final JsonMap response = await gateway.invoke('saveClass', payload);
    return AcademicMutationResult.fromJson(response);
  }

  /// Active/completed/archived transitions and archival (S08).
  Future<AcademicMutationResult> setClassStatus({
    required String id,
    required String congregationId,
    required ClassStatus status,
    required int expectedRevision,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'setClassStatus',
      <String, Object?>{
        'id': id,
        'congregationId': congregationId,
        'status': status.wire,
        'expectedRevision': expectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return AcademicMutationResult.fromJson(response);
  }

  /// Active local contacts holding the teacher role are the only eligible
  /// teachers (S05, S08).
  Future<List<Contact>> listEligibleTeachers({
    required String congregationId,
  }) async {
    final PageResult page = await gateway.query(
      QueryRequest(
        resource: QueryResource.contacts,
        congregationId: congregationId,
        equalityFilters: const <String, Object?>{
          'archived': false,
          'scope': 'congregation',
          'roleCode': 'teacher',
        },
        limit: maxPageSize,
      ),
    );
    return page.items.map(Contact.fromJson).toList(growable: false);
  }

  /// Unarchived same-congregation students selectable for enrollment (S07).
  Future<List<StudentOption>> listEligibleStudents({
    required String congregationId,
  }) async {
    final PageResult page = await gateway.query(
      QueryRequest(
        resource: QueryResource.students,
        congregationId: congregationId,
        equalityFilters: const <String, Object?>{'archived': false},
        limit: maxPageSize,
      ),
    );
    return page.items.map(StudentOption.fromJson).toList(growable: false);
  }

  /// Every enrollment record for a class, including completed/withdrawn, so
  /// the S08 historical capacity and the current roster are both visible.
  Future<List<Enrollment>> listEnrollments({
    required String congregationId,
    required String classId,
  }) async {
    final PageResult page = await gateway.query(
      QueryRequest(
        resource: QueryResource.enrollments,
        congregationId: congregationId,
        equalityFilters: <String, Object?>{'classId': classId},
        limit: maxPageSize,
      ),
    );
    return page.items.map(Enrollment.fromJson).toList(growable: false);
  }

  /// S07 enroll with an explicit start date and a fresh stable UUID.
  Future<AcademicMutationResult> enrollStudent({
    required String congregationId,
    required String classId,
    required String studentId,
    required CalendarDate startDate,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'enrollStudent',
      <String, Object?>{
        'id': newRecordId(),
        'congregationId': congregationId,
        'classId': classId,
        'studentId': studentId,
        'startDate': startDate.toIso8601String(),
        'requestId': requestId ?? newRequestId(),
      },
    );
    return AcademicMutationResult.fromJson(response);
  }

  /// S07 complete/withdraw with an explicit end date and revision.
  Future<AcademicMutationResult> closeEnrollment({
    required String congregationId,
    required String classId,
    required String enrollmentId,
    required EnrollmentStatus status,
    required CalendarDate endDate,
    required int expectedRevision,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'closeEnrollment',
      <String, Object?>{
        'id': enrollmentId,
        'congregationId': congregationId,
        'classId': classId,
        'status': status.wire,
        'endDate': endDate.toIso8601String(),
        'expectedRevision': expectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return AcademicMutationResult.fromJson(response);
  }

  /// S08 create an open session with date and optional topic.
  Future<AcademicMutationResult> createSession({
    required String congregationId,
    required String classId,
    required CalendarDate date,
    String? topic,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'createSession',
      <String, Object?>{
        'id': newRecordId(),
        'congregationId': congregationId,
        'classId': classId,
        'date': date.toIso8601String(),
        'topic': topic,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return AcademicMutationResult.fromJson(response);
  }

  Future<List<Session>> listSessions({
    required String congregationId,
    required String classId,
  }) async {
    final PageResult page = await gateway.query(
      QueryRequest(
        resource: QueryResource.sessions,
        congregationId: congregationId,
        equalityFilters: <String, Object?>{'classId': classId},
        limit: maxPageSize,
      ),
    );
    return page.items.map(Session.fromJson).toList(growable: false);
  }

  /// Reads the session plus its roster. The roster preserves the historical
  /// student names frozen at the first save (S08).
  Future<AttendanceView> getSessionAttendance({
    required String congregationId,
    required String classId,
    required String sessionId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'getSessionAttendance',
      <String, Object?>{
        'congregationId': congregationId,
        'classId': classId,
        'sessionId': sessionId,
      },
    );
    return AttendanceView.fromJson(response);
  }

  /// S08 submits the exact complete roster map with the expected session
  /// revision; `finalize` performs the atomic save-and-finalize.
  Future<AcademicMutationResult> saveAttendance({
    required String congregationId,
    required String classId,
    required String sessionId,
    required int expectedRevision,
    required Map<String, AttendanceStatus> marks,
    required bool finalize,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'saveAttendance',
      <String, Object?>{
        'congregationId': congregationId,
        'classId': classId,
        'sessionId': sessionId,
        'expectedRevision': expectedRevision,
        'finalize': finalize,
        'attendance': <String, Object?>{
          for (final MapEntry<String, AttendanceStatus> entry in marks.entries)
            entry.key: entry.value.wire,
        },
        'requestId': requestId ?? newRequestId(),
      },
    );
    return AcademicMutationResult.fromJson(response);
  }

  /// Cancels an open or finalized session while preserving its history (S08).
  Future<AcademicMutationResult> cancelSession({
    required String congregationId,
    required String classId,
    required String sessionId,
    required int expectedRevision,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'cancelSession',
      <String, Object?>{
        'id': sessionId,
        'congregationId': congregationId,
        'classId': classId,
        'status': 'canceled',
        'expectedRevision': expectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return AcademicMutationResult.fromJson(response);
  }
}
