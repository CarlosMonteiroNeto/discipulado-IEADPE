import '../../data/supabase_gateway.dart';
import '../../domain/models.dart';

class FeedbackRepository {
  FeedbackRepository(this.gateway);
  final Gateway gateway;
  Future<MutationResult<String>> submit(
    String message,
    String operationId,
  ) async {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.runes.length > 5000) {
      return MutationResult.rejected(
        operationId: operationId,
        errorCode: 'invalid',
      );
    }
    return _command('submit_feedback', operationId, {'message': normalized});
  }

  Future<MutationResult<String>> update(
    String id,
    FeedbackStatus status,
    String operationId,
  ) => _command('update_feedback', operationId, {
    'id': id,
    'status': status.wireValue,
  });
  Future<MutationResult<String>> _command(
    String command,
    String operationId,
    Map<String, Object?> payload,
  ) async {
    final token = gateway.context;
    gateway.ensureCurrent(token);
    final result = await gateway.command(command, operationId, payload);
    gateway.ensureCurrent(token);
    return result;
  }

  Future<List<Feedback>> list() async {
    final token = gateway.context;
    final result = <Feedback>[];
    String? after;
    while (true) {
      gateway.ensureCurrent(token);
      final rows = await gateway.read(
        'feedback',
        context: token,
        afterId: after,
      );
      gateway.ensureCurrent(token);
      if (rows.length > 100) throw const DataFailure('invalid_response');
      validatePageOrder(rows, after);
      try {
        result.addAll(rows.map(Feedback.fromJson));
      } catch (_) {
        throw const DataFailure('invalid_response');
      }
      if (rows.length < 100) break;
      after = result.last.id;
    }
    return List.unmodifiable(result);
  }
}
