import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/class_form.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_test_support.dart';

void main() {
  testWidgets('selects among eligible teachers and submits ISO dates', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    gateway.onQuery = (QueryRequest request) =>
        request.resource == QueryResource.contacts
        ? PageResult(
            items: <JsonMap>[
              contactJson(id: 't1', name: 'Professor A', roleCode: 'teacher'),
              contactJson(id: 't2', name: 'Professor B', roleCode: 'teacher'),
            ],
          )
        : const PageResult(items: <JsonMap>[]);
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-id',
      'revision': 1,
    };

    await pumpAcademicPage(
      tester,
      ClassForm(
        repository: newRepository(gateway),
        config: const ClassFormConfig(congregationId: 'c1'),
      ),
    );

    final QueryRequest teacherQuery = gateway.queries.single;
    expect(teacherQuery.resource, QueryResource.contacts);
    expect(teacherQuery.equalityFilters?['roleCode'], 'teacher');

    await tester.enterText(
      find.byKey(ClassForm.nameFieldKey),
      'Discipulado 2026',
    );
    await tester.enterText(
      find.byKey(ClassForm.startDateFieldKey),
      '05/01/2026',
    );
    await tester.tap(find.byKey(ClassForm.teacherFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Professor B').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, ClassForm.saveKey);

    final JsonMap payload = gateway.invocations.single.payload;
    expect(payload['name'], 'Discipulado 2026');
    expect(payload['teacherContactId'], 't2');
    expect(payload['startDate'], '2026-01-05');
  });

  testWidgets('backend failure keeps the typed values and offers reload', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);
    gateway.onInvoke = (_, _) => throw const AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Serviço indisponível.',
    );

    await pumpAcademicPage(
      tester,
      ClassForm(
        repository: newRepository(gateway),
        config: const ClassFormConfig(congregationId: 'c1'),
      ),
    );

    await tester.enterText(
      find.byKey(ClassForm.nameFieldKey),
      'Discipulado Alfa',
    );
    await tester.enterText(
      find.byKey(ClassForm.startDateFieldKey),
      '05/01/2026',
    );
    await tapVisible(tester, ClassForm.saveKey);

    expect(find.text('Serviço indisponível.'), findsOneWidget);
    expect(find.text('Discipulado Alfa'), findsOneWidget);
    expect(find.byKey(ClassForm.reloadKey), findsOneWidget);
  });
}
