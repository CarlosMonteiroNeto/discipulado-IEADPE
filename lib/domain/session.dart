/// Session model (S05).
library;

import 'common.dart';

enum SessionStatus {
  open('open'),
  finalized('finalized'),
  canceled('canceled');

  const SessionStatus(this.wire);

  final String wire;

  static SessionStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw DataFormatException('Unknown session status: $value'),
  );
}

class Session extends DomainRecord {
  const Session({
    required this.metadata,
    required this.classId,
    required this.congregationId,
    required this.date,
    required this.topic,
    required this.status,
    required this.rosterFrozen,
  });

  @override
  final CommonMetadata metadata;
  final String classId;
  final String congregationId;
  final CalendarDate date;
  final String? topic;
  final SessionStatus status;
  final bool rosterFrozen;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'classId': classId,
    'congregationId': congregationId,
    'date': date.toIso8601String(),
    'topic': topic,
    'status': status.wire,
    'rosterFrozen': rosterFrozen,
  };

  factory Session.fromJson(JsonMap json) {
    final status = requireString(json, 'status');
    final date = decodeCalendarDate(json['date']);
    if (date == null) {
      throw const DataFormatException('Missing session date.');
    }
    return Session(
      metadata: CommonMetadata.fromJson(json),
      classId: requireString(json, 'classId'),
      congregationId: requireString(json, 'congregationId'),
      date: date,
      topic: optionalString(json, 'topic'),
      status: SessionStatus.fromWire(status),
      rosterFrozen: requireBool(json, 'rosterFrozen'),
    );
  }
}
