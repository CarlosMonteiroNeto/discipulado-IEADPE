import 'package:discipulado_ieadpe/domain/access.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/congregations/congregation_controller.dart';
import 'package:discipulado_ieadpe/features/congregations/congregation_repository.dart';
import 'package:discipulado_ieadpe/features/congregations/congregations_page.dart';
import 'package:discipulado_ieadpe/ui/confirmation_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import '../team/team_test_support.dart';

JsonMap _congregationJson({
  String id = 'c1',
  String name = 'Central',
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

CongregationController _controller(
  FakeTeamGateway gateway, {
  AccessRole role = AccessRole.supervisor,
}) => CongregationController(
  repository: CongregationRepository(gateway: gateway),
  profile: testProfile(role: role),
);

void main() {
  testWidgets('staff sees no write controls', (WidgetTester tester) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onQuery = (QueryRequest request) =>
        request.equalityFilters?['active'] == true
        ? PageResult(items: <JsonMap>[_congregationJson()])
        : const PageResult(items: <JsonMap>[]);
    final CongregationController controller = _controller(
      gateway,
      role: AccessRole.congregationStaff,
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, CongregationsPage(controller: controller));

    expect(find.text('Central'), findsOneWidget);
    expect(find.byKey(CongregationsPage.createKey), findsNothing);
    expect(find.byKey(CongregationsPage.renameKey('c1')), findsNothing);
    expect(find.byKey(CongregationsPage.archiveKey('c1')), findsNothing);
  });

  testWidgets('a supervisor receives the lifecycle controls', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onQuery = (QueryRequest request) =>
        request.equalityFilters?['active'] == true
        ? PageResult(items: <JsonMap>[_congregationJson()])
        : const PageResult(items: <JsonMap>[]);
    final CongregationController controller = _controller(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, CongregationsPage(controller: controller));

    expect(find.byKey(CongregationsPage.createKey), findsOneWidget);
    expect(find.byKey(CongregationsPage.archiveKey('c1')), findsOneWidget);
  });

  testWidgets('a blocked archive renders an actionable explanation', (
    WidgetTester tester,
  ) async {
    final FakeTeamGateway gateway = FakeTeamGateway();
    gateway.onQuery = (_) => PageResult(items: <JsonMap>[_congregationJson()]);
    gateway.onInvoke = (String operation, JsonMap payload) {
      throw const AppFailure(
        code: AppFailureCode.conflict,
        message: 'A congregação possui vínculos ativos.',
      );
    };
    final CongregationController controller = _controller(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, CongregationsPage(controller: controller));
    await tester.tap(find.byKey(CongregationsPage.archiveKey('c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmationDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(CongregationsPage.explanationKey), findsOneWidget);
    expect(find.textContaining('vínculos'), findsOneWidget);
  });
}
