import '../../../data/supabase_gateway.dart';
import '../domain/ministry_models.dart';
import 'ministry_codec.dart';

/// Typed client port for the scoped ministry RPC boundary.
/// Every read is a bounded server projection; every write carries a receipt ID.
class MinistryRepository {
  MinistryRepository(this.gateway);
  final ReadRpcGateway gateway;

  Future<MinistryCommandResult> setStudentArchived({
    required String operationId,
    required String id,
    required String congregationId,
    required bool archived,
    required int expectedRevision,
  }) => command(
    name: 'set_student_archived',
    operationId: operationId,
    payload: {
      'id': id,
      'congregation_id': congregationId,
      'archived': archived,
      'expected_revision': expectedRevision,
    },
  );

  Future<MinistryPerson> getPerson({
    required String congregationId,
    required String personId,
  }) async {
    _uuid(congregationId);
    _uuid(personId);
    final result = await _read('ministry_get_person', {
      'congregation_id': congregationId,
      'person_id': personId,
    });
    try {
      final person = decodeMinistryPersonDetail(result);
      if (person.id != personId || person.congregationId != congregationId) {
        throw const MinistryDataException('Person scope does not match.');
      }
      return person;
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryPage<MinistryPersonSummary>> listPeople({
    required String congregationId,
    String? namePrefix,
    int limit = 50,
    String? cursor,
  }) async {
    _uuid(congregationId);
    _page(limit, cursor);
    if (namePrefix != null &&
        (namePrefix.trim().isEmpty ||
            namePrefix != namePrefix.trim() ||
            namePrefix.length > 200)) {
      throw const DataFailure('invalid');
    }
    final result = await _read('ministry_list_people', {
      'congregation_id': congregationId,
      'name_prefix': namePrefix,
      'limit': limit,
      'cursor': cursor,
    });
    try {
      return decodePeoplePage(result);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryCommandResult> savePerson({
    required String operationId,
    required String id,
    required String congregationId,
    required int expectedRevision,
    required MinistryPersonDraft person,
  }) async {
    _uuid(id);
    _uuid(congregationId);
    if (expectedRevision < 1) throw const DataFailure('invalid');
    final result = await command(
      name: 'save_person',
      operationId: operationId,
      payload: {
        'id': id,
        'congregation_id': congregationId,
        'expected_revision': expectedRevision,
        'person': person.toJson(),
      },
    );
    if (result.revision != expectedRevision + 1) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  Future<StudentPersonLinkResult> linkStudentPerson({
    required String operationId,
    required String congregationId,
    required String studentId,
    required String personId,
    required int expectedStudentRevision,
    required int expectedPersonRevision,
  }) async {
    _uuid(operationId);
    _uuid(congregationId);
    _uuid(studentId);
    _uuid(personId);
    if (expectedStudentRevision < 1 || expectedPersonRevision < 1) {
      throw const DataFailure('invalid');
    }
    final transport = gateway;
    if (transport is! MinistryCommandGateway) {
      throw const DataFailure('unavailable');
    }
    try {
      final commandGateway = transport as MinistryCommandGateway;
      final raw = await commandGateway.linkStudentPerson(operationId, {
        'congregation_id': congregationId,
        'student_id': studentId,
        'person_id': personId,
        'expected_student_revision': expectedStudentRevision,
        'expected_person_revision': expectedPersonRevision,
      });
      return decodeStudentPersonLinkResult(
        raw,
        expectedStudentId: studentId,
        expectedPersonId: personId,
        expectedStudentRevision: expectedStudentRevision,
        expectedPersonRevision: expectedPersonRevision,
      );
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryPage<MinistryDirectoryEntry>> listDirectory({
    required String scope,
    String? congregationId,
    String? roleCode,
    String? namePrefix,
    int limit = 50,
    String? cursor,
  }) async {
    if (!{'congregation', 'supervision', 'all'}.contains(scope) ||
        limit < 1 ||
        limit > 100 ||
        (scope == 'congregation' && congregationId == null) ||
        (scope != 'congregation' && congregationId != null && scope == 'all') ||
        (cursor?.length ?? 0) > 4096) {
      throw const DataFailure('invalid');
    }
    final token = gateway.context;
    try {
      final result = await gateway.readRpc(
        'ministry_list_directory',
        context: token,
        parameters: {
          'scope': scope,
          'congregation_id': congregationId,
          'role_code': roleCode,
          'name_prefix': namePrefix,
          'limit': limit,
          'cursor': cursor,
        },
      );
      gateway.ensureCurrent(token);
      return decodeDirectoryPage(result);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryPage<ClassStudentEntry>> listClassStudents({
    required String congregationId,
    required String classId,
    int limit = 50,
    String? cursor,
  }) async {
    _uuid(congregationId);
    _uuid(classId);
    _page(limit, cursor);
    final result = await _read('ministry_list_class_students', {
      'congregation_id': congregationId,
      'class_id': classId,
      'limit': limit,
      'cursor': cursor,
    });
    try {
      return decodeClassStudents(result);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryRoster> getSessionAttendance({
    required String congregationId,
    required String sessionId,
  }) async {
    _uuid(congregationId);
    _uuid(sessionId);
    final result = await _read('ministry_get_session_attendance', {
      'congregation_id': congregationId,
      'session_id': sessionId,
    });
    try {
      return decodeRoster(result);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<EnrollmentProgress> getEnrollmentProgress({
    required String congregationId,
    required String enrollmentId,
  }) async {
    _uuid(congregationId);
    _uuid(enrollmentId);
    final result = await _read('ministry_get_enrollment_progress', {
      'congregation_id': congregationId,
      'enrollment_id': enrollmentId,
    });
    try {
      return decodeProgress(result);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<Map<String, Object?>> getOverview({String? congregationId}) async {
    if (congregationId != null) _uuid(congregationId);
    final result = await _read('ministry_get_overview', {
      'congregation_id': congregationId,
    });
    const keys = {'students', 'classes', 'open_sessions', 'through_date'};
    if (result.keys.toSet().difference(keys).isNotEmpty ||
        !result.keys.toSet().containsAll(keys) ||
        result.values.any((v) => v is! int && v is! String)) {
      throw const DataFailure('invalid_response');
    }
    return Map.unmodifiable(result);
  }

  Future<MinistryPage<PendingMinistrySession>> listPendingSessions({
    String? congregationId,
    int limit = 50,
    String? cursor,
  }) async {
    if (congregationId != null) _uuid(congregationId);
    _page(limit, cursor);
    final result = await _read('ministry_list_pending_sessions', {
      'congregation_id': congregationId,
      'limit': limit,
      'cursor': cursor,
    });
    try {
      return decodePendingSessions(result);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryCommandResult> command({
    required String name,
    required String operationId,
    required Map<String, Object?> payload,
  }) async {
    _uuid(operationId);
    final transport = gateway;
    if (transport is! MinistryCommandGateway) {
      throw const DataFailure('unavailable');
    }
    try {
      final commandGateway = transport as MinistryCommandGateway;
      final result = await commandGateway.ministryCommand(
        name,
        operationId,
        payload,
      );
      final resultId = payload['id'] ?? payload['session_id'];
      if (resultId is! String) throw const DataFailure('invalid');
      _uuid(resultId);
      return decodeCommandResult(result, expectedId: resultId);
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<Map<String, dynamic>> _read(
    String rpc,
    Map<String, Object?> parameters,
  ) async {
    final token = gateway.context;
    final result = await gateway.readRpc(
      rpc,
      context: token,
      parameters: parameters,
    );
    gateway.ensureCurrent(token);
    return result;
  }

  static void _uuid(String value) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw const DataFailure('invalid');
    }
  }

  static void _page(int limit, String? cursor) {
    if (limit < 1 || limit > 100 || (cursor?.length ?? 0) > 4096) {
      throw const DataFailure('invalid');
    }
  }
}
