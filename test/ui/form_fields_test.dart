import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  testWidgets(
    'submit focuses the first invalid field and shows every field error',
    (tester) async {
      final formKey = GlobalKey<AppFormState>();
      final nameFocus = FocusNode();
      final emailFocus = FocusNode();
      addTearDown(nameFocus.dispose);
      addTearDown(emailFocus.dispose);

      await pumpApp(
        tester,
        Scaffold(
          body: AppForm(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  label: 'Nome',
                  focusNode: nameFocus,
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Informe o nome' : null,
                ),
                AppTextField(
                  label: 'E-mail',
                  focusNode: emailFocus,
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Informe o e-mail' : null,
                ),
                AppButton(
                  label: 'Salvar',
                  onPressed: () =>
                      formKey.currentState!.validateAndFocusFirstError(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(find.text('Informe o nome'), findsOneWidget);
      expect(find.text('Informe o e-mail'), findsOneWidget);
      expect(nameFocus.hasFocus, isTrue);
      expect(emailFocus.hasFocus, isFalse);
    },
  );

  testWidgets('a valid form validates without moving focus', (tester) async {
    final formKey = GlobalKey<AppFormState>();
    final name = TextEditingController(text: 'Maria');
    addTearDown(name.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: AppForm(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                label: 'Nome',
                controller: name,
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Informe o nome' : null,
              ),
              AppButton(
                label: 'Salvar',
                onPressed: () =>
                    formKey.currentState!.validateAndFocusFirstError(),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(find.text('Informe o nome'), findsNothing);
  });

  testWidgets(
    'a button invokes its action on activation, not on pointer down',
    (tester) async {
      var activations = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(label: 'Salvar', onPressed: () => activations++),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(activations, 0, reason: 'pressing must not commit the action');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(activations, 1);
    },
  );

  testWidgets(
    'a disabled button is semantically disabled and never activates',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(child: AppButton(label: 'Salvar')),
        ),
      );

      final node = tester.getSemantics(find.byType(AppButton));
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();
      handle.dispose();
    },
  );

  testWidgets(
    'a submitting button exposes progress and blocks duplicate activation',
    (tester) async {
      final handle = tester.ensureSemantics();
      var activations = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(
              label: 'Salvar',
              isSubmitting: true,
              onPressed: () => activations++,
            ),
          ),
        ),
        settle: false,
      );

      expect(find.byKey(AppButton.submittingIndicatorKey), findsOneWidget);
      final node = tester.getSemantics(find.byType(AppButton));
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();
      expect(activations, 0);
      handle.dispose();
    },
  );

  testWidgets('keyboard navigation activates the button', (tester) async {
    var activations = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: AppButton(
            label: 'Salvar',
            focusNode: focusNode,
            onPressed: () => activations++,
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activations, 1);
  });
}
