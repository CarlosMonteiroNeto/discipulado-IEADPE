/// Enrollment progress math (S08).
library;

import 'attendance.dart';
import 'session.dart';

/// One enrollment's attendance in one session, with the session status so the
/// learner can be excluded when it is not finalized.
class SessionProgress {
  const SessionProgress({
    required this.sessionStatus,
    required this.attendanceStatus,
  });

  final SessionStatus sessionStatus;
  final AttendanceStatus attendanceStatus;
}

class EnrollmentProgress {
  const EnrollmentProgress({
    required this.present,
    required this.absent,
    required this.excused,
  });

  final int present;
  final int absent;
  final int excused;

  int get denominator => present + absent;

  /// `present / (present + absent)`; null when nothing is counted, so the UI
  /// can show "Sem aulas contabilizadas" instead of 0%.
  double? get percentage => denominator == 0 ? null : present / denominator;

  /// The display value rounded to the nearest whole percent, or null.
  int? get roundedPercentage {
    final value = percentage;
    return value == null ? null : (value * 100).round();
  }
}

/// Counts only finalized, noncanceled sessions. Excused sessions are reported
/// separately and excluded from the denominator; unmarked entries never count.
EnrollmentProgress computeProgress(Iterable<SessionProgress> sessions) {
  var present = 0;
  var absent = 0;
  var excused = 0;
  for (final entry in sessions) {
    if (entry.sessionStatus != SessionStatus.finalized) continue;
    final status = entry.attendanceStatus;
    if (status == AttendanceStatus.present) {
      present++;
    } else if (status == AttendanceStatus.absent) {
      absent++;
    } else if (status == AttendanceStatus.excused) {
      excused++;
    }
  }
  return EnrollmentProgress(present: present, absent: absent, excused: excused);
}
