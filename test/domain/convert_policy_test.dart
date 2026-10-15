import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/convert_policy.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';

ConvertRecord record({
  int elapsed = 0,
  bool visited = false,
  bool active = false,
  int visits = 0,
  int? start,
  bool completed = false,
  bool deviated = false,
  DateTime? deleted,
}) => ConvertRecord(
  id: 'id',
  internalId: 'legacy-base44-text',
  name: 'Synthetic',
  landmark: 'Square',
  gender: Gender.male,
  conversionDate: DateOnly(2026, 1, 1).addDays(-elapsed),
  worshipType: worshipTypes.first,
  age: 0,
  wasVisitedOnce: visited,
  isInDiscipleship: active,
  visitCount: visits,
  discipleshipStartDate: start == null
      ? null
      : DateOnly(2026, 1, 1).addDays(-start),
  isDiscipleshipCompleted: completed,
  isDeviated: deviated,
  deletedAt: deleted,
);
void main() {
  final today = DateOnly(2026, 1, 1);
  test('business date follows Sao Paulo across UTC midnight', () {
    expect(
      BusinessCalendar().today(DateTime.utc(2026, 10, 15, 1)),
      DateOnly(2026, 10, 14),
    );
  });
  test('date-only strict round trips and leap day arithmetic', () {
    expect(DateOnly.parse('2024-02-29').toString(), '2024-02-29');
    expect(DateOnly(2024, 2, 29).addDays(1), DateOnly(2024, 3, 1));
    for (final invalid in [
      '2026-02-29',
      '2026-13-01',
      '2026-01-01T00:00:00Z',
      '2026-1-1',
    ]) {
      expect(() => DateOnly.parse(invalid), throwsFormatException);
    }
  });
  test('visit due boundaries and source colors', () {
    for (final threshold in [1, 7, 30]) {
      final visited = threshold != 1;
      final active = threshold == 30;
      expect(
        needsVisit(
          record(elapsed: threshold - 1, visited: visited, active: active),
          today,
        ),
        false,
      );
      expect(
        needsVisit(
          record(elapsed: threshold, visited: visited, active: active),
          today,
        ),
        true,
      );
    }
    expect(visitState(record(elapsed: 1), today), VisitState.urgent);
    expect(visitState(record(active: true), today), VisitState.current);
    expect(
      visitState(record(active: true, visited: true, elapsed: 30), today),
      VisitState.attention,
    );
    final json = record(elapsed: 50, visited: true).toJson()
      ..['last_visit_date'] = '2026-01-01';
    expect(needsVisit(ConvertRecord.fromJson(json), today), false);
  });
  test('completion requires active known start at least ninety days', () {
    expect(
      canCompleteDiscipleship(record(active: true, start: 89), today),
      false,
    );
    expect(
      canCompleteDiscipleship(record(active: true, start: 90), today),
      true,
    );
    expect(canCompleteDiscipleship(record(start: 100), today), false);
    expect(canCompleteDiscipleship(record(active: true), today), false);
  });
  test(
    'deviation requires three visits and terminal records reject lifecycle',
    () {
      expect(canMarkDeviated(record(visits: 2)), false);
      expect(canMarkDeviated(record(visits: 3)), true);
      for (final terminal in [
        record(
          completed: true,
          visits: 3,
          active: true,
          start: 100,
          elapsed: 100,
        ),
        record(deviated: true, visits: 3),
        record(deleted: DateTime.utc(2026)),
      ]) {
        expect(needsVisit(terminal, today), false);
        expect(canCompleteDiscipleship(terminal, today), false);
        expect(canMarkDeviated(terminal), false);
        expect(canStartDiscipleship(terminal), false);
        expect(canStopDiscipleship(terminal), false);
      }
      expect(canStartDiscipleship(record()), true);
      expect(canStopDiscipleship(record(active: true)), true);
    },
  );
  test('all sixty-four worship labels exactly match captured values', () {
    final source = File('reference/base44/src/utils/worshipTypes.js')
        .readAsStringSync();
    final expected = RegExp('"([^"]+)"')
        .allMatches(source)
        .map((match) => match.group(1))
        .toList();
    expect(worshipTypes, expected);
    expect(worshipTypes.toSet(), hasLength(64));
  });
  test('Sunday 19:59 and 20:00 use Sao Paulo and Monday periods', () {
    final calendar = BusinessCalendar();
    expect(
      calendar.reportingWeekStart(DateTime.utc(2026, 10, 18, 22, 59)),
      DateOnly(2026, 10, 5),
    );
    expect(
      calendar.reportingWeekStart(DateTime.utc(2026, 10, 18, 23)),
      DateOnly(2026, 10, 12),
    );
    expect(
      calendar.reportingWeekStart(DateTime.utc(2026, 10, 19, 3)),
      DateOnly(2026, 10, 12),
    );
    expect(calendar.today(DateTime.utc(2018, 12, 1, 2)), DateOnly(2018, 12, 1));
  });
  test(
    'convert codec preserves nullable fields zero age and legacy identifiers',
    () {
      final original = record();
      final decoded = ConvertRecord.fromJson(original.toJson());
      expect(decoded.toJson(), original.toJson());
      expect(decoded.age, 0);
      expect(decoded.internalId, 'legacy-base44-text');
      final sparse = Map<String, dynamic>.from(original.toJson())
        ..remove('age')
        ..remove('visit_count');
      expect(ConvertRecord.fromJson(sparse).age, isNull);
      expect(ConvertRecord.fromJson(sparse).visitCount, 0);
    },
  );
  test('six source schema DTOs and enums round trip', () {
    final rows = <Map<String, dynamic>>[
      Congregation(id: 'c', name: 'Synthetic').toJson(),
      ConvertEvent(
        id: 'e',
        convertId: 'i',
        eventType: ConvertEventType.discipleshipStarted,
        eventDate: today,
      ).toJson(),
      Feedback(id: 'f', message: 'Synthetic').toJson(),
      UserAccess(
        id: 'u',
        userEmail: 'a@example.invalid',
        role: AccessRole.direction,
        congregationId: 'c',
      ).toJson(),
      WeeklyReport(
        id: 'w',
        congregationId: 'c',
        weekStart: today,
        confirmedByEmail: 'a@example.invalid',
      ).toJson(),
    ];
    expect(Congregation.fromJson(rows[0]).toJson(), rows[0]);
    expect(ConvertEvent.fromJson(rows[1]).toJson(), rows[1]);
    expect(Feedback.fromJson(rows[2]).toJson(), rows[2]);
    expect(UserAccess.fromJson(rows[3]).toJson(), rows[3]);
    expect(WeeklyReport.fromJson(rows[4]).toJson(), rows[4]);
    for (final value in Gender.values) {
      expect(Gender.fromWire(value.wireValue), value);
    }
    for (final value in ConvertEventType.values) {
      expect(ConvertEventType.fromWire(value.wireValue), value);
    }
    for (final value in AccessRole.values) {
      expect(AccessRole.fromWire(value.wireValue), value);
    }
    for (final value in FeedbackStatus.values) {
      expect(FeedbackStatus.fromWire(value.wireValue), value);
    }
    expect(() => Gender.fromWire('unknown'), throwsFormatException);
  });
  test('pagination and scope defensively copy collections', () {
    final items = ['a'];
    final page = Page(items: items, nextCursor: 'next');
    items.clear();
    expect(page.items, ['a']);
    expect(() => page.items.add('b'), throwsUnsupportedError);
    final grants = ['c'];
    final scope = AccessScope(congregationIds: grants);
    grants.clear();
    expect(scope.canAccess('c'), true);
    expect(scope.canAccess(null), false);
    expect(AccessScope(isSupervision: true).canAccess(null), true);
    expect(AccessScope(isAdmin: true).isGlobalManager, true);
    expect(
      const MutationResult<String>.applied(
        operationId: 'op',
        value: 'id',
      ).status,
      MutationStatus.applied,
    );
    expect(
      const MutationResult<String>.rejected(
        operationId: 'op',
        errorCode: 'denied',
      ).value,
      isNull,
    );
  });
}
