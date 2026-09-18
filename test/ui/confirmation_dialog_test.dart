import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  testWidgets('confirming returns true and reports the outcome', (
    tester,
  ) async {
    late bool result;
    final triggerFocus = FocusNode();
    addTearDown(triggerFocus.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: AppButton(
            label: 'Arquivar',
            focusNode: triggerFocus,
            onPressed: () async {
              result = await showConfirmationDialog(
                tester.element(find.byType(AppButton)),
                title: 'Arquivar contato',
                message: 'Deseja arquivar Maria?',
                confirmLabel: 'Arquivar',
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);

    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byKey(ConfirmationDialog.dialogKey), findsNothing);
  });

  testWidgets('cancelling returns false and changes nothing', (tester) async {
    late bool result;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Arquivar',
              onPressed: () async {
                result = await showConfirmationDialog(
                  context,
                  title: 'Arquivar contato',
                  message: 'Deseja arquivar Maria?',
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('is fully operable with the keyboard alone', (tester) async {
    late bool result;
    final triggerFocus = FocusNode();
    addTearDown(triggerFocus.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Excluir',
              focusNode: triggerFocus,
              onPressed: () async {
                result = await showConfirmationDialog(
                  context,
                  title: 'Excluir',
                  message: 'Confirma a exclusão?',
                  destructive: true,
                );
              },
            ),
          ),
        ),
      ),
    );

    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);

    // Cancel receives initial focus; Tab reaches confirm and Enter commits.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('traps focus inside the dialog', (tester) async {
    final backgroundFocus = FocusNode();
    addTearDown(backgroundFocus.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: <Widget>[
              AppButton(
                label: 'Fundo',
                focusNode: backgroundFocus,
                onPressed: () {},
              ),
              AppButton(
                label: 'Abrir',
                onPressed: () => showConfirmationDialog(
                  context,
                  title: 'Confirmar',
                  message: 'Continuar?',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);

    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      expect(
        _isInsideDialog(focus!),
        isTrue,
        reason: 'focus escaped the dialog on tab $i',
      );
      expect(backgroundFocus.hasFocus, isFalse);
    }
  });

  testWidgets('Escape cancels and restores focus to the trigger', (
    tester,
  ) async {
    late bool result;
    final triggerFocus = FocusNode();
    addTearDown(triggerFocus.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Abrir',
              focusNode: triggerFocus,
              onPressed: () async {
                result = await showConfirmationDialog(
                  context,
                  title: 'Confirmar',
                  message: 'Continuar?',
                );
              },
            ),
          ),
        ),
      ),
    );

    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(ConfirmationDialog.dialogKey), findsNothing);
    expect(result, isFalse);
    expect(triggerFocus.hasFocus, isTrue);
  });
}

bool _isInsideDialog(FocusNode focus) {
  final context = focus.context;
  if (context == null) {
    return false;
  }
  return context.findAncestorWidgetOfExactType<AlertDialog>() != null;
}
