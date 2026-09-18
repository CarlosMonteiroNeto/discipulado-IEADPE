import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/congregations/congregation_repository.dart';
import 'package:discipulado_ieadpe/features/team/contact_page.dart';
import 'package:discipulado_ieadpe/features/team/team_controller.dart';
import 'package:discipulado_ieadpe/features/team/team_page.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'team_test_support.dart';

/// A directory projection exactly as the backend writes it: no display
/// congregation name (that field is resolved from the authorized catalog).
const JsonMap _directoryEntry = <String, Object?>{
  'id': 'ct1',
  'name': 'Ana Souza',
  'normalizedName': 'ana souza',
  'scope': 'congregation',
  'roleCode': 'teacher',
  'congregationId': 'c1',
  'phoneE164': null,
};

JsonMap _congregationJson({
  String id = 'c1',
  required String name,
  bool active = true,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'normalizedName': name.toLowerCase(),
  'active': active,
  'revision': 1,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'updatedBy': 'u1',
};

void main() {
  testWidgets('the list resolves names from the catalog, not the projection', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway teamGateway = FakeTeamGateway()
      ..onQuery = (_) => const PageResult(items: <JsonMap>[_directoryEntry]);
    final FakeTeamGateway catalogGateway = FakeTeamGateway();
    catalogGateway.onQuery = (QueryRequest request) => PageResult(
      items: <JsonMap>[
        if (request.equalityFilters?['active'] == true)
          _congregationJson(name: 'Central'),
      ],
    );
    final TeamController controller = TeamController(
      repository: TeamRepository(gateway: teamGateway),
      profile: testProfile(),
      catalog: CongregationRepository(gateway: catalogGateway),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, TeamPage(controller: controller));

    expect(find.text('Central'), findsOneWidget);
    expect(find.text('c1'), findsNothing);
  });

  testWidgets('the list reflects a rename after a catalog refresh', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway teamGateway = FakeTeamGateway()
      ..onQuery = (_) => const PageResult(items: <JsonMap>[_directoryEntry]);
    final FakeTeamGateway catalogGateway = FakeTeamGateway();
    String catalogName = 'Central';
    catalogGateway.onQuery = (QueryRequest request) => PageResult(
      items: <JsonMap>[
        if (request.equalityFilters?['active'] == true)
          _congregationJson(name: catalogName),
      ],
    );
    final TeamController controller = TeamController(
      repository: TeamRepository(gateway: teamGateway),
      profile: testProfile(),
      catalog: CongregationRepository(gateway: catalogGateway),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, TeamPage(controller: controller));
    expect(find.text('Central'), findsOneWidget);

    catalogName = 'Central Renomeada';
    await tester.tap(find.byKey(TeamPage.refreshKey));
    await tester.pumpAndSettle();

    expect(find.text('Central Renomeada'), findsOneWidget);
    expect(find.text('Central'), findsNothing);
  });

  testWidgets('the detail line resolves the catalog name, never the UUID', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway repositoryGateway = FakeTeamGateway();
    repositoryGateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return _directoryEntry;
      if (locator.resource == QueryResource.contacts) {
        return contactJson(id: 'ct1', name: 'Ana Souza', revision: 3);
      }
      return null;
    };
    final FakeTeamGateway catalogGateway = FakeTeamGateway()
      ..onGet = (_) => _congregationJson(name: 'Central');

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: repositoryGateway),
        profile: testProfile(),
        contactId: 'ct1',
        catalog: CongregationRepository(gateway: catalogGateway),
      ),
    );

    expect(find.text('Central'), findsOneWidget);
    expect(find.text('c1'), findsNothing);
  });

  testWidgets('the detail line reflects a rename after a catalog refresh', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway repositoryGateway = FakeTeamGateway();
    repositoryGateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return _directoryEntry;
      if (locator.resource == QueryResource.contacts) {
        return contactJson(id: 'ct1', name: 'Ana Souza', revision: 3);
      }
      return null;
    };
    final FakeTeamGateway catalogGateway = FakeTeamGateway()
      ..onGet = (_) => _congregationJson(name: 'Central Renomeada');

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: repositoryGateway),
        profile: testProfile(),
        contactId: 'ct1',
        catalog: CongregationRepository(gateway: catalogGateway),
      ),
    );

    expect(find.text('Central Renomeada'), findsOneWidget);
    expect(find.text('Central'), findsNothing);
  });

  testWidgets('an unavailable catalog name falls back to a placeholder', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway repositoryGateway = FakeTeamGateway();
    repositoryGateway.onGet = (RecordLocator locator) {
      if (locator.resource == QueryResource.directory) return _directoryEntry;
      if (locator.resource == QueryResource.contacts) {
        return contactJson(id: 'ct1', name: 'Ana Souza', revision: 3);
      }
      return null;
    };
    final FakeTeamGateway catalogGateway = FakeTeamGateway()
      ..onGet = (_) => null;

    await pumpApp(
      tester,
      ContactPage(
        repository: TeamRepository(gateway: repositoryGateway),
        profile: testProfile(),
        contactId: 'ct1',
        catalog: CongregationRepository(gateway: catalogGateway),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('c1'), findsNothing);
  });
}
