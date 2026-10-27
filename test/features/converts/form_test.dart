import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/domain/business_calendar.dart';
import 'package:ieadpe_converts/domain/worship_types.dart';
import 'package:ieadpe_converts/features/converts/convert_form.dart';
import 'package:ieadpe_converts/ui/br_input.dart';

import '../../support/date_picker.dart';

const _congregationId = 'b0000000-0000-4000-8000-000000000001';

ConvertRecord record({
  String? worship = '01 - Oração',
  String name = 'Pessoa',
  String? congregationId = _congregationId,
  String? personId,
  int? personRevision,
  CanonicalPersonIdentity? personIdentity,
  String? address,
}) => ConvertRecord(
  id: 'id',
  internalId: 'legacy',
  name: name,
  landmark: 'Praça',
  gender: Gender.male,
  conversionDate: DateOnly(2026, 1, 1),
  worshipType: worship,
  age: 0,
  congregationId: congregationId,
  personId: personId,
  personRevision: personRevision,
  personIdentity: personIdentity,
  address: address,
);
Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
  testWidgets('convert form hides birth date and structured address parts', (
    t,
  ) async {
    await t.pumpWidget(host(ConvertForm(onSubmit: (_) async {})));

    expect(find.byKey(const ValueKey('person-birth-date')), findsNothing);
    expect(find.byKey(const ValueKey('person-address-district')), findsNothing);
    expect(find.byKey(const ValueKey('person-address-city')), findsNothing);
    expect(
      find.byKey(const ValueKey('person-address-postal-code')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('person-address-state-code')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('person-address-street')), findsOneWidget);
    expect(find.text('Endereço'), findsOneWidget);
  });

  testWidgets(
    'new convert has no birth date or worship and only street address',
    (t) async {
      ConvertDraft? saved;
      await t.pumpWidget(
        host(
          ConvertForm(
            now: () => DateTime.utc(2026, 10, 28, 1, 30),
            congregations: const [
              Congregation(id: _congregationId, name: 'Central'),
            ],
            onSubmit: (draft) async => saved = draft,
          ),
        ),
      );
      await t.enterText(find.byKey(const ValueKey('person-name')), 'Pessoa');
      await t.enterText(
        find.byKey(const ValueKey('person-address-street')),
        'Rua Nova',
      );
      await t.enterText(find.byKey(const ValueKey('landmark')), 'Praça');
      await t.ensureVisible(find.text('Congregação *'));
      await t.tap(find.text('Congregação *'));
      await t.pumpAndSettle();
      await t.tap(find.text('Central').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Gênero *'));
      await t.tap(find.text('Gênero *'));
      await t.pumpAndSettle();
      await t.tap(find.text('Masculino').last);
      await t.pumpAndSettle();
      await tapSave(t, 'Cadastrar');

      expect(saved, isNotNull);
      expect(saved!.birthDate, isNull);
      expect(saved!.worshipType, isNull);
      expect((saved!.payload()['person'] as Map)['address'], {
        'street': 'Rua Nova',
        'district': null,
        'city': null,
        'postal_code': null,
        'state_code': null,
      });
    },
  );

  testWidgets('new form suggests Sao Paulo business date at each mount', (
    t,
  ) async {
    Future<DateTime?> displayedDate(DateTime now) async {
      await t.pumpWidget(
        host(
          ConvertForm(
            key: ValueKey(now.toIso8601String()),
            onSubmit: (_) async {},
            now: () => now,
          ),
        ),
      );
      final field = find.descendant(
        of: find.byKey(const ValueKey('conversion_date')),
        matching: find.byType(TextFormField),
      );
      return parseDateInput(t.widget<TextFormField>(field).controller!.text);
    }

    expect(
      await displayedDate(DateTime.utc(2026, 10, 28, 1, 30)),
      DateTime(2026, 10, 27),
    );
    expect(
      await displayedDate(DateTime.utc(2026, 10, 28, 3, 30)),
      DateTime(2026, 10, 28),
    );
  });

  testWidgets('editing street preserves birth date and hidden address parts', (
    t,
  ) async {
    const name = 'Pessoa vinculada';
    const address = <String, Object?>{
      'street': 'Rua Antiga',
      'district': 'Boa Vista',
      'city': 'Recife',
      'postal_code': '50000-000',
      'state_code': 'PE',
    };
    final initial = record(
      name: name,
      personId: 'person',
      personRevision: 3,
      personIdentity: CanonicalPersonIdentity(
        name: name,
        birthDate: DateOnly(1990, 2, 3),
        address: address,
      ),
    );
    ConvertDraft? saved;
    await t.pumpWidget(
      host(
        ConvertForm(initial: initial, onSubmit: (draft) async => saved = draft),
      ),
    );
    await t.enterText(
      find.byKey(const ValueKey('person-address-street')),
      'Rua Nova',
    );
    await tapSave(t, 'Atualizar');

    expect(saved!.birthDate, DateOnly(1990, 2, 3));
    expect((saved!.payload()['person'] as Map)['address'], {
      ...address,
      'street': 'Rua Nova',
    });
  });

  testWidgets('blank required fields explain validation in Portuguese', (
    t,
  ) async {
    await t.pumpWidget(host(ConvertForm(onSubmit: (_) async {})));
    await tapSave(t, 'Cadastrar');
    expect(find.text('Nome é obrigatório'), findsOneWidget);
    expect(find.text('Ponto de referência é obrigatório'), findsOneWidget);
  });
  testWidgets('photo upload failure does not claim that access changed', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        ConvertForm(
          initial: record(),
          onSubmit: (_) async => throw const DataFailure('photo_upload'),
        ),
      ),
    );
    await tapSave(t, 'Atualizar');
    expect(
      find.text(
        'Não foi possível enviar a foto. Seus dados foram mantidos. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Seu acesso mudou'), findsNothing);
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
      expect(drafts.single.congregationId, _congregationId);
      expect(drafts.single.worshipType, 'Culto legado');
      await t.tap(find.text('Salvando…'));
      await t.pump();
      expect(drafts.length, 1);
      pending.complete();
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'unchanged null canonical address stays null for an inherited long name',
    (t) async {
      final name = List.filled(244, 'A').join();
      ConvertDraft? saved;
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(
              name: name,
              congregationId: _congregationId,
              personId: 'person',
              personRevision: 7,
              personIdentity: CanonicalPersonIdentity(name: name),
            ),
            onSubmit: (draft) async => saved = draft,
          ),
        ),
      );

      await tapSave(t, 'Atualizar');

      expect(saved!.name, name);
      expect((saved!.payload()['person'] as Map)['address'], isNull);
    },
  );
  testWidgets(
    'editing canonical street preserves existing address components',
    (t) async {
      ConvertDraft? saved;
      const name = 'Pessoa';
      const address = <String, Object?>{
        'street': 'Rua Antiga',
        'district': 'Boa Vista',
        'city': 'Olinda',
        'postal_code': '50000-000',
        'state_code': 'PE',
      };
      await t.pumpWidget(
        host(
          ConvertForm(
            initial: record(
              name: name,
              congregationId: _congregationId,
              personId: 'person',
              personRevision: 1,
              personIdentity: CanonicalPersonIdentity(
                name: name,
                address: address,
              ),
            ),
            onSubmit: (draft) async => saved = draft,
          ),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('person-address-street')),
        'Rua Nova',
      );

      await tapSave(t, 'Atualizar');

      expect((saved!.payload()['person'] as Map)['address'], {
        ...address,
        'street': 'Rua Nova',
      });
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
      await pickDate(
        t,
        const ValueKey('conversion_date'),
        DateTime(2026, 1, 2),
      );
      await tapSave(t, 'Atualizar');
      expect(calls, 0);
      expect(find.text('A data não pode ser futura'), findsOneWidget);
      await pickDate(
        t,
        const ValueKey('conversion_date'),
        DateTime(2026, 1, 1),
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
      await t.ensureVisible(find.byKey(const ValueKey('person-phone')));
      await t.tap(find.byKey(const ValueKey('person-phone')));
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
