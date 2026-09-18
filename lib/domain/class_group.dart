/// Class group model (S05).
library;

import 'common.dart';

enum ClassStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const ClassStatus(this.wire);

  final String wire;

  static ClassStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw DataFormatException('Unknown class status: $value'),
  );
}

class ClassGroup extends DomainRecord {
  const ClassGroup({
    required this.metadata,
    required this.congregationId,
    required this.name,
    required this.normalizedName,
    required this.teacherContactId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  @override
  final CommonMetadata metadata;
  final String congregationId;
  final String name;
  final String normalizedName;
  final String? teacherContactId;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final ClassStatus status;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'congregationId': congregationId,
    'name': name,
    'normalizedName': normalizedName,
    'teacherContactId': teacherContactId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'status': status.wire,
  };

  factory ClassGroup.fromJson(JsonMap json) {
    final status = requireString(json, 'status');
    final startDate = decodeCalendarDate(json['startDate']);
    if (startDate == null) {
      throw const DataFormatException('Missing class start date.');
    }
    return ClassGroup(
      metadata: CommonMetadata.fromJson(json),
      congregationId: requireString(json, 'congregationId'),
      name: requireString(json, 'name'),
      normalizedName: requireString(json, 'normalizedName'),
      teacherContactId: optionalString(json, 'teacherContactId'),
      startDate: startDate,
      endDate: decodeCalendarDate(json['endDate']),
      status: ClassStatus.fromWire(status),
    );
  }
}
