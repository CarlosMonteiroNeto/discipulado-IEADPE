import 'package:discipulado_ieadpe/domain/attendance.dart';
import 'package:discipulado_ieadpe/domain/progress.dart';
import 'package:discipulado_ieadpe/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

SessionProgress entry(SessionStatus session, AttendanceStatus attendance) =>
    SessionProgress(sessionStatus: session, attendanceStatus: attendance);

void main() {
  test('three present plus one absent plus two excused yields 75%', () {
    final progress = computeProgress([
      entry(SessionStatus.finalized, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.absent),
      entry(SessionStatus.finalized, AttendanceStatus.excused),
      entry(SessionStatus.finalized, AttendanceStatus.excused),
    ]);

    expect(progress.present, 3);
    expect(progress.absent, 1);
    expect(progress.excused, 2);
    expect(progress.percentage, closeTo(0.75, 1e-9));
    expect(progress.roundedPercentage, 75);
  });

  test('a zero denominator has no percentage even with excused sessions', () {
    final progress = computeProgress([
      entry(SessionStatus.finalized, AttendanceStatus.excused),
      entry(SessionStatus.finalized, AttendanceStatus.excused),
    ]);

    expect(progress.present, 0);
    expect(progress.absent, 0);
    expect(progress.excused, 2);
    expect(progress.percentage, isNull);
    expect(progress.roundedPercentage, isNull);
  });

  test('no finalized sessions at all has no percentage', () {
    final progress = computeProgress([]);
    expect(progress.percentage, isNull);
    expect(progress.roundedPercentage, isNull);
    expect(progress.present, 0);
    expect(progress.absent, 0);
    expect(progress.excused, 0);
  });

  test('open and canceled sessions do not contribute', () {
    final progress = computeProgress([
      entry(SessionStatus.open, AttendanceStatus.present),
      entry(SessionStatus.canceled, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.absent),
    ]);

    expect(progress.present, 1);
    expect(progress.absent, 1);
    expect(progress.excused, 0);
    expect(progress.roundedPercentage, 50);
  });

  test('unmarked attendance never affects the percentage', () {
    final progress = computeProgress([
      entry(SessionStatus.finalized, AttendanceStatus.unmarked),
      entry(SessionStatus.finalized, AttendanceStatus.present),
    ]);

    expect(progress.present, 1);
    expect(progress.absent, 0);
    expect(progress.roundedPercentage, 100);
  });

  test('rounds the displayed percentage to the nearest whole percent', () {
    final progress = computeProgress([
      entry(SessionStatus.finalized, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.present),
      entry(SessionStatus.finalized, AttendanceStatus.absent),
    ]);

    expect(progress.percentage, closeTo(0.6666666667, 1e-9));
    expect(progress.roundedPercentage, 67);
  });
}
