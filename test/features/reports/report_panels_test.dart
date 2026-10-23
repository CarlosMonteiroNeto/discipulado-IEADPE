import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/platform/file_exporter.dart';
import 'package:ieadpe_converts/features/reports/events_panel.dart';

import '../../support/date_picker.dart';

import 'package:ieadpe_converts/features/reports/conversion_panel.dart';
import 'package:ieadpe_converts/features/reports/reports_repository.dart';

import 'reports_test.dart' show RowsGateway, id;

class Saver implements FileExporter {
  Uint8List? bytes;
  SaveOutcome outcome = SaveOutcome.cancelled;
  Completer<SaveOutcome>? pending;
  void Function()? guard;
  @override
  Future<SaveOutcome> save(
    String name,
    Uint8List data, {
    void Function()? ensureCurrent,
  }) async {
    bytes = data;
    guard = ensureCurrent;
    return pending == null ? outcome : pending!.future;
  }
}

class PanelGateway extends RowsGateway {
  Completer<void>? pending;
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async {
    if (table == 'congregations') {
      return [
        {'id': id(9997), 'name': 'Sede', 'archived_at': null},
        {
          'id': id(9998),
          'name': 'São José',
          'archived_at': '2026-09-01T00:00:00Z',
        },
      ];
    }
    if (pending != null) await pending!.future;
    if (table == 'converts') {
      return [
        for (var i = 1; i < 4; i++)
          {
            'id': id(i),
            'conversion_date': '2026-10-15',
            'worship_type': i == 3 ? null : 'Culto de oração',
          },
      ];
    }
    return [
      {
        'id': id(1),
        'convert_id': id(8888),
        'convert_name': 'Zélia',
        'congregation_id': id(9998),
        'event_type': 'visit',
        'event_date': '2026-10-01',
        'done_by_email': 'ação@example.test',
      },
      {
        'id': id(2),
        'convert_id': id(8888),
        'convert_name': 'Álvaro',
        'congregation_id': id(9997),
        'event_type': 'discipleship_started',
        'event_date': '2026-10-31',
        'done_by_email': 'a@example.test',
      },
    ].where((r) => equals.entries.every((e) => r[e.key] == e.value)).toList();
  }
}

class CatalogRaceGateway extends PanelGateway {
  final initial = Completer<List<Map<String, dynamic>>>();
  int catalogCalls = 0;
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async {
    if (table == 'congregations' && ++catalogCalls == 1) return initial.future;
    return super.read(
      table,
      context: context,
      afterId: afterId,
      equals: equals,
      name: name,
      excludeDeleted: excludeDeleted,
    );
  }
}

class LargePanelGateway extends RowsGateway {
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async {
    if (table == 'congregations') {
      return [
        {'id': id(9998), 'name': 'São José', 'archived_at': null},
      ];
    }
    return super.read(
      table,
      context: context,
      afterId: afterId,
      equals: equals,
      name: name,
      excludeDeleted: excludeDeleted,
    );
  }
}

List<String> cells(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final doc = XmlDocument.parse(
    utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content),
  );
  return doc.findAllElements('t').map((e) => e.innerText).toList();
}

Widget host(Widget child, {bool scaled = false}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scaled ? 2 : 1),
        disableAnimations: true,
      ),
      child: SingleChildScrollView(child: child),
    ),
  ),
);
void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('br.org.ieadpe/locale'), (
          call,
        ) async {
          final values = List<String>.from(call.arguments as List);
          return [
            'Sede',
            'São José',
            'Álvaro',
            'Zélia',
          ].where(values.contains).toList();
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('br.org.ieadpe/locale'),
          null,
        ),
  );
  testWidgets(
    'events loads historical catalog before applying and starts without exportable data',
    (tester) async {
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: Saver(),
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro de Eventos'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);
      expect(find.text('Exportar XLSX'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('São José'), findsOneWidget);
    },
  );
  testWidgets(
    'applied inclusive filters and displayed ptBR order are exactly exported',
    (tester) async {
      final saver = Saver();
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await pickDate(
        tester,
        const Key('report-start-date'),
        DateTime(2026, 10, 1),
      );
      await pickDate(
        tester,
        const Key('report-end-date'),
        DateTime(2026, 10, 31),
      );
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('2 evento(s) encontrado(s)'), findsOneWidget);
      await tester.tap(find.text('Convertido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pumpAndSettle();
      expect(cells(saver.bytes!), [
        'Convertido',
        'Congregação',
        'Evento',
        'Data do Evento',
        'Registrado por',
        'Álvaro',
        'Sede',
        'Iniciou discipulado',
        '31/10/2026',
        'a@example.test',
        'Zélia',
        'São José',
        'Visita realizada',
        '01/10/2026',
        'ação@example.test',
      ]);
      expect(find.text('Salvamento cancelado.'), findsOneWidget);
      await pickDate(
        tester,
        const Key('report-start-date'),
        DateTime(2026, 10, 31),
      );
      await tester.pump();
      expect(find.text('Exportar XLSX'), findsNothing);
      expect(saver.bytes!.every((b) => b == 0), isTrue);
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('1 evento(s) encontrado(s)'), findsOneWidget);
      expect(find.text('Zélia'), findsNothing);
    },
  );
  testWidgets(
    'congregation filter retains historical archived labels and export identity',
    (tester) async {
      final saver = Saver();
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('São José').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Álvaro'), findsNothing);
      expect(find.text('Zélia'), findsOneWidget);
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pumpAndSettle();
      expect(cells(saver.bytes!).skip(5), [
        'Zélia',
        'São José',
        'Visita realizada',
        '01/10/2026',
        'ação@example.test',
      ]);
    },
  );
  testWidgets(
    'conversion chart and export use same descending worship groups including fallback',
    (tester) async {
      final saver = Saver();
      await tester.pumpWidget(
        host(
          ConversionPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 conversões no período'), findsOneWidget);
      expect(find.text('Distribuição por Tipo de Culto'), findsOneWidget);
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pumpAndSettle();
      expect(cells(saver.bytes!), [
        'Tipo de Culto',
        'Conversões',
        'Culto de oração',
        '2',
        'Não informado',
        '1',
      ]);
    },
  );
  testWidgets(
    'owner replacement discards old async events and retained export bytes',
    (tester) async {
      final old = PanelGateway()..pending = Completer<void>();
      final saver = Saver();
      final repo = ReportsRepository(old);
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: repo,
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pump();
      old.boundary.invalidate();
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      old.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Zélia'), findsNothing);
      expect(find.text('Exportar XLSX'), findsNothing);
    },
  );
  testWidgets(
    'closing report during chooser clears bytes and prevents obsolete write',
    (tester) async {
      final saver = Saver()..pending = Completer<SaveOutcome>();
      await tester.pumpWidget(
        host(
          ConversionPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pump();
      expect(saver.guard, isNotNull);
      expect(saver.guard!, returnsNormally);
      await tester.pumpWidget(host(const Text('Outra página')));
      await tester.pumpAndSettle();
      expect(saver.bytes!.every((b) => b == 0), isTrue);
      expect(saver.guard!, throwsA(isA<Exception>()));
      saver.pending!.complete(SaveOutcome.saved);
      await tester.pumpAndSettle();
      expect(find.text('Arquivo salvo no local escolhido.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed export never reports saved and retry reports actual saved outcome',
    (tester) async {
      final saver = Saver()..outcome = SaveOutcome.failed;
      await tester.pumpWidget(
        host(
          ConversionPanel(
            repository: ReportsRepository(PanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pumpAndSettle();
      expect(find.text('Arquivo salvo no local escolhido.'), findsNothing);
      expect(find.textContaining('Não foi possível salvar.'), findsOneWidget);
      saver.outcome = SaveOutcome.saved;
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pumpAndSettle();
      expect(find.text('Arquivo salvo no local escolhido.'), findsOneWidget);
    },
  );
  testWidgets('reversed dates require correction and cannot export', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        EventsPanel(
          repository: ReportsRepository(PanelGateway()),
          exporter: Saver(),
          onScopeRefresh: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pickDate(
      tester,
      const Key('report-start-date'),
      DateTime(2026, 11, 1),
    );
    await pickDate(tester, const Key('report-end-date'), DateTime(2026, 10, 1));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confira as datas'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsNothing);
  });
  testWidgets(
    'all 1205 traversed events remain displayed and exported without a cap',
    (tester) async {
      final saver = Saver();
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: ReportsRepository(LargePanelGateway()),
            exporter: saver,
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('1205 evento(s) encontrado(s)'), findsOneWidget);
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.rows.length, 1205);
      await tester.tap(find.text('Exportar XLSX'));
      await tester.pumpAndSettle();
      final actual = cells(saver.bytes!);
      expect(actual.length, 6030);
      expect(actual.where((v) => v.startsWith('João ')).toSet().length, 1205);
      expect(actual, contains('João 1204'));
      expect(actual, contains('João 0'));
    },
  );
  testWidgets(
    'older initial catalog cannot replace a newer applied catalog selection',
    (tester) async {
      final gateway = CatalogRaceGateway();
      await tester.pumpWidget(
        host(
          EventsPanel(
            repository: ReportsRepository(gateway),
            exporter: Saver(),
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('São José').last);
      await tester.pumpAndSettle();
      gateway.initial.complete([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('São José'), findsOneWidget);
    },
  );
  testWidgets('360px 200 percent reduced motion report is usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        ConversionPanel(
          repository: ReportsRepository(PanelGateway()),
          exporter: Saver(),
          onScopeRefresh: () async {},
        ),
        scaled: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
