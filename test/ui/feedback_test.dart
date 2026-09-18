import 'package:discipulado_ieadpe/ui/feedback.dart';
import 'package:discipulado_ieadpe/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_support.dart';

void main() {
  testWidgets('announces an outcome through a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Salvar',
              onPressed: () => showAppFeedback(
                context,
                message: 'Contato salvo',
                type: AppFeedbackType.success,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Contato salvo'), findsOneWidget);
    final node = tester.getSemantics(find.byKey(AppFeedback.messageKey));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('errors surface with the same announcement hook', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'Salvar',
              onPressed: () => showAppFeedback(
                context,
                message: 'Não foi possível salvar.',
                type: AppFeedbackType.error,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Não foi possível salvar.'), findsOneWidget);
  });
}
