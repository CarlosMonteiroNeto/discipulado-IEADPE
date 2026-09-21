import 'dart:async';

import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/attendance/session_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'attendance_test_support.dart';

void main() {
  testWidgets('prevents a duplicate submission and sends ISO date and topic', (
    WidgetTester tester,
  ) async {
    final Completer<JsonMap> completer = Completer<JsonMap>();
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvokeAsync = (_, _) => completer.future;

    await pumpAcademicPage(
      tester,
      SessionEditor(
        repository: newRepository(gateway),
        congregationId: 'c1',
        classId: 'cls1',
      ),
    );

    await setFormText(
      tester,
      SessionEditor.dateFieldKey,
      '03/02/2026',
    );
    await tester.enterText(find.byKey(SessionEditor.topicFieldKey), 'Aula 1');
    await tester.tap(find.byKey(SessionEditor.saveKey));
    await tester.pump();
    await tester.tap(find.byKey(SessionEditor.saveKey), warnIfMissed: false);
    await tester.pump();

    expect(gateway.invocations, hasLength(1));
    expect(gateway.invocations.single.payload['date'], '2026-02-03');
    expect(gateway.invocations.single.payload['topic'], 'Aula 1');

    completer.complete(const <String, Object?>{'id': 'ses1', 'revision': 1});
    await tester.pumpAndSettle();
  });

  testWidgets('backend failure keeps the date and topic', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onInvoke = (_, _) => throw const AppFailure(
        code: AppFailureCode.validation,
        message: 'Data fora do período da turma.',
      );

    await pumpAcademicPage(
      tester,
      SessionEditor(
        repository: newRepository(gateway),
        congregationId: 'c1',
        classId: 'cls1',
      ),
    );

    await setFormText(
      tester,
      SessionEditor.dateFieldKey,
      '03/02/2026',
    );
    await tester.enterText(find.byKey(SessionEditor.topicFieldKey), 'Aula 1');
    await tapVisible(tester, SessionEditor.saveKey);

    expect(find.text('Data fora do período da turma.'), findsOneWidget);
    expect(find.text('03/02/2026'), findsOneWidget);
    expect(find.text('Aula 1'), findsOneWidget);
  });
}
