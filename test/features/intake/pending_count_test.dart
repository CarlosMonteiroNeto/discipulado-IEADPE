import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/intake/pending_count.dart';
import 'package:ieadpe_converts/features/intake/pending_submission_repository.dart';

const _central = '20000000-0000-0000-0000-000000000002';
const _north = '20000000-0000-0000-0000-000000000003';

Map<String, dynamic> _summary(int index, String congregationId) => {
  'id': '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  'congregation_id': congregationId,
  'congregation_name': 'Congregação',
  'submitted_at': '2026-10-20T10:00:00Z',
  'expires_at': '2026-11-19T10:00:00Z',
  'name': 'Pessoa $index',
  'revision': 1,
};

class _Gateway implements PendingReviewGateway {
  @override
  final boundary = ProtectedDataBoundary();
  @override
  String get context => boundary.generation;
  final reads = <Map<String, Object?>>[];
  final pages = <String?, ({int items, bool more})>{};

  @override
  void ensureCurrent(String token) {}

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    expect(rpc, 'list_pending_intake');
    reads.add(Map.of(parameters));
    final congregationId = parameters['congregation_id'] as String?;
    final page = pages[congregationId] ?? (items: 0, more: false);
    return {
      'items': [
        for (var index = 0; index < page.items; index++)
          _summary(index, congregationId ?? _central),
      ],
      'next_cursor': page.more ? 'cursor-token' : null,
    };
  }

  @override
  Future<Map<String, dynamic>> reviewPendingIntake(
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();

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
  test('global manager reads one unscoped queue', () async {
    final gateway = _Gateway()..pages[null] = (items: 2, more: false);
    final count = await PendingCountLoader(
      PendingSubmissionRepository(gateway),
    ).load(global: true, congregationIds: const []);

    expect(gateway.reads, hasLength(1));
    expect(gateway.reads.single['congregation_id'], isNull);
    expect(count.count, 2);
    expect(count.capped, isFalse);
  });

  test('scoped leader sums only the authorized congregations', () async {
    final gateway = _Gateway()
      ..pages[_central] = (items: 2, more: false)
      ..pages[_north] = (items: 1, more: false);
    final count = await PendingCountLoader(
      PendingSubmissionRepository(gateway),
    ).load(global: false, congregationIds: const [_central, _north]);

    expect(
      [for (final read in gateway.reads) read['congregation_id']],
      [_central, _north],
    );
    expect(count.count, 3);
    expect(count.capped, isFalse);
  });

  test('a full page marks the visible count as capped', () async {
    final gateway = _Gateway()..pages[_central] = (items: 50, more: true);
    final count = await PendingCountLoader(
      PendingSubmissionRepository(gateway),
    ).load(global: false, congregationIds: const [_central]);

    expect(count.count, 50);
    expect(count.capped, isTrue);
  });

  test('no authorized congregation reads nothing', () async {
    final gateway = _Gateway();
    final count = await PendingCountLoader(
      PendingSubmissionRepository(gateway),
    ).load(global: false, congregationIds: const []);

    expect(gateway.reads, isEmpty);
    expect(count.count, 0);
    expect(count.capped, isFalse);
  });
}
