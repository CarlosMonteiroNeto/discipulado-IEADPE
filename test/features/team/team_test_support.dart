import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';

/// Records every call so tests can prove which resource was requested and
/// whether a mutation was sent.
class FakeTeamGateway implements BackendGateway {
  final List<QueryRequest> queries = <QueryRequest>[];
  final List<RecordLocator> gets = <RecordLocator>[];
  final List<({String operation, JsonMap payload})> invocations =
      <({String operation, JsonMap payload})>[];

  PageResult Function(QueryRequest request)? onQuery;
  JsonMap? Function(RecordLocator locator)? onGet;
  JsonMap Function(String operation, JsonMap payload)? onInvoke;

  @override
  Future<PageResult> query(QueryRequest request) async {
    queries.add(request);
    return onQuery?.call(request) ?? const PageResult(items: <JsonMap>[]);
  }

  @override
  Future<JsonMap?> get(RecordLocator locator) async {
    gets.add(locator);
    return onGet?.call(locator);
  }

  @override
  Future<JsonMap> invoke(String operation, JsonMap payload) async {
    invocations.add((operation: operation, payload: payload));
    return onInvoke?.call(operation, payload) ??
        const <String, Object?>{'id': 'generated', 'revision': 1};
  }
}

AccessProfile testProfile({
  AccessRole role = AccessRole.congregationStaff,
  String? congregationId = 'c1',
}) => AccessProfile(
  accessRole: role,
  congregationId: congregationId,
  active: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 1, 1),
);

JsonMap directoryJson({
  required String id,
  required String name,
  String? normalizedName,
  String scope = 'congregation',
  String? roleCode,
  String? congregationId = 'c1',
  String? phoneE164,
  String? congregationName = 'Central',
  String? birthDate,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'normalizedName': normalizedName ?? name.toLowerCase(),
  'scope': scope,
  'roleCode': roleCode,
  'congregationId': congregationId,
  'phoneE164': phoneE164,
  'congregationName': congregationName,
  'birthDate': ?birthDate,
};

JsonMap contactJson({
  required String id,
  required String name,
  int revision = 1,
  String scope = 'congregation',
  String? roleCode,
  String? congregationId = 'c1',
  String? phoneE164,
  String? birthDate,
  bool archived = false,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'normalizedName': name.toLowerCase(),
  'scope': scope,
  'congregationId': congregationId,
  'roleCode': roleCode,
  'phoneE164': phoneE164,
  'birthDate': birthDate,
  'archived': archived,
  'revision': revision,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
};
