import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/features/home/home_repository.dart';

import '../converts/list_test.dart' show RowsRepository, row;
import '../converts/save_test.dart' show TestGateway;

void main() {
  test('Home traverses beyond 1000 and includes terminal totals with latest five business dates', () async {
    final rows = List.generate(
      1005,
      (i) => row(
        '$i',
        terminal: i == 0,
        date: DateOnly(2026, 10, 15).addDays(-(i % 10)),
        created: DateTime.utc(2026, 10, 15).add(Duration(seconds: i)),
      ),
    );
    final repository = RowsRepository(TestGateway(), rows);
    final result = await HomeRepository(
      repository,
      now: () => DateTime.utc(2026, 10, 16, 1),
    ).summary();
    expect(result.total, 1005);
    expect(repository.requests, 11);
    expect(result.recent.map((r) => r.id), [
      '1000',
      '990',
      '980',
      '970',
      '960',
    ]);
    expect(result.urgentVisits, 904);
  });
  test('deleted excluded, terminal included, recent includes today and six preceding dates only', () async {
    final date = DateOnly(2026, 10, 15);
    final deleted = ConvertRecord(
      id: 'deleted',
      internalId: 'deleted',
      name: 'Deleted',
      landmark: 'Praça',
      gender: Gender.male,
      conversionDate: date,
      worshipType: 'Culto',
      deletedAt: DateTime.utc(2026),
    );
    final rows = [
      deleted,
      row('terminal', terminal: true, date: date),
      row('disciple', discipleship: true, date: date),
      row('six', date: date.addDays(-6)),
      row('seven', date: date.addDays(-7)),
      row('future', date: date.addDays(1)),
    ];
    final result = await HomeRepository(
      RowsRepository(TestGateway(), rows),
      now: () => DateTime.utc(2026, 10, 16, 1),
    ).summary();
    expect(result.total, 5);
    expect(result.inDiscipleship, 1);
    expect(result.recent.map((r) => r.id).toSet(), {
      'terminal',
      'disciple',
      'six',
    });
  });
  test('dashboard counts server-derived enrollment state', () async {
    final today = DateOnly(2026, 10, 15);
    final result = await HomeRepository(
      RowsRepository(TestGateway(), [
        row(
          'enrolled-by-ministry',
          effectiveDiscipleship: true,
          effectiveFollowUpDate: today.addDays(-29),
        ),
        row(
          'manual-inactive',
          effectiveDiscipleship: false,
          effectiveFollowUpDate: today.addDays(-7),
        ),
      ]),
      now: () => DateTime.utc(2026, 10, 16, 1),
    ).summary();
    expect(result.inDiscipleship, 1);
    expect(result.urgentVisits, 1);
  });
  test('failed traversal never publishes fabricated empty summary', () async {
    final repository = RowsRepository(TestGateway(), [])..fail = true;
    await expectLater(
      HomeRepository(repository).summary(),
      throwsA(isA<DataFailure>()),
    );
  });
  test('boundary invalidation rejects pending traversal', () async {
    final gateway = TestGateway();
    final repository = RowsRepository(gateway, [])
      ..pending = Completer<Page<ConvertRecord>>();
    final summary = HomeRepository(repository).summary();
    gateway.boundary.invalidate();
    repository.pending!.complete(Page(items: [row('old')]));
    await expectLater(
      summary,
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'stale')),
    );
  });
}
