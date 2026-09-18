import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';

/// Records every call so tests can prove which operation/scope was requested.
class FakeOverviewGateway implements BackendGateway {
  final List<QueryRequest> queries = <QueryRequest>[];
  final List<RecordLocator> gets = <RecordLocator>[];
  final List<({String operation, JsonMap payload})> invocations =
      <({String operation, JsonMap payload})>[];

  PageResult Function(QueryRequest request)? onQuery;
  JsonMap? Function(RecordLocator locator)? onGet;
  Future<JsonMap> Function(String operation, JsonMap payload)? onInvoke;

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
    final Future<JsonMap> Function(String operation, JsonMap payload)? handler =
        onInvoke;
    if (handler == null) {
      return const <String, Object?>{};
    }
    return handler(operation, payload);
  }

  JsonMap lastPayload(String operation) {
    return invocations
        .lastWhere(
          (({String operation, JsonMap payload}) entry) =>
              entry.operation == operation,
        )
        .payload;
  }
}

AccessProfile staffProfile({String congregationId = 'c1'}) => AccessProfile(
  accessRole: AccessRole.congregationStaff,
  congregationId: congregationId,
  active: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 1, 1),
);

AccessProfile supervisorProfile() => AccessProfile(
  accessRole: AccessRole.supervisor,
  congregationId: null,
  active: true,
  revision: 1,
  updatedAt: DateTime.utc(2026, 1, 1),
);

JsonMap overviewJson({
  int students = 2,
  int classes = 1,
  int openSessions = 3,
  String throughDate = '2026-09-18',
}) => <String, Object?>{
  'students': students,
  'classes': classes,
  'openSessions': openSessions,
  'throughDate': throughDate,
};

JsonMap pendingSessionJson({
  required String id,
  String classId = 'k1',
  String? className = 'Turma Central',
  String congregationId = 'c1',
  String date = '2026-09-17',
  String? topic = 'Tema',
}) => <String, Object?>{
  'id': id,
  'classId': classId,
  'className': className,
  'congregationId': congregationId,
  'date': date,
  'topic': topic,
  'status': 'open',
};
