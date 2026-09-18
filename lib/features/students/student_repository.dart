/// Typed student queries and mutations for the students feature
/// (S04, S05, S07, S09, S11).
library;

import 'package:uuid/uuid.dart';

import '../../data/query_codec.dart';
import '../../domain/class_group.dart';
import '../../domain/common.dart';
import '../../domain/enrollment.dart';
import '../../domain/ports.dart';
import '../../domain/student.dart';
import 'enrollment_history.dart';

/// A student list row. Only list-safe fields; private personal/religious data
/// never enters a list row or a URL (S07, S12).
class StudentListEntry {
  const StudentListEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.congregationId,
    required this.archived,
    required this.revision,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String congregationId;
  final bool archived;
  final int revision;

  factory StudentListEntry.fromJson(JsonMap json) => StudentListEntry(
    id: requireString(json, 'id'),
    name: requireString(json, 'name'),
    normalizedName: requireString(json, 'normalizedName'),
    congregationId: requireString(json, 'congregationId'),
    archived: requireBool(json, 'archived'),
    revision: requireInt(json, 'revision'),
  );
}

/// Immutable student list state, including the URL-addressable filters (S09,
/// S10). The pagination cursor stays session-local and is not route state.
class StudentQuery {
  const StudentQuery({
    this.search = '',
    this.archived = false,
    this.classId,
    this.congregationId,
    this.cursor,
    this.limit = defaultPageSize,
  });

  final String search;
  final bool archived;
  final String? classId;
  final String? congregationId;
  final String? cursor;
  final int limit;

  bool get hasSearch => search.trim().isNotEmpty;

  StudentQuery copyWith({
    String? search,
    bool? archived,
    String? classId,
    bool clearClass = false,
    String? congregationId,
    bool clearCongregation = false,
    String? cursor,
    bool clearCursor = false,
    int? limit,
  }) {
    return StudentQuery(
      search: search ?? this.search,
      archived: archived ?? this.archived,
      classId: clearClass ? null : (classId ?? this.classId),
      congregationId: clearCongregation
          ? null
          : (congregationId ?? this.congregationId),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      limit: limit ?? this.limit,
    );
  }

  Map<String, String> toQueryParameters() => <String, String>{
    if (hasSearch) 'busca': search.trim(),
    if (archived) 'arquivados': '1',
    if (classId != null && classId!.isNotEmpty) 'turma': classId!,
    if (congregationId != null && congregationId!.isNotEmpty)
      'congregacao': congregationId!,
  };

  factory StudentQuery.fromQueryParameters(Map<String, String> parameters) =>
      StudentQuery(
        search: parameters['busca'] ?? '',
        archived: parameters['arquivados'] == '1',
        classId: parameters['turma'],
        congregationId: parameters['congregacao'],
      );
}

/// The editable student fields for create and edit (S05, S07). A null optional
/// value means "not informed" and is preserved as null on the wire.
class StudentDraft {
  const StudentDraft({
    required this.name,
    this.phone,
    this.birthDate,
    this.address,
    this.education,
    this.maritalStatus,
    this.newConvert,
    this.waterBaptized,
    this.wantsBaptism,
  });

  final String name;
  final String? phone;
  final CalendarDate? birthDate;
  final Address? address;
  final String? education;
  final String? maritalStatus;
  final bool? newConvert;
  final bool? waterBaptized;
  final bool? wantsBaptism;
}

class StudentMutationResult {
  const StudentMutationResult({required this.id, required this.revision});

  final String id;
  final int revision;

  factory StudentMutationResult.fromJson(JsonMap json) => StudentMutationResult(
    id: requireString(json, 'id'),
    revision: requireInt(json, 'revision'),
  );
}

class StudentRepository {
  StudentRepository({
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

  /// Lists students in the caller's scope. A class filter is routed through the
  /// backend `listClassStudents` callable (the query codec recognizes the
  /// `classId` filter), so membership is resolved before the page is assembled
  /// (S07, S09).
  Future<PageResult> listStudents(StudentQuery query) {
    final Map<String, Object?> filters = <String, Object?>{
      'archived': query.archived,
    };
    if (query.classId != null && query.classId!.isNotEmpty) {
      filters['classId'] = query.classId;
    }
    return gateway.query(
      QueryRequest(
        resource: QueryResource.students,
        congregationId: query.congregationId,
        equalityFilters: filters,
        namePrefix: query.hasSearch ? query.search.trim() : null,
        limit: query.limit,
        cursor: query.cursor,
      ),
    );
  }

  /// Reads the private scoped student record. An out-of-scope or forged ID
  /// resolves to null (or a safe not-found failure) without personal data.
  Future<Student?> getStudent({
    required String id,
    required String congregationId,
  }) async {
    final JsonMap? json = await gateway.get(
      RecordLocator(
        resource: QueryResource.students,
        id: id,
        congregationId: congregationId,
      ),
    );
    return json == null ? null : Student.fromJson(json);
  }

  /// S07 create and edit. [id] and [expectedRevision] identify an existing
  /// record; both absent means a create with a fresh stable UUID. Optional
  /// fields are sent explicitly so a null answer stays "not informed".
  Future<StudentMutationResult> saveStudent({
    required StudentDraft draft,
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
      'phone': draft.phone,
      'birthDate': draft.birthDate?.toIso8601String(),
      'address': draft.address?.toJson(),
      'education': draft.education,
      'maritalStatus': draft.maritalStatus,
      'newConvert': draft.newConvert,
      'waterBaptized': draft.waterBaptized,
      'wantsBaptism': draft.wantsBaptism,
      'requestId': requestId ?? newRequestId(),
    };
    if (expectedRevision != null) {
      payload['expectedRevision'] = expectedRevision;
    }
    final JsonMap response = await gateway.invoke('saveStudent', payload);
    return StudentMutationResult.fromJson(response);
  }

  /// S07 archive and restore by the existing stable ID and revision.
  Future<StudentMutationResult> setStudentArchived({
    required String id,
    required String congregationId,
    required bool archived,
    required int expectedRevision,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'setStudentArchived',
      <String, Object?>{
        'id': id,
        'congregationId': congregationId,
        'archived': archived,
        'expectedRevision': expectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return StudentMutationResult.fromJson(response);
  }

  /// Active classes selectable as a student list filter (S07, S09).
  Future<List<ClassGroup>> listActiveClasses({
    required String congregationId,
  }) async {
    final PageResult page = await gateway.query(
      QueryRequest(
        resource: QueryResource.classes,
        congregationId: congregationId,
        equalityFilters: const <String, Object?>{'status': 'active'},
        limit: maxPageSize,
      ),
    );
    return page.items.map(ClassGroup.fromJson).toList(growable: false);
  }

  /// Reads the immutable enrollment history in `startDate` order and resolves
  /// each class name and the authoritative S08 progress for every enrollment.
  Future<List<EnrollmentHistoryEntry>> enrollmentHistory({
    required String studentId,
    required String congregationId,
  }) async {
    final List<EnrollmentHistoryEntry> entries = <EnrollmentHistoryEntry>[];
    String? cursor;
    while (true) {
      final PageResult page = await gateway.query(
        QueryRequest(
          resource: QueryResource.enrollments,
          congregationId: congregationId,
          equalityFilters: <String, Object?>{'studentId': studentId},
          limit: maxPageSize,
          cursor: cursor,
        ),
      );
      for (final JsonMap item in page.items) {
        final Enrollment enrollment = Enrollment.fromJson(item);
        entries.add(
          EnrollmentHistoryEntry(
            enrollment: enrollment,
            className: await _className(congregationId, enrollment.classId),
            progress: await _progress(congregationId, enrollment.id),
          ),
        );
      }
      cursor = page.nextCursor;
      if (cursor == null) {
        break;
      }
    }
    return entries;
  }

  Future<String?> _className(String congregationId, String classId) async {
    final JsonMap? json = await gateway.get(
      RecordLocator(
        resource: QueryResource.classes,
        id: classId,
        congregationId: congregationId,
      ),
    );
    return json == null ? null : ClassGroup.fromJson(json).name;
  }

  Future<EnrollmentProgressView?> _progress(
    String congregationId,
    String enrollmentId,
  ) async {
    final JsonMap response = await gateway.invoke(
      'getEnrollmentProgress',
      <String, Object?>{
        'congregationId': congregationId,
        'enrollmentId': enrollmentId,
      },
    );
    return EnrollmentProgressView.fromJson(response);
  }
}
