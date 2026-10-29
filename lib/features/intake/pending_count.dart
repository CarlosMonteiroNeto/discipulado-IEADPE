import 'pending_submission_repository.dart';

final class PendingCount {
  const PendingCount({required this.count, this.capped = false});

  final int count;
  final bool capped;
}

/// Counts the pending intake queue without loading every page of it.
///
/// Global managers can read the unscoped queue in one call. Scoped leaders
/// must query each authorized congregation because the review RPC rejects an
/// unscoped request for them.
final class PendingCountLoader {
  const PendingCountLoader(this.repository);

  final PendingSubmissionRepository repository;

  Future<PendingCount> load({
    required bool global,
    required List<String> congregationIds,
  }) async {
    if (!global && congregationIds.isEmpty) {
      return const PendingCount(count: 0);
    }
    final scopes = global ? const <String?>[null] : congregationIds;
    var count = 0;
    var capped = false;
    for (final congregationId in scopes) {
      final page = await repository.list(congregationId: congregationId);
      count += page.items.length;
      capped = capped || page.nextCursor != null;
    }
    return PendingCount(count: count, capped: capped);
  }
}
