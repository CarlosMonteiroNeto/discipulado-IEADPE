import '../../domain/models.dart';
import '../../platform/portuguese_sort.dart';

/// Prepare platform locale ordering before synchronous list presentation.
Future<List<Congregation>> orderCongregations(
  List<Congregation> congregations, {
  Future<List<String>> Function(List<String>) sortNames = sortPortugueseNames,
}) async {
  final names = congregations.map((c) => c.name).toSet().toList();
  final sorted = names.length < 2 ? names : await sortNames(names);
  if (sorted.length != names.length ||
      sorted.toSet().length != names.length ||
      !sorted.toSet().containsAll(names)) {
    throw StateError('Invalid locale ordering');
  }
  final ranks = {for (final entry in sorted.indexed) entry.$2: entry.$1};
  final indexed = congregations.indexed.toList();
  indexed.sort((a, b) {
    final sedeA = a.$2.name.toLowerCase().contains('sede');
    final sedeB = b.$2.name.toLowerCase().contains('sede');
    if (sedeA != sedeB) return sedeA ? -1 : 1;
    final order = ranks[a.$2.name]!.compareTo(ranks[b.$2.name]!);
    return order == 0 ? a.$1.compareTo(b.$1) : order;
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}
