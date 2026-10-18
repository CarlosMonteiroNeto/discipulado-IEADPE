import 'dart:async';

import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';

const catalogId = '10000000-0000-0000-0000-000000000001';

class AdminGateway implements Gateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  final operations = <String>[];
  final commands = <String>[];
  final payloads = <Map<String, Object?>>[];
  List<Map<String, dynamic>> catalog = [
    {'id': catalogId, 'name': 'Sede', 'archived_at': null},
  ];
  List<Map<String, dynamic>> accesses = [];
  String? failure;
  Completer<List<Map<String, dynamic>>>? pendingRead;
  Completer<MutationResult<String>>? pendingMutation;
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
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
    ensureCurrent(context);
    if (pendingRead != null) return pendingRead!.future;
    return table == 'congregations' ? catalog : accesses;
  }

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    commands.add(command);
    operations.add(operationId);
    payloads.add(Map.of(payload));
    if (pendingMutation != null) return pendingMutation!.future;
    if (failure != null) {
      return MutationResult.rejected(
        operationId: operationId,
        errorCode: failure,
      );
    }
    return MutationResult.applied(operationId: operationId, value: catalogId);
  }
}
