import '../domain/models.dart';
import 'supabase_gateway.dart';

class AccessRepository {
  AccessRepository(this.gateway);
  final Gateway gateway;
  Future<Page<UserAccess>> list([String? cursor]) async {
    final token = gateway.context;
    final after = decodeCursor(cursor, token, 'user_access');
    final rows = await gateway.read(
      'user_access',
      context: token,
      afterId: after,
    );
    gateway.ensureCurrent(token);
    validatePageOrder(rows, after);
    final records = rows
        .map((row) {
          try {
            validateUuid(row['id']);
            if (row['user_id'] != null) validateUuid(row['user_id']);
            if (row['congregation_id'] != null) {
              validateUuid(row['congregation_id']);
            }
            final record = UserAccess.fromJson(row);
            if (!record.userEmail.contains('@') ||
                record.userEmail != record.userEmail.trim().toLowerCase() ||
                (record.role == AccessRole.direction) !=
                    (record.congregationId != null)) {
              throw const FormatException();
            }
            return record;
          } catch (_) {
            throw const DataFailure('invalid_response');
          }
        })
        .toList(growable: false);
    return Page(
      items: records,
      nextCursor: rows.length == 100
          ? encodeCursor(token, 'user_access', records.last.id)
          : null,
    );
  }

  Future<MutationResult<String>> save(
    String operationId, {
    String? id,
    required String email,
    required AccessRole role,
    String? congregationId,
  }) => gateway.command('save_access', operationId, {
    'id': ?id,
    'user_email': email.trim().toLowerCase(),
    'role': role.wireValue,
    'congregation_id': congregationId,
  });
  Future<MutationResult<String>> revoke(String operationId, String id) =>
      gateway.command('revoke_access', operationId, {'id': id});
}
