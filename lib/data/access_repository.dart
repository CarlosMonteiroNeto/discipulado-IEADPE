import '../features/ministry/data/ministry_codec.dart';
import '../features/ministry/data/ministry_repository.dart';
import '../features/ministry/domain/ministry_models.dart';
import '../domain/models.dart' show AccessRole;
import 'supabase_gateway.dart';

/// Login access is changed only together with an explicitly selected ministry
/// contact. This repository deliberately exposes no standalone user_access
/// list, grant, or revoke command.
class AccessRepository {
  AccessRepository(ReadRpcGateway gateway)
    : _ministry = MinistryRepository(gateway);

  final MinistryRepository _ministry;

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
  }) => _ministry.saveContactWithAccess(
    operationId: operationId,
    id: id,
    expectedRevision: expectedRevision,
    scope: scope,
    congregationId: congregationId,
    name: name,
    roleCode: roleCode,
    phoneE164: phoneE164,
    birthDate: birthDate,
    email: email,
    accessId: accessId,
    accessRole: accessRole,
    accessCongregationId: accessCongregationId,
  );

  Future<MinistryContactAccessRevocationResult> revokeContactAccess({
    required String operationId,
    required String id,
    required ContactScope scope,
    String? congregationId,
    required int expectedRevision,
  }) => _ministry.revokeContactAccess(
    operationId: operationId,
    id: id,
    scope: scope,
    congregationId: congregationId,
    expectedRevision: expectedRevision,
  );
}
