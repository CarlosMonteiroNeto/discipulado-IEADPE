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
import 'package:ieadpe_converts/features/intake/pending_count.dart';

import 'save_test.dart' show TestGateway, NoPhotos;

ConvertRecord row(
  String id, {
  String name = 'Pessoa',
  String? congregationId,
  String? personId,
  bool terminal = false,
  String? photo,
  bool discipleship = false,
  bool? effectiveDiscipleship,
  DateOnly? effectiveFollowUpDate,
  DateOnly? date,
  DateTime? created,
  String? worshipType = 'Culto legado',
}) => ConvertRecord(
  id: id,
  internalId: 'legacy-$id',
  name: name,
  landmark: 'Praça',
  gender: Gender.male,
  conversionDate: date ?? DateOnly(2026, 1, 1),
  worshipType: worshipType,
  congregationId: congregationId,
  personId: personId,
  isDeviated: terminal,
  photoAssetId: photo,
  isInDiscipleship: discipleship,
  effectiveIsInDiscipleship: effectiveDiscipleship,
  effectiveFollowUpDate: effectiveFollowUpDate,
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
  final statuses = <String?>[];
  final cursors = <String?>[];
  @override
  Future<Page<ConvertRecord>> dashboardPage({
    String? congregationId,
    List<String>? congregationIds,
    String? search,
    String? status,
    String? cursor,
  }) async {
    requests++;
    statuses.add(status);
    cursors.add(cursor);
    if (pending != null) return pending!.future;
    if (fail) throw const DataFailure('backend');
    final filtered = rows
        .where(
          (r) =>
              (congregationId == null || r.congregationId == congregationId) &&
              (search == null ||
                  r.name.toLowerCase().contains(search.toLowerCase())) &&
              (status == null ||
                  statusCode(r, BusinessCalendar().today(DateTime.now())) ==
                      status),
        )
        .toList();
    final offset = int.parse(cursor ?? '0');
    final end = (offset + 50).clamp(0, filtered.length);
    return Page(
      items: filtered.sublist(offset, end),
      nextCursor: end < filtered.length ? '$end' : null,
    );
  }

  @override
  Future<Map<String, int>> dashboardCounts(
    List<String> congregationIds, {
    String? search,
  }) async => {for (final id in congregationIds) id: 0};
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

class DashboardRepository extends RowsRepository {
  DashboardRepository(super.gateway, super.rows);
  final queries = <String?>[];
  String? lastStatus;
  List<String>? lastScopes;
  bool denied = false;
  @override
  Future<Page<ConvertRecord>> dashboardPage({
    String? congregationId,
    List<String>? congregationIds,
    String? search,
    String? status,
    String? cursor,
  }) async {
    queries.add(congregationId);
    lastStatus = status;
    lastScopes = congregationIds;
    if (denied) throw const DataFailure('permission');
    return Page(
      items: rows
          .where(
            (r) => congregationId == null || r.congregationId == congregationId,
          )
          .toList(),
    );
  }

  @override
  Future<Map<String, int>> dashboardCounts(
    List<String> congregationIds, {
    String? search,
  }) async => {for (final id in congregationIds) id: 1};
}

class OverlapRepository extends DashboardRepository {
  OverlapRepository(super.gateway, super.rows);
  @override
  Future<Page<ConvertRecord>> dashboardPage({
    String? congregationId,
    List<String>? congregationIds,
    String? search,
    String? status,
    String? cursor,
  }) async {
    return cursor == null
        ? Page(items: rows.take(2), nextCursor: 'next')
        : Page(items: rows.skip(1));
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

class ClassPickerGateway extends TestGateway implements ReadRpcGateway {
  Map<String, Object?>? query;
  bool academicInvalid = false;
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    if (!academicInvalid) return super.command(command, operationId, payload);
    calls.add({
      'command': command,
      'operationId': operationId,
      'payload': Map.of(payload),
    });
    return MutationResult.rejected(
      operationId: operationId,
      errorCode: 'academic_invalid',
    );
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    query = parameters;
    return {
      'items': [
        {
          'id': '40000000-0000-4000-8000-000000000001',
          'name': 'Turma local',
          'status': 'active',
          'start_date': '2026-01-01',
          'end_date': null,
          'revision': 1,
          'teacher_contact_id': null,
        },
      ],
      'next_cursor': null,
    };
  }
}

void main() {
  for (final drawer in [true, false]) {
    testWidgets(
      'overlapping pages do not duplicate ${drawer ? 'drawer' : 'urgent'} cards',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const scope = '30000000-0000-4000-8000-000000000001';
        final repository = OverlapRepository(TestGateway(), [
          row('a', name: 'Pessoa A', congregationId: scope),
          row('b', name: 'Pessoa B', congregationId: scope),
          row('c', name: 'Pessoa C', congregationId: scope),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            home: ConvertsPage(
              scope: AccessScope(isAdmin: true),
              converts: repository,
              photos: NoPhotos(),
              congregations: const [Congregation(id: scope, name: 'Matriz')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(drawer ? 'Matriz' : 'Ver todas as visitas urgentes'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Carregar mais'));
        await tester.tap(find.text('Carregar mais'));
        await tester.pumpAndSettle();
        expect(find.text('Pessoa B'), findsOneWidget);
        expect(find.text('Pessoa C'), findsOneWidget);
      },
    );
  }
  testWidgets('local list fetches the next page only on request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const scope = '30000000-0000-4000-8000-000000000001';
    final repository = RowsRepository(
      TestGateway(),
      List.generate(
        51,
        (i) => row('$i', name: 'Pessoa $i', congregationId: scope),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          scope: AccessScope(congregationIds: [scope]),
          converts: repository,
          photos: NoPhotos(),
          congregations: const [Congregation(id: scope, name: 'Matriz')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    await tester.tap(find.widgetWithText(FilterChip, 'Visita Urgente'));
    await tester.pumpAndSettle();
    expect(repository.statuses.last, 'red');
    await tester.scrollUntilVisible(
      find.text('Carregar mais'),
      600,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(repository.requests, 3);
    expect(repository.statuses.last, 'red');
    expect(repository.cursors.last, '50');
    await tester.scrollUntilVisible(
      find.text('Pessoa 50'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Pessoa 50'), findsOneWidget);
  });
  testWidgets('supervisor loads congregation records only when opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const locale = MethodChannel('br.org.ieadpe/locale');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      locale,
      (call) async => (call.arguments as List).cast<String>()..sort(),
    );
    addTearDown(() => messenger.setMockMethodCallHandler(locale, null));
    final gateway = TestGateway();
    final repository = DashboardRepository(gateway, [
      row('a', congregationId: 'a'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          scope: AccessScope(isAdmin: true),
          converts: repository,
          photos: NoPhotos(),
          congregations: const [
            Congregation(id: 'a', name: 'Matriz'),
            Congregation(id: 'b', name: 'Alfa'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(repository.queries, isEmpty);
    expect(find.text('1 visitas urgentes'), findsNWidgets(2));
    await tester.tap(find.text('Matriz'));
    await tester.pumpAndSettle();
    expect(repository.queries, ['a']);
    expect(find.byType(ConvertCard), findsOneWidget);
    await tester.ensureVisible(find.text('Ver todas as visitas urgentes'));
    await tester.tap(find.text('Ver todas as visitas urgentes'));
    await tester.pumpAndSettle();
    expect(repository.lastStatus, 'red');
    expect(repository.lastScopes, ['a', 'b']);
  });

  testWidgets('drawer permission denial clears protected content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DashboardRepository(TestGateway(), [
      row('a', congregationId: 'a'),
    ])..denied = true;
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          scope: AccessScope(isAdmin: true),
          converts: repository,
          photos: NoPhotos(),
          onScopeRefresh: () async {
            refreshed = true;
          },
          congregations: const [Congregation(id: 'a', name: 'Matriz')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matriz'));
    await tester.pumpAndSettle();
    expect(refreshed, isTrue);
    expect(find.textContaining('Seu acesso mudou'), findsOneWidget);
    expect(find.byType(ConvertCard), findsNothing);
  });

  testWidgets(
    'uncertain enrollment keeps receipt and class across drawer collapse',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const scope = '30000000-0000-4000-8000-000000000001';
      final gateway = ClassPickerGateway();
      final repository = DashboardRepository(gateway, [
        row(
          'convert',
          congregationId: scope,
          personId: '50000000-0000-4000-8000-000000000001',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: ConvertsPage(
            scope: AccessScope(isAdmin: true),
            converts: repository,
            photos: NoPhotos(),
            congregations: const [Congregation(id: scope, name: 'Matriz')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Matriz'));
      await tester.pumpAndSettle();
      Future<void> start() async {
        await tester.ensureVisible(find.text('Iniciou discipulado'));
        await tester.tap(find.text('Iniciou discipulado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
      }

      await start();
      await tester.tap(find.text('Turma da congregação'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turma local').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Matricular e iniciar'));
      await tester.pumpAndSettle();
      final drawerTitle = find
          .descendant(
            of: find.byKey(
              const ValueKey('drawer:30000000-0000-4000-8000-000000000001'),
            ),
            matching: find.text('Matriz'),
          )
          .first;
      await tester.ensureVisible(drawerTitle);
      await tester.tap(drawerTitle);
      await tester.pumpAndSettle();
      await tester.tap(drawerTitle);
      await tester.pumpAndSettle();
      await start();
      expect(find.text('Selecionar turma'), findsNothing);
      expect(gateway.calls, hasLength(2));
      expect(gateway.calls[1], gateway.calls[0]);
    },
  );
  test('convert decoding accepts null worship but rejects blank text', () {
    final json =
        row('d0000000-0000-4000-8000-000000000001', worshipType: null).toJson()
          ..['created_at'] = '2026-01-02T00:00:00Z'
          ..['updated_at'] = '2026-01-02T00:00:00Z'
          ..['legacy_identity'] = {
            'name': 'Pessoa',
            'phone': null,
            'address': null,
          };

    expect(decodeConvert(json).worshipType, isNull);
    expect(
      () => decodeConvert({...json, 'worship_type': '  '}),
      throwsA(isA<DataFailure>()),
    );
  });

  testWidgets('card presents a missing worship type as not informed', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConvertCard(
              record: row('no-worship', worshipType: null),
              today: DateOnly(2026, 10, 15),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Não informado'), findsOneWidget);
  });

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
  testWidgets('card uses projected contact date and enrollment state', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConvertCard(
              record: row(
                'enrolled',
                effectiveDiscipleship: true,
                effectiveFollowUpDate: today.addDays(-29),
              ),
              today: today,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Em dia'), findsOneWidget);
    expect(find.text('29 dias desde último contato'), findsOneWidget);
    expect(find.text('Em Discipulado'), findsOneWidget);
    expect(find.text('0 visitas'), findsOneWidget);
    expect(find.text('Já visitado'), findsNothing);
    expect(t.takeException(), isNull);
  });
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
  test('sorts severity, then congregation, then person name', () {
    const congregations = [
      Congregation(id: 'a', name: 'Matriz'),
      Congregation(id: 'b', name: 'Norte'),
    ];
    final rows = [
      row(
        'green-a',
        name: 'Ana',
        congregationId: 'a',
        discipleship: true,
        effectiveFollowUpDate: today.addDays(-1),
      ),
      row('red-b', name: 'Bia', congregationId: 'b'),
      row('red-a-z', name: 'Zelia', congregationId: 'a'),
      row('yellow-a', name: 'Bruna', congregationId: 'a', date: today),
      row('red-a-a', name: 'Ana', congregationId: 'a'),
      row('yellow-b', name: 'Aline', congregationId: 'b', date: today),
    ];
    expect(
      visibleConverts(
        rows,
        congregations,
        AccessScope(isAdmin: true),
        today,
      ).map((r) => r.id),
      ['red-a-a', 'red-a-z', 'red-b', 'yellow-a', 'yellow-b', 'green-a'],
    );
    expect(
      visibleConverts(
        rows,
        congregations,
        AccessScope(congregationIds: ['a']),
        today,
      ).map((r) => r.id),
      ['red-a-a', 'red-a-z', 'yellow-a', 'green-a'],
    );
  });

  test(
    'Portuguese name order applies within equal status and congregation',
    () async {
      final rows = [
        row('z', name: 'Zélia', congregationId: 'a'),
        row('a', name: 'Álvaro', congregationId: 'a'),
        row('ana', name: 'Ana', congregationId: 'a'),
      ];
      final ranks = await convertNameRanks(
        rows,
        sortNames: (_) async => ['Álvaro', 'Ana', 'Zélia'],
      );
      expect(
        visibleConverts(
          rows,
          const [Congregation(id: 'a', name: 'Matriz')],
          AccessScope(isAdmin: true),
          today,
          nameRanks: ranks,
        ).map((r) => r.id),
        ['a', 'ana', 'z'],
      );
    },
  );

  testWidgets('convert list displays severity and Portuguese name order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const locale = MethodChannel('br.org.ieadpe/locale');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      locale,
      (_) async => ['Álvaro', 'Ana', 'Zélia'],
    );
    addTearDown(() => messenger.setMockMethodCallHandler(locale, null));
    final currentDay = BusinessCalendar().today(DateTime.now());
    final repository = RowsRepository(TestGateway(), [
      row('red-a', name: 'Álvaro', date: currentDay.addDays(-2)),
      row('red-z', name: 'Zélia', date: currentDay.addDays(-2)),
      row(
        'green',
        name: 'Ana',
        discipleship: true,
        effectiveFollowUpDate: currentDay,
      ),
    ]);
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
    expect(
      tester
          .widgetList<ConvertCard>(find.byType(ConvertCard))
          .map((card) => card.record.id),
      ['red-a', 'red-z', 'green'],
    );
  });

  test('active filters preserve congregation ordering and unknown last', () {
    const congregations = [
      Congregation(id: 's', name: 'Sede'),
      Congregation(id: 'a', name: 'Água'),
    ];
    final rows = [
      row('old', congregationId: 'a', created: DateTime(2026)),
      row('unknown'),
      row('sede', congregationId: 's'),
      row('new', name: 'ANA', congregationId: 'a', created: DateTime(2026, 2)),
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
  });
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
    await expectLater(
      actions.execute(ConvertAction.start, row('id')),
      throwsA(isA<DataFailure>()),
    );
    await actions.execute(ConvertAction.start, row('id'), classId: 'class-id');
    expect(gateway.calls.last['payload'], {
      'id': 'id',
      'action': 'start',
      'class_id': 'class-id',
    });
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
    'search reaches records beyond the first page and preserves errors',
    (tester) async {
      const locale = MethodChannel('br.org.ieadpe/locale');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        locale,
        (call) async => List<String>.from(call.arguments as List)..sort(),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(locale, null));
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
      expect(repository.requests, 1);
      await tester.enterText(find.byType(TextField), 'Última');
      await tester.pump(const Duration(milliseconds: 350));
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

  testWidgets('starting a convert requires a local class selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = ClassPickerGateway()..fail = false;
    const congregation = '30000000-0000-4000-8000-000000000001';
    final repository = RowsRepository(gateway, [
      row(
        'convert',
        congregationId: congregation,
        personId: '50000000-0000-4000-8000-000000000001',
      ),
    ]);
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
    await tester.ensureVisible(find.text('Iniciou discipulado'));
    await tester.tap(find.text('Iniciou discipulado'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar'));
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(gateway.query?['congregation_id'], congregation);
    expect(gateway.query?['status'], 'active');
    expect(gateway.calls, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Matricular e iniciar'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Turma da congregação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turma local').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matricular e iniciar'));
    await tester.pumpAndSettle();
    expect(gateway.calls.last['payload'], {
      'id': 'convert',
      'action': 'start',
      'class_id': '40000000-0000-4000-8000-000000000001',
    });
  });

  testWidgets('rejected class selection can be changed on retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = ClassPickerGateway()..academicInvalid = true;
    final repository = RowsRepository(gateway, [
      row(
        'convert',
        congregationId: '30000000-0000-4000-8000-000000000001',
        personId: '50000000-0000-4000-8000-000000000001',
      ),
    ]);
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
    Future<void> start() async {
      await tester.ensureVisible(find.text('Iniciou discipulado'));
      await tester.tap(find.text('Iniciou discipulado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    }

    await start();
    await tester.tap(find.text('Turma da congregação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turma local').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matricular e iniciar'));
    await tester.pumpAndSettle();
    await start();
    expect(find.text('Selecionar turma'), findsOneWidget);
    await tester.tap(find.text('Turma da congregação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turma local').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matricular e iniciar'));
    await tester.pumpAndSettle();
    expect(gateway.calls, hasLength(2));
    expect(
      gateway.calls[1]['operationId'],
      isNot(gateway.calls[0]['operationId']),
    );
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

  test('Matriz comes first and all others follow alphabetical order', () async {
    final ordered = await orderCongregations(const [
      Congregation(id: 'sede', name: 'Sede Nova'),
      Congregation(id: 'z', name: 'Zeta'),
      Congregation(id: 'matriz', name: 'Matriz'),
      Congregation(id: 'a', name: 'Água'),
    ], sortNames: (_) async => ['Água', 'Matriz', 'Sede Nova', 'Zeta']);
    expect(ordered.map((c) => c.name), ['Matriz', 'Água', 'Sede Nova', 'Zeta']);
  });

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
      ['a-old', 'a-new', 'b-new', 'b-old'],
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

  testWidgets(
    'pending banner sits above the converts heading and opens review',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConvertsPage(
            scope: AccessScope(isAdmin: true),
            converts: RowsRepository(TestGateway(), [row('id')]),
            photos: NoPhotos(),
            loadPending: () async => const PendingCount(count: 3),
            onOpenPending: () => opened++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 cadastros pendentes'), findsOneWidget);
      final bannerY = tester
          .getTopLeft(find.byKey(const ValueKey('pending-banner')))
          .dy;
      final headingY = tester.getTopLeft(find.text('Convertidos')).dy;
      expect(bannerY, lessThan(headingY));

      await tester.tap(find.byKey(const ValueKey('pending-banner-review')));
      expect(opened, 1);
    },
  );

  testWidgets('pending banner stays hidden when the count is zero or fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          key: const ValueKey('zero-count'),
          scope: AccessScope(isAdmin: true),
          converts: RowsRepository(TestGateway(), []),
          photos: NoPhotos(),
          loadPending: () async => const PendingCount(count: 0),
          onOpenPending: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-banner')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: ConvertsPage(
          key: const ValueKey('failed-count'),
          scope: AccessScope(isAdmin: true),
          converts: RowsRepository(TestGateway(), []),
          photos: NoPhotos(),
          loadPending: () async => throw const DataFailure('backend'),
          onOpenPending: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-banner')), findsNothing);
    expect(find.text('Nenhum convertido encontrado'), findsOneWidget);
  });
}
