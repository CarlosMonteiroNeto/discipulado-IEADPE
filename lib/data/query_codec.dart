/// Query/cursor construction and validation shared by every repository (S09).
///
/// Cursors are opaque and bind the resource, scope, filter identity and
/// ordering, so a cursor can never be reused after a filter or scope change.
library;

import 'dart:convert';

import '../domain/ports.dart';
import '../domain/validation.dart';
import 'error_mapper.dart';

const int defaultPageSize = 50;
const int maxPageSize = 100;

const Set<String> _internalCollections = <String>{
  'users',
  'operations',
  'receipts',
  'roster',
  'roleSlots',
  'supervisionRoleSlots',
  'internal',
  'references',
};

const Set<QueryResource> _scopedResources = <QueryResource>{
  QueryResource.contacts,
  QueryResource.students,
  QueryResource.classes,
  QueryResource.enrollments,
  QueryResource.sessions,
};

const Set<QueryResource> _prefixResources = <QueryResource>{
  QueryResource.directory,
  QueryResource.students,
  QueryResource.classes,
};

const Map<QueryResource, Set<String>> _supportedFilters =
    <QueryResource, Set<String>>{
      QueryResource.directory: <String>{'scope', 'roleCode', 'congregationId'},
      QueryResource.congregations: <String>{'active'},
      QueryResource.contacts: <String>{'archived', 'scope', 'roleCode'},
      QueryResource.students: <String>{'archived', 'classId'},
      QueryResource.classes: <String>{'status', 'teacherContactId'},
      QueryResource.enrollments: <String>{'classId', 'studentId', 'status'},
      QueryResource.sessions: <String>{'classId', 'status'},
    };

const Map<QueryResource, String> _orderFields = <QueryResource, String>{
  QueryResource.directory: 'normalizedName',
  QueryResource.congregations: 'normalizedName',
  QueryResource.contacts: 'normalizedName',
  QueryResource.students: 'normalizedName',
  QueryResource.classes: 'normalizedName',
  QueryResource.enrollments: 'startDate',
  QueryResource.sessions: 'date',
};

const Map<QueryResource, String> _collectionNames = <QueryResource, String>{
  QueryResource.directory: 'directory',
  QueryResource.congregations: 'congregations',
  QueryResource.contacts: 'contacts',
  QueryResource.students: 'students',
  QueryResource.classes: 'classes',
  QueryResource.enrollments: 'enrollments',
  QueryResource.sessions: 'sessions',
};

AppFailure _invalid(String message) =>
    AppFailure(code: AppFailureCode.validation, message: message);

/// Normalizes a raw prefix with the same key as the stored `normalizedName`
/// field (S05/S09). A blank prefix is not a search and yields `null`.
String? _normalizedPrefix(String? raw) {
  if (raw == null) {
    return null;
  }
  final String normalized = normalizeName(raw);
  return normalized.isEmpty ? null : normalized;
}

class QueryFilter {
  const QueryFilter(this.field, this.value);

  final String field;
  final Object? value;
}

class QueryPlan {
  const QueryPlan({
    required this.resource,
    required this.collection,
    required this.filters,
    required this.orderBy,
    required this.limit,
    required this.filterFingerprint,
    this.congregationId,
    this.cursor,
    this.callableOperation,
    this.namePrefix,
  });

  final QueryResource resource;
  final String collection;
  final List<QueryFilter> filters;
  final String orderBy;
  final int limit;
  final String filterFingerprint;
  final String? congregationId;
  final String? cursor;
  final String? callableOperation;

  /// Normalized name prefix bound into this plan (S09). The single source for
  /// both cursor identity and the Firestore range constraint.
  final String? namePrefix;
}

class QueryCursor {
  const QueryCursor({
    required this.resource,
    required this.filterFingerprint,
    required this.orderBy,
    required this.lastId,
    this.congregationId,
    this.lastSortValue,
  });

  final QueryResource resource;
  final String filterFingerprint;
  final String orderBy;
  final String lastId;
  final String? congregationId;
  final Object? lastSortValue;
}

class QueryCodec {
  const QueryCodec();

  QueryPlan plan(QueryRequest request) {
    final int limit = request.limit ?? defaultPageSize;
    if (limit < 1 || limit > maxPageSize) {
      throw _invalid('O limite deve estar entre 1 e $maxPageSize.');
    }
    if (request.namePrefix != null &&
        !_prefixResources.contains(request.resource)) {
      throw _invalid('Busca por nome não é suportada para este recurso.');
    }
    final Set<String> allowed = _supportedFilters[request.resource]!;
    final List<QueryFilter> filters = <QueryFilter>[];
    request.equalityFilters?.forEach((String key, Object? value) {
      if (!allowed.contains(key)) {
        throw _invalid('Filtro não suportado: $key.');
      }
      filters.add(QueryFilter(key, value));
    });
    final String? callable =
        request.resource == QueryResource.students &&
            request.equalityFilters?['classId'] != null
        ? 'listClassStudents'
        : null;
    return QueryPlan(
      resource: request.resource,
      collection: collectionPath(request),
      filters: filters,
      orderBy: _orderFields[request.resource]!,
      limit: limit,
      filterFingerprint: filterFingerprint(request),
      congregationId: request.congregationId,
      cursor: request.cursor,
      callableOperation: callable,
      namePrefix: _normalizedPrefix(request.namePrefix),
    );
  }

  String collectionPath(QueryRequest request) {
    final String name = _collectionNames[request.resource]!;
    if (!_scopedResources.contains(request.resource)) {
      return name;
    }
    return 'congregations/${_requireScope(request.congregationId)}/$name';
  }

  String filterFingerprint(QueryRequest request) {
    final Map<String, String> entries = <String, String>{};
    request.equalityFilters?.forEach((String key, Object? value) {
      entries[key] = '$value';
    });
    final List<MapEntry<String, String>> sorted = entries.entries.toList()
      ..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.key.compareTo(b.key),
      );
    final StringBuffer buffer = StringBuffer();
    for (final MapEntry<String, String> entry in sorted) {
      buffer.write('${entry.key}=${entry.value};');
    }
    final String? prefix = _normalizedPrefix(request.namePrefix);
    if (prefix != null) {
      buffer.write('prefix=$prefix;');
    }
    return buffer.toString();
  }

  String encodeCursor(QueryCursor cursor) {
    final String payload = jsonEncode(<String, Object?>{
      'r': cursor.resource.wire,
      's': cursor.congregationId,
      'f': cursor.filterFingerprint,
      'o': cursor.orderBy,
      'l': cursor.lastSortValue,
      'i': cursor.lastId,
    });
    return base64Url.encode(utf8.encode(payload));
  }

  QueryCursor decodeCursor(String cursor) {
    try {
      final String decoded = utf8.decode(base64Url.decode(cursor));
      final Object? raw = jsonDecode(decoded);
      if (raw is! Map) {
        throw _invalid(kInvalidCursorMessage);
      }
      final Map<String, Object?> map = Map<String, Object?>.from(raw);
      return QueryCursor(
        resource: QueryResource.fromWire(map['r']! as String),
        congregationId: map['s'] as String?,
        filterFingerprint: map['f']! as String,
        orderBy: map['o']! as String,
        lastSortValue: map['l'],
        lastId: map['i']! as String,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw _invalid(kInvalidCursorMessage);
    }
  }

  void verifyCursor(String cursor, QueryRequest request) {
    final QueryCursor decoded = decodeCursor(cursor);
    final QueryPlan plan = this.plan(request);
    final bool matches =
        decoded.resource == request.resource &&
        decoded.congregationId == request.congregationId &&
        decoded.filterFingerprint == plan.filterFingerprint &&
        decoded.orderBy == plan.orderBy;
    if (!matches) {
      throw _invalid(kInvalidCursorMessage);
    }
  }

  String recordPath(RecordLocator locator) {
    validateId(locator.id);
    switch (locator.resource) {
      case QueryResource.directory:
        return 'directory/${locator.id}';
      case QueryResource.congregations:
        return 'congregations/${locator.id}';
      case QueryResource.contacts:
        // A contact with no congregation is a supervision contact, stored in
        // the supervisor-protected top-level collection (S04, S06). The path
        // is never guessed from the caller's profile.
        final String? scope = locator.congregationId?.trim();
        if (scope == null || scope.isEmpty) {
          return 'supervisionContacts/${locator.id}';
        }
        validateId(scope);
        return 'congregations/$scope/contacts/${locator.id}';
      case QueryResource.students:
      case QueryResource.classes:
      case QueryResource.enrollments:
      case QueryResource.sessions:
        final String scope = _requireScope(locator.congregationId);
        final String name = _collectionNames[locator.resource]!;
        return 'congregations/$scope/$name/${locator.id}';
    }
  }

  static void validateId(String id) {
    final String trimmed = id.trim();
    final bool invalid =
        trimmed.isEmpty ||
        trimmed.contains('/') ||
        trimmed.contains(r'\') ||
        trimmed == '.' ||
        trimmed == '..' ||
        _internalCollections.contains(trimmed);
    if (invalid) {
      throw _invalid('Identificador inválido.');
    }
  }

  String _requireScope(String? congregationId) {
    final String? value = congregationId?.trim();
    if (value == null || value.isEmpty) {
      throw _invalid('Informe a congregação.');
    }
    validateId(value);
    return value;
  }
}
