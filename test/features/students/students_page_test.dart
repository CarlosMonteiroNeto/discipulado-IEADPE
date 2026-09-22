import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/students/student_controller.dart';
import 'package:discipulado_ieadpe/features/students/student_repository.dart';
import 'package:discipulado_ieadpe/features/students/students_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'student_test_support.dart';

void main() {
  testWidgets('renders homonymous students as distinct rows', (
    WidgetTester tester,
  ) async {
    final FakeStudentGateway gateway = FakeStudentGateway()
      ..onQuery = (QueryRequest request) =>
          request.resource == QueryResource.classes
          ? const PageResult(items: <JsonMap>[])
          : PageResult(
              items: <JsonMap>[
                studentJson(id: 'a', name: 'Ana Souza'),
                studentJson(id: 'b', name: 'Ana Souza'),
              ],
            );
    final StudentController controller = StudentController(
      repository: StudentRepository(gateway: gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, StudentsPage(controller: controller));

    expect(find.text('Ana Souza'), findsNWidgets(2));
  });

  testWidgets('list rows never render private personal or religious data', (
    WidgetTester tester,
  ) async {
    final FakeStudentGateway gateway = FakeStudentGateway()
      ..onQuery = (QueryRequest request) =>
          request.resource == QueryResource.classes
          ? const PageResult(items: <JsonMap>[])
          : PageResult(
              items: <JsonMap>[
                studentJson(
                  id: 'a',
                  name: 'Ana Souza',
                  birthDate: '1990-05-04',
                  address: <String, Object?>{'street': 'Rua das Flores'},
                  wantsBaptism: true,
                ),
              ],
            );
    final StudentController controller = StudentController(
      repository: StudentRepository(gateway: gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, StudentsPage(controller: controller));

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.textContaining('1990'), findsNothing);
    expect(find.textContaining('Rua das Flores'), findsNothing);
  });

  testWidgets('staff scope is fixed and supervisor creation needs a scope', (
    WidgetTester tester,
  ) async {
    final FakeStudentGateway gateway = FakeStudentGateway()
      ..onQuery = (_) => const PageResult(items: <JsonMap>[]);
    final StudentController supervisor = StudentController(
      repository: StudentRepository(gateway: gateway),
      profile: supervisorProfile(),
    );
    addTearDown(supervisor.dispose);

    await pumpApp(
      tester,
      StudentsPage(controller: supervisor, onCreate: () {}),
    );

    expect(supervisor.canCreate, isFalse);
    expect(find.byKey(StudentsPage.createKey), findsNothing);

    await supervisor.setCongregation('c2');
    await tester.pumpAndSettle();

    expect(supervisor.query.congregationId, 'c2');
    expect(supervisor.canCreate, isTrue);
    expect(find.byKey(StudentsPage.createKey), findsOneWidget);
  });

  test(
    'class filter resets pagination and pages with the opaque cursor',
    () async {
      final FakeStudentGateway gateway = FakeStudentGateway()
        ..onQuery = (QueryRequest request) {
          if (request.resource == QueryResource.classes) {
            return const PageResult(items: <JsonMap>[]);
          }
          return request.cursor == null
              ? PageResult(
                  items: <JsonMap>[studentJson(id: 'a', name: 'Ana')],
                  nextCursor: 'cursor-1',
                )
              : PageResult(
                  items: <JsonMap>[studentJson(id: 'b', name: 'Bruno')],
                );
        };
      final StudentController controller = StudentController(
        repository: StudentRepository(gateway: gateway),
        profile: staffProfile(),
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      expect(controller.hasNextPage, isTrue);
      await controller.nextPage();
      expect(controller.hasPreviousPage, isTrue);

      await controller.setClassFilter('cls1');

      expect(controller.query.classId, 'cls1');
      expect(controller.hasPreviousPage, isFalse);
      final QueryRequest studentsQuery = gateway.queries.lastWhere(
        (QueryRequest request) => request.resource == QueryResource.students,
      );
      expect(studentsQuery.equalityFilters?['classId'], 'cls1');
      expect(studentsQuery.cursor, isNull);
    },
  );

  test('student filter state round-trips as percent-encoded route state', () {
    const StudentQuery query = StudentQuery(
      search: 'José da Silva',
      archived: true,
      classId: 'cls1',
      congregationId: 'c1',
    );

    final String encoded = Uri(queryParameters: query.toQueryParameters())
        .query;
    expect(encoded, contains('busca=Jos%C3%A9+da+Silva'));
    expect(encoded, isNot(contains(' ')));

    final StudentQuery decoded = StudentQuery.fromQueryParameters(
      Uri.splitQueryString(encoded),
    );
    expect(decoded.search, 'José da Silva');
    expect(decoded.archived, isTrue);
    expect(decoded.classId, 'cls1');
    expect(decoded.congregationId, 'c1');
  });

  test(
    'staff scope cannot be changed away from the assigned congregation',
    () async {
      final FakeStudentGateway gateway = FakeStudentGateway()
        ..onQuery = (_) => const PageResult(items: <JsonMap>[]);
      final StudentController controller = StudentController(
        repository: StudentRepository(gateway: gateway),
        profile: staffProfile(),
      );
      addTearDown(controller.dispose);

      await controller.setCongregation('c2');

      expect(controller.query.congregationId, 'c1');
      expect(controller.canCreate, isTrue);
    },
  );

  testWidgets(
    'the filter bar reflows at 360 with 200% text without overflowing',
    (WidgetTester tester) async {
      final FakeStudentGateway gateway = FakeStudentGateway()
        ..onQuery = (QueryRequest request) =>
            request.resource == QueryResource.students
            ? PageResult(
                items: <JsonMap>[
                  studentJson(
                    id: 'a',
                    name: 'Maria José da Conceição Araújo e Silva dos Santos',
                  ),
                ],
              )
            : const PageResult(items: <JsonMap>[]);
      final StudentController supervisor = StudentController(
        repository: StudentRepository(gateway: gateway),
        profile: supervisorProfile(),
      );
      addTearDown(supervisor.dispose);

      await pumpApp(
        tester,
        StudentsPage(controller: supervisor),
        width: 360,
        textScale: 2.0,
      );
      await supervisor.setCongregation('c2');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(StudentsPage.congregationFilterKey), findsOneWidget);
      expect(find.byKey(StudentsPage.classFilterKey), findsOneWidget);
      expect(find.byKey(StudentsPage.searchFieldKey), findsOneWidget);
    },
  );
}
