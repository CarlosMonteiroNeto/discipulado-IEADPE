import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/team_controller.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'team_test_support.dart';

void main() {
  late FakeTeamGateway gateway;
  late TeamRepository repository;
  late TeamController controller;

  setUp(() {
    gateway = FakeTeamGateway();
    repository = TeamRepository(
      gateway: gateway,
      recordIdFactory: () => 'new-contact-id',
      requestIdFactory: () => 'request-1',
    );
    controller = TeamController(repository: repository, profile: testProfile());
  });

  tearDown(() => controller.dispose());

  test(
    'refresh loads the first directory page and exposes the cursor',
    () async {
      gateway.onQuery = (QueryRequest request) => request.cursor == null
          ? PageResult(
              items: <JsonMap>[directoryJson(id: 'a', name: 'Ana')],
              nextCursor: 'cursor-1',
            )
          : const PageResult(items: <JsonMap>[]);

      await controller.refresh();

      expect(controller.state.data, hasLength(1));
      expect(controller.state.data!.single.id, 'a');
      expect(controller.hasNextPage, isTrue);
      expect(controller.hasPreviousPage, isFalse);
    },
  );

  test(
    'next and previous pages use the opaque cursor, never an offset',
    () async {
      gateway.onQuery = (QueryRequest request) {
        if (request.cursor == null) {
          return PageResult(
            items: <JsonMap>[directoryJson(id: 'a', name: 'Ana')],
            nextCursor: 'cursor-1',
          );
        }
        return PageResult(
          items: <JsonMap>[directoryJson(id: 'b', name: 'Bruno')],
        );
      };

      await controller.refresh();
      await controller.nextPage();

      expect(controller.state.data!.single.id, 'b');
      expect(controller.hasPreviousPage, isTrue);
      expect(gateway.queries.last.cursor, 'cursor-1');

      await controller.previousPage();
      expect(controller.state.data!.single.id, 'a');
      expect(gateway.queries.last.cursor, isNull);
    },
  );

  test('changing a filter resets pagination', () async {
    gateway.onQuery = (QueryRequest request) => PageResult(
      items: <JsonMap>[directoryJson(id: 'a', name: 'Ana')],
      nextCursor: request.cursor == null ? 'cursor-1' : null,
    );

    await controller.refresh();
    await controller.nextPage();
    expect(controller.hasPreviousPage, isTrue);

    await controller.setSearch('jo');

    expect(controller.query.search, 'jo');
    expect(controller.query.cursor, isNull);
    expect(controller.hasPreviousPage, isFalse);
    expect(gateway.queries.last.cursor, isNull);
    expect(gateway.queries.last.namePrefix, 'jo');
  });

  test('scope and role filters are carried on the query', () async {
    gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

    await controller.setScopeFilter(ContactScope.supervision);
    await controller.setRoleFilter(RoleCode.campaignSupervisor);

    expect(controller.query.scope, ContactScope.supervision);
    expect(controller.query.roleCode, RoleCode.campaignSupervisor);
    expect(gateway.queries.last.equalityFilters, <String, Object?>{
      'scope': 'supervision',
      'roleCode': 'campaignSupervisor',
    });
  });

  test('team filters round-trip as percent-encoded route state', () {
    final TeamQuery query = const TeamQuery(
      search: 'José da Silva',
      scope: ContactScope.supervision,
      roleCode: RoleCode.campaignSupervisor,
      archived: true,
      congregationId: 'c1',
    );

    final String encoded = Uri(queryParameters: query.toQueryParameters())
        .query;
    expect(encoded, contains('busca=Jos%C3%A9+da+Silva'));
    expect(encoded, isNot(contains(' ')));

    final TeamQuery decoded = TeamQuery.fromQueryParameters(
      Uri.splitQueryString(encoded),
    );
    expect(decoded.search, 'José da Silva');
    expect(decoded.scope, ContactScope.supervision);
    expect(decoded.roleCode, RoleCode.campaignSupervisor);
    expect(decoded.archived, isTrue);
    expect(decoded.congregationId, 'c1');
  });
}
