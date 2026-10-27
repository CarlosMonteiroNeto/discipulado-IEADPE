import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';

/// Share one instance across protected repositories and invalidate synchronously
/// from SessionRouter.clearProtectedCaches before clearing feature state.
class ProtectedDataBoundary {
  String _generation = const Uuid().v4();
  String get generation => _generation;
  void invalidate() => _generation = const Uuid().v4();
}

class DataFailure implements Exception {
  const DataFailure(this.code);
  final String code;
  @override
  String toString() => 'DataFailure($code)';
}

/// Injectable transport contract. Read requests must obey the boundary token.
abstract interface class Gateway {
  ProtectedDataBoundary get boundary;
  String get context;
  void ensureCurrent(String context);
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  });
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  );
}

/// Additive protected read-RPC contract; existing Gateway implementers remain valid.
abstract interface class ReadRpcGateway implements Gateway {
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  });
}

/// Authenticated review RPC transport. Pending-review writes have a typed
/// result distinct from the older ID-only [Gateway.command] contract.
abstract interface class PendingReviewGateway implements ReadRpcGateway {
  Future<Map<String, dynamic>> reviewPendingIntake(
    String operationId,
    Map<String, Object?> payload,
  );
}

/// Additive ministry command transport. Rich ministry results include revisions
/// and status values, while the older convert command contract returns an ID.
abstract interface class MinistryCommandGateway implements Gateway {
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  );

  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  );
}

abstract interface class StudentRegistrationCommandGateway implements Gateway {
  Future<MutationResult<PersonRegistrationResult>> registerStudent(
    String operationId,
    Map<String, Object?> payload,
  );
}

abstract interface class HandoffCommandGateway implements Gateway {
  Future<Map<String, dynamic>> promoteConvertToStudent(
    String operationId,
    Map<String, Object?> payload,
  );
}

abstract interface class ConvertCommandGateway implements Gateway {
  Future<MutationResult<PersonRegistrationResult>> saveConvert(
    String command,
    String operationId,
    Map<String, Object?> payload,
  );
}

abstract interface class ImportRpcGateway implements Gateway {
  Future<Map<String, dynamic>> importRow(
    String operationId,
    Map<String, Object?> payload,
  );
}

class SupabaseGateway
    implements
        PendingReviewGateway,
        ImportRpcGateway,
        MinistryCommandGateway,
        StudentRegistrationCommandGateway,
        HandoffCommandGateway,
        ConvertCommandGateway {
  SupabaseGateway(
    this.client,
    this.boundary, {
    this.requestTimeout = const Duration(seconds: 15),
  });
  final SupabaseClient client;
  @override
  final ProtectedDataBoundary boundary;
  final Duration requestTimeout;
  @override
  String get context =>
      '${boundary.generation}:${client.auth.currentUser?.id ?? ''}';
  @override
  void ensureCurrent(String token) {
    if (context != token) throw const DataFailure('stale');
  }

  Future<T> _run<T>(String token, Future<T> Function() request) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      ensureCurrent(token);
      try {
        final result = await request();
        ensureCurrent(token);
        return result;
      } catch (error) {
        ensureCurrent(token);
        if (error is PostgrestException &&
            error.code == '40001' &&
            error.message.contains('stale_revision')) {
          throw const DataFailure('stale_revision');
        }
        if (error is PostgrestException &&
            error.message.contains('active_enrollment')) {
          throw const DataFailure('active_enrollment');
        }
        final transient =
            error is TimeoutException ||
            (error is PostgrestException &&
                {'40001', '40P01', '502', '503', '504'}.contains(error.code));
        if (transient && attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 100 * (attempt + 1)),
          );
          continue;
        }
        if (error is DataFailure) rethrow;
        if (error is PostgrestException) {
          if (error.code == '42501' ||
              error.code == '403' ||
              error.code == '401') {
            throw const DataFailure('permission');
          }
          if (error.code == '23505' &&
              error.message.trim() == 'academic_conflict') {
            throw const DataFailure('academic_conflict');
          }
          if (error.code == '22023' &&
              error.message.trim() == 'academic_invalid') {
            throw const DataFailure('academic_invalid');
          }
          if (error.code == '22023' ||
              error.code == '22P02' ||
              error.code == '23514') {
            throw const DataFailure('invalid');
          }
        }
        throw DataFailure(transient ? 'unavailable' : 'backend');
      }
    }
    throw const DataFailure('unavailable');
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async {
    if (!{
      'converts',
      'user_access',
      'photo_assets',
      'congregations',
      'convert_events',
      'feedback',
    }.contains(table)) {
      throw ArgumentError.value(table, 'table');
    }
    final result = await _run(context, () {
      var request = client.from(table).select();
      if (excludeDeleted) request = request.isFilter('deleted_at', null);
      if (afterId != null) request = request.gt('id', afterId);
      for (final entry in equals.entries) {
        request = request.eq(entry.key, entry.value);
      }
      if (name != null && name.isNotEmpty) {
        final escaped = name
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_');
        request = name.contains('*')
            ? request.filter('name', 'imatch', RegExp.escape(name))
            : request.ilike('name', '%$escaped%');
      }
      return request
          .order('id', ascending: true)
          .limit(100)
          .retry(enabled: false, requestTimeout: requestTimeout);
    });
    if (result.length > 100) throw const DataFailure('invalid_response');
    return result;
  }

  @override
  Future<MutationResult<PersonRegistrationResult>> saveConvert(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    if (!{'create_convert', 'edit_convert'}.contains(command)) {
      throw ArgumentError.value(command, 'command');
    }
    final expectedKeys = command == 'create_convert'
        ? const {'congregation_id', 'person', 'convert'}
        : const {
            'id',
            'congregation_id',
            'expected_revision',
            'expected_person_revision',
            'person',
            'convert',
          };
    if (!_hasExactKeys(payload, expectedKeys)) {
      throw const DataFailure('invalid');
    }
    validateUuid(payload['congregation_id']);
    if (command == 'edit_convert') {
      validateUuid(payload['id']);
      for (final key in ['expected_revision', 'expected_person_revision']) {
        final revision = payload[key];
        if (revision is! int || revision < 1) {
          throw const DataFailure('invalid');
        }
      }
    }
    final rawPerson = payload['person'];
    final rawConvert = payload['convert'];
    if (rawPerson is! Map || rawConvert is! Map) {
      throw const DataFailure('invalid');
    }
    final person = Map<String, Object?>.from(rawPerson);
    final convert = Map<String, Object?>.from(rawConvert);
    const personKeys = {'name', 'phone', 'birth_date', 'address'};
    const convertKeys = {
      'landmark',
      'gender',
      'conversion_date',
      'worship_type',
      'age',
      'photo_asset_id',
    };
    final name = person['name'];
    if (!_hasExactKeys(person, personKeys) ||
        !_hasExactKeys(convert, convertKeys) ||
        name is! String ||
        name.trim().isEmpty ||
        name != name.trim() ||
        (command == 'create_convert' && name.length > 200)) {
      throw const DataFailure('invalid');
    }
    final phone = person['phone'];
    final birthDate = person['birth_date'];
    if ((phone != null && phone is! String) ||
        (birthDate != null &&
            (birthDate is! String || !_isIsoDate(birthDate)))) {
      throw const DataFailure('invalid');
    }
    final rawAddress = person['address'];
    if (rawAddress != null) {
      if (rawAddress is! Map) throw const DataFailure('invalid');
      final address = Map<String, Object?>.from(rawAddress);
      const addressKeys = {
        'street',
        'district',
        'city',
        'postal_code',
        'state_code',
      };
      if (!_hasExactKeys(address, addressKeys) ||
          address.values.any((value) => value != null && value is! String)) {
        throw const DataFailure('invalid');
      }
    }
    final landmark = convert['landmark'];
    final gender = convert['gender'];
    final conversionDate = convert['conversion_date'];
    final worshipType = convert['worship_type'];
    final age = convert['age'];
    final photoAssetId = convert['photo_asset_id'];
    if (landmark is! String ||
        landmark.trim().isEmpty ||
        landmark != landmark.trim() ||
        (gender != 'male' && gender != 'female') ||
        conversionDate is! String ||
        !_isIsoDate(conversionDate) ||
        (worshipType != null &&
            (worshipType is! String ||
                worshipType.trim().isEmpty ||
                worshipType != worshipType.trim())) ||
        (age != null && (age is! int || age < 0 || age > 150))) {
      throw const DataFailure('invalid');
    }
    if (photoAssetId != null) validateUuid(photoAssetId);
    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final token = context;
    try {
      final value = await _run(
        token,
        () => client
            .rpc(
              'ieadpe_$command',
              params: {'operation_id': operationId, 'payload': frozen},
            )
            .retry(enabled: false, requestTimeout: requestTimeout),
      );
      const resultKeys = {'id', 'person_id', 'revision', 'person_revision'};
      if (value is! Map<String, dynamic> ||
          !_hasExactKeys(value, resultKeys) ||
          value['id'] is! String ||
          value['person_id'] is! String ||
          value['revision'] is! int ||
          value['person_revision'] is! int ||
          (value['revision'] as int) < 1 ||
          (value['person_revision'] as int) < 1) {
        throw const DataFailure('invalid_response');
      }
      validateUuid(value['id']);
      validateUuid(value['person_id']);
      if (command == 'create_convert' &&
          (value['revision'] != 1 || value['person_revision'] != 1)) {
        throw const DataFailure('invalid_response');
      }
      if (command == 'edit_convert' &&
          (value['id'] != payload['id'] ||
              value['revision'] != (payload['expected_revision'] as int) + 1 ||
              !{
                payload['expected_person_revision'],
                (payload['expected_person_revision'] as int) + 1,
              }.contains(value['person_revision']))) {
        throw const DataFailure('invalid_response');
      }
      return MutationResult.applied(
        operationId: operationId,
        value: PersonRegistrationResult(
          personId: value['person_id'] as String,
          convertId: value['id'] as String,
          personRevision: value['person_revision'] as int,
          convertRevision: value['revision'] as int,
        ),
      );
    } on DataFailure catch (error) {
      return MutationResult.rejected(
        operationId: operationId,
        errorCode: error.code,
      );
    }
  }

  @override
  Future<MutationResult<PersonRegistrationResult>> registerStudent(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const topLevelKeys = {
      'id',
      'person_id',
      'congregation_id',
      'person',
      'academic',
    };
    if (!_hasExactKeys(payload, topLevelKeys)) {
      throw const DataFailure('invalid');
    }
    for (final key in ['id', 'person_id', 'congregation_id']) {
      validateUuid(payload[key]);
    }
    final rawPerson = payload['person'];
    final rawAcademic = payload['academic'];
    if (rawPerson is! Map || rawAcademic is! Map) {
      throw const DataFailure('invalid');
    }
    final person = Map<String, Object?>.from(rawPerson);
    final academic = Map<String, Object?>.from(rawAcademic);
    const personKeys = {'name', 'phone', 'birth_date', 'address'};
    const academicKeys = {
      'education',
      'marital_status',
      'new_convert',
      'water_baptized',
      'wants_baptism',
    };
    final name = person['name'];
    if (!_hasExactKeys(person, personKeys) ||
        !_hasExactKeys(academic, academicKeys) ||
        name is! String ||
        name.trim().isEmpty ||
        name != name.trim() ||
        name.length > 200) {
      throw const DataFailure('invalid');
    }
    final phone = person['phone'];
    final birthDate = person['birth_date'];
    if ((phone != null && phone is! String) ||
        (birthDate != null &&
            (birthDate is! String || !_isIsoDate(birthDate)))) {
      throw const DataFailure('invalid');
    }
    final rawAddress = person['address'];
    if (rawAddress != null) {
      if (rawAddress is! Map) throw const DataFailure('invalid');
      final address = Map<String, Object?>.from(rawAddress);
      const addressKeys = {
        'street',
        'district',
        'city',
        'postal_code',
        'state_code',
      };
      if (!_hasExactKeys(address, addressKeys) ||
          address.values.any((value) => value != null && value is! String)) {
        throw const DataFailure('invalid');
      }
    }
    if (academic['new_convert'] == true ||
        academic.values.any(
          (value) => value != null && value is! String && value is! bool,
        ) ||
        (academic['new_convert'] != null && academic['new_convert'] is! bool) ||
        (academic['water_baptized'] != null &&
            academic['water_baptized'] is! bool) ||
        (academic['wants_baptism'] != null &&
            academic['wants_baptism'] is! bool) ||
        (academic['water_baptized'] == true &&
            academic['wants_baptism'] == true)) {
      throw const DataFailure('invalid');
    }

    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final token = context;
    try {
      final value = await _run(
        token,
        () => client
            .rpc(
              'ieadpe_ministry_register_student',
              params: {'operation_id': operationId, 'payload': frozen},
            )
            .retry(enabled: false, requestTimeout: requestTimeout),
      );
      const resultKeys = {'id', 'person_id', 'revision', 'person_revision'};
      if (value is! Map<String, dynamic> ||
          !_hasExactKeys(value, resultKeys) ||
          value['id'] != payload['id'] ||
          value['person_id'] != payload['person_id'] ||
          value['revision'] != 1 ||
          value['person_revision'] != 1) {
        throw const DataFailure('invalid_response');
      }
      validateUuid(value['id']);
      validateUuid(value['person_id']);
      return MutationResult.applied(
        operationId: operationId,
        value: PersonRegistrationResult(
          personId: value['person_id'] as String,
          studentId: value['id'] as String,
          personRevision: value['person_revision'] as int,
          studentRevision: value['revision'] as int,
        ),
      );
    } on DataFailure catch (error) {
      return MutationResult.rejected(
        operationId: operationId,
        errorCode: error.code,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    const pendingReadParameters = <String, Set<String>>{
      'list_pending_intake': {'congregation_id', 'limit', 'cursor'},
      'get_pending_intake': {'id'},
    };
    const ministryReadParameters = <String, Set<String>>{
      'ministry_list_congregations': {'limit', 'cursor'},
      'ministry_list_people': {
        'congregation_id',
        'name_prefix',
        'limit',
        'cursor',
      },
      'ministry_list_converts': {
        'congregation_id',
        'name_prefix',
        'limit',
        'cursor',
      },
      'ministry_get_convert': {'congregation_id', 'convert_id'},
      'ministry_get_person': {'congregation_id', 'person_id'},
      'ministry_get_student': {'congregation_id', 'student_id'},
      'ministry_get_teacher_contact': {'congregation_id', 'contact_id'},
      'ministry_get_contact': {'scope', 'congregation_id', 'contact_id'},
      'ministry_list_directory': {
        'scope',
        'congregation_id',
        'role_code',
        'name_prefix',
        'limit',
        'cursor',
      },
      'ministry_list_access_candidates': {
        'scope',
        'congregation_id',
        'role',
        'limit',
        'cursor',
      },
      'ministry_list_class_students': {
        'congregation_id',
        'class_id',
        'limit',
        'cursor',
      },
      'ministry_list_class_sessions': {
        'congregation_id',
        'class_id',
        'limit',
        'cursor',
      },
      'ministry_get_session_attendance': {'congregation_id', 'session_id'},
      'ministry_get_enrollment_progress': {'congregation_id', 'enrollment_id'},
      'ministry_list_student_enrollments': {
        'congregation_id',
        'student_id',
        'limit',
        'cursor',
      },
      'ministry_get_overview': {'congregation_id'},
      'ministry_list_pending_sessions': {'congregation_id', 'limit', 'cursor'},
      'ministry_list_convert_referrals': {'congregation_id', 'limit', 'cursor'},
      'ministry_list_convert_student_candidates': {
        'congregation_id',
        'name_prefix',
        'limit',
        'cursor',
      },
      'ministry_list_students': {
        'congregation_id',
        'name_prefix',
        'limit',
        'cursor',
      },
      'ministry_list_classes': {'congregation_id', 'status', 'limit', 'cursor'},
    };
    final ministryKeys = ministryReadParameters[rpc];
    final pendingKeys = pendingReadParameters[rpc];
    final ministryRead = ministryKeys != null;
    final Set<String>? allowed =
        ministryKeys ??
        pendingKeys ??
        (rpc == 'weekly_overview'
            ? <String>{'after_id', 'expected_week'}
            : null);
    if (allowed == null ||
        parameters.keys.any((key) => !allowed.contains(key))) {
      throw const DataFailure('invalid');
    }
    const requiredReadKeys = <String, Set<String>>{
      'list_pending_intake': {'congregation_id', 'limit', 'cursor'},
      'get_pending_intake': {'id'},
      'ministry_list_people': {'congregation_id', 'limit'},
      'ministry_list_converts': {'limit'},
      'ministry_get_convert': {'congregation_id', 'convert_id'},
      'ministry_get_person': {'congregation_id', 'person_id'},
      'ministry_get_student': {'congregation_id', 'student_id'},
      'ministry_get_teacher_contact': {'congregation_id', 'contact_id'},
      'ministry_get_contact': {'scope', 'contact_id'},
      'ministry_list_access_candidates': {
        'scope',
        'congregation_id',
        'role',
        'limit',
        'cursor',
      },
      'ministry_list_students': {'congregation_id', 'limit'},
      'ministry_list_class_students': {'congregation_id', 'class_id', 'limit'},
      'ministry_list_class_sessions': {
        'congregation_id',
        'class_id',
        'limit',
        'cursor',
      },
      'ministry_list_student_enrollments': {
        'congregation_id',
        'student_id',
        'limit',
        'cursor',
      },
    };
    final required = requiredReadKeys[rpc];
    if (required != null && !parameters.keys.toSet().containsAll(required)) {
      throw const DataFailure('invalid');
    }
    final frozen = Map<String, Object?>.unmodifiable(parameters);
    final result = await _run(
      context,
      () => client
          .rpc(
            'ieadpe_$rpc',
            params: ministryRead || pendingKeys != null
                ? {'request': frozen}
                : frozen,
          )
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    if (result is! Map<String, dynamic>) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> reviewPendingIntake(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    if (!_hasExactKeys(payload, {
          'id',
          'expected_revision',
          'decision',
          if (payload['decision'] == 'approve') 'draft',
        }) ||
        !{'approve', 'reject'}.contains(payload['decision'])) {
      throw const DataFailure('invalid');
    }
    validateUuid(payload['id']);
    final revision = payload['expected_revision'];
    if (revision is! int || revision < 1) throw const DataFailure('invalid');
    if (payload['decision'] == 'approve' && payload['draft'] is! Map ||
        payload['decision'] == 'reject' && payload.containsKey('draft')) {
      throw const DataFailure('invalid');
    }
    final frozen = Map<String, Object?>.unmodifiable(payload);
    final result = await _run(
      context,
      () => client
          .rpc(
            'ieadpe_review_pending_intake',
            params: {'operation_id': operationId, 'payload': frozen},
          )
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    if (result is! Map<String, dynamic>) {
      throw const DataFailure('invalid_response');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> ministryCommand(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const fields = <String, Set<String>>{
      'save_contact': {
        'id',
        'scope',
        'congregation_id',
        'name',
        'role_code',
        'phone_e164',
        'birth_date',
        'email',
        'expected_revision',
      },
      'save_contact_with_access': {
        'id',
        'expected_revision',
        'scope',
        'congregation_id',
        'name',
        'role_code',
        'phone_e164',
        'birth_date',
        'email',
        'access',
      },
      'revoke_contact_access': {
        'id',
        'scope',
        'congregation_id',
        'expected_revision',
      },
      'replace_role_holder': {
        'scope',
        'congregation_id',
        'role_code',
        'previous_contact_id',
        'previous_expected_revision',
        'id',
        'expected_revision',
      },
      'set_contact_archived': {
        'id',
        'scope',
        'congregation_id',
        'archived',
        'expected_revision',
      },
      'save_student': {
        'id',
        'congregation_id',
        'education',
        'marital_status',
        'new_convert',
        'water_baptized',
        'wants_baptism',
        'expected_revision',
      },
      'save_person': {'id', 'congregation_id', 'expected_revision', 'person'},
      'set_student_archived': {
        'id',
        'congregation_id',
        'archived',
        'expected_revision',
      },
      'save_class': {
        'id',
        'congregation_id',
        'name',
        'teacher_contact_id',
        'start_date',
        'end_date',
        'expected_revision',
      },
      'set_class_status': {
        'id',
        'congregation_id',
        'status',
        'expected_revision',
      },
      'enroll_student': {
        'id',
        'congregation_id',
        'class_id',
        'person_id',
        'start_date',
      },
      'close_enrollment': {
        'id',
        'congregation_id',
        'status',
        'end_date',
        'expected_revision',
      },
      'create_session': {
        'id',
        'congregation_id',
        'class_id',
        'date',
        'topic',
        'replaces_session_id',
      },
      'cancel_session': {'id', 'congregation_id', 'expected_revision'},
      'save_attendance': {
        'congregation_id',
        'session_id',
        'expected_revision',
        'marks',
        'finalize',
      },
    };
    final allowed = fields[command];
    if (allowed == null || payload.keys.any((key) => !allowed.contains(key))) {
      throw const DataFailure('invalid');
    }
    const required = <String, Set<String>>{
      'save_contact': {
        'id',
        'scope',
        'congregation_id',
        'name',
        'role_code',
        'phone_e164',
        'birth_date',
        'email',
      },
      'save_contact_with_access': {
        'scope',
        'congregation_id',
        'name',
        'role_code',
        'phone_e164',
        'birth_date',
        'email',
        'access',
      },
      'revoke_contact_access': {
        'id',
        'scope',
        'congregation_id',
        'expected_revision',
      },
      'replace_role_holder': {
        'scope',
        'congregation_id',
        'role_code',
        'previous_contact_id',
        'previous_expected_revision',
        'id',
        'expected_revision',
      },
      'set_contact_archived': {
        'id',
        'scope',
        'congregation_id',
        'archived',
        'expected_revision',
      },
      'save_student': {'id', 'congregation_id', 'expected_revision'},
      'save_person': {'id', 'congregation_id', 'expected_revision', 'person'},
      'set_student_archived': {
        'id',
        'congregation_id',
        'archived',
        'expected_revision',
      },
      'save_class': {
        'id',
        'congregation_id',
        'name',
        'teacher_contact_id',
        'start_date',
        'end_date',
      },
      'set_class_status': {
        'id',
        'congregation_id',
        'status',
        'expected_revision',
      },
      'enroll_student': {
        'id',
        'congregation_id',
        'class_id',
        'person_id',
        'start_date',
      },
      'close_enrollment': {
        'id',
        'congregation_id',
        'status',
        'end_date',
        'expected_revision',
      },
      'create_session': {'id', 'congregation_id', 'class_id', 'date', 'topic'},
      'cancel_session': {'id', 'congregation_id', 'expected_revision'},
      'save_attendance': {
        'congregation_id',
        'session_id',
        'expected_revision',
        'marks',
        'finalize',
      },
    };
    if (!payload.keys.toSet().containsAll(required[command]!)) {
      throw const DataFailure('invalid');
    }
    if (command == 'create_session' &&
        payload.containsKey('replaces_session_id') &&
        payload['replaces_session_id'] != null &&
        payload['replaces_session_id'] is! String) {
      throw const DataFailure('invalid');
    }
    for (final key in [
      'id',
      'congregation_id',
      'class_id',
      'student_id',
      'person_id',
      'session_id',
      'previous_contact_id',
      'replaces_session_id',
    ]) {
      if (payload.containsKey(key) && payload[key] != null) {
        validateUuid(payload[key]);
      }
    }
    if (command == 'save_person') {
      final revision = payload['expected_revision'];
      if (revision is! int || revision < 1) {
        throw const DataFailure('invalid');
      }
      final rawPerson = payload['person'];
      if (rawPerson is! Map) throw const DataFailure('invalid');
      final person = Map<String, Object?>.from(rawPerson);
      const personFields = {'name', 'phone', 'birth_date', 'address'};
      if (person.keys.toSet().difference(personFields).isNotEmpty ||
          !person.keys.toSet().containsAll(personFields)) {
        throw const DataFailure('invalid');
      }
      final name = person['name'];
      final phone = person['phone'];
      final birthDate = person['birth_date'];
      if (name is! String ||
          name.trim().isEmpty ||
          name != name.trim() ||
          name.length > 200 ||
          (phone != null && phone is! String) ||
          (birthDate != null &&
              (birthDate is! String || !_isIsoDate(birthDate)))) {
        throw const DataFailure('invalid');
      }
      final rawAddress = person['address'];
      if (rawAddress != null) {
        if (rawAddress is! Map) throw const DataFailure('invalid');
        final address = Map<String, Object?>.from(rawAddress);
        const addressFields = {
          'street',
          'district',
          'city',
          'postal_code',
          'state_code',
        };
        if (address.keys.toSet().difference(addressFields).isNotEmpty ||
            !address.keys.toSet().containsAll(addressFields) ||
            address.values.any((value) => value != null && value is! String)) {
          throw const DataFailure('invalid');
        }
      }
    }
    if (command == 'save_contact_with_access') {
      final id = payload['id'];
      final expectedRevision = payload['expected_revision'];
      final scope = payload['scope'];
      final congregationId = payload['congregation_id'];
      final name = payload['name'];
      final roleCode = payload['role_code'];
      final phone = payload['phone_e164'];
      final birthDate = payload['birth_date'];
      final email = payload['email'];
      final rawAccess = payload['access'];
      if ((payload.containsKey('id') && id is! String) ||
          (payload.containsKey('expected_revision') &&
              (expectedRevision is! int ||
                  expectedRevision < 1 ||
                  id == null)) ||
          (scope != 'congregation' && scope != 'supervision') ||
          (scope == 'congregation' && congregationId is! String) ||
          (scope == 'supervision' && congregationId != null) ||
          name is! String ||
          name.isEmpty ||
          name != name.trim() ||
          name.length > 200 ||
          (roleCode != null && roleCode is! String) ||
          (roleCode is String &&
              !(scope == 'congregation'
                  ? const {
                      'congregationAssistant',
                      'campaignLeader',
                      'campaignDeputyLeader',
                      'teacher',
                      'discipleshipSecretary',
                      'discipleshipDeputySecretary',
                    }.contains(roleCode)
                  : const {
                      'campaignSupervisor',
                      'campaignDeputy',
                      'discipleshipCoordinator',
                      'discipleshipDeputy',
                      'coordinationSecretary',
                      'coordinationDeputySecretary',
                    }.contains(roleCode))) ||
          (phone != null &&
              (phone is! String ||
                  !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phone))) ||
          (birthDate != null &&
              (birthDate is! String || !_isIsoDate(birthDate))) ||
          email is! String ||
          email.isEmpty ||
          email != email.trim().toLowerCase() ||
          !email.contains('@') ||
          rawAccess is! Map) {
        throw const DataFailure('invalid');
      }
      final access = Map<String, Object?>.from(rawAccess);
      const accessFields = {'id', 'user_email', 'role', 'congregation_id'};
      if (access.keys.toSet().difference(accessFields).isNotEmpty ||
          !access.keys.toSet().containsAll({
            'user_email',
            'role',
            'congregation_id',
          }) ||
          (access.containsKey('id') && access['id'] is! String) ||
          access['user_email'] != email ||
          access['role'] is! String ||
          (access['congregation_id'] != null &&
              access['congregation_id'] is! String)) {
        throw const DataFailure('invalid');
      }
      final accessRole = access['role'];
      final accessScope = access['congregation_id'];
      if ((scope == 'congregation' &&
              (accessRole != 'Membro da direção da campanha' ||
                  accessScope != congregationId)) ||
          (scope == 'supervision' &&
              (accessRole != 'Membro da supervisão das campanhas' ||
                  accessScope != null))) {
        throw const DataFailure('invalid');
      }
      if (access['id'] != null) validateUuid(access['id']);
      if (accessScope != null) validateUuid(accessScope);
    }
    if (command == 'revoke_contact_access') {
      final scope = payload['scope'];
      final congregationId = payload['congregation_id'];
      final revision = payload['expected_revision'];
      if ((scope != 'congregation' && scope != 'supervision') ||
          (scope == 'congregation' && congregationId is! String) ||
          (scope == 'supervision' && congregationId != null) ||
          revision is! int ||
          revision < 1) {
        throw const DataFailure('invalid');
      }
    }
    if (command == 'save_contact') {
      final email = payload['email'];
      if ((email != null &&
              (email is! String ||
                  email.isEmpty ||
                  email != email.trim().toLowerCase() ||
                  !email.contains('@'))) ||
          (payload['expected_revision'] != null &&
              (payload['expected_revision'] is! int ||
                  (payload['expected_revision'] as int) < 1))) {
        throw const DataFailure('invalid');
      }
    }
    if (command == 'save_student') {
      final revision = payload['expected_revision'];
      if (revision is! int ||
          revision < 1 ||
          ['education', 'marital_status'].any(
            (key) =>
                payload.containsKey(key) &&
                payload[key] != null &&
                payload[key] is! String,
          ) ||
          ['new_convert', 'water_baptized', 'wants_baptism'].any(
            (key) =>
                payload.containsKey(key) &&
                payload[key] != null &&
                payload[key] is! bool,
          )) {
        throw const DataFailure('invalid');
      }
    }
    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final token = context;
    final value = await _run(
      token,
      () => client
          .rpc(
            'ieadpe_ministry_$command',
            params: {'operation_id': operationId, 'payload': frozen},
          )
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    const resultFields = <String, Set<String>>{
      'save_contact_with_access': {'id', 'revision', 'access_id'},
      'revoke_contact_access': {'id', 'revision', 'revoked_access_id'},
      'enroll_student': {
        'id',
        'student_id',
        'person_id',
        'revision',
        'student_revision',
      },
      'replace_role_holder': {
        'id',
        'revision',
        'previous_contact_id',
        'previous_revision',
      },
      'create_session': {'id', 'revision', 'status'},
      'cancel_session': {'id', 'revision', 'status'},
      'save_attendance': {
        'id',
        'revision',
        'status',
        'roster_frozen',
        'attendance_count',
      },
    };
    final expectedFields = resultFields[command] ?? {'id', 'revision'};
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value.keys.any((key) => !expectedFields.contains(key)) ||
        !value.keys.toSet().containsAll(expectedFields) ||
        value['revision'] is! int ||
        (value['revision'] as int) < 1) {
      throw const DataFailure('invalid_response');
    }
    if (command == 'save_student' &&
        value['revision'] != (payload['expected_revision'] as int) + 1) {
      throw const DataFailure('invalid_response');
    }
    if (command == 'save_person' &&
        value['revision'] != (payload['expected_revision'] as int) + 1) {
      throw const DataFailure('invalid_response');
    }
    validateUuid(value['id']);
    if (command == 'save_contact_with_access') {
      validateUuid(value['access_id']);
      if (payload['id'] != null && value['id'] != payload['id']) {
        throw const DataFailure('invalid_response');
      }
      final expectedRevision = payload['expected_revision'];
      if (value['revision'] !=
          (expectedRevision == null ? 1 : (expectedRevision as int) + 1)) {
        throw const DataFailure('invalid_response');
      }
    }
    if (command == 'revoke_contact_access') {
      validateUuid(value['revoked_access_id']);
      if (value['id'] != payload['id'] ||
          value['revision'] != (payload['expected_revision'] as int) + 1) {
        throw const DataFailure('invalid_response');
      }
    }
    if (value.containsKey('previous_contact_id')) {
      validateUuid(value['previous_contact_id']);
      if (value['previous_revision'] is! int ||
          (value['previous_revision'] as int) < 1) {
        throw const DataFailure('invalid_response');
      }
    }
    if (value.containsKey('status')) {
      final statuses = switch (command) {
        'create_session' => {'open'},
        'cancel_session' => {'canceled'},
        'save_attendance' => {'open', 'finalized'},
        _ => <String>{},
      };
      if (!statuses.contains(value['status'])) {
        throw const DataFailure('invalid_response');
      }
    }
    if (command == 'save_attendance' &&
        (value['roster_frozen'] != true ||
            value['attendance_count'] is! int ||
            (value['attendance_count'] as int) < 0)) {
      throw const DataFailure('invalid_response');
    }
    return Map<String, dynamic>.unmodifiable(value);
  }

  @override
  Future<Map<String, dynamic>> linkStudentPerson(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const expectedFields = {
      'congregation_id',
      'student_id',
      'person_id',
      'expected_student_revision',
      'expected_person_revision',
    };
    if (payload.keys.toSet().difference(expectedFields).isNotEmpty ||
        !payload.keys.toSet().containsAll(expectedFields)) {
      throw const DataFailure('invalid');
    }
    for (final key in ['congregation_id', 'student_id', 'person_id']) {
      validateUuid(payload[key]);
    }
    final expectedStudentRevision = payload['expected_student_revision'];
    final expectedPersonRevision = payload['expected_person_revision'];
    if (expectedStudentRevision is! int ||
        expectedStudentRevision < 1 ||
        expectedPersonRevision is! int ||
        expectedPersonRevision < 1) {
      throw const DataFailure('invalid');
    }
    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final value = await _run(
      context,
      () => client
          .rpc(
            'ieadpe_ministry_link_student_person',
            params: {'operation_id': operationId, 'payload': frozen},
          )
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    const resultFields = {
      'student_id',
      'person_id',
      'student_revision',
      'person_revision',
    };
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(resultFields).isNotEmpty ||
        !value.keys.toSet().containsAll(resultFields) ||
        value['student_id'] != payload['student_id'] ||
        value['person_id'] != payload['person_id'] ||
        value['student_revision'] is! int ||
        value['student_revision'] != expectedStudentRevision + 1 ||
        value['person_revision'] is! int ||
        value['person_revision'] != expectedPersonRevision) {
      throw const DataFailure('invalid_response');
    }
    validateUuid(value['student_id']);
    validateUuid(value['person_id']);
    return Map<String, dynamic>.unmodifiable(value);
  }

  @override
  Future<Map<String, dynamic>> promoteConvertToStudent(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const allowed = {
      'convert_id',
      'congregation_id',
      'student_id',
      'expected_student_revision',
    };
    const required = {'convert_id', 'congregation_id', 'student_id'};
    if (payload.keys.toSet().difference(allowed).isNotEmpty ||
        !payload.keys.toSet().containsAll(required) ||
        (payload['student_id'] == null &&
            payload.containsKey('expected_student_revision')) ||
        (payload['student_id'] != null &&
            !payload.containsKey('expected_student_revision'))) {
      throw const DataFailure('invalid');
    }
    validateUuid(payload['convert_id']);
    validateUuid(payload['congregation_id']);
    if (payload['student_id'] != null) validateUuid(payload['student_id']);
    if (payload['expected_student_revision'] != null &&
        (payload['expected_student_revision'] is! int ||
            (payload['expected_student_revision'] as int) < 1)) {
      throw const DataFailure('invalid');
    }
    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final token = context;
    final value = await _run(
      token,
      () => client
          .rpc(
            'ieadpe_promote_convert_to_student',
            params: {'operation_id': operationId, 'payload': frozen},
          )
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    const expected = {
      'convert_id',
      'student_id',
      'person_id',
      'congregation_id',
      'status',
    };
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(expected).isNotEmpty ||
        !value.keys.toSet().containsAll(expected) ||
        value['convert_id'] != payload['convert_id'] ||
        value['congregation_id'] != payload['congregation_id'] ||
        value['student_id'] is! String ||
        value['person_id'] != null && value['person_id'] is! String ||
        value['status'] != 'linked') {
      throw const DataFailure('invalid_response');
    }
    validateUuid(value['student_id']);
    validateUuid(value['person_id']);
    return Map<String, dynamic>.unmodifiable(value);
  }

  @override
  Future<Map<String, dynamic>> importRow(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const allowed = {
      'internal_id',
      'name',
      'landmark',
      'gender',
      'conversion_date',
      'worship_type',
      'congregation_name',
      'address',
      'phone',
      'age',
      'last_visit_date',
      'was_visited_once',
      'visit_count',
      'is_in_discipleship',
      'discipleship_start_date',
      'is_discipleship_completed',
      'is_deviated',
    };
    if (payload.keys.any((key) => !allowed.contains(key))) {
      throw const DataFailure('invalid');
    }
    final worshipType = payload['worship_type'];
    if (worshipType != null &&
        (worshipType is! String ||
            worshipType.trim().isEmpty ||
            worshipType != worshipType.trim())) {
      throw const DataFailure('invalid');
    }
    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final result = await _run(
      context,
      () => client
          .rpc(
            'ieadpe_import_convert',
            params: {'operation_id': operationId, 'payload': frozen},
          )
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    if (result is! Map<String, dynamic> ||
        !{'created', 'duplicate', 'tombstone'}.contains(result['status']) ||
        result.keys.any((k) => !{'id', 'status', 'warning'}.contains(k)) ||
        (result['warning'] != null &&
            result['warning'] != 'unknown_congregation')) {
      throw const DataFailure('invalid_response');
    }
    validateUuid(result['id']);
    return Map.unmodifiable(result);
  }

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const editable = {
      'name',
      'landmark',
      'gender',
      'conversion_date',
      'worship_type',
      'congregation_id',
      'photo_asset_id',
      'address',
      'phone',
      'age',
    };
    final allowed = switch (command) {
      'create_convert' => editable,
      'edit_convert' => {...editable, 'id'},
      'delete_convert' || 'revoke_access' || 'archive_congregation' => {'id'},
      'save_congregation' => {'id', 'name'},
      'submit_feedback' => {'message'},
      'update_feedback' => {'id', 'status'},
      'transition_convert' => {'id', 'action'},
      'confirm_zero' => {'congregation_id'},
      'create_photo_draft' => <String>{},
      'detach_photo' => {'id'},
      'save_access' => {'id', 'user_email', 'role', 'congregation_id'},
      _ => throw ArgumentError.value(command, 'command'),
    };
    if (payload.keys.any((key) => !allowed.contains(key))) {
      throw const DataFailure('invalid');
    }
    // Snapshot now so caller mutation cannot change a retried operation.
    final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final token = context;
    try {
      final value = await _run(
        token,
        () => client
            .rpc(
              'ieadpe_$command',
              params: {'operation_id': operationId, 'payload': frozen},
            )
            .retry(enabled: false, requestTimeout: requestTimeout),
      );
      if (value is! Map || value.length != 1 || value['id'] is! String) {
        throw const DataFailure('invalid_response');
      }
      validateUuid(value['id']);
      return MutationResult.applied(
        operationId: operationId,
        value: value['id'] as String,
      );
    } on DataFailure catch (error) {
      return MutationResult.rejected(
        operationId: operationId,
        errorCode: error.code,
      );
    }
  }
}

void validateUuid(Object? value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$').hasMatch(value)) {
    throw const DataFailure('invalid_response');
  }
}

bool _hasExactKeys(Map<String, Object?> value, Set<String> expected) =>
    value.keys.toSet().difference(expected).isEmpty &&
    value.keys.toSet().containsAll(expected);

bool _isIsoDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' ==
          value;
}

/// Opaque continuation bound to query, identity and invalidation generation.
String encodeCursor(String context, String query, String id) =>
    base64Url.encode(utf8.encode(jsonEncode([1, context, query, id])));
String? decodeCursor(String? cursor, String context, String query) {
  if (cursor == null) return null;
  try {
    if (cursor.length > 4096) throw const FormatException();
    final value = jsonDecode(utf8.decode(base64Url.decode(cursor)));
    if (value is! List ||
        value.length != 4 ||
        value[0] != 1 ||
        value[1] != context ||
        value[2] != query) {
      throw const FormatException();
    }
    validateUuid(value[3]);
    return value[3] as String;
  } catch (_) {
    throw const DataFailure('invalid_cursor');
  }
}

void validatePageOrder(List<Map<String, dynamic>> rows, String? after) {
  var previous = after;
  for (final row in rows) {
    validateUuid(row['id']);
    final id = row['id'] as String;
    if (previous != null && id.compareTo(previous) <= 0) {
      throw const DataFailure('invalid_response');
    }
    previous = id;
  }
}
