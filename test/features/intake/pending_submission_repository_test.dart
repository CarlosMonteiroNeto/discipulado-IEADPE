import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/intake/pending_submission_repository.dart';
import 'package:ieadpe_converts/routing/router.dart';

import '../../data/repositories_test.dart' as fixture;

const _submission = '10000000-0000-0000-0000-000000000001';
const _congregation = '20000000-0000-0000-0000-000000000002';
const _operation = '30000000-0000-0000-0000-000000000003';

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

Map<String, dynamic> _summary({Map<String, Object?> extra = const {}}) => {
  'id': _submission,
  'congregation_id': _congregation,
  'congregation_name': 'Central',
  'submitted_at': '2026-10-20T10:00:00Z',
  'expires_at': '2026-11-19T10:00:00Z',
  'name': 'Maria de Exemplo',
  'revision': 1,
  ...extra,
};

class _Gateway implements PendingReviewGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  final reads = <({String rpc, Map<String, Object?> parameters})>[];
  final reviews = <({String operationId, Map<String, Object?> payload})>[];
  Map<String, dynamic> Function(String, Map<String, Object?>)? respondRead;
  Map<String, dynamic> Function(String, Map<String, Object?>)? respondReview;
  String? failure;

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
    return respondRead?.call(rpc, parameters) ??
        {'items': <Object>[], 'next_cursor': null};
  }

  @override
  Future<Map<String, dynamic>> reviewPendingIntake(
    String operationId,
    Map<String, Object?> payload,
  ) async {
    ensureCurrent(context);
    reviews.add((operationId: operationId, payload: Map.of(payload)));
    if (failure != null) throw DataFailure(failure!);
    return respondReview?.call(operationId, payload) ??
        {
          'id': _submission,
          'status': 'approved',
          'official_convert_id': _congregation,
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

void main() {
  test('pending route is scoped to campaign reviewers and global managers', () {
    final campaignReviewer = AccessScope(congregationIds: [_congregation]);
    final globalManager = AccessScope(isAdmin: true);
    final ministryOnly = AccessScope(
      isMinistrySupervision: true,
      ministryCongregationIds: [_congregation],
    );

    expect(routesFor(campaignReviewer), contains('/pending'));
    expect(routesFor(globalManager), contains('/pending'));
    expect(routesFor(ministryOnly), isNot(contains('/pending')));
  });

  test('pending is a known route for authorization checks', () {
    expect(safeRoute('/pending'), '/pending');
  });

  test('list uses the exact server scope, opaque cursor and fixed page size 50', () async {
    final gateway = _Gateway()
      ..respondRead = (_, __) => {
        'items': [
          for (var i = 1; i <= 50; i++)
            _summary(
              extra: {
                'id':
                    '10000000-0000-0000-0000-${i.toString().padLeft(12, '0')}',
              },
            ),
        ],
        'next_cursor': 'opaque_cursor_2',
      };

    final page = await PendingSubmissionRepository(gateway)
        .list(congregationId: _congregation, cursor: 'opaque_cursor_1');

    expect(gateway.reads.single.rpc, 'list_pending_intake');
    expect(gateway.reads.single.parameters, {
      'congregation_id': _congregation,
      'limit': 50,
      'cursor': 'opaque_cursor_1',
    });
    expect(page.items, hasLength(50));
    expect(page.items.first.id, _submission);
    expect(page.nextCursor, 'opaque_cursor_2');
  });

  test(
    'global list sends null scope and rejects private or extra projections',
    () async {
      final gateway = _Gateway()
        ..respondRead = (_, __) => {
          'items': [
            _summary(extra: {'draft': _draft}),
          ],
          'next_cursor': null,
        };

      await expectLater(
        PendingSubmissionRepository(gateway).list(congregationId: null),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
      expect(gateway.reads.single.parameters, {
        'congregation_id': null,
        'limit': 50,
        'cursor': null,
      });
    },
  );

  test(
    'detail preserves only the T5 summary and approved draft projection',
    () async {
      final gateway = _Gateway()
        ..respondRead = (_, __) => {..._summary(), 'draft': _draft};

      final detail = await PendingSubmissionRepository(gateway)
          .get(_submission);

      expect(gateway.reads.single.rpc, 'get_pending_intake');
      expect(gateway.reads.single.parameters, {'id': _submission});
      expect(detail.summary.name, 'Maria de Exemplo');
      expect(detail.summary.expiresAt, DateTime.utc(2026, 11, 19, 10));
      expect(detail.draft['congregation_id'], _congregation);
      expect(detail.draft['person'], _draft['person']);
      expect(detail.draft['convert'], _draft['convert']);
    },
  );

  test(
    'review sends the stable key, expected revision and unchanged congregation',
    () async {
      final gateway = _Gateway();
      final repository = PendingSubmissionRepository(gateway);

      final result = await repository.review(
        operationId: _operation,
        id: _submission,
        expectedRevision: 4,
        decision: PendingReviewDecision.approve,
        draft: _draft,
      );

      expect(gateway.reviews.single.operationId, _operation);
      expect(gateway.reviews.single.payload, {
        'id': _submission,
        'expected_revision': 4,
        'decision': 'approve',
        'draft': _draft,
      });
      expect(result.status, 'approved');
    },
  );

  test(
    'rejection omits draft and unknown transport outcome is explicit',
    () async {
      final gateway = _Gateway()..failure = 'unavailable';
      final repository = PendingSubmissionRepository(gateway);

      await expectLater(
        repository.review(
          operationId: _operation,
          id: _submission,
          expectedRevision: 1,
          decision: PendingReviewDecision.reject,
        ),
        throwsA(
          isA<PendingReviewFailure>().having(
            (error) => error.outcomeUnknown,
            'outcomeUnknown',
            isTrue,
          ),
        ),
      );
      expect(gateway.reviews.single.payload, {
        'id': _submission,
        'expected_revision': 1,
        'decision': 'reject',
      });
    },
  );

  test(
    'Supabase review reads use exact T5 RPC names and request envelopes',
    () async {
      var requests = 0;
      final gateway = await fixture.fixture((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_list_pending_intake');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'request': {
            'congregation_id': _congregation,
            'limit': 50,
            'cursor': null,
          },
        });
        await fixture.respond(request, {'items': [], 'next_cursor': null});
      });

      expect(
        await gateway.readRpc(
          'list_pending_intake',
          context: gateway.context,
          parameters: {
            'congregation_id': _congregation,
            'limit': 50,
            'cursor': null,
          },
        ),
        {'items': [], 'next_cursor': null},
      );
      await expectLater(
        gateway.readRpc(
          'list_pending_intake',
          context: gateway.context,
          parameters: {
            'congregation_id': _congregation,
            'limit': 50,
            'cursor': null,
            'private_table': 'public_intake_submissions',
          },
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'Supabase review command preserves operation ID and exact payload',
    () async {
      final gateway = await fixture.fixture((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/rest/v1/rpc/ieadpe_review_pending_intake');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'operation_id': fixture.operationId,
          'payload': {
            'id': fixture.id(1),
            'expected_revision': 4,
            'decision': 'approve',
            'draft': _draft,
          },
        });
        await fixture.respond(request, {
          'id': fixture.id(1),
          'status': 'approved',
          'official_convert_id': fixture.id(2),
        });
      });

      expect(
        await gateway.reviewPendingIntake(fixture.operationId, {
          'id': fixture.id(1),
          'expected_revision': 4,
          'decision': 'approve',
          'draft': _draft,
        }),
        {
          'id': fixture.id(1),
          'status': 'approved',
          'official_convert_id': fixture.id(2),
        },
      );
    },
  );
}
