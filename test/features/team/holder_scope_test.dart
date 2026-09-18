import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/contact.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'team_test_support.dart';

JsonMap _holder({
  required String id,
  required String name,
  required String roleCode,
  String scope = 'congregation',
  String? congregationId,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'normalizedName': name.toLowerCase(),
  'scope': scope,
  'roleCode': roleCode,
  'congregationId': congregationId,
  'phoneE164': null,
};

void main() {
  late FakeTeamGateway gateway;
  late TeamRepository repository;

  setUp(() {
    gateway = FakeTeamGateway();
    repository = TeamRepository(gateway: gateway);
    final List<JsonMap> holders = <JsonMap>[
      _holder(
        id: 'c1-holder',
        name: 'Ana C1',
        roleCode: 'congregationAssistant',
        congregationId: 'c1',
      ),
      _holder(
        id: 'c2-holder',
        name: 'Bruno C2',
        roleCode: 'congregationAssistant',
        congregationId: 'c2',
      ),
      _holder(
        id: 'sup-holder',
        name: 'Carla Sup',
        roleCode: 'campaignSupervisor',
        scope: 'supervision',
      ),
    ];
    // Emulates the server-side equality filtering so a client-side post-filter
    // over an unscoped page cannot pass the test.
    gateway.onQuery = (QueryRequest request) {
      final Map<String, Object?> filters =
          request.equalityFilters ?? <String, Object?>{};
      return PageResult(
        items: holders
            .where((JsonMap holder) {
              return (filters['scope'] == null ||
                      holder['scope'] == filters['scope']) &&
                  (filters['roleCode'] == null ||
                      holder['roleCode'] == filters['roleCode']) &&
                  (filters['congregationId'] == null ||
                      holder['congregationId'] == filters['congregationId']);
            })
            .toList(growable: false),
      );
    };
  });

  test('a congregation lookup carries the congregation filter', () async {
    final DirectoryEntry? holder = await repository.findAdministrativeHolder(
      scope: ContactScope.congregation,
      congregationId: 'c1',
      roleCode: RoleCode.congregationAssistant,
    );

    expect(holder?.id, 'c1-holder');
    expect(
      gateway.queries.last.equalityFilters,
      containsPair('scope', 'congregation'),
    );
    expect(
      gateway.queries.last.equalityFilters,
      containsPair('roleCode', 'congregationAssistant'),
    );
    expect(
      gateway.queries.last.equalityFilters,
      containsPair('congregationId', 'c1'),
    );
  });

  test('two congregations holding the same role stay isolated', () async {
    final DirectoryEntry? c1 = await repository.findAdministrativeHolder(
      scope: ContactScope.congregation,
      congregationId: 'c1',
      roleCode: RoleCode.congregationAssistant,
    );
    final DirectoryEntry? c2 = await repository.findAdministrativeHolder(
      scope: ContactScope.congregation,
      congregationId: 'c2',
      roleCode: RoleCode.congregationAssistant,
    );

    expect(c1?.id, 'c1-holder');
    expect(c2?.id, 'c2-holder');
    expect(c1?.id, isNot(c2?.id));
  });

  test('a congregation with no holder returns null', () async {
    final DirectoryEntry? holder = await repository.findAdministrativeHolder(
      scope: ContactScope.congregation,
      congregationId: 'c3',
      roleCode: RoleCode.congregationAssistant,
    );

    expect(holder, isNull);
  });

  test('a supervision lookup carries no congregation filter', () async {
    final DirectoryEntry? holder = await repository.findAdministrativeHolder(
      scope: ContactScope.supervision,
      roleCode: RoleCode.campaignSupervisor,
    );

    expect(holder?.id, 'sup-holder');
    final Map<String, Object?>? filters = gateway.queries.last.equalityFilters;
    expect(filters, containsPair('scope', 'supervision'));
    expect(filters!.containsKey('congregationId'), isFalse);
  });
}
