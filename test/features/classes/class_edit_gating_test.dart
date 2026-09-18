import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/class_detail_page.dart';
import 'package:discipulado_ieadpe/features/classes/class_form.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'class_test_support.dart';

Future<void> pumpDetail(
  WidgetTester tester,
  FakeAcademicGateway gateway, {
  required String status,
  String? teacherContactId = 't1',
}) async {
  gateway.onGet = (_) => classJson(
    id: 'cls1',
    name: 'Discipulado 2026',
    status: status,
    teacherContactId: teacherContactId,
  );
  gateway.onQuery = (QueryRequest request) =>
      request.resource == QueryResource.contacts
      ? PageResult(
          items: <JsonMap>[
            contactJson(id: 't1', name: 'Professor A', roleCode: 'teacher'),
          ],
        )
      : const PageResult(items: <JsonMap>[]);
  await pumpApp(
    tester,
    ClassDetailPage(
      repository: newRepository(gateway),
      classId: 'cls1',
      congregationId: 'c1',
    ),
    height: 2000,
  );
}

void main() {
  testWidgets('a completed class hides Editar and never opens ClassForm', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    await pumpDetail(tester, gateway, status: 'completed');

    expect(find.byKey(ClassDetailPage.editKey), findsNothing);
    expect(find.byKey(ClassForm.nameFieldKey), findsNothing);
    // Archival of a completed class stays available and detail stays visible.
    expect(find.byKey(ClassDetailPage.archiveKey), findsOneWidget);
    expect(find.text('Discipulado 2026'), findsOneWidget);
  });

  testWidgets('an archived class hides Editar', (WidgetTester tester) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    await pumpDetail(tester, gateway, status: 'archived');

    expect(find.byKey(ClassDetailPage.editKey), findsNothing);
    expect(find.byKey(ClassForm.nameFieldKey), findsNothing);
    expect(find.text('Discipulado 2026'), findsOneWidget);
  });

  testWidgets('an active class still opens the edit form', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway();
    await pumpDetail(tester, gateway, status: 'active', teacherContactId: null);

    expect(find.byKey(ClassDetailPage.editKey), findsOneWidget);

    await tester.tap(find.byKey(ClassDetailPage.editKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ClassForm.nameFieldKey), findsOneWidget);
  });
}
