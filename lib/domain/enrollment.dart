/// Enrollment model (S05).
library;

import 'common.dart';

enum EnrollmentStatus {
  active('active'),
  completed('completed'),
  withdrawn('withdrawn');

  const EnrollmentStatus(this.wire);

  final String wire;

  static EnrollmentStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () =>
        throw DataFormatException('Unknown enrollment status: $value'),
  );
}

class Enrollment extends DomainRecord {
  const Enrollment({
    required this.metadata,
    required this.studentId,
    required this.classId,
    required this.congregationId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  @override
  final CommonMetadata metadata;
  final String studentId;
  final String classId;
  final String congregationId;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final EnrollmentStatus status;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'studentId': studentId,
    'classId': classId,
    'congregationId': congregationId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'status': status.wire,
  };

  factory Enrollment.fromJson(JsonMap json) {
    final status = requireString(json, 'status');
    final startDate = decodeCalendarDate(json['startDate']);
    if (startDate == null) {
      throw const DataFormatException('Missing enrollment start date.');
    }
    return Enrollment(
      metadata: CommonMetadata.fromJson(json),
      studentId: requireString(json, 'studentId'),
      classId: requireString(json, 'classId'),
      congregationId: requireString(json, 'congregationId'),
      startDate: startDate,
      endDate: decodeCalendarDate(json['endDate']),
      status: EnrollmentStatus.fromWire(status),
    );
  }
}
