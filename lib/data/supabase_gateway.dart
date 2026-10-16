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

class SupabaseGateway implements ReadRpcGateway {
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
        request = request.ilike('name', '%$escaped%');
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
    if (rpc != 'weekly_overview' ||
        parameters.keys.any(
          (key) => !{'after_id', 'expected_week'}.contains(key),
        )) {
      throw const DataFailure('invalid');
    }
    final frozen = Map<String, Object?>.unmodifiable(parameters);
    final result = await _run(
      context,
      () => client
          .rpc('ieadpe_$rpc', params: frozen)
          .retry(enabled: false, requestTimeout: requestTimeout),
    );
    if (result is! Map<String, dynamic>) {
      throw const DataFailure('invalid_response');
    }
    return result;
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
