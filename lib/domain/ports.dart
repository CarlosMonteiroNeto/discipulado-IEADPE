/// Shared ports consumed by feature repositories (S11).
library;

import 'access.dart';
import 'common.dart';

/// Generic query resources. Internal collections (`users`, role/uniqueness
/// indexes, `operations` receipts and session `roster`) are deliberately
/// absent so they cannot be addressed through a generic query.
enum QueryResource {
  directory('directory'),
  congregations('congregations'),
  contacts('contacts'),
  students('students'),
  classes('classes'),
  enrollments('enrollments'),
  sessions('sessions');

  const QueryResource(this.wire);

  final String wire;

  static QueryResource fromWire(String value) => values.firstWhere(
    (resource) => resource.wire == value,
    orElse: () => throw DataFormatException('Unknown query resource: $value'),
  );
}

class QueryRequest {
  const QueryRequest({
    required this.resource,
    this.congregationId,
    this.equalityFilters,
    this.namePrefix,
    this.limit,
    this.cursor,
  });

  final QueryResource resource;
  final String? congregationId;
  final JsonMap? equalityFilters;
  final String? namePrefix;
  final int? limit;
  final String? cursor;
}

class RecordLocator {
  const RecordLocator({
    required this.resource,
    required this.id,
    this.congregationId,
    this.parentClassId,
    this.parentSessionId,
  });

  final QueryResource resource;
  final String id;
  final String? congregationId;
  final String? parentClassId;
  final String? parentSessionId;
}

class PageResult {
  const PageResult({required this.items, this.nextCursor});

  final List<JsonMap> items;
  final String? nextCursor;
}

enum AppFailureCode {
  validation('validation'),
  unauthenticated('unauthenticated'),
  forbidden('forbidden'),
  notFound('notFound'),
  conflict('conflict'),
  unavailable('unavailable'),
  unknown('unknown');

  const AppFailureCode(this.wire);

  final String wire;
}

/// Safe transport/domain failure. The message is displayable; stack traces,
/// tokens and raw backend responses never reach it.
class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    this.fieldErrors,
    required this.message,
  });

  final AppFailureCode code;
  final Map<String, String>? fieldErrors;
  final String message;

  @override
  String toString() => 'AppFailure(${code.wire}): $message';
}

abstract interface class AuthRepository {
  Stream<AuthSession?> watchSession();

  Future<void> signIn(String email, String password);

  Future<void> requestPasswordReset(String email);

  Future<void> signOut();
}

abstract interface class BackendGateway {
  Future<JsonMap> invoke(String operation, JsonMap payload);

  Future<PageResult> query(QueryRequest request);

  Future<JsonMap?> get(RecordLocator locator);
}
