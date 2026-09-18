/// Typed overview reads for the dashboard feature (S09, S11).
///
/// Counts and pending sessions are always produced by the authorized backend
/// callables; the browser never downloads collections to compute them.
library;

import '../../data/query_codec.dart';
import '../../domain/common.dart';
import '../../domain/ports.dart';

/// Authoritative counts for one authorized scope.
class OverviewCounts {
  const OverviewCounts({
    required this.students,
    required this.classes,
    required this.openSessions,
    required this.throughDate,
  });

  final int students;
  final int classes;
  final int openSessions;
  final CalendarDate throughDate;

  factory OverviewCounts.fromJson(JsonMap json) {
    final CalendarDate? throughDate = decodeCalendarDate(json['throughDate']);
    if (throughDate == null) {
      throw const DataFormatException('Missing overview through date.');
    }
    return OverviewCounts(
      students: requireInt(json, 'students'),
      classes: requireInt(json, 'classes'),
      openSessions: requireInt(json, 'openSessions'),
      throughDate: throughDate,
    );
  }
}

/// One pending attendance call. It carries the class and congregation IDs so
/// the row can deep-link to the exact class/session (S09).
class PendingSessionEntry {
  const PendingSessionEntry({
    required this.id,
    required this.classId,
    required this.className,
    required this.congregationId,
    required this.date,
    required this.topic,
  });

  final String id;
  final String classId;
  final String? className;
  final String congregationId;
  final CalendarDate date;
  final String? topic;

  factory PendingSessionEntry.fromJson(JsonMap json) {
    final CalendarDate? date = decodeCalendarDate(json['date']);
    if (date == null) {
      throw const DataFormatException('Missing pending session date.');
    }
    return PendingSessionEntry(
      id: requireString(json, 'id'),
      classId: requireString(json, 'classId'),
      className: optionalString(json, 'className'),
      congregationId: requireString(json, 'congregationId'),
      date: date,
      topic: optionalString(json, 'topic'),
    );
  }
}

class PendingSessionPage {
  const PendingSessionPage({required this.items, this.nextCursor});

  final List<PendingSessionEntry> items;
  final String? nextCursor;
}

class OverviewRepository {
  OverviewRepository({required this.gateway});

  final BackendGateway gateway;

  /// Aggregate counts for the requested scope; a null scope means Todas and is
  /// only honored for a supervisor by the backend.
  Future<OverviewCounts> getOverview({String? congregationId}) async {
    final JsonMap response = await gateway.invoke(
      'getOverview',
      <String, Object?>{'congregationId': congregationId},
    );
    return OverviewCounts.fromJson(response);
  }

  /// One page of open sessions through today, ordered by date then ID, scoped
  /// to the caller. The opaque cursor stays session-local (S09).
  Future<PendingSessionPage> listPendingSessions({
    String? congregationId,
    int limit = defaultPageSize,
    String? cursor,
  }) async {
    final JsonMap response = await gateway.invoke(
      'listPendingSessions',
      <String, Object?>{
        'congregationId': congregationId,
        'limit': limit,
        'cursor': ?cursor,
      },
    );
    final Object? rawItems = response['items'];
    final List<PendingSessionEntry> items = rawItems is List
        ? rawItems
              .whereType<Map<Object?, Object?>>()
              .map(
                (Map<Object?, Object?> item) => PendingSessionEntry.fromJson(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
        : const <PendingSessionEntry>[];
    final Object? nextCursor = response['nextCursor'];
    return PendingSessionPage(
      items: items,
      nextCursor: nextCursor is String ? nextCursor : null,
    );
  }
}
