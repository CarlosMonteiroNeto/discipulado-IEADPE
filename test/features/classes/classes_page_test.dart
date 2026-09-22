import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/class_controller.dart';
import 'package:discipulado_ieadpe/features/classes/classes_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'class_test_support.dart';

void main() {
  testWidgets('renders scoped class rows', (WidgetTester tester) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onQuery = (_) => PageResult(
        items: <JsonMap>[
          classJson(
            id: 'cls1',
            name: 'Discipulado 2026',
            teacherContactId: 't1',
          ),
        ],
      );
    final ClassController controller = ClassController(
      repository: newRepository(gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, ClassesPage(controller: controller));

    expect(find.text('Discipulado 2026'), findsOneWidget);
  });

  testWidgets('create is only offered when a scope is selected', (
    WidgetTester tester,
  ) async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onQuery = (_) => const PageResult(items: <JsonMap>[]);
    final ClassController controller = ClassController(
      repository: newRepository(gateway),
      profile: supervisorProfile(),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, ClassesPage(controller: controller, onCreate: () {}));

    expect(find.byKey(ClassesPage.createKey), findsNothing);

    await controller.setCongregation('c2');
    await tester.pumpAndSettle();

    expect(controller.canCreate, isTrue);
    expect(find.byKey(ClassesPage.createKey), findsOneWidget);
  });

  testWidgets(
    'the filter bar reflows at 360 with 200% text without overflowing',
    (WidgetTester tester) async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onQuery = (_) => PageResult(
          items: <JsonMap>[
            classJson(
              id: 'cls-c',
              name: 'Assembléia de Deus Ministério do Belém — Discipulado',
            ),
          ],
        );
      final ClassController controller = ClassController(
        repository: newRepository(gateway),
        profile: supervisorProfile(),
      );
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        ClassesPage(controller: controller),
        width: 360,
        textScale: 2.0,
      );
      await controller.setCongregation('c2');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(ClassesPage.congregationFilterKey), findsOneWidget);
      expect(find.byKey(ClassesPage.statusFilterKey), findsOneWidget);
      expect(find.byKey(ClassesPage.searchFieldKey), findsOneWidget);
    },
  );
}
