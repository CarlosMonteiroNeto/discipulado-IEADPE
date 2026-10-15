import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A Gregorian business date; its wire representation never uses an instant.
final class DateOnly implements Comparable<DateOnly> {
  DateOnly(this.year, this.month, this.day) {
    final checked = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        checked.year != year ||
        checked.month != month ||
        checked.day != day) {
      throw FormatException('Invalid calendar date');
    }
  }
  factory DateOnly.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw FormatException('Expected yyyy-MM-dd');
    }
    return DateOnly(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }
  final int year, month, day;
  DateTime get _ordinal => DateTime.utc(year, month, day);
  int get weekday => _ordinal.weekday;
  DateOnly addDays(int days) {
    final date = _ordinal.add(Duration(days: days));
    return DateOnly(date.year, date.month, date.day);
  }

  int differenceInDays(DateOnly other) =>
      _ordinal.difference(other._ordinal).inDays;
  @override
  int compareTo(DateOnly other) => _ordinal.compareTo(other._ordinal);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
}

final class BusinessCalendar {
  BusinessCalendar() {
    _initialize();
  }
  static bool _initialized = false;
  static void _initialize() {
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
    }
  }

  tz.TZDateTime _local(DateTime instant) =>
      tz.TZDateTime.from(instant, tz.getLocation('America/Sao_Paulo'));
  DateOnly today(DateTime instant) {
    final date = _local(instant);
    return DateOnly(date.year, date.month, date.day);
  }

  DateOnly weekStart(DateOnly date) => date.addDays(1 - date.weekday);

  /// The latest reportable Monday. Sunday becomes reportable at 20:00.
  DateOnly reportingWeekStart(DateTime instant) {
    final local = _local(instant);
    final date = today(instant);
    final monday = weekStart(date);
    return date.weekday == DateTime.sunday && local.hour >= 20
        ? monday
        : monday.addDays(-7);
  }
}
