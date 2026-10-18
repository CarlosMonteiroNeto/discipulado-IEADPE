import 'dart:async';

import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart' as domain;
import 'package:ieadpe_converts/features/feedback/feedback_manager.dart';
import 'package:flutter/material.dart';
import 'package:ieadpe_converts/features/feedback/feedback_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/features/feedback/feedback_repository.dart';

import '../admin/admin_gateway.dart';

Map<String, dynamic> row(int n) => {
  'id': '17000000-0000-0000-0000-${n.toString().padLeft(12, '0')}',
  'message': 'Mensagem $n',
  'status': 'pending',
  'user_email': 'synthetic@example.test',
};

class FeedbackGateway extends AdminGateway {
  final rows = <Map<String, dynamic>>[];
  int reads = 0;
  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async {
    ensureCurrent(context);
    reads++;
    if (pendingRead != null) return pendingRead!.future;
    return rows
        .where(
          (r) => afterId == null || (r['id'] as String).compareTo(afterId) > 0,
        )
        .take(100)
        .toList();
  }
}

Widget surface(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: Scaffold(body: child),
  ),
);
void main() {
  test('all pages are read without truncating at 100 or 1000', () async {
    final gateway = FeedbackGateway()
      ..rows.addAll(List.generate(1001, (i) => row(i + 1)));
    final rows = await FeedbackRepository(gateway).list();
    expect(rows.length, 1001);
    expect(gateway.reads, 11);
    expect(rows.last.message, 'Mensagem 1001');
  });
  test('invalid messages never reach command and 5000 Unicode characters are accepted', () async {
    final gateway = AdminGateway();
    final repository = FeedbackRepository(gateway);
    expect((await repository.submit(' ', catalogId)).errorCode, 'invalid');
    expect(
      (await repository.submit('a' * 5001, catalogId)).errorCode,
      'invalid',
    );
    expect(gateway.operations, isEmpty);
    expect(
      (await repository.submit('😀' * 5000, catalogId)).status,
      domain.MutationStatus.applied,
    );
  });
  test('unknown status is rejected rather than silently mapped', () async {
    final gateway = FeedbackGateway()..rows.add({...row(1), 'status': 'other'});
    await expectLater(
      FeedbackRepository(gateway).list(),
      throwsA(isA<DataFailure>()),
    );
  });
  test(
    'late mutation cannot report success after identity invalidation',
    () async {
      final gateway = AdminGateway()
        ..pendingMutation = Completer<domain.MutationResult<String>>();
      final result = FeedbackRepository(gateway).submit('Mensagem', catalogId);
      gateway.boundary.invalidate();
      gateway.pendingMutation!.complete(
        const domain.MutationResult.applied(
          operationId: catalogId,
          value: catalogId,
        ),
      );
      await expectLater(result, throwsA(isA<DataFailure>()));
    },
  );
  testWidgets(
    'uncertain submit blocks overlap and retains exact operation and snapshot',
    (tester) async {
      final gateway = AdminGateway()
        ..pendingMutation = Completer<domain.MutationResult<String>>();
      final repository = FeedbackRepository(gateway);
      await tester.pumpWidget(
        surface(
          FeedbackDialog(
            repository: repository,
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '  Minha mensagem  ');
      await tester.tap(find.text('Enviar'));
      await tester.pump();
      expect(find.text('Enviando…'), findsOneWidget);
      expect(gateway.operations.length, 1);
      gateway.pendingMutation!.complete(
        domain.MutationResult.rejected(
          operationId: gateway.operations.single,
          errorCode: 'unavailable',
        ),
      );
      await tester.pump();
      final operation = gateway.operations.single;
      await tester.pumpWidget(
        surface(
          FeedbackDialog(
            repository: FeedbackRepository(gateway),
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      gateway.pendingMutation = null;
      gateway.failure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(gateway.operations, [operation, operation]);
      expect(gateway.payloads, [
        {'message': 'Minha mensagem'},
        {'message': 'Minha mensagem'},
      ]);
      expect(find.textContaining('Mensagem enviada'), findsOneWidget);
    },
  );
  testWidgets('permission denial removes previously displayed manager rows', (
    tester,
  ) async {
    final gateway = FeedbackGateway()..rows.add(row(1));
    await tester.pumpWidget(
      surface(
        FeedbackManager(
          repository: FeedbackRepository(gateway),
          onClose: () {},
          onScopeRefresh: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mensagem 1'), findsOneWidget);
    gateway.failure = 'permission';
    await tester.tap(find.text('Resolver'));
    await tester.pump();
    expect(find.text('Mensagem 1'), findsNothing);
    expect(find.textContaining('Seu acesso mudou'), findsOneWidget);
  });
  testWidgets(
    'inline form supports 360px and 200 percent text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        surface(
          FeedbackDialog(
            repository: FeedbackRepository(AdminGateway()),
            onClose: () {},
            onScopeRefresh: () async {},
          ),
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manager retry survives refresh and keeps its original status operation',
    (tester) async {
      final gateway = FeedbackGateway()..rows.add(row(1));
      final repository = FeedbackRepository(gateway);
      await tester.pumpWidget(
        surface(
          FeedbackManager(
            repository: repository,
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pump();
      gateway.failure = 'unavailable';
      await tester.tap(find.text('Resolver'));
      await tester.pump();
      final operation = gateway.operations.single;
      await tester.tap(find.text('Atualizar'));
      await tester.pump();
      await tester.pumpWidget(
        surface(
          FeedbackManager(
            repository: FeedbackRepository(gateway),
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      gateway.failure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump();
      expect(gateway.operations, [operation, operation]);
      expect(gateway.payloads, [
        {'id': row(1)['id'], 'status': 'resolved'},
        {'id': row(1)['id'], 'status': 'resolved'},
      ]);
    },
  );
  testWidgets(
    'protected rebuild clears input and unmount prevents detached route leaks',
    (tester) async {
      final gateway = AdminGateway();
      final repository = FeedbackRepository(gateway);
      await tester.pumpWidget(
        surface(
          FeedbackDialog(
            repository: repository,
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Private draft');
      gateway.boundary.invalidate();
      await tester.pumpWidget(
        surface(
          FeedbackDialog(
            repository: repository,
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      expect(find.text('Private draft'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Other draft');
      await tester.pumpWidget(surface(const Text('Entrar')));
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Other draft'), findsNothing);
    },
  );
  testWidgets(
    'manager protected rebuild removes old rows during replacement load',
    (tester) async {
      final gateway = FeedbackGateway()..rows.add(row(1));
      final repository = FeedbackRepository(gateway);
      await tester.pumpWidget(
        surface(
          FeedbackManager(
            repository: repository,
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mensagem 1'), findsOneWidget);
      gateway.boundary.invalidate();
      gateway.pendingRead = Completer<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        surface(
          FeedbackManager(
            repository: repository,
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      );
      expect(find.text('Mensagem 1'), findsNothing);
      await tester.pumpWidget(surface(const Text('Entrar')));
      gateway.pendingRead!.complete([row(2)]);
      await tester.pump();
      expect(find.text('Mensagem 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('scope refresh is an explicit recovery action', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      surface(
        FeedbackDialog(
          repository: FeedbackRepository(AdminGateway()),
          onClose: () {},
          onScopeRefresh: () async {
            refreshes++;
          },
        ),
      ),
    );
    await tester.tap(find.text('Atualizar acesso'));
    await tester.pump();
    expect(refreshes, 1);
  });
  testWidgets('inline submission sends feedback and announces success', (
    tester,
  ) async {
    final gateway = AdminGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackDialog(
            repository: FeedbackRepository(gateway),
            onClose: () {},
            onScopeRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sugestão');
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    expect(
      find.text('Mensagem enviada! Obrigado pelo feedback.'),
      findsOneWidget,
    );
  });

  test('submission trims message and uses minimal payload', () async {
    final gateway = AdminGateway();
    await FeedbackRepository(gateway).submit('  Minha sugestão  ', catalogId);
    expect(gateway.commands, ['submit_feedback']);
    expect(gateway.payloads.single, {'message': 'Minha sugestão'});
  });
}
