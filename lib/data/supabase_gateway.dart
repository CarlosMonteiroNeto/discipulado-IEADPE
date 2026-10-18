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

/// Additive ministry command transport. Rich ministry results include revisions
/// and status values, while the older convert command contract returns an ID.
abstract interface class MinistryCommandGateway implements Gateway {
  Future<Map<String, dynamic>> ministryCommand(
    String command,
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

abstract interface class ImportRpcGateway implements Gateway {
  Future<Map<String, dynamic>> importRow(
    String operationId,
    Map<String, Object?> payload,
  );
}

class SupabaseGateway
    implements
        ReadRpcGateway,
        ImportRpcGateway,
        MinistryCommandGateway,
        HandoffCommandGateway {
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
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    const ministryReadParameters = <String, Set<String>>{
      'ministry_list_congregations': {'limit', 'cursor'},
      'ministry_list_directory': {
        'scope',
        'congregation_id',
        'role_code',
        'name_prefix',
        'limit',
        'cursor',
      },
      'ministry_list_class_students': {
        'congregation_id',
        'class_id',
        'limit',
        'cursor',
      },
      'ministry_get_session_attendance': {'congregation_id', 'session_id'},
      'ministry_get_enrollment_progress': {'congregation_id', 'enrollment_id'},
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
    final ministryRead = ministryKeys != null;
    final Set<String>? allowed =
        ministryKeys ??
        (rpc == 'weekly_overview'
            ? <String>{'after_id', 'expected_week'}
            : null);
    if (allowed == null ||
        parameters.keys.any((key) => !allowed.contains(key))) {
      throw const DataFailure('invalid');
    }
    final frozen = Map<String, Object?>.unmodifiable(parameters);
    final result = await _run(
      context,
      () => client
          .rpc(
            'ieadpe_$rpc',
            params: ministryRead ? {'request': frozen} : frozen,
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
        'name',
        'phone_e164',
        'birth_date',
        'address',
        'education',
        'marital_status',
        'new_convert',
        'water_baptized',
        'wants_baptism',
        'expected_revision',
      },
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
        'student_id',
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
      'save_student': {'id', 'congregation_id', 'name'},
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
        'student_id',
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
    for (final key in [
      'id',
      'congregation_id',
      'class_id',
      'student_id',
      'session_id',
      'previous_contact_id',
    ]) {
      if (payload.containsKey(key) && payload[key] != null) {
        validateUuid(payload[key]);
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
    validateUuid(value['id']);
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
  Future<Map<String, dynamic>> promoteConvertToStudent(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    validateUuid(operationId);
    const required = {'convert_id', 'congregation_id', 'student_id'};
    if (payload.keys.toSet().difference(required).isNotEmpty ||
        !payload.keys.toSet().containsAll(required)) {
      throw const DataFailure('invalid');
    }
    validateUuid(payload['convert_id']);
    validateUuid(payload['congregation_id']);
    if (payload['student_id'] != null) validateUuid(payload['student_id']);
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
    const expected = {'convert_id', 'student_id', 'congregation_id', 'status'};
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(expected).isNotEmpty ||
        !value.keys.toSet().containsAll(expected) ||
        value['convert_id'] != payload['convert_id'] ||
        value['congregation_id'] != payload['congregation_id'] ||
        value['student_id'] is! String ||
        value['status'] != 'linked') {
      throw const DataFailure('invalid_response');
    }
    validateUuid(value['student_id']);
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
