/// Overview reads for the direct transport (internal mode).
///
/// Mirrors `functions/src/overview`: the dashboard counts and the cursor-paged
/// pending session list are produced on the client with direct queries instead
/// of scope-owning server-side aggregates. A `null` congregation scope means
/// Todas and reads every congregation through collection-group queries. The
/// opaque cursor uses the shared `QueryCodec` wire format and binds the
/// resource, scope, filter fingerprint and ordering, so a cursor minted for
/// another scope or filter never pages here.
library;

import '../../domain/class_group.dart';
import '../../domain/common.dart';
import '../../domain/ports.dart';
import '../../domain/session.dart';
import '../../domain/validation.dart';
import '../direct_store.dart';
import '../query_codec.dart';
import '../transport_support.dart';

/// The overview slice of the direct-transport dispatch table.
Map<String, DirectOperationHandler> overviewHandlers() =>
    <String, DirectOperationHandler>{
      'getOverview': getOverviewHandler,
      'listPendingSessions': listPendingSessionsHandler,
    };

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String? _scopeOf(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw validationFailure('congregaçãoId inválida.', fieldErrors: <String, String>{
      'congregationId': 'congregaçãoId inválida.',
    });
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requireLimit(Object? value) {
  if (value == null) {
    return defaultPageSize;
  }
  if (value is! int || value < 1 || value > maxPageSize) {
    throw validationFailure(
      'O limite deve estar entre 1 e $maxPageSize.',
      fieldErrors: <String, String>{'limit': 'O limite deve estar entre 1 e 100.'},
    );
  }
  return value;
}

/// Scoped or collection-group read of a congregation-owned collection.
Future<List<JsonMap>> _collection(
  DirectStore store,
  String collection,
  String? scope,
) => scope == null
    ? store.query(StoreQuery(collection: collection, group: true))
    : store.query(StoreQuery(collection: 'congregations/$scope/$collection'));

bool _isOpenThrough(JsonMap session, String throughIso) {
  if (session['status'] != SessionStatus.open.wire) {
    return false;
  }
  final Object? date = session['date'];
  return date is String && date.compareTo(throughIso) <= 0;
}

int _compareSessions(JsonMap a, JsonMap b) {
  final String aDate = '${a['date']}';
  final String bDate = '${b['date']}';
  if (aDate != bDate) {
    return aDate.compareTo(bDate);
  }
  return '${a['id']}'.compareTo('${b['id']}');
}

Future<JsonMap> getOverviewHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String? scope = _scopeOf(payload['congregationId']);
  final String throughIso = recifeToday(context.now).toIso8601String();
  final DirectStore store = context.store;

  final List<JsonMap> students = await _collection(store, 'students', scope);
  int studentCount = 0;
  for (final JsonMap student in students) {
    if (student['archived'] != true) {
      studentCount += 1;
    }
  }

  final List<JsonMap> classes = await _collection(store, 'classes', scope);
  int activeClasses = 0;
  for (final JsonMap klass in classes) {
    if (klass['status'] == ClassStatus.active.wire) {
      activeClasses += 1;
    }
  }

  final List<JsonMap> sessions = await _collection(store, 'sessions', scope);
  int openSessions = 0;
  for (final JsonMap session in sessions) {
    if (_isOpenThrough(session, throughIso)) {
      openSessions += 1;
    }
  }

  return <String, Object?>{
    'students': studentCount,
    'classes': activeClasses,
    'openSessions': openSessions,
    'throughDate': throughIso,
  };
}

Future<JsonMap> listPendingSessionsHandler(
  HandlerContext context,
  JsonMap payload,
) async {
  final String? scope = _scopeOf(payload['congregationId']);
  final int limit = _requireLimit(payload['limit']);
  final String throughIso = recifeToday(context.now).toIso8601String();
  final String fingerprint = QueryCodec().filterFingerprint(
    QueryRequest(
      resource: QueryResource.sessions,
      equalityFilters: <String, Object?>{'status': SessionStatus.open.wire},
    ),
  );
  final DirectStore store = context.store;

  ({String date, String id})? after;
  final String? cursor = _nonEmpty(payload['cursor']);
  if (cursor != null) {
    final QueryCursor decoded;
    try {
      decoded = const QueryCodec().decodeCursor(cursor);
    } on AppFailure {
      throw conflictFailure('O cursor não pertence a esta consulta.');
    }
    final bool matches =
        decoded.resource == QueryResource.sessions &&
        decoded.orderBy == 'date' &&
        decoded.congregationId == scope &&
        decoded.filterFingerprint == fingerprint;
    if (!matches) {
      throw conflictFailure('O cursor não pertence a esta consulta.');
    }
    after = (
      date: '${decoded.lastSortValue ?? ''}',
      id: decoded.lastId,
    );
  }

  final List<JsonMap> sessions = await _collection(store, 'sessions', scope);
  final List<JsonMap> open = <JsonMap>[
    for (final JsonMap session in sessions)
      if (_isOpenThrough(session, throughIso)) session,
  ]..sort(_compareSessions);

  final ({String date, String id})? anchor = after;
  final List<JsonMap> candidates =
      (anchor == null
          ? open
          : open.where((JsonMap session) {
              final String date = '${session['date']}';
              if (date != anchor.date) {
                return date.compareTo(anchor.date) > 0;
              }
              return '${session['id']}'.compareTo(anchor.id) > 0;
            }))
          .toList(growable: false);

  final bool hasMore = candidates.length > limit;
  final List<JsonMap> page = candidates.take(limit).toList(growable: false);

  final List<JsonMap> items = <JsonMap>[];
  for (final JsonMap session in page) {
    final String classId = _nonEmpty(session['classId']) ?? '';
    final String sessionCongregationId =
        _nonEmpty(session['congregationId']) ?? scope ?? '';
    String? className;
    if (classId.isNotEmpty && sessionCongregationId.isNotEmpty) {
      final JsonMap? klass = await store.read(
        StorePaths.classGroup(sessionCongregationId, classId),
      );
      className = _nonEmpty(klass?['name']);
    }
    items.add(<String, Object?>{
      'id': session['id'],
      'classId': classId,
      'className': className,
      'congregationId': sessionCongregationId,
      'date': session['date'],
      'topic': _nonEmpty(session['topic']),
      'status': session['status'],
    });
  }

  String? nextCursor;
  if (hasMore && page.isNotEmpty) {
    final JsonMap last = page.last;
    nextCursor = const QueryCodec().encodeCursor(
      QueryCursor(
        resource: QueryResource.sessions,
        congregationId: scope,
        filterFingerprint: fingerprint,
        orderBy: 'date',
        lastId: '${last['id']}',
        lastSortValue: last['date'],
      ),
    );
  }

  return <String, Object?>{'items': items, 'nextCursor': nextCursor};
}