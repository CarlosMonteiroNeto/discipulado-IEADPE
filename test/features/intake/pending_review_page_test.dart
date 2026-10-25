import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/intake/pending_review_page.dart';
import 'package:ieadpe_converts/features/intake/pending_submission_repository.dart';
import 'package:ieadpe_converts/routing/router.dart';
import 'package:ieadpe_converts/widgets/app_shell.dart';

import '../auth/auth_flow_test.dart' show FakeAuth;

const _submission = '10000000-0000-0000-0000-000000000001';
const _congregation = '20000000-0000-0000-0000-000000000002';
const _otherCongregation = '30000000-0000-0000-0000-000000000003';

final _draft = <String, Object?>{
  'congregation_id': _congregation,
  'person': {
    'name': 'Maria de Exemplo',
    'phone': null,
    'birth_date': null,
    'address': {
      'street': null,
      'district': null,
      'city': null,
      'postal_code': null,
      'state_code': null,
    },
  },
  'convert': {
    'landmark': 'Praça Central',
    'gender': 'female',
    'conversion_date': '2026-10-20',
    'worship_type': 'Culto de domingo',
    'age': null,
  },
};

Map<String, dynamic> _summary({String id = _submission}) => {
  'id': id,
  'congregation_id': _congregation,
  'congregation_name': 'Central',
  'submitted_at': '2026-10-20T10:00:00Z',
  'expires_at': '2026-11-19T10:00:00Z',
  'name': 'Maria de Exemplo',
  'revision': 7,
};

class _Gateway implements PendingReviewGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  final reads = <({String rpc, Map<String, Object?> parameters})>[];
  final reviews = <({String operationId, Map<String, Object?> payload})>[];
  final listItems = <Map<String, dynamic>>[_summary()];
  Map<String, dynamic>? detail = {..._summary(), 'draft': _draft};
  String? nextCursor;
  String? failure;
  String? reviewFailure;
  int? failReviewCount;
  Completer<Map<String, dynamic>>? pendingReview;
  Completer<Map<String, dynamic>>? pendingList;

  @override
  void ensureCurrent(String token) {
    if (token != context || failure == 'stale') {
      throw const DataFailure('stale');
    }
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    ensureCurrent(context);
    reads.add((rpc: rpc, parameters: Map.of(parameters)));
    if (failure != null) throw DataFailure(failure!);
    if (rpc == 'get_pending_intake') {
      if (detail == null) throw const DataFailure('permission');
      return Map<String, dynamic>.from(detail!);
    }
    if (pendingList != null) return pendingList!.future;
    return {'items': List.of(listItems), 'next_cursor': nextCursor};
  }

  @override
  Future<Map<String, dynamic>> reviewPendingIntake(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    reviews.add((operationId: operationId, payload: Map.of(payload)));
    final pending = pendingReview;
    if (pending != null) return pending.future;
    if (failReviewCount != null && failReviewCount! > 0) {
      failReviewCount = failReviewCount! - 1;
      final error = reviewFailure ?? failure ?? 'unavailable';
      if (failReviewCount == 0) reviewFailure = null;
      throw DataFailure(error);
    }
    if (reviewFailure != null) throw DataFailure(reviewFailure!);
    if (failure != null) throw DataFailure(failure!);
    listItems.removeWhere((item) => item['id'] == payload['id']);
    return {
      'id': payload['id'],
      'status': payload['decision'] == 'reject' ? 'rejected' : 'approved',
      'official_convert_id': payload['decision'] == 'reject'
          ? null
          : _otherCongregation,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => [];

  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

Future<void> _showPage(
  WidgetTester tester, {
  required _Gateway gateway,
  required AccessScope scope,
  List<Congregation>? congregations,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PendingReviewPage(
        key: UniqueKey(),
        repository: PendingSubmissionRepository(gateway),
        scope: scope,
        congregations:
            congregations ??
            const [
              Congregation(id: _congregation, name: 'Central'),
              Congregation(id: _otherCongregation, name: 'Norte'),
            ],
        now: () => DateTime.utc(2026, 10, 25, 10),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only review-authorized scope receives Pendentes navigation', (
    t,
  ) async {
    final opened = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          scope: AccessScope(congregationIds: [_congregation]),
          onNavigate: opened.add,
          onSignOut: () {},
          child: const Text('Conteúdo'),
        ),
      ),
    );
    expect(find.text('Pendentes'), findsOneWidget);
    await t.tap(find.text('Pendentes'));
    expect(opened, ['/pending']);

    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          scope: AccessScope(ministryCongregationIds: [_congregation]),
          onNavigate: opened.add,
          onSignOut: () {},
          child: const Text('Conteúdo'),
        ),
      ),
    );
    expect(find.text('Pendentes'), findsNothing);
  });

  testWidgets(
    'forged direct route resolves to register without review authority',
    (t) async {
      final auth = FakeAuth()..access = AccessScope();
      final router = SessionRouter(
        auth,
        clearProtectedCaches: () {},
        intendedRoute: '/pending',
      );
      await t.pumpAndSettle();
      expect(router.route, '/register');
      router.go('/pending');
      expect(router.route, '/register');
      router.dispose();
      await auth.events.close();
    },
  );

  testWidgets('no-grant and ministry-only users cannot open reviewer UI', (
    t,
  ) async {
    final noGrant = _Gateway();
    await _showPage(t, gateway: noGrant, scope: AccessScope());
    expect(
      find.text('Você não tem acesso às solicitações pendentes.'),
      findsOneWidget,
    );
    expect(noGrant.reads, isEmpty);

    await _showPage(
      t,
      gateway: _Gateway(),
      scope: AccessScope(ministryCongregationIds: [_congregation]),
    );
    expect(
      find.text('Você não tem acesso às solicitações pendentes.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'campaign reviewer is limited to granted congregation and cannot reassign or upload photo',
    (t) async {
      final gateway = _Gateway();
      await _showPage(
        t,
        gateway: gateway,
        scope: AccessScope(congregationIds: [_congregation]),
      );

      expect(gateway.reads.single.parameters['congregation_id'], _congregation);
      expect(find.text('Maria de Exemplo'), findsOneWidget);
      expect(find.textContaining('Expira em 25 dias'), findsOneWidget);
      await t.tap(find.text('Maria de Exemplo'));
      await t.pumpAndSettle();

      final congregationField = t.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('convert-congregation')),
      );
      expect(congregationField.onChanged, isNull);
      expect(find.text('Escolher foto'), findsNothing);
      final approve = find.text('Aprovar cadastro');
      await t.ensureVisible(approve);
      expect(approve, findsOneWidget);
      expect(find.text('Rejeitar'), findsOneWidget);
    },
  );

  testWidgets('global manager can choose all or an active congregation', (
    t,
  ) async {
    final gateway = _Gateway();
    await _showPage(t, gateway: gateway, scope: AccessScope(isAdmin: true));

    expect(gateway.reads.single.parameters['congregation_id'], isNull);
    final selector = find.byKey(const ValueKey('pending-congregation-filter'));
    expect(selector, findsOneWidget);
    await t.tap(selector);
    await t.pumpAndSettle();
    expect(find.text('Todas as congregações'), findsWidgets);
    expect(find.text('Norte'), findsWidgets);
  });

  testWidgets(
    'campaign congregation selector omits ungranted catalog choices',
    (t) async {
      final gateway = _Gateway();
      await _showPage(
        t,
        gateway: gateway,
        scope: AccessScope(
          congregationIds: [_congregation, _otherCongregation],
        ),
        congregations: const [
          Congregation(id: _congregation, name: 'Central'),
          Congregation(id: _otherCongregation, name: 'Norte'),
          Congregation(id: '40000000-0000-0000-0000-000000000004', name: 'Sul'),
        ],
      );
      await t.tap(find.byKey(const ValueKey('pending-congregation-filter')));
      await t.pumpAndSettle();
      expect(find.text('Central'), findsWidgets);
      expect(find.text('Norte'), findsWidgets);
      expect(find.text('Sul'), findsNothing);
    },
  );

  testWidgets('cancel closes detail without changing server pending item', (
    t,
  ) async {
    final gateway = _Gateway();
    await _showPage(
      t,
      gateway: gateway,
      scope: AccessScope(congregationIds: [_congregation]),
    );
    await t.tap(find.text('Maria de Exemplo'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Cancelar'));
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();

    expect(gateway.reviews, isEmpty);
    expect(gateway.listItems, hasLength(1));
    expect(find.text('Maria de Exemplo'), findsOneWidget);
  });

  testWidgets(
    'unknown approval retries exact key, revision and frozen corrected draft',
    (t) async {
      final gateway = _Gateway()
        ..reviewFailure = 'unavailable'
        ..failReviewCount = 1;
      await _showPage(t, gateway: gateway, scope: AccessScope(isAdmin: true));
      await t.tap(find.text('Maria de Exemplo'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('person-name')));
      await t.enterText(
        find.byKey(const ValueKey('person-name')),
        'Maria Corrigida',
      );
      await t.ensureVisible(find.text('Aprovar cadastro'));
      await t.tap(find.text('Aprovar cadastro'));
      await t.pumpAndSettle();

      expect(
        gateway.reviews,
        hasLength(1),
        reason: t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(
        find.textContaining('resultado ainda é desconhecido'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.byKey(const ValueKey('pending-refresh-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('pending-congregation-filter')),
            )
            .onChanged,
        isNull,
      );
      final first = gateway.reviews.single;
      expect(first.payload['expected_revision'], 7);
      expect(
        (first.payload['draft'] as Map)['person']['name'],
        'Maria Corrigida',
      );
      await t.tap(find.text('Tentar novamente'));
      await t.pumpAndSettle();

      expect(gateway.reviews, hasLength(2));
      expect(gateway.reviews.last.operationId, first.operationId);
      expect(gateway.reviews.last.payload, first.payload);
      expect(gateway.listItems, isEmpty);
    },
  );

  testWidgets(
    'definitive review error releases draft for correction and a new operation',
    (t) async {
      final gateway = _Gateway()
        ..reviewFailure = 'invalid'
        ..failReviewCount = 1;
      await _showPage(
        t,
        gateway: gateway,
        scope: AccessScope(congregationIds: [_congregation]),
      );
      await t.tap(find.text('Maria de Exemplo'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Aprovar cadastro'));
      await t.tap(find.text('Aprovar cadastro'));
      await t.pumpAndSettle();
      expect(gateway.reviews, hasLength(1));
      expect(find.byKey(const ValueKey('person-name')), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      await t.ensureVisible(find.byKey(const ValueKey('person-name')));
      await t.enterText(
        find.byKey(const ValueKey('person-name')),
        'Maria Ajustada',
      );
      await t.ensureVisible(find.text('Aprovar cadastro'));
      await t.tap(find.text('Aprovar cadastro'));
      await t.pumpAndSettle();

      expect(gateway.reviews, hasLength(2));
      expect(
        gateway.reviews.last.operationId,
        isNot(gateway.reviews.first.operationId),
      );
      expect(
        (gateway.reviews.last.payload['draft'] as Map)['person']['name'],
        'Maria Ajustada',
      );
    },
  );

  testWidgets(
    'rejection sends no draft and successful decision removes the item',
    (t) async {
      final gateway = _Gateway();
      await _showPage(
        t,
        gateway: gateway,
        scope: AccessScope(congregationIds: [_congregation]),
      );
      await t.tap(find.text('Maria de Exemplo'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Rejeitar'));
      await t.tap(find.text('Rejeitar'));
      await t.pumpAndSettle();

      expect(gateway.reviews.single.payload['decision'], 'reject');
      expect(gateway.reviews.single.payload.containsKey('draft'), isFalse);
      expect(gateway.listItems, isEmpty);
      expect(find.text('Nenhuma solicitação pendente.'), findsOneWidget);
    },
  );

  testWidgets(
    'loading, empty, error, malformed cursor and revoked session clear stale details',
    (t) async {
      final empty = _Gateway()..listItems.clear();
      await _showPage(t, gateway: empty, scope: AccessScope(isAdmin: true));
      expect(find.text('Nenhuma solicitação pendente.'), findsOneWidget);

      final revoked = _Gateway()..failure = 'stale';
      await _showPage(t, gateway: revoked, scope: AccessScope(isAdmin: true));
      expect(find.text('Maria de Exemplo'), findsNothing);
      expect(
        find.text('Não foi possível carregar as solicitações pendentes.'),
        findsOneWidget,
      );

      final staleDetail = _Gateway();
      await _showPage(
        t,
        gateway: staleDetail,
        scope: AccessScope(congregationIds: [_congregation]),
      );
      await t.tap(find.text('Maria de Exemplo'));
      await t.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
      staleDetail.failure = 'stale';
      await t.tap(find.byKey(const ValueKey('pending-refresh-button')));
      await t.pumpAndSettle();
      expect(find.text('Cancelar'), findsNothing);
      expect(find.text('Maria de Exemplo'), findsNothing);

      final malformedCursor = _Gateway();
      await _showPage(
        t,
        gateway: malformedCursor,
        scope: AccessScope(congregationIds: [_congregation]),
      );
      expect(malformedCursor.reads, hasLength(1));
      await t.tap(find.text('Maria de Exemplo'));
      await t.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
      malformedCursor.nextCursor = 'not*an*opaque*cursor';
      await t.tap(find.byKey(const ValueKey('pending-refresh-button')));
      await t.pumpAndSettle();
      expect(find.text('Cancelar'), findsNothing);
      expect(find.text('Maria de Exemplo'), findsNothing);
      expect(
        find.text('Não foi possível carregar as solicitações pendentes.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'queue shows loading feedback before the first protected response',
    (t) async {
      final gateway = _Gateway()
        ..pendingList = Completer<Map<String, dynamic>>();
      await t.pumpWidget(
        MaterialApp(
          home: PendingReviewPage(
            repository: PendingSubmissionRepository(gateway),
            scope: AccessScope(isAdmin: true),
            congregations: const [
              Congregation(id: _congregation, name: 'Central'),
            ],
            now: () => DateTime.utc(2026, 10, 25, 10),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gateway.pendingList!.complete({'items': <Object>[], 'next_cursor': null});
      gateway.pendingList = null;
      await t.pumpAndSettle();
      expect(find.text('Nenhuma solicitação pendente.'), findsOneWidget);
    },
  );

  testWidgets('duplicate approval clicks cannot dispatch a second operation', (
    t,
  ) async {
    final gateway = _Gateway()
      ..pendingReview = Completer<Map<String, dynamic>>();
    await _showPage(
      t,
      gateway: gateway,
      scope: AccessScope(congregationIds: [_congregation]),
    );
    await t.tap(find.text('Maria de Exemplo'));
    await t.pumpAndSettle();
    final approve = find.byType(FilledButton);
    await t.ensureVisible(approve);
    await t.tap(approve);
    await t.pump();
    expect(t.widget<FilledButton>(approve).onPressed, isNull);
    expect(gateway.reviews, hasLength(1));
    gateway.pendingReview!.complete({
      'id': _submission,
      'status': 'approved',
      'official_convert_id': _otherCongregation,
    });
    await t.pumpAndSettle();
    expect(gateway.reviews, hasLength(1));
  });
}
