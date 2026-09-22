import 'package:discipulado_ieadpe/domain/class_group.dart';
import 'package:discipulado_ieadpe/domain/common.dart';
import 'package:discipulado_ieadpe/domain/ports.dart';
import 'package:discipulado_ieadpe/features/overview/overview_controller.dart';
import 'package:discipulado_ieadpe/features/overview/overview_page.dart';
import 'package:discipulado_ieadpe/features/overview/overview_repository.dart';
import 'package:discipulado_ieadpe/ui/async_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui/ui_test_support.dart';
import 'overview_test_support.dart';

bool _hasFocus(WidgetTester tester, Key key) {
  final Finder finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    return false;
  }
  final Element target = finder.evaluate().first;
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) {
    return false;
  }
  bool found = false;
  focused.visitAncestorElements((Element ancestor) {
    if (ancestor == target) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> _tabUntilFocused(WidgetTester tester, Key key) async {
  for (int attempt = 0; attempt < 10; attempt++) {
    if (_hasFocus(tester, key)) {
      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('could not focus $key by keyboard');
}

OverviewController _controller(
  FakeOverviewGateway gateway, {
  bool supervisor = false,
  OverviewQuery? initialQuery,
}) => OverviewController(
  repository: OverviewRepository(gateway: gateway),
  profile: supervisor ? supervisorProfile() : staffProfile(),
  initialQuery: initialQuery,
);

void main() {
  testWidgets('renders authoritative counts with clear labels', (
    WidgetTester tester,
  ) async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async =>
          overviewJson(students: 2, classes: 1, openSessions: 3);
    final OverviewController controller = _controller(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, OverviewPage(controller: controller));

    expect(find.text('Alunos não arquivados'), findsOneWidget);
    expect(find.text('Turmas ativas'), findsOneWidget);
    expect(find.text('Chamadas em aberto'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(OverviewPage.countsStudentsKey),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(OverviewPage.countsClassesKey),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(OverviewPage.countsOpenSessionsKey),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('links carry the current scope and the active class filter', (
    WidgetTester tester,
  ) async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController controller = _controller(
      gateway,
      supervisor: true,
    );
    addTearDown(controller.dispose);
    String? studentsScope;
    ClassesLinkTarget? classesTarget;

    await pumpApp(
      tester,
      OverviewPage(
        controller: controller,
        onOpenStudents: (String? scope) => studentsScope = scope,
        onOpenClasses: (ClassesLinkTarget target) => classesTarget = target,
      ),
    );
    await controller.setCongregation('c2');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(OverviewPage.openStudentsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OverviewPage.openClassesKey));
    await tester.pumpAndSettle();

    expect(studentsScope, 'c2');
    expect(classesTarget?.congregationId, 'c2');
    expect(classesTarget?.status, ClassStatus.active);
  });

  testWidgets(
    'a failed endpoint shows retry and never fabricates zero counts',
    (WidgetTester tester) async {
      int attempts = 0;
      final FakeOverviewGateway gateway = FakeOverviewGateway()
        ..onInvoke = (_, _) async {
          attempts += 1;
          throw const AppFailure(
            code: AppFailureCode.unavailable,
            message: 'Não foi possível carregar a visão geral.',
          );
        };
      final OverviewController controller = _controller(gateway);
      addTearDown(controller.dispose);

      await pumpApp(tester, OverviewPage(controller: controller));

      expect(find.byKey(AsyncContent.errorKey), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.text('Alunos não arquivados'), findsNothing);

      await tester.tap(find.byKey(AsyncContent.retryKey));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );

  testWidgets('count links are reachable and activatable by keyboard', (
    WidgetTester tester,
  ) async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController controller = _controller(gateway);
    addTearDown(controller.dispose);
    String? opened;

    await pumpApp(
      tester,
      OverviewPage(
        controller: controller,
        onOpenStudents: (String? scope) => opened = scope,
      ),
    );

    await _tabUntilFocused(tester, OverviewPage.openStudentsKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(opened, 'c1');
  });

  testWidgets(
    'the open-session count reveals pending calls that link to the session',
    (WidgetTester tester) async {
      final FakeOverviewGateway gateway = FakeOverviewGateway()
        ..onInvoke = (String operation, JsonMap payload) async {
          if (operation == 'getOverview') {
            return overviewJson();
          }
          return <String, Object?>{
            'items': <JsonMap>[
              pendingSessionJson(
                id: 'x1',
                classId: 'k1',
                className: 'Turma Central',
                congregationId: 'c1',
              ),
            ],
            'nextCursor': null,
          };
        };
      final OverviewController controller = _controller(gateway);
      addTearDown(controller.dispose);
      PendingSessionEntry? opened;

      await pumpApp(
        tester,
        OverviewPage(
          controller: controller,
          onOpenSession: (PendingSessionEntry entry) => opened = entry,
        ),
      );

      await tester.tap(find.byKey(OverviewPage.openPendingKey));
      await tester.pumpAndSettle();

      expect(controller.pendingVisible, isTrue);
      expect(find.text('Chamadas pendentes'), findsWidgets);
      expect(find.text('Turma Central'), findsOneWidget);
      // The row renders the shared pt-BR date, never the raw ISO value.
      expect(find.textContaining('17/09/2026'), findsOneWidget);
      expect(find.textContaining('2026-09-17'), findsNothing);

      await tester.tap(find.byKey(const Key('overview-pending-open-x1')));
      await tester.pumpAndSettle();

      expect(opened?.id, 'x1');
      expect(opened?.classId, 'k1');
      expect(opened?.congregationId, 'c1');
    },
  );

  testWidgets('staff see no congregation selector', (
    WidgetTester tester,
  ) async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController staff = _controller(gateway);
    addTearDown(staff.dispose);

    await pumpApp(tester, OverviewPage(controller: staff));
    expect(find.byKey(OverviewPage.congregationFilterKey), findsNothing);
  });

  testWidgets('supervisors can select one congregation or Todas', (
    WidgetTester tester,
  ) async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (_, _) async => overviewJson();
    final OverviewController supervisor = _controller(
      gateway,
      supervisor: true,
    );
    addTearDown(supervisor.dispose);

    await pumpApp(tester, OverviewPage(controller: supervisor));
    expect(find.byKey(OverviewPage.congregationFilterKey), findsOneWidget);
    expect(find.text('Todas'), findsWidgets);
  });

  testWidgets('the pendentes route state drives the pending section', (
    WidgetTester tester,
  ) async {
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (String operation, JsonMap payload) async {
        if (operation == 'getOverview') {
          return overviewJson();
        }
        return <String, Object?>{
          'items': <JsonMap>[pendingSessionJson(id: 'x1')],
          'nextCursor': null,
        };
      };
    final OverviewController controller = _controller(
      gateway,
      initialQuery: OverviewQuery.fromQueryParameters(<String, String>{
        'pendentes': 'true',
      }),
    );
    addTearDown(controller.dispose);

    await pumpApp(tester, OverviewPage(controller: controller));

    expect(controller.pendingVisible, isTrue);
    expect(find.text('Chamadas pendentes'), findsWidgets);
    expect(find.text('Turma Central'), findsOneWidget);
  });

  testWidgets('page entry and Atualizar invalidate the counts', (
    WidgetTester tester,
  ) async {
    int overviewCalls = 0;
    final FakeOverviewGateway gateway = FakeOverviewGateway()
      ..onInvoke = (String operation, JsonMap payload) async {
        if (operation == 'getOverview') {
          overviewCalls += 1;
          return overviewJson();
        }
        return <String, Object?>{'items': <JsonMap>[], 'nextCursor': null};
      };
    final OverviewController controller = _controller(gateway);
    addTearDown(controller.dispose);

    await pumpApp(tester, OverviewPage(controller: controller));
    expect(overviewCalls, 1);

    await tester.tap(find.byKey(OverviewPage.refreshKey));
    await tester.pumpAndSettle();
    expect(overviewCalls, 2);
  });

  testWidgets(
    'the supervisor toolbar reflows at 360 with 200% text without overflow',
    (WidgetTester tester) async {
      final FakeOverviewGateway gateway = FakeOverviewGateway()
        ..onInvoke = (_, _) async => overviewJson();
      final OverviewController controller = _controller(
        gateway,
        supervisor: true,
      );
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        OverviewPage(controller: controller),
        width: 360,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(OverviewPage.congregationFilterKey), findsOneWidget);
      expect(find.byKey(OverviewPage.refreshKey), findsOneWidget);
    },
  );
}
