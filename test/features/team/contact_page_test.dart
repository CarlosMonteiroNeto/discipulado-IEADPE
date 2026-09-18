import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/contact_page.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'team_test_support.dart';

void main() {
  testWidgets('cross-scope detail requests only the directory projection', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onGet = (RecordLocator locator) {
        if (locator.resource == QueryResource.directory) {
          return directoryJson(
            id: 'ct1',
            name: 'Ana Souza',
            normalizedName: 'ana souza',
            roleCode: 'teacher',
            congregationId: 'c2',
            birthDate: '1990-05-04',
          );
        }
        fail('A cross-scope detail must not fetch the private contact record.');
      };
    final TeamRepository repository = TeamRepository(gateway: gateway);

    await pumpApp(
      tester,
      ContactPage(
        repository: repository,
        profile: testProfile(congregationId: 'c1'),
        contactId: 'ct1',
      ),
    );

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Professor(a) do discipulado'), findsOneWidget);
    expect(gateway.gets.map((RecordLocator l) => l.resource), <QueryResource>[
      QueryResource.directory,
    ]);
    expect(find.textContaining('1990'), findsNothing);
    expect(find.byKey(ContactPage.archiveKey), findsNothing);
    expect(find.byKey(ContactPage.editKey), findsNothing);
  });

  testWidgets('a local editor loads the full record and sees write controls', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway()
      ..onGet = (RecordLocator locator) {
        if (locator.resource == QueryResource.directory) {
          return directoryJson(
            id: 'ct1',
            name: 'Ana Souza',
            roleCode: 'teacher',
            congregationId: 'c1',
          );
        }
        return contactJson(
          id: 'ct1',
          name: 'Ana Souza',
          roleCode: 'teacher',
          revision: 3,
        );
      };
    final TeamRepository repository = TeamRepository(gateway: gateway);

    await pumpApp(
      tester,
      ContactPage(
        repository: repository,
        profile: testProfile(congregationId: 'c1'),
        contactId: 'ct1',
      ),
    );

    expect(gateway.gets.map((RecordLocator l) => l.resource), <QueryResource>[
      QueryResource.directory,
      QueryResource.contacts,
    ]);
    expect(find.byKey(ContactPage.editKey), findsOneWidget);
    expect(find.byKey(ContactPage.archiveKey), findsOneWidget);
  });
}
