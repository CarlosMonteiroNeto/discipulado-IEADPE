import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _monthNames = <String>[
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
  'janeiro',
  'fevereiro',
  'marco',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Selects a date through the Material calendar, including month navigation.
Future<void> pickDate(WidgetTester tester, Key fieldKey, DateTime date) async {
  await tester.ensureVisible(find.byKey(fieldKey));
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  final dialog = find.byType(DatePickerDialog);
  expect(dialog, findsOneWidget);

  for (var attempt = 0; attempt < 36; attempt++) {
    if (_visibleMonthMatches(tester, dialog, date)) break;
    final current = _visibleMonth(tester, dialog);
    expect(current, isNotNull);
    final forward =
        date.year * 12 + date.month > current!.year * 12 + current.month;
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.byIcon(
          forward ? Icons.chevron_right : Icons.chevron_left,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final day = find.descendant(
    of: find.byType(CalendarDatePicker),
    matching: find.text('${date.day}'),
  );
  expect(day, findsWidgets);
  await tester.tap(day.last);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)).last,
  );
  await tester.pumpAndSettle();
}

bool _visibleMonthMatches(WidgetTester tester, Finder dialog, DateTime date) =>
    _visibleMonth(tester, dialog) == DateTime(date.year, date.month);

DateTime? _visibleMonth(WidgetTester tester, Finder dialog) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: dialog, matching: find.byType(Text)),
  );
  for (final text in texts) {
    final data = text.data?.toLowerCase();
    if (data == null) continue;
    final match = RegExp(r'([a-z]+)(?:\s+de)?\s+(\d{4})').firstMatch(data);
    if (match == null) continue;
    final month = _monthNames.indexOf(match.group(1)!);
    if (month < 0) continue;
    return DateTime(int.parse(match.group(2)!), month % 12 + 1);
  }
  return null;
}
