/// Congregation lifecycle repository over the shared backend port (S06, S11).
library;

import 'package:uuid/uuid.dart';

import '../../data/query_codec.dart';
import '../../domain/common.dart';
import '../../domain/congregation.dart';
import '../../domain/ports.dart';
import '../team/team_repository.dart';

class CongregationRepository {
  CongregationRepository({
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

  /// Lists congregations by active flag, ordered by normalized name (S09).
  Future<List<Congregation>> listCongregations({required bool active}) async {
    final PageResult page = await gateway.query(
      QueryRequest(
        resource: QueryResource.congregations,
        equalityFilters: <String, Object?>{'active': active},
        limit: maxPageSize,
      ),
    );
    return page.items.map(Congregation.fromJson).toList(growable: false);
  }

  Future<Congregation?> getCongregation(String id) async {
    final JsonMap? json = await gateway.get(
      RecordLocator(resource: QueryResource.congregations, id: id),
    );
    return json == null ? null : Congregation.fromJson(json);
  }

  /// S06 create (no revision) and rename (stable ID plus revision).
  Future<TeamMutationResult> saveCongregation({
    required String name,
    String? id,
    int? expectedRevision,
    String? requestId,
  }) async {
    final String recordId = id ?? newRecordId();
    final Map<String, Object?> payload = <String, Object?>{
      'id': recordId,
      'name': name.trim(),
      'requestId': requestId ?? newRequestId(),
    };
    if (expectedRevision != null) {
      payload['expectedRevision'] = expectedRevision;
    }
    final JsonMap response = await gateway.invoke('saveCongregation', payload);
    return TeamMutationResult.fromJson(response);
  }

  /// S06 archive and restore by stable ID.
  Future<TeamMutationResult> setCongregationArchived({
    required String id,
    required bool archived,
    required int expectedRevision,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'setCongregationArchived',
      <String, Object?>{
        'id': id,
        'archived': archived,
        'expectedRevision': expectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return TeamMutationResult.fromJson(response);
  }
}
