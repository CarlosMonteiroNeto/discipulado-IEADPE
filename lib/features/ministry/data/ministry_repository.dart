import 'dart:convert';

import '../../../data/supabase_gateway.dart';
import '../../../domain/models.dart';
import '../domain/ministry_models.dart';
import 'ministry_codec.dart';

/// Typed client port for the scoped ministry RPC boundary.
/// Every read is a bounded server projection; every write carries a receipt ID.
class MinistryRepository {
  MinistryRepository(this.gateway);
  final ReadRpcGateway gateway;
  final _teacherContactSaves = <String, _PendingTeacherContactSave>{};

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

  Future<MinistryStudentDetail> getStudent({
    required String congregationId,
    required String studentId,
  }) async {
    _uuid(congregationId);
    _uuid(studentId);
    final result = await _read('ministry_get_student', {
      'congregation_id': congregationId,
      'student_id': studentId,
    });
    try {
      final student = decodeMinistryStudentDetail(result);
      if (student.id != studentId || student.congregationId != congregationId) {
        throw const MinistryDataException('Student scope does not match.');
      }
      return student;
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryTeacherContactDetail> getTeacherContact({
    required String congregationId,
    required String contactId,
  }) async {
    _uuid(congregationId);
    _uuid(contactId);
    final result = await _read('ministry_get_teacher_contact', {
      'congregation_id': congregationId,
      'contact_id': contactId,
    });
    try {
      final contact = decodeTeacherContactDetail(result);
      if (contact.id != contactId || contact.congregationId != congregationId) {
        throw const MinistryDataException(
          'Teacher contact scope does not match.',
        );
      }
      return contact;
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryContactDetail> getContact({
    required ContactScope scope,
    String? congregationId,
    required String contactId,
  }) async {
    _uuid(contactId);
    if ((scope == ContactScope.congregation) != (congregationId != null)) {
      throw const DataFailure('invalid');
    }
    if (congregationId != null) _uuid(congregationId);
    final result = await _read('ministry_get_contact', {
      'scope': scope.wire,
      'congregation_id': congregationId,
      'contact_id': contactId,
    });
    try {
      final detail = decodeMinistryContactDetail(result);
      if (detail.contact.id != contactId ||
          detail.contact.scope != scope ||
          detail.contact.congregationId != congregationId) {
        throw const MinistryDataException('Contact scope does not match.');
      }
      return detail;
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryContactAccessResult> saveContactWithAccess({
    required String operationId,
    String? id,
    int? expectedRevision,
    required ContactScope scope,
    String? congregationId,
    required String name,
    required RoleCode? roleCode,
    required String? phoneE164,
    required CalendarDate? birthDate,
    required String email,
    String? accessId,
    required AccessRole accessRole,
    String? accessCongregationId,
  }) async {
    _uuid(operationId);
    if (id != null) _uuid(id);
    if (accessId != null) _uuid(accessId);
    if (congregationId != null) _uuid(congregationId);
    if (accessCongregationId != null) _uuid(accessCongregationId);
    if ((scope == ContactScope.congregation) != (congregationId != null) ||
        (expectedRevision != null && (id == null || expectedRevision < 1)) ||
        name.isEmpty ||
        name != name.trim() ||
        name.length > 200 ||
        (roleCode != null && roleCode.scope != scope) ||
        (phoneE164 != null &&
            !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phoneE164)) ||
        email.isEmpty ||
        email != email.trim().toLowerCase() ||
        !email.contains('@') ||
        (accessRole == AccessRole.direction &&
            accessCongregationId != congregationId) ||
        (accessRole == AccessRole.supervision &&
            accessCongregationId != null) ||
        (scope == ContactScope.congregation &&
            accessRole != AccessRole.direction) ||
        (scope == ContactScope.supervision &&
            accessRole != AccessRole.supervision)) {
      throw const DataFailure('invalid');
    }
    final transport = gateway;
    if (transport is! MinistryCommandGateway) {
      throw const DataFailure('unavailable');
    }
    final commandGateway = transport as MinistryCommandGateway;
    final payload = <String, Object?>{
      if (id != null) 'id': id,
      if (expectedRevision != null) 'expected_revision': expectedRevision,
      'scope': scope.wire,
      'congregation_id': congregationId,
      'name': name,
      'role_code': roleCode?.wire,
      'phone_e164': phoneE164,
      'birth_date': birthDate?.toString(),
      'email': email,
      'access': <String, Object?>{
        if (accessId != null) 'id': accessId,
        'user_email': email,
        'role': accessRole.wireValue,
        'congregation_id': accessCongregationId,
      },
    };
    try {
      final result = await commandGateway.ministryCommand(
        'save_contact_with_access',
        operationId,
        payload,
      );
      return decodeMinistryContactAccessResult(
        result,
        expectedId: id,
        expectedRevision: expectedRevision == null ? 1 : expectedRevision + 1,
      );
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryContactAccessRevocationResult> revokeContactAccess({
    required String operationId,
    required String id,
    required ContactScope scope,
    String? congregationId,
    required int expectedRevision,
  }) async {
    _uuid(operationId);
    _uuid(id);
    if (congregationId != null) _uuid(congregationId);
    if ((scope == ContactScope.congregation) != (congregationId != null) ||
        expectedRevision < 1) {
      throw const DataFailure('invalid');
    }
    final transport = gateway;
    if (transport is! MinistryCommandGateway) {
      throw const DataFailure('unavailable');
    }
    final commandGateway = transport as MinistryCommandGateway;
    try {
      final result = await commandGateway.ministryCommand(
        'revoke_contact_access',
        operationId,
        {
          'id': id,
          'scope': scope.wire,
          'congregation_id': congregationId,
          'expected_revision': expectedRevision,
        },
      );
      return decodeMinistryContactAccessRevocationResult(
        result,
        expectedId: id,
        expectedRevision: expectedRevision + 1,
      );
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

  Future<MinistryCommandResult> saveContact({
    required String operationId,
    required String id,
    required ContactScope scope,
    String? congregationId,
    required String name,
    required RoleCode? roleCode,
    required String? phoneE164,
    required CalendarDate? birthDate,
    required String? email,
    int? expectedRevision,
  }) async {
    _uuid(operationId);
    _uuid(id);
    if (congregationId != null) _uuid(congregationId);
    if ((scope == ContactScope.congregation) != (congregationId != null) ||
        (expectedRevision != null && expectedRevision < 1) ||
        name.isEmpty ||
        name != name.trim() ||
        name.length > 200 ||
        (roleCode != null && roleCode.scope != scope) ||
        (phoneE164 != null &&
            !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phoneE164)) ||
        (email != null &&
            (email.isEmpty ||
                email != email.trim().toLowerCase() ||
                !email.contains('@')))) {
      throw const DataFailure('invalid');
    }
    final result = await command(
      name: 'save_contact',
      operationId: operationId,
      payload: {
        'id': id,
        'scope': scope.wire,
        'congregation_id': congregationId,
        'name': name,
        'role_code': roleCode?.wire,
        'phone_e164': phoneE164,
        'birth_date': birthDate?.toString(),
        'email': email,
        if (expectedRevision != null) 'expected_revision': expectedRevision,
      },
    );
    if (result.revision !=
        (expectedRevision == null ? 1 : expectedRevision + 1)) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  Future<MinistryCommandResult> setContactArchived({
    required String operationId,
    required String id,
    required ContactScope scope,
    String? congregationId,
    required bool archived,
    required int expectedRevision,
  }) async {
    _uuid(operationId);
    _uuid(id);
    if (congregationId != null) _uuid(congregationId);
    if ((scope == ContactScope.congregation) != (congregationId != null) ||
        expectedRevision < 1) {
      throw const DataFailure('invalid');
    }
    final result = await command(
      name: 'set_contact_archived',
      operationId: operationId,
      payload: {
        'id': id,
        'scope': scope.wire,
        'congregation_id': congregationId,
        'archived': archived,
        'expected_revision': expectedRevision,
      },
    );
    if (result.revision != expectedRevision + 1) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  Future<MinistryCommandResult> replaceRoleHolder({
    required String operationId,
    required String id,
    required ContactScope scope,
    String? congregationId,
    required RoleCode roleCode,
    required String previousContactId,
    required int expectedRevision,
    required int previousExpectedRevision,
  }) async {
    _uuid(operationId);
    _uuid(id);
    _uuid(previousContactId);
    if (congregationId != null) _uuid(congregationId);
    if ((scope == ContactScope.congregation) != (congregationId != null) ||
        roleCode.scope != scope ||
        id == previousContactId ||
        expectedRevision < 1 ||
        previousExpectedRevision < 1) {
      throw const DataFailure('invalid');
    }
    final result = await command(
      name: 'replace_role_holder',
      operationId: operationId,
      payload: {
        'id': id,
        'scope': scope.wire,
        'congregation_id': congregationId,
        'role_code': roleCode.wire,
        'previous_contact_id': previousContactId,
        'expected_revision': expectedRevision,
        'previous_expected_revision': previousExpectedRevision,
      },
    );
    if (result.revision != expectedRevision + 1 ||
        result.fields['previous_contact_id'] != previousContactId ||
        result.fields['previous_revision'] != previousExpectedRevision + 1 ||
        result.fields.keys.toSet().difference(const {
          'previous_contact_id',
          'previous_revision',
        }).isNotEmpty) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  /// Edits only academic fields. Canonical name and contact data use
  /// [savePerson] with its independent person revision.
  Future<MinistryCommandResult> saveStudent({
    required String operationId,
    required String id,
    required String congregationId,
    required int expectedRevision,
    required String? education,
    required String? maritalStatus,
    required bool? newConvert,
    required bool? waterBaptized,
    required bool? wantsBaptism,
  }) async {
    _uuid(operationId);
    _uuid(id);
    _uuid(congregationId);
    if (expectedRevision < 1 ||
        (waterBaptized == true && wantsBaptism == true)) {
      throw const DataFailure('invalid');
    }
    final result = await command(
      name: 'save_student',
      operationId: operationId,
      payload: {
        'id': id,
        'congregation_id': congregationId,
        'expected_revision': expectedRevision,
        'education': education,
        'marital_status': maritalStatus,
        'new_convert': newConvert,
        'water_baptized': waterBaptized,
        'wants_baptism': wantsBaptism,
      },
    );
    if (result.revision != expectedRevision + 1) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  Future<MinistryCommandResult> saveTeacherContact({
    required String operationId,
    required String id,
    required String congregationId,
    required String name,
    required String? phoneE164,
    required CalendarDate? birthDate,
    int? expectedRevision,
  }) async {
    _uuid(operationId);
    _uuid(id);
    _uuid(congregationId);
    final normalizedName = name.trim();
    if (normalizedName.isEmpty ||
        normalizedName.length > 200 ||
        name != normalizedName ||
        (phoneE164 != null &&
            !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phoneE164)) ||
        (expectedRevision != null && expectedRevision < 1)) {
      throw const DataFailure('invalid');
    }
    final signature = jsonEncode([
      id,
      congregationId,
      normalizedName,
      phoneE164,
      birthDate?.toString(),
      expectedRevision,
    ]);
    final previous = _teacherContactSaves[operationId];
    if (previous != null && previous.signature != signature) {
      throw const DataFailure('operation_conflict');
    }
    final pending =
        previous ??
        _teacherContactSaves.putIfAbsent(
          operationId,
          () => _PendingTeacherContactSave(
            signature: signature,
            payload: _buildTeacherContactPayload(
              id: id,
              congregationId: congregationId,
              name: normalizedName,
              phoneE164: phoneE164,
              birthDate: birthDate,
              expectedRevision: expectedRevision,
            ),
          ),
        );
    late final Map<String, Object?> payload;
    try {
      payload = await pending.payload;
    } catch (_) {
      if (identical(_teacherContactSaves[operationId], pending)) {
        _teacherContactSaves.remove(operationId);
      }
      rethrow;
    }
    final result = await command(
      name: 'save_contact',
      operationId: operationId,
      payload: payload,
    );
    if (result.revision !=
        (expectedRevision == null ? 1 : expectedRevision + 1)) {
      throw const DataFailure('invalid_response');
    }
    _teacherContactSaves.remove(operationId);
    return result;
  }

  Future<Map<String, Object?>> _buildTeacherContactPayload({
    required String id,
    required String congregationId,
    required String name,
    required String? phoneE164,
    required CalendarDate? birthDate,
    required int? expectedRevision,
  }) async {
    final email = expectedRevision == null
        ? null
        : (await getContact(
            scope: ContactScope.congregation,
            congregationId: congregationId,
            contactId: id,
          )).contact.email;
    return Map<String, Object?>.unmodifiable({
      'id': id,
      'scope': 'congregation',
      'congregation_id': congregationId,
      'name': name,
      'role_code': 'teacher',
      'phone_e164': phoneE164,
      'birth_date': birthDate?.toString(),
      'email': email,
      if (expectedRevision != null) 'expected_revision': expectedRevision,
    });
  }

  Future<MinistryEnrollmentResult> enrollStudent({
    required String operationId,
    required String id,
    required String congregationId,
    required String classId,
    required String personId,
    required CalendarDate startDate,
  }) async {
    _uuid(operationId);
    _uuid(id);
    _uuid(congregationId);
    _uuid(classId);
    _uuid(personId);
    final commandResult = await command(
      name: 'enroll_student',
      operationId: operationId,
      payload: {
        'id': id,
        'congregation_id': congregationId,
        'class_id': classId,
        'person_id': personId,
        'start_date': startDate.toString(),
      },
    );
    try {
      return decodeMinistryEnrollmentResult(
        {
          'id': commandResult.id,
          'revision': commandResult.revision,
          ...commandResult.fields,
        },
        expectedId: id,
        expectedPersonId: personId,
      );
    } on MinistryDataException {
      throw const DataFailure('invalid_response');
    }
  }

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

  Future<PersonRegistrationResult> registerStudent({
    required String operationId,
    required String studentId,
    required String personId,
    required String congregationId,
    required MinistryPersonDraft person,
    String? education,
    String? maritalStatus,
    bool? newConvert,
    bool? waterBaptized,
    bool? wantsBaptism,
  }) async {
    _uuid(operationId);
    _uuid(studentId);
    _uuid(personId);
    _uuid(congregationId);
    if (person.name.trim().isEmpty ||
        person.name != person.name.trim() ||
        person.name.length > 200 ||
        newConvert == true ||
        (waterBaptized == true && wantsBaptism == true)) {
      throw const DataFailure('invalid');
    }
    final transport = gateway;
    if (transport is! StudentRegistrationCommandGateway) {
      throw const DataFailure('unavailable');
    }
    final commandGateway = transport as StudentRegistrationCommandGateway;
    final result = await commandGateway.registerStudent(operationId, {
      'id': studentId,
      'person_id': personId,
      'congregation_id': congregationId,
      'person': person.toJson(),
      'academic': {
        'education': education,
        'marital_status': maritalStatus,
        'new_convert': newConvert,
        'water_baptized': waterBaptized,
        'wants_baptism': wantsBaptism,
      },
    });
    if (result.status != MutationStatus.applied || result.value == null) {
      throw DataFailure(result.errorCode ?? 'invalid_response');
    }
    final value = result.value!;
    if (value.studentId != studentId ||
        value.personId != personId ||
        value.studentRevision != 1 ||
        value.personRevision != 1 ||
        value.convertId != null ||
        value.convertRevision != null) {
      throw const DataFailure('invalid_response');
    }
    return value;
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

class _PendingTeacherContactSave {
  const _PendingTeacherContactSave({
    required this.signature,
    required this.payload,
  });

  final String signature;
  final Future<Map<String, Object?>> payload;
}
