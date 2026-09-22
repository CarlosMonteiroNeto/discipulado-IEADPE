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
    this.lessonIndex,
    this.lessonPart,
    this.lessonFinished = false,
  });

  @override
  final CommonMetadata metadata;
  final String classId;
  final String congregationId;
  final CalendarDate date;
  final String? topic;
  final SessionStatus status;
  final bool rosterFrozen;

  /// Zero-based curriculum lesson this session attends (S11); null for
  /// sessions created before the lesson sequence existed.
  final int? lessonIndex;

  /// Repeat part of the lesson, >= 1; an unconcluded lesson continues into
  /// the next part (S11).
  final int? lessonPart;

  /// Supervisor conclusion at the last attendance save; the falsy default
  /// keeps legacy sessions out of the sequence (S11).
  final bool lessonFinished;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'classId': classId,
    'congregationId': congregationId,
    'date': date.toIso8601String(),
    'topic': topic,
    'status': status.wire,
    'rosterFrozen': rosterFrozen,
    if (lessonIndex != null) 'lessonIndex': lessonIndex,
    if (lessonPart != null) 'lessonPart': lessonPart,
    'lessonFinished': lessonFinished,
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
      lessonIndex: optionalInt(json, 'lessonIndex'),
      lessonPart: optionalInt(json, 'lessonPart'),
      lessonFinished: optionalBool(json, 'lessonFinished') ?? false,
    );
  }
}
