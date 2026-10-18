import 'dart:async';

import 'package:ieadpe_converts/features/photos/photo_repository.dart';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/convert_repository.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/converts/convert_actions.dart';
import 'package:ieadpe_converts/features/converts/convert_card.dart';
import 'package:ieadpe_converts/features/converts/converts_page.dart';

import 'package:ieadpe_converts/features/converts/congregation_order.dart';

import 'save_test.dart' show TestGateway, NoPhotos;

ConvertRecord row(
  String id, {
  String name = 'Pessoa',
  String? congregationId,
  bool terminal = false,
  String? photo,
  bool discipleship = false,
  DateOnly? date,
  DateTime? created,
}) => ConvertRecord(
  id: id,
  internalId: 'legacy-$id',
  name: name,
  landmark: 'Praça',
  gender: Gender.male,
  conversionDate: date ?? DateOnly(2026, 1, 1),
  worshipType: 'Culto legado',
  congregationId: congregationId,
  isDeviated: terminal,
  photoAssetId: photo,
  isInDiscipleship: discipleship,
  wasVisitedOnce: discipleship,
  age: 0,
  createdAt: created,
);

class RowsRepository extends ConvertRepository {
  RowsRepository(super.gateway, this.rows);
  final List<ConvertRecord> rows;
  int requests = 0;
  Completer<Page<ConvertRecord>>? pending;
  bool fail = false;
  @override
  Future<Page<ConvertRecord>> list(ConvertQuery query, String? cursor) async {
    requests++;
    if (pending != null) return pending!.future;
    if (fail) throw const DataFailure('backend');
    final offset = int.parse(cursor ?? '0');
    final end = (offset + 100).clamp(0, rows.length);
    return Page(
      items: rows.sublist(offset, end),
      nextCursor: end < rows.length ? '$end' : null,
    );
  }
}

class PendingPhotos implements PhotoRepository {
  final metadata = Completer<PhotoAsset>();
  int downloads = 0;
  @override
  Future<PhotoAsset> get(String id) => metadata.future;
  @override
  Future<Uint8List> download(PhotoAsset asset) async {
    downloads++;
    return Uint8List(1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OrderedGateway extends TestGateway {
  final commands = <String, Completer<MutationResult<String>>>{};
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) {
    return (commands[payload['id'] as String] = Completer()).future;
  }
}

void main() {
  testWidgets('removing a photo asset clears pending and failed photo state', (
    t,
  ) async {
    final gateway = TestGateway();
    for (final fail in [false, true]) {
      final photos = PendingPhotos();
      Widget card(String? photo) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConvertCard(
              key: ValueKey('card-$fail'),
              record: row('one', photo: photo),
              today: DateOnly(2026, 10, 16),
              gateway: gateway,
              photos: photos,
            ),
          ),
        ),
      );
      await t.pumpWidget(card('asset'));
      if (fail) {
        photos.metadata.completeError(const DataFailure('backend'));
        await t.pump();
      }
      await t.pumpWidget(card(null));
      expect(find.text('Carregando foto…'), findsNothing);
      expect(find.text('Não foi possível carregar a foto.'), findsNothing);
      if (!fail) photos.metadata.completeError(const DataFailure('backend'));
      await t.pump();
    }
  });
  final today = DateOnly(2026, 10, 15);
  test('Brazilian WhatsApp validates and prefixes domestic numbers', () {
    expect(
      brazilWhatsApp('(81) 99999-1234')?.toString(),
      'https://wa.me/5581999991234',
    );
    expect(
      brazilWhatsApp('+55 81 99999-1234')?.toString(),
      'https://wa.me/5581999991234',
    );
    expect(
      brazilWhatsApp('55 99999-1234')?.toString(),
      'https://wa.me/5555999991234',
    );
    for (final value in [null, '', '123', '00000000000', '+1 202 555 0111']) {
      expect(brazilWhatsApp(value), isNull);
    }
  });
  test(
    'active filters preserve newest order within congregation and unknown last',
    () {
      const congregations = [
        Congregation(id: 's', name: 'Sede'),
        Congregation(id: 'a', name: 'Água'),
      ];
      final rows = [
        row('old', congregationId: 'a', created: DateTime(2026)),
        row('unknown'),
        row('sede', congregationId: 's'),
        row(
          'new',
          name: 'ANA',
          congregationId: 'a',
          created: DateTime(2026, 2),
        ),
        row('terminal', terminal: true),
      ];
      expect(
        visibleConverts(
          rows,
          congregations,
          AccessScope(isAdmin: true),
          today,
        ).map((r) => r.id),
        ['sede', 'new', 'old', 'unknown'],
      );
      expect(
        visibleConverts(
          rows,
          congregations,
          AccessScope(congregationIds: ['a']),
          today,
          name: 'ana',
        ).map((r) => r.id),
        ['new'],
      );
      expect(
        visibleConverts(
          [row('yellow', discipleship: true)],
          congregations,
          AccessScope(isAdmin: true),
          today,
          status: 'yellow',
        ).length,
        1,
      );
      expect(
        visibleConverts(
          rows,
          congregations,
          AccessScope(isAdmin: true),
          today,
          congregationId: 's',
        ).map((r) => r.id),
        ['sede'],
      );
    },
  );
  test('failed lifecycle retries preserve operation and only editable action payload', () async {
    final gateway = TestGateway();
    final actions = ConvertActions(gateway);
    await expectLater(
      actions.execute(ConvertAction.visit, row('id')),
      throwsA(isA<DataFailure>()),
    );
    gateway.fail = false;
    await actions.execute(ConvertAction.visit, row('id'));
    expect(gateway.calls.length, 2);
    expect(gateway.calls.first, gateway.calls.last);
    expect(gateway.calls.last['command'], 'transition_convert');
    expect(gateway.calls.last['payload'], {'id': 'id', 'action': 'visit'});
    await actions.execute(ConvertAction.start, row('id'));
    expect(
      gateway.calls.last['operationId'],
      isNot(gateway.calls.first['operationId']),
    );
  });
  testWidgets(
    'card exposes overdue yellow and preserves legacy worship and age zero at 200%',
    (tester) async {
      tester.view.physicalSize = const Size(360, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ConvertCard(
                  record: row('id', discipleship: true),
                  today: today,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Atenção'), findsOneWidget);
      expect(find.text('0 anos'), findsOneWidget);
      expect(find.text('Culto legado'), findsOneWidget);
      final whatsapp = tester.widget<FilledButton>(
        find.widgetWithIcon(FilledButton, Icons.chat_bubble_outline),
      );
      expect(whatsapp.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'list traverses beyond 1000 and never turns failures into empty',
    (tester) async {
      final repository = RowsRepository(
        TestGateway(),
        List.generate(
          1205,
          (i) => row('$i', name: i == 1204 ? 'Última pessoa' : 'Pessoa $i'),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ConvertsPage(
            scope: AccessScope(isAdmin: true),
            converts: repository,
            photos: NoPhotos(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.requests, 13);
      await tester.enterText(find.byType(TextField), 'Última');
      await tester.pumpAndSettle();
      expect(find.text('Última pessoa'), findsOneWidget);
      repository.fail = true;
      await tester.tap(find.byTooltip('Atualizar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
      expect(find.text('Nenhum convertido encontrado'), findsNothing);
      expect(find.text('0 convertidos encontrados'), findsNothing);
    },
  );
  testWidgets('stale list result cannot publish rows', (tester) async {
    final gateway = TestGateway();
    final repository = RowsRepository(gateway, [])..pending = Completer();
    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          scope: AccessScope(isAdmin: true),
          converts: repository,
          photos: NoPhotos(),
        ),
      ),
    );
    gateway.boundary.invalidate();
    repository.pending!.complete(Page(items: [row('id', name: 'Sigiloso')]));
    await tester.pumpAndSettle();
    expect(find.text('Sigiloso'), findsNothing);
  });

  test('terminal records reject all lifecycle predicates', () {
    for (final action in ConvertAction.values.where(
      (a) => a != ConvertAction.delete,
    )) {
      expect(
        actionAllowed(action, row('terminal', terminal: true), today),
        false,
      );
    }
    expect(
      actionAllowed(ConvertAction.visit, row('today', date: today), today),
      false,
    );
    expect(
      actionAllowed(
        ConvertAction.visit,
        row('yesterday', date: today.addDays(-1)),
        today,
      ),
      true,
    );
  });
  testWidgets('ungranted list never requests protected records', (
    tester,
  ) async {
    final repository = RowsRepository(TestGateway(), []);
    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          scope: AccessScope(),
          converts: repository,
          photos: NoPhotos(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests, 0);
    expect(find.textContaining('precisa de acesso'), findsOneWidget);
  });
  testWidgets(
    'photo invalidation between metadata and download prevents continuation',
    (tester) async {
      final gateway = TestGateway();
      final photos = PendingPhotos();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConvertCard(
                record: row('id', photo: 'asset'),
                today: today,
                gateway: gateway,
                photos: photos,
              ),
            ),
          ),
        ),
      );
      gateway.boundary.invalidate();
      photos.metadata.complete(
        const PhotoAsset(id: 'asset', path: 'owner/asset.jpg'),
      );
      await tester.pumpAndSettle();
      expect(photos.downloads, 0);
      expect(find.byType(Image), findsNothing);
    },
  );
  testWidgets(
    'confirmations cancel without mutation and pending controls disable duplicates',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <ConvertAction>[];
      Future<void> action(ConvertAction value) async {
        calls.add(value);
      }

      Widget card(bool busy) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConvertCard(
              record: row('id'),
              today: today,
              busy: busy,
              onAction: action,
            ),
          ),
        ),
      );
      await tester.pumpWidget(card(false));
      await tester.ensureVisible(find.text('Excluir'));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Confirmar').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.ensureVisible(find.text('Excluir'));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirmar'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, [ConvertAction.delete]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(card(true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Excluir'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  test('accented names remain distinct and equal-name congregation IDs stay grouped', () async {
    final ordered = await orderCongregations(const [
      Congregation(id: 'accent', name: 'São'),
      Congregation(id: 'plain', name: 'Sao'),
    ], sortNames: (_) async => ['Sao', 'São']);
    expect(ordered.map((c) => c.id), ['plain', 'accent']);
    expect(
      visibleConverts(
        [
          row('plain-old', congregationId: 'plain', created: DateTime(2026, 1)),
          row(
            'accent-new',
            congregationId: 'accent',
            created: DateTime(2026, 2),
          ),
        ],
        ordered,
        AccessScope(isAdmin: true),
        today,
      ).map((r) => r.id),
      ['plain-old', 'accent-new'],
    );
    const congregations = [
      Congregation(id: 'a', name: 'Mesmo'),
      Congregation(id: 'b', name: 'Mesmo'),
    ];
    final rows = [
      row('a-old', congregationId: 'a', created: DateTime(2026, 1)),
      row('b-new', congregationId: 'b', created: DateTime(2026, 4)),
      row('a-new', congregationId: 'a', created: DateTime(2026, 3)),
      row('b-old', congregationId: 'b', created: DateTime(2026, 2)),
    ];
    expect(
      visibleConverts(
        rows,
        congregations,
        AccessScope(isAdmin: true),
        today,
      ).map((r) => r.id),
      ['a-new', 'a-old', 'b-new', 'b-old'],
    );
  });
  testWidgets(
    'permission denial invalidates an outstanding mutation refresh before its next page',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = OrderedGateway();
      final repository = RowsRepository(gateway, [row('a'), row('b')]);
      await tester.pumpWidget(
        MaterialApp(
          home: ConvertsPage(
            scope: AccessScope(isAdmin: true),
            converts: repository,
            photos: NoPhotos(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cards = tester
          .widgetList<ConvertCard>(find.byType(ConvertCard))
          .toList();
      expect(cards.length, 2);
      final a = cards[0].onAction!(ConvertAction.visit),
          b = cards[1].onAction!(ConvertAction.visit);
      repository.pending = Completer();
      gateway.commands['a']!.complete(
        const MutationResult.applied(operationId: 'a', value: 'a'),
      );
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      gateway.commands['b']!.complete(
        const MutationResult.rejected(
          operationId: 'b',
          errorCode: 'permission',
        ),
      );
      await tester.pumpAndSettle();
      repository.pending!.complete(
        Page(items: [row('obsolete')], nextCursor: '0'),
      );
      repository.pending = null;
      await tester.pumpAndSettle();
      await Future.wait([a, b]);
      expect(repository.requests, 2);
      expect(find.textContaining('Seu acesso mudou'), findsOneWidget);
      expect(find.text('Pessoa'), findsNothing);
    },
  );
}
