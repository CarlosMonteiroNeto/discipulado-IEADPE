import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:discipulado_ieadpe/ui/dirty_form_guard.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  test('tracks a dirty draft without persisting it locally', () {
    final guard = DirtyFormGuard();
    addTearDown(guard.dispose);

    expect(guard.isDirty, isFalse);
    expect(guard.persistsDraftLocally, isFalse);

    guard.markDirty();
    expect(guard.isDirty, isTrue);
    expect(guard.shouldConfirmUnload, isTrue);

    guard.markClean();
    expect(guard.isDirty, isFalse);
    expect(guard.shouldConfirmUnload, isFalse);
  });

  test('exposes an in-app navigation hook that can veto leaving', () async {
    final guard = DirtyFormGuard();
    addTearDown(guard.dispose);
    guard.markDirty();
    guard.registerInAppNavigationHook(() async => false);

    expect(await guard.handleInAppNavigation(), isFalse);

    final clean = DirtyFormGuard();
    addTearDown(clean.dispose);
    expect(await clean.handleInAppNavigation(), isTrue);
  });

  testWidgets('confirmLeave asks before discarding a dirty draft', (
    tester,
  ) async {
    final guard = DirtyFormGuard();
    addTearDown(guard.dispose);
    guard.markDirty();
    late bool decision;

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Sair',
              onPressed: () async =>
                  decision = await guard.confirmLeave(context),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);

    await tester.tap(find.byKey(ConfirmationDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(decision, isFalse);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(decision, isTrue);
  });

  testWidgets('confirmLeave is a no-op for a clean draft', (tester) async {
    final guard = DirtyFormGuard();
    addTearDown(guard.dispose);
    late bool decision;

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Sair',
              onPressed: () async =>
                  decision = await guard.confirmLeave(context),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(decision, isTrue);
    expect(find.byKey(ConfirmationDialog.dialogKey), findsNothing);
  });

  testWidgets('browser history back is intercepted while dirty', (
    tester,
  ) async {
    final guard = DirtyFormGuard();
    addTearDown(guard.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Editar',
              onPressed: () {
                guard.markDirty();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => guard.wrap(
                      context,
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Editar')),
                        body: const Text('rascunho'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.text('rascunho'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);

    await tester.tap(find.byKey(ConfirmationDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text('rascunho'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(find.text('rascunho'), findsNothing);
  });

  testWidgets(
    'intercepts a browser history back issued after the form becomes dirty',
    (tester) async {
      final guard = DirtyFormGuard();
      addTearDown(guard.dispose);

      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: AppButton(
                label: 'Editar',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => guard.wrap(
                        context,
                        child: Scaffold(
                          appBar: AppBar(title: const Text('Editar')),
                          body: const Text('rascunho'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(find.text('rascunho'), findsOneWidget);

      // The form starts clean and only becomes dirty after the route is built;
      // the guard must react to the notification without an external rebuild.
      guard.markDirty();
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(ConfirmationDialog.dialogKey), findsOneWidget);
      expect(find.text('rascunho'), findsOneWidget);
    },
  );
}
