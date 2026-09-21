/// Callable-free [FirebaseTransport] that dispatches operations to
/// handlers over the [DirectStore] seam (internal mode).
///
/// Reads and queries stay direct Firestore reads. Equality filters and the
/// order key are pushed to the store query; when a name prefix or cursor is
/// present the transport drops the server-side limit and applies the prefix
/// range and cursor paging in Dart, so every page of a prefixed or cursored
/// query reads the whole collection once per page. Capacity accounting for
/// Spark read quota in directory/global name searches and paged lists must
/// budget for that amplification. Mutations never call Cloud Functions;
/// [callFunction] resolves the operation in the [HandlerRegistry] and runs the
/// registered handler with the caller's identity and clock.
library;

import '../domain/common.dart';
import '../domain/ports.dart';
import 'direct_store.dart';
import 'error_mapper.dart';
import 'firebase_gateway.dart';
import 'query_codec.dart';
import 'transport_support.dart';

/// [FirebaseTransport] implementation backed by a [DirectStore].
class FirestoreDirectTransport implements FirebaseTransport {
  FirestoreDirectTransport({
    required this.store,
    required this.registry,
    this.codec = const QueryCodec(),
    this.errorMapper = const ErrorMapper(),
    String Function()? uid,
    DateTime Function()? now,
  })  : _uid = uid ?? (() => 'system'),
        _now = now ?? DateTime.now;

  final DirectStore store;
  final HandlerRegistry registry;
  final QueryCodec codec;
  final ErrorMapper errorMapper;
  final String Function() _uid;
  final DateTime Function() _now;

  @override
  Future<JsonMap?> getDocument(String path) async {
    try {
      return await store.read(path);
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  @override
  Future<TransportPage> runQuery(QueryPlan plan) async {
    try {
      final Map<String, Object?> filters =
          <String, Object?>{for (final QueryFilter f in plan.filters) f.field: f.value};
      final bool clientSidePaging = plan.namePrefix != null || plan.cursor != null;
      final List<JsonMap> rows = await store.query(
        StoreQuery(
          collection: plan.collection,
          filters: filters,
          orderBy: plan.orderBy,
          limit: clientSidePaging ? null : plan.limit,
        ),
      );

      Iterable<JsonMap> matches = rows;
      final PrefixRange? range = prefixRangeFor(plan);
      if (range != null) {
        matches = rows.where((JsonMap row) {
          final String key = '${row[plan.orderBy]}';
          return key.compareTo(range.lower) >= 0 && key.compareTo(range.upper) < 0;
        });
      }
      final String? cursor = plan.cursor;
      if (cursor != null) {
        final QueryCursor bound = codec.decodeCursor(cursor);
        matches = matches.where((JsonMap row) {
          final String key = '${row[plan.orderBy]}';
          final int ordering = key.compareTo('${bound.lastSortValue}');
          if (ordering != 0) {
            return ordering > 0;
          }
          return '${row['id']}'.compareTo(bound.lastId) > 0;
        });
      }

      return TransportPage(items: matches.take(plan.limit).toList(growable: false));
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  @override
  Future<JsonMap> callFunction(String operation, JsonMap payload) async {
    final DirectOperationHandler? handler = registry[operation];
    if (handler == null) {
      throw validationFailure('Operação não suportada.');
    }
    final HandlerContext context = HandlerContext(
      store: store,
      uid: _uid(),
      now: _now(),
    );
    try {
      return await handler(context, payload);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw errorMapper.map(error);
    }
  }
}