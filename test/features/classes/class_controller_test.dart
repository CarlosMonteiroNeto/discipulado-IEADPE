import 'package:discipulado_ieadpe/domain/class_group.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/classes/class_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_test_support.dart';

void main() {
  test('staff scope is fixed to the assigned congregation', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onQuery = (_) => const PageResult(items: <JsonMap>[]);
    final ClassController controller = ClassController(
      repository: newRepository(gateway),
      profile: staffProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.setCongregation('c2');

    expect(controller.query.congregationId, 'c1');
    expect(controller.canCreate, isTrue);
  });

  test('supervisor must select a congregation before creating', () async {
    final FakeAcademicGateway gateway = FakeAcademicGateway()
      ..onQuery = (_) => const PageResult(items: <JsonMap>[]);
    final ClassController controller = ClassController(
      repository: newRepository(gateway),
      profile: supervisorProfile(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.canCreate, isFalse);

    await controller.setCongregation('c2');
    expect(controller.query.congregationId, 'c2');
    expect(controller.canCreate, isTrue);
  });

  test(
    'status filter resets pagination and requests the status filter',
    () async {
      final FakeAcademicGateway gateway = FakeAcademicGateway()
        ..onQuery = (QueryRequest request) => request.cursor == null
            ? PageResult(
                items: <JsonMap>[classJson(id: 'a', name: 'Alfa')],
                nextCursor: 'cursor-1',
              )
            : PageResult(
                items: <JsonMap>[classJson(id: 'b', name: 'Beta')],
              );
      final ClassController controller = ClassController(
        repository: newRepository(gateway),
        profile: staffProfile(),
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      expect(controller.hasNextPage, isTrue);
      await controller.nextPage();
      expect(controller.hasPreviousPage, isTrue);

      await controller.setStatus(ClassStatus.completed);

      expect(controller.query.status, ClassStatus.completed);
      expect(controller.hasPreviousPage, isFalse);
      final QueryRequest request = gateway.queries.last;
      expect(request.equalityFilters?['status'], 'completed');
      expect(request.cursor, isNull);
    },
  );

  test('class filter state round-trips as percent-encoded route state', () {
    const ClassQuery query = ClassQuery(
      search: 'Discipulado Infantil',
      status: ClassStatus.active,
      congregationId: 'c1',
    );

    final String encoded = Uri(queryParameters: query.toQueryParameters())
        .query;
    expect(encoded, contains('busca=Discipulado+Infantil'));
    expect(encoded, contains('situacao=active'));

    final ClassQuery decoded = ClassQuery.fromQueryParameters(
      Uri.splitQueryString(encoded),
    );
    expect(decoded.search, 'Discipulado Infantil');
    expect(decoded.status, ClassStatus.active);
    expect(decoded.congregationId, 'c1');
  });
}
