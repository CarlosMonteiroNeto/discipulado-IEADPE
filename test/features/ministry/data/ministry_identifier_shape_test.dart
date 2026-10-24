import 'package:flutter_test/flutter_test.dart';
import 'package:ieadpe_converts/data/supabase_gateway.dart';
import 'package:ieadpe_converts/domain/models.dart';
import 'package:ieadpe_converts/features/ministry/data/ministry_browser_repository.dart';

/// A PostgreSQL-valid uuid that is not RFC 4122 version 1-8 / variant 89ab.
/// The shape matches what `private.base44_stable_uuid` produces for the
/// imported congregation rows: raw md5 hex with unconstrained nibbles.
const _imported = 'a1b2c3d4-e5f6-0a1b-2c3d-4e5f6a7b8c9d';

class _Gateway implements ReadRpcGateway {
  _Gateway(this.respond);
  final Object? Function(String rpc) respond;
  @override
  final boundary = ProtectedDataBoundary();
  int calls = 0;
  @override
  String get context => boundary.generation;
  @override
  void ensureCurrent(String token) {
    if (token != context) throw const DataFailure('stale');
  }

  @override
  Future<Map<String, dynamic>> readRpc(
    String rpc, {
    required String context,
    Map<String, Object?> parameters = const {},
  }) async {
    calls++;
    return respond(rpc) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> read(
    String table, {
    required String context,
    String? afterId,
    Map<String, Object> equals = const {},
    String? name,
    bool excludeDeleted = false,
  }) async => throw UnimplementedError();
  @override
  Future<MutationResult<String>> command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async => throw UnimplementedError();
}

void main() {
  group('ministry identifiers accept PostgreSQL uuid shapes', () {
    test('the congregation picker keeps an imported id', () async {
      final gateway = _Gateway(
        (_) => {
          'items': [
            {'id': _imported, 'name': 'Congregação importada'},
          ],
          'next_cursor': null,
        },
      );
      final page = await MinistryBrowserRepository(gateway).listCongregations();
      expect(page.items.single.id, _imported);
      expect(page.items.single.name, 'Congregação importada');
    });

    test('a scoped student read is not rejected before the request', () async {
      final gateway = _Gateway(
        (_) => {'items': <Object?>[], 'next_cursor': null},
      );
      final page = await MinistryBrowserRepository(gateway)
          .listStudents(congregationId: _imported);
      expect(page.items, isEmpty);
      expect(gateway.calls, 1);
    });

    test('a non-uuid identifier is still rejected', () async {
      final gateway = _Gateway((_) => throw StateError('must not be called'));
      await expectLater(
        MinistryBrowserRepository(gateway)
            .listStudents(congregationId: 'not-a-uuid'),
        throwsA(
          isA<DataFailure>().having((error) => error.code, 'code', 'invalid'),
        ),
      );
      expect(gateway.calls, 0);
    });

    test('the ministry route context accepts an imported id', () {
      const context = MinistryRouteContext(
        congregationId: _imported,
        returnTo: MinistryReturnRoute.students,
      );
      expect(context.hasValidIds, isTrue);
    });
  });
}
