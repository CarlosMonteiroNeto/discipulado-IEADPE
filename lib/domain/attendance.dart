/// Attendance model (S05). The document id is the enrollment id under a
/// session; there is no free-text pastoral note.
library;

import 'common.dart';

enum AttendanceStatus {
  present('present'),
  absent('absent'),
  excused('excused'),
  unmarked('unmarked');

  const AttendanceStatus(this.wire);

  final String wire;

  static AttendanceStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () =>
        throw DataFormatException('Unknown attendance status: $value'),
  );
}

class Attendance extends DomainRecord {
  const Attendance({
    required this.metadata,
    required this.studentId,
    required this.enrollmentId,
    required this.status,
  });

  @override
  final CommonMetadata metadata;
  final String studentId;
  final String enrollmentId;
  final AttendanceStatus status;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...metadata.toJson(),
    'studentId': studentId,
    'enrollmentId': enrollmentId,
    'status': status.wire,
  };

  factory Attendance.fromJson(JsonMap json) => Attendance(
    metadata: CommonMetadata.fromJson(json),
    studentId: requireString(json, 'studentId'),
    enrollmentId: requireString(json, 'enrollmentId'),
    status: AttendanceStatus.fromWire(requireString(json, 'status')),
  );
}
