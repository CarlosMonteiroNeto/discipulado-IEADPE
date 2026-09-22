import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/team_controller.dart';
import 'package:discipulado_ieadpe/features/team/team_page.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'team_test_support.dart';

void main() {
  testWidgets('renders homonymous contacts as distinct rows', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onQuery = (_) => const PageResult(
        items: <JsonMap>[
          <String, Object?>{
            'id': 'a',
            'name': 'Ana Souza',
            'normalizedName': 'ana souza',
            'scope': 'congregation',
            'roleCode': 'teacher',
            'congregationId': 'c1',
            'congregationName': 'Central',
            'phoneE164': '+5511987654321',
          },
          <String, Object?>{
            'id': 'b',
            'name': 'Ana Souza',
            'normalizedName': 'ana souza',
            'scope': 'congregation',
            'roleCode': null,
            'congregationId': 'c1',
            'congregationName': 'Central',
            'phoneE164': null,
          },
        ],
      );
    final TeamController controller = TeamController(
      repository: TeamRepository(gateway: gateway),
      profile: testProfile(),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, TeamPage(controller: controller));

    expect(find.text('Ana Souza'), findsNWidgets(2));
    expect(find.text('Professor(a) do discipulado'), findsOneWidget);
  });

  testWidgets('directory UI never renders a birth date', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onQuery = (_) => PageResult(
        items: <JsonMap>[
          directoryJson(id: 'a', name: 'Ana Souza', birthDate: '1990-05-04'),
        ],
      );
    final TeamController controller = TeamController(
      repository: TeamRepository(gateway: gateway),
      profile: testProfile(),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, TeamPage(controller: controller));

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.textContaining('1990'), findsNothing);
    expect(find.textContaining('04/05/1990'), findsNothing);
  });

  testWidgets(
    'the filter bar reflows at 360 with 200% text without overflowing',
    (WidgetTester tester) async {
      final FakeTeamGateway gateway = FakeTeamGateway()
        ..onQuery = (_) => PageResult(
          items: <JsonMap>[
            directoryJson(
              id: 'a',
              name: 'Maria José da Conceição Araújo e Silva dos Santos',
            ),
          ],
        );
      final TeamController controller = TeamController(
        repository: TeamRepository(gateway: gateway),
        profile: testProfile(),
      );
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        TeamPage(controller: controller),
        width: 360,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(TeamPage.searchFieldKey), findsOneWidget);
      expect(find.byKey(TeamPage.scopeFilterKey), findsOneWidget);
      expect(find.byKey(TeamPage.roleFilterKey), findsOneWidget);
    },
  );
}
