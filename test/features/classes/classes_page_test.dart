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
}
