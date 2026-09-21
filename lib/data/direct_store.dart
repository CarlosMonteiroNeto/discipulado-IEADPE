/// Narrow persistence boundary for the direct (callable-free) transport.
///
/// Handlers perform validated, role-scoped Firestore reads and writes through
/// this seam, so they stay unit-testable against an in-memory implementation
/// without an emulator or a live project.
library;

import '../domain/common.dart';

/// A document collection selector for handler-internal reads.
///
/// [collection] is either a full collection path (`congregations/{id}/students`)
/// or, when [group] is true, a collection name matched anywhere in the tree
/// (`students`).
class StoreQuery {
  const StoreQuery({
    required this.collection,
    this.group = false,
    this.filters = const <String, Object?>{},
    this.orderBy,
    this.descending = false,
    this.limit,
  });

  final String collection;
  final bool group;
  final Map<String, Object?> filters;
  final String? orderBy;
  final bool descending;
  final int? limit;
}

/// Read/write scope of one atomic transaction.
abstract interface class DirectTransaction {
  Future<JsonMap?> read(String path);

  Future<void> write(String path, JsonMap data);

  Future<void> delete(String path);
}

/// Document store used by the direct transport handlers.
abstract interface class DirectStore {
  Future<JsonMap?> read(String path);

  Future<void> write(String path, JsonMap data);

  Future<void> delete(String path);

  Future<List<JsonMap>> query(StoreQuery query);

  Future<T> runTransaction<T>(Future<T> Function(DirectTransaction tx) work);
}

/// Deterministic in-memory [DirectStore] for handler unit tests.
class InMemoryDirectStore implements DirectStore {
  InMemoryDirectStore([Map<String, JsonMap> seed = const <String, JsonMap>{}]) {
    seed.forEach((String path, JsonMap data) {
      _documents[path] = _clone(data);
    });
  }

  final Map<String, JsonMap> _documents = <String, JsonMap>{};

  @override
  Future<JsonMap?> read(String path) async {
    final JsonMap? data = _documents[path];
    return data == null ? null : _clone(data);
  }

  @override
  Future<void> write(String path, JsonMap data) async {
    _documents[path] = _clone(data);
  }

  @override
  Future<void> delete(String path) async {
    _documents.remove(path);
  }

  @override
  Future<List<JsonMap>> query(StoreQuery query) async {
    final List<MapEntry<String, JsonMap>> matches = _documents.entries
        .where((MapEntry<String, JsonMap> entry) => _matches(entry.key, query))
        .where(
          (MapEntry<String, JsonMap> entry) => query.filters.entries.every(
            (MapEntry<String, Object?> filter) =>
                entry.value[filter.key] == filter.value,
          ),
        )
        .toList();

    final String? orderBy = query.orderBy;
    if (orderBy != null) {
      matches.sort((MapEntry<String, JsonMap> a, MapEntry<String, JsonMap> b) {
        final Object? left = a.value[orderBy];
        final Object? right = b.value[orderBy];
        int result;
        if (left is Comparable && right is Comparable) {
          result = left.compareTo(right);
        } else {
          result = '$left'.compareTo('$right');
        }
        if (result == 0) {
          result = a.key.compareTo(b.key);
        }
        return query.descending ? -result : result;
      });
    }

    final Iterable<MapEntry<String, JsonMap>> capped = query.limit == null
        ? matches
        : matches.take(query.limit!);
    return capped
        .map((MapEntry<String, JsonMap> entry) => _clone(entry.value))
        .toList(growable: false);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(DirectTransaction tx) work,
  ) async {
    final Map<String, JsonMap?> staged = <String, JsonMap?>{};

    Future<JsonMap?> readStaged(String path) async {
      if (staged.containsKey(path)) {
        final JsonMap? value = staged[path];
        return value == null ? null : _clone(value);
      }
      return read(path);
    }

    final DirectTransaction tx = _InMemoryTransaction(
      readStaged: readStaged,
      stage: (String path, JsonMap? data) => staged[path] = data,
    );

    final T result = await work(tx);
    staged.forEach((String path, JsonMap? data) {
      if (data == null) {
        _documents.remove(path);
      } else {
        _documents[path] = data;
      }
    });
    return result;
  }

  bool _matches(String path, StoreQuery query) {
    final List<String> parts = path.split('/');
    if (query.group) {
      if (parts.length < 2) {
        return false;
      }
      return parts[parts.length - 2] == query.collection;
    }
    const String separator = '/';
    final String prefix = '${query.collection}$separator';
    if (!path.startsWith(prefix)) {
      return false;
    }
    return !path.substring(prefix.length).contains(separator);
  }

  static JsonMap _clone(JsonMap data) => Map<String, Object?>.from(data);
}

class _InMemoryTransaction implements DirectTransaction {
  const _InMemoryTransaction({required this.readStaged, required this.stage});

  final Future<JsonMap?> Function(String path) readStaged;
  final void Function(String path, JsonMap? data) stage;

  @override
  Future<JsonMap?> read(String path) => readStaged(path);

  @override
  Future<void> write(String path, JsonMap data) async {
    stage(path, _clone(data));
  }

  @override
  Future<void> delete(String path) async {
    stage(path, null);
  }

  static JsonMap _clone(JsonMap data) => Map<String, Object?>.from(data);
}
