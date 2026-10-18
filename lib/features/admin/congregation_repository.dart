import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';
import '../converts/congregation_order.dart';

class CongregationRepository {
  CongregationRepository(this.gateway);
  final Gateway gateway;
  Future<List<Congregation>> list() async {
    final token = gateway.context;
    final result = <Congregation>[];
    String? after;
    while (true) {
      final rows = await gateway.read(
        'congregations',
        context: token,
        afterId: after,
      );
      gateway.ensureCurrent(token);
      validatePageOrder(rows, after);
      for (final row in rows) {
        try {
          final item = Congregation.fromJson(row);
          if (item.name.trim().isEmpty || item.name != item.name.trim()) {
            throw const FormatException();
          }
          result.add(item);
        } catch (_) {
          throw const DataFailure('invalid_response');
        }
      }
      if (rows.length < 100) break;
      after = result.last.id;
    }
    final ordered = await orderCongregations(result);
    gateway.ensureCurrent(token);
    return List.unmodifiable(ordered);
  }

  Future<MutationResult<String>> save(
    String operationId,
    String name, {
    String? id,
  }) => gateway.command('save_congregation', operationId, {
    'id': ?id,
    'name': name.trim(),
  });
  Future<MutationResult<String>> archive(String operationId, String id) =>
      gateway.command('archive_congregation', operationId, {'id': id});
}
