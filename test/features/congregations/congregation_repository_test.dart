import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/congregation.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/congregations/congregation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../team/team_test_support.dart';

Map<String, Object?> congregationJson({
  required String id,
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
  late FakeTeamGateway gateway;
  late CongregationRepository repository;

  setUp(() {
    gateway = FakeTeamGateway();
    repository = CongregationRepository(
      gateway: gateway,
      recordIdFactory: () => 'new-congregation',
      requestIdFactory: () => 'request-1',
    );
  });

  test(
    'lists congregations by active flag with stable name ordering',
    () async {
      gateway.onQuery = (_) => PageResult(
        items: <JsonMap>[congregationJson(id: 'c1', name: 'Central')],
      );

      final List<Congregation> congregations = await repository
          .listCongregations(active: true);

      expect(congregations.single.name, 'Central');
      final QueryRequest request = gateway.queries.single;
      expect(request.resource, QueryResource.congregations);
      expect(request.equalityFilters, <String, Object?>{'active': true});
    },
  );

  test('saveCongregation create uses a fresh ID and no revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'new-congregation',
      'revision': 1,
    };

    await repository.saveCongregation(name: 'Nova Congregação');

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'saveCongregation');
    expect(call.payload['id'], 'new-congregation');
    expect(call.payload.containsKey('expectedRevision'), isFalse);
    expect(call.payload['requestId'], 'request-1');
  });

  test('saveCongregation rename preserves the stable ID', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'c1',
      'revision': 2,
    };

    await repository.saveCongregation(
      name: 'Renomeada',
      id: 'c1',
      expectedRevision: 1,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.payload['id'], 'c1');
    expect(call.payload['expectedRevision'], 1);
  });

  test('setCongregationArchived sends the flag and revision', () async {
    gateway.onInvoke = (_, _) => const <String, Object?>{
      'id': 'c1',
      'revision': 3,
    };

    await repository.setCongregationArchived(
      id: 'c1',
      archived: true,
      expectedRevision: 2,
    );

    final ({String operation, JsonMap payload}) call =
        gateway.invocations.single;
    expect(call.operation, 'setCongregationArchived');
    expect(call.payload['archived'], isTrue);
    expect(call.payload['expectedRevision'], 2);
  });
}
