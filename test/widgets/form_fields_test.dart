import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/ui/form_fields.dart';

import '../support/date_picker.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

TextField _textField(WidgetTester tester, Key key) => tester.widget<TextField>(
  find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
);

void main() {
  testWidgets('phone mask formats eleven digits and submits E.164', (
    tester,
  ) async {
    final phone = TextEditingController();
    addTearDown(phone.dispose);
    await tester.pumpWidget(
      _host(
        Form(
          child: BrPhoneField(fieldKey: const Key('phone'), controller: phone),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('phone')), '11999990001');
    await tester.pump();

    expect(
      _textField(tester, const Key('phone')).controller!.text,
      '(11) 9 9999-0001',
    );
  });

  testWidgets('phone warns after blur when the number is incomplete', (
    tester,
  ) async {
    final phone = TextEditingController();
    addTearDown(phone.dispose);
    await tester.pumpWidget(
      _host(
        Form(
          child: Column(
            children: [
              BrPhoneField(fieldKey: const Key('phone'), controller: phone),
              const SizedBox(height: 16),
              TextField(
                key: const Key('other-field'),
                decoration: const InputDecoration(labelText: 'Outro'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('phone')), '1199999000');
    await tester.tap(find.byKey(const Key('other-field')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('phone')),
        matching: find.text('O telefone deve ter 11 dígitos.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('date field is calendar-only and selects dd/MM/yyyy', (
    tester,
  ) async {
    final date = TextEditingController(text: '02/01/2026');
    addTearDown(date.dispose);
    await tester.pumpWidget(
      _host(
        Form(
          child: BrDateField(
            fieldKey: const Key('date'),
            controller: date,
            label: 'Data',
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          ),
        ),
      ),
    );

    expect(_textField(tester, const Key('date')).readOnly, isTrue);
    await pickDate(tester, const Key('date'), DateTime(2026, 1, 3));
    expect(date.text, '03/01/2026');
  });

  testWidgets('text field validates when focus leaves the field', (
    tester,
  ) async {
    final name = TextEditingController();
    addTearDown(name.dispose);
    await tester.pumpWidget(
      _host(
        Form(
          child: Column(
            children: [
              AppTextFormField(
                fieldKey: const Key('name'),
                controller: name,
                label: 'Nome',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('other-field'),
                decoration: const InputDecoration(labelText: 'Outro'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('name')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('other-field')));
    await tester.pumpAndSettle();

    expect(find.text('Obrigatório'), findsOneWidget);
  });
}
