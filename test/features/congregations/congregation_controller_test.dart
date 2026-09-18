import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/congregation.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/congregations/congregation_controller.dart';
import 'package:discipulado_ieadpe/features/congregations/congregation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../team/team_test_support.dart';

JsonMap congregationJson({
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

Congregation congregation({String name = 'Central'}) => Congregation(
  metadata: CommonMetadata(
    id: 'c1',
    revision: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    updatedBy: 'u1',
  ),
  name: name,
  normalizedName: name.toLowerCase(),
  active: true,
);

void main() {
  late FakeTeamGateway gateway;
  late CongregationController controller;

  CongregationController buildController({
    AccessRole role = AccessRole.supervisor,
  }) => CongregationController(
    repository: CongregationRepository(gateway: gateway),
    profile: testProfile(role: role),
  );

  setUp(() {
    gateway = FakeTeamGateway();
  });

  tearDown(() => controller.dispose());

  test('refresh loads active and archived congregations separately', () async {
    gateway.onQuery = (QueryRequest request) => PageResult(
      items: <JsonMap>[
        congregationJson(
          id: request.equalityFilters?['active'] == true ? 'c1' : 'c2',
          name: request.equalityFilters?['active'] == true
              ? 'Central'
              : 'Antiga',
          active: request.equalityFilters?['active'] == true,
        ),
      ],
    );
    controller = buildController();

    await controller.refresh();

    expect(controller.activeState.data!.single.name, 'Central');
    expect(controller.archivedState.data!.single.name, 'Antiga');
  });

  test('a blocked archive renders an actionable explanation', () async {
    gateway.onQuery = (_) => PageResult(
      items: <JsonMap>[congregationJson(id: 'c1', name: 'Central')],
    );
    gateway.onInvoke = (String operation, JsonMap payload) {
      throw const AppFailure(
        code: AppFailureCode.conflict,
        message: 'A congregação possui vínculos ativos.',
      );
    };
    controller = buildController();
    await controller.refresh();

    await controller.archive(controller.activeState.data!.single);

    expect(controller.lastFailure?.code, AppFailureCode.conflict);
    expect(controller.archiveExplanation, isNotNull);
    expect(controller.archiveExplanation, contains('vínculos'));
  });

  test('a staff backend denial maps to a safe error', () async {
    gateway.onInvoke = (String operation, JsonMap payload) {
      throw const AppFailure(
        code: AppFailureCode.forbidden,
        message: 'Acesso não autorizado',
      );
    };
    controller = buildController(role: AccessRole.congregationStaff);

    await controller.archive(congregation());

    expect(controller.lastFailure?.code, AppFailureCode.forbidden);
    expect(controller.lastFailure?.message, 'Acesso não autorizado');
    expect(controller.archiveExplanation, isNull);
  });

  test('staff cannot be a supervisor', () {
    controller = buildController(role: AccessRole.congregationStaff);
    expect(controller.isSupervisor, isFalse);
  });
}
