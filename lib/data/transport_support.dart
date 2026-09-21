/// Shared helpers for the direct-transport operation handlers.
///
/// Handlers are plain functions over [DirectStore]; they validate their
/// payload, apply the role-scoped write and return the exact wire response the
/// feature repository decodes. Failures are `AppFailure`s so the existing
/// gateway error path is preserved.
library;

import '../domain/common.dart';
import '../domain/ports.dart';
import 'direct_store.dart';

/// Canonical document paths; the single place collection names are spelled.
class StorePaths {
  const StorePaths._();

  static String congregation(String id) => 'congregations/$id';

  static String directory(String id) => 'directory/$id';

  static String supervisionContact(String id) => 'supervisionContacts/$id';

  static String supervisionRoleSlot(String id) => 'supervisionRoleSlots/$id';

  static String contact(String congregationId, String id) =>
      'congregations/$congregationId/contacts/$id';

  static String roleSlot(String congregationId, String id) =>
      'congregations/$congregationId/roleSlots/$id';

  static String student(String congregationId, String id) =>
      'congregations/$congregationId/students/$id';

  static String classGroup(String congregationId, String id) =>
      'congregations/$congregationId/classes/$id';

  static String enrollment(String congregationId, String id) =>
      'congregations/$congregationId/enrollments/$id';

  static String session(String congregationId, String id) =>
      'congregations/$congregationId/sessions/$id';

  static String roster(String congregationId, String sessionId) =>
      'congregations/$congregationId/sessions/$sessionId/roster';

  static String attendance(String congregationId, String sessionId) =>
      'congregations/$congregationId/sessions/$sessionId/attendance';

  static String studentsCollection(String congregationId) =>
      'congregations/$congregationId/students';

  static String classesCollection(String congregationId) =>
      'congregations/$congregationId/classes';

  static String enrollmentsCollection(String congregationId) =>
      'congregations/$congregationId/enrollments';

  static String sessionsCollection(String congregationId) =>
      'congregations/$congregationId/sessions';
}

/// Per-call identity and time available to a handler.
class HandlerContext {
  const HandlerContext({
    required this.store,
    required this.uid,
    required this.now,
  });

  final DirectStore store;
  final String uid;
  final DateTime now;
}

/// One operation handler: validates and applies one mutation or projection.
typedef DirectOperationHandler =
    Future<JsonMap> Function(HandlerContext context, JsonMap payload);

/// A feature's slice of the dispatch table keyed by operation name.
typedef HandlerRegistry = Map<String, DirectOperationHandler>;

AppFailure validationFailure(String message, {Map<String, String>? fieldErrors}) =>
    AppFailure(
      code: AppFailureCode.validation,
      message: message,
      fieldErrors: fieldErrors,
    );

AppFailure forbiddenFailure(String message) =>
    AppFailure(code: AppFailureCode.forbidden, message: message);

AppFailure notFoundFailure(String message) =>
    AppFailure(code: AppFailureCode.notFound, message: message);

AppFailure conflictFailure(String message) =>
    AppFailure(code: AppFailureCode.conflict, message: message);

AppFailure unauthenticatedFailure(String message) =>
    AppFailure(code: AppFailureCode.unauthenticated, message: message);

String requirePayloadString(JsonMap payload, String field) {
  final Object? value = payload[field];
  if (value is! String || value.trim().isEmpty) {
    throw validationFailure('Campo obrigatório ausente.', fieldErrors: <String, String>{
      field: 'Campo obrigatório ausente.',
    });
  }
  return value;
}

String? optionalPayloadString(JsonMap payload, String field) {
  final Object? value = payload[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw validationFailure('Valor inválido.', fieldErrors: <String, String>{
      field: 'Valor inválido.',
    });
  }
  return value;
}

bool requirePayloadBool(JsonMap payload, String field) {
  final Object? value = payload[field];
  if (value is! bool) {
    throw validationFailure('Valor inválido.', fieldErrors: <String, String>{
      field: 'Valor inválido.',
    });
  }
  return value;
}

int requirePayloadInt(JsonMap payload, String field) {
  final Object? value = payload[field];
  if (value is! int) {
    throw validationFailure('Valor inválido.', fieldErrors: <String, String>{
      field: 'Valor inválido.',
    });
  }
  return value;
}

String isoNow(DateTime now) => now.toUtc().toIso8601String();

/// Applies the common metadata of a create/update write.
JsonMap withRecordMeta({
  required JsonMap base,
  required DateTime now,
  required String uid,
  required int revision,
  String? createdAt,
}) {
  final String timestamp = isoNow(now);
  return <String, Object?>{
    ...base,
    'revision': revision,
    'createdAt': createdAt ?? timestamp,
    'updatedAt': timestamp,
    'updatedBy': uid,
  };
}
