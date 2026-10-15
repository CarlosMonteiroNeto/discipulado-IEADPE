import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';

ConvertRecord record({String worship = '01 - Oração'}) => ConvertRecord(
  id: 'id',
  internalId: 'legacy',
  name: 'Pessoa',
  landmark: 'Praça',
  gender: Gender.male,
  conversionDate: DateOnly(2026, 1, 1),
  worshipType: worship,
  age: 0,
);
Widget host(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);
Future<void> tapSave(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.tap(find.text(text));
  await t.pump();
}

void main() {
  testWidgets('blank required fields explain validation in Portuguese', (
    t,
  ) async {
    await t.pumpWidget(host(ConvertForm(onSubmit: (_) async {})));
    await tapSave(t, 'Cadastrar');
    expect(find.text('Nome é obrigatório'), findsOneWidget);
    expect(find.text('Ponto de referência é obrigatório'), findsOneWidget);
  });
  testWidgets(
    'age zero, optional nulls and legacy worship round trip; double press submits once',
    (t) async {
      final pending = Completer<void>();
      final drafts = <ConvertDraft>[];
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(worship: 'Culto legado'),
            onSubmit: (d) {
              drafts.add(d);
              return pending.future;
            },
          ),
        ),
      );
      await tapSave(t, 'Atualizar');
      expect(drafts.single.age, 0);
      expect(drafts.single.phone, null);
      expect(drafts.single.congregationId, null);
      expect(drafts.single.worshipType, 'Culto legado');
      await t.tap(find.text('Salvando…'));
      await t.pump();
      expect(drafts.length, 1);
      pending.complete();
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'cancelling photo picker retains fields and does not request removal',
    (t) async {
      ConvertDraft? saved;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(),
            pickPhoto: () async => null,
            onSubmit: (d) async {
              saved = d;
            },
          ),
        ),
      );
      await t.tap(find.text('Escolher foto'));
      await t.pumpAndSettle();
      await tapSave(t, 'Atualizar');
      expect(saved!.name, 'Pessoa');
      expect(saved!.photoBytes, null);
      expect(saved!.removePhoto, false);
    },
  );
  testWidgets(
    'future date uses Sao Paulo business today and keeps draft on failure',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(),
            now: () => DateTime.utc(2026, 1, 2, 1),
            onSubmit: (d) async {
              calls++;
              throw Exception('secret SQL');
            },
          ),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('conversion_date')),
        '2026-01-02',
      );
      await tapSave(t, 'Atualizar');
      expect(calls, 0);
      expect(find.text('A data não pode ser futura'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('conversion_date')),
        '2026-01-01',
      );
      await tapSave(t, 'Atualizar');
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Seus dados foram mantidos'), findsOneWidget);
      expect(find.textContaining('secret SQL'), findsNothing);
    },
  );
  testWidgets(
    'form fits 360 pixels at 200 percent with reduced motion and keyboard',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(worship: worshipTypes[42]),
            onSubmit: (_) async {},
          ),
          scale: 2,
        ),
      );
      await t.ensureVisible(find.byKey(const ValueKey('phone')));
      await t.tap(find.byKey(const ValueKey('phone')));
      await t.pump();
      await t.ensureVisible(find.text('Atualizar'));
      await t.pump();
      expect(t.takeException(), null);
    },
  );
  test('source worship choices preserve all 64 exact wire labels', () {
    expect(worshipTypes.length, 64);
    expect(worshipTypes.first, '01 - Oração');
    expect(worshipTypes.last, '64 - Inauguração de Templo');
  });
}
