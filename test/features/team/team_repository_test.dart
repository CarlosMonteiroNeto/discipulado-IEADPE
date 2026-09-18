import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'team_test_support.dart';

void main() {
  late FakeTeamGateway gateway;
  late TeamRepository repository;

  setUp(() {
    gateway = FakeTeamGateway();
    repository = TeamRepository(
      gateway: gateway,
      recordIdFactory: () => 'new-contact-id',
      requestIdFactory: () => 'request-1',
    );
  });

  test(
    'listDirectory requests the directory projection with filters',
    () async {
      gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

      await repository.listDirectory(
        const TeamQuery(
          search: 'José',
          scope: ContactScope.supervision,
          roleCode: RoleCode.campaignSupervisor,
        ),
      );

      final QueryRequest request = gateway.queries.single;
      expect(request.resource, QueryResource.directory);
      expect(request.namePrefix, 'José');
      expect(request.equalityFilters, <String, Object?>{
        'scope': 'supervision',
        'roleCode': 'campaignSupervisor',
      });
      expect(request.limit, 50);
    },
  );

  test('archived contacts are read from the scoped private record', () async {
    gateway.onQuery = (_) => const PageResult(items: <JsonMap>[]);

    await repository.listDirectory(
      const TeamQuery(archived: true, congregationId: 'c1'),
    );

    final QueryRequest request = gateway.queries.single;
    expect(request.resource, QueryResource.contacts);
    expect(request.congregationId, 'c1');
    expect(request.equalityFilters, <String, Object?>{'archived': true});
  });

  test('directory projection never exposes a birth date', () async {
    gateway.onGet = (_) =>
        directoryJson(id: 'ct1', name: 'Ana Souza', birthDate: '1990-05-04');

    final DirectoryEntry? entry = await repository.getDirectoryEntry('ct1');

    expect(entry, isNotNull);
    expect(entry!.name, 'Ana Souza');
    expect(entry.toJson().containsKey('birthDate'), isFalse);
  });

  test('reads the full scoped contact only for a congregation scope', () async {
    gateway.onGet = (_) =>
        contactJson(id: 'ct1', name: 'Ana Souza', revision: 4);

    final Contact? contact = await repository.getContact(
      id: 'ct1',
      scope: ContactScope.congregation,
      congregationId: 'c1',
    );

    expect(contact, isNotNull);
    expect(contact!.revision, 4);
    final RecordLocator locator = gateway.gets.single;
    expect(locator.resource, QueryResource.contacts);
    expect(locator.congregationId, 'c1');
  });

  test('saveContact rename preserves the stable ID and revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'ct1',
      'revision': 4,
    };

    final TeamMutationResult result = await repository.saveContact(
      draft: const ContactDraft(
        name: 'Ana Souza',
        scope: ContactScope.congregation,
        congregationId: 'c1',
        roleCode: RoleCode.congregationAssistant,
      ),
      id: 'ct1',
      expectedRevision: 3,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'saveContact');
    expect(call.payload['id'], 'ct1');
    expect(call.payload['expectedRevision'], 3);
    expect(call.payload['scope'], 'congregation');
    expect(call.payload['congregationId'], 'c1');
    expect(call.payload['roleCode'], 'congregationAssistant');
    expect(call.payload['requestId'], 'request-1');
    expect(result.id, 'ct1');
    expect(result.revision, 4);
  });

  test('saveContact create uses a fresh stable ID and no revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-contact-id',
      'revision': 1,
    };

    final TeamMutationResult result = await repository.saveContact(
      draft: const ContactDraft(
        name: 'Novo Contato',
        scope: ContactScope.supervision,
      ),
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.payload['id'], 'new-contact-id');
    expect(call.payload.containsKey('expectedRevision'), isFalse);
    expect(call.payload['congregationId'], isNull);
    expect(result.id, 'new-contact-id');
  });

  test('setContactArchived sends the archive flag and revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'ct1',
      'revision': 5,
    };

    await repository.setContactArchived(
      id: 'ct1',
      scope: ContactScope.congregation,
      congregationId: 'c1',
      archived: true,
      expectedRevision: 4,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'setContactArchived');
    expect(call.payload['archived'], isTrue);
    expect(call.payload['expectedRevision'], 4);
  });

  test('replaceRoleHolder carries both holder revisions', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'target',
      'revision': 2,
      'previousContactId': 'old',
      'previousRevision': 6,
    };

    final TeamMutationResult result = await repository.replaceRoleHolder(
      request: const RoleReplacementRequest(
        scope: ContactScope.congregation,
        congregationId: 'c1',
        roleCode: RoleCode.congregationAssistant,
        previousContactId: 'old',
        previousExpectedRevision: 5,
        targetContactId: 'target',
        targetExpectedRevision: 1,
      ),
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'replaceRoleHolder');
    expect(call.payload['previousContactId'], 'old');
    expect(call.payload['previousExpectedRevision'], 5);
    expect(call.payload['id'], 'target');
    expect(call.payload['expectedRevision'], 1);
    expect(result.previousContactId, 'old');
  });

  test('findAdministrativeHolder resolves the directory holder', () async {
    gateway.onQuery = (_) => PageResult(
      items: <JsonMap>[
        directoryJson(
          id: 'old',
          name: 'Carlos Lima',
          roleCode: 'congregationAssistant',
        ),
      ],
    );

    final DirectoryEntry? holder = await repository.findAdministrativeHolder(
      scope: ContactScope.congregation,
      congregationId: 'c1',
      roleCode: RoleCode.congregationAssistant,
    );

    expect(holder?.id, 'old');
    final QueryRequest request = gateway.queries.single;
    expect(request.resource, QueryResource.directory);
    expect(request.equalityFilters?['roleCode'], 'congregationAssistant');
    expect(request.equalityFilters?['congregationId'], 'c1');
  });
}
