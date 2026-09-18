import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDate', () {
    test('accepts February 29 in a leap year', () {
      final date = CalendarDate.parse('2024-02-29');
      expect(date, CalendarDate(2024, 2, 29));
      expect(date.toIso8601String(), '2024-02-29');
    });

    test('accepts February 29 in a leap century year', () {
      expect(CalendarDate.parse('2000-02-29'), CalendarDate(2000, 2, 29));
    });

    test('rejects February 29 in a common year', () {
      expect(
        () => CalendarDate.parse('2023-02-29'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects February 29 in a non-leap century year', () {
      expect(
        () => CalendarDate.parse('1900-02-29'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an impossible month', () {
      expect(
        () => CalendarDate.parse('2024-13-01'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CalendarDate.parse('2024-00-10'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an impossible day for a thirty-day month', () {
      expect(
        () => CalendarDate.parse('2024-04-31'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects day zero', () {
      expect(
        () => CalendarDate.parse('2024-01-00'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a malformed date string', () {
      expect(
        () => CalendarDate.parse('24-01-01'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CalendarDate.parse('2024/01/01'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CalendarDate.parse('2024-1-1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trips through its UTC instant without shifting the day', () {
      final date = CalendarDate.parse('2024-02-29');
      expect(CalendarDate.fromDateTime(date.toDateTime()), date);
    });

    test('orders dates chronologically', () {
      expect(
        CalendarDate(1899, 12, 31).compareTo(CalendarDate(1900, 1, 1)),
        isNegative,
      );
      expect(
        CalendarDate(2024, 2, 29).compareTo(CalendarDate(2024, 3, 1)),
        isNegative,
      );
    });
  });
}
