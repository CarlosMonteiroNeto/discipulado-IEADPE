/// Firebase-backed [BackendGateway] and retry/generation guards (S11, S12).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../domain/common.dart';
import '../domain/ports.dart';
import 'error_mapper.dart';
import 'query_codec.dart';

class TransportPage {
  const TransportPage({required this.items, this.nextCursor});

  final List<JsonMap> items;
  final String? nextCursor;
}

/// Inclusive/exclusive bounds for a normalized name-prefix range scan (S09).
class PrefixRange {
  const PrefixRange({required this.lower, required this.upper});

  final String lower;
  final String upper;
}

/// The Firestore range constraint a prefix plan must apply, or `null` when the
/// plan is not prefix-bound. Keeping it a pure function makes the constraint
/// testable without an emulator.
PrefixRange? prefixRangeFor(QueryPlan plan) {
  final String? prefix = plan.namePrefix;
  if (prefix == null) {
    return null;
  }
  return PrefixRange(lower: prefix, upper: '$prefix\uf8ff');
}

/// Thin seam over Firestore/Cloud Functions so the gateway stays testable.
abstract interface class FirebaseTransport {
  Future<JsonMap?> getDocument(String path);

  Future<TransportPage> runQuery(QueryPlan plan);

  Future<JsonMap> callFunction(String operation, JsonMap payload);
}

/// A mutation identity retained across an explicit retry (S11).
class MutationRequest {
  const MutationRequest({
    required this.operation,
    required this.recordId,
    required this.requestId,
    required this.payload,
  });

  final String operation;
  final String recordId;
  final String requestId;
  final JsonMap payload;

  JsonMap toPayload() => <String, Object?>{
    ...payload,
    'id': recordId,
    'requestId': requestId,
  };
}

/// Monotonic generation counter used to discard stale asynchronous results.
class RequestGuard {
  int _generation = 0;

  int begin() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;
}

/// Runs a query and discards the result when a newer request superseded it.
class QueryRunner {
  QueryRunner(this._gateway);

  final BackendGateway _gateway;
  final RequestGuard _guard = RequestGuard();

  Future<PageResult?> run(QueryRequest request) async {
    final int generation = _guard.begin();
    final PageResult result = await _gateway.query(request);
    return _guard.isCurrent(generation) ? result : null;
  }
}

class FirebaseGateway implements BackendGateway {
  FirebaseGateway({
    required this.transport,
    this.codec = const QueryCodec(),
    this.errorMapper = const ErrorMapper(),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final FirebaseTransport transport;
  final QueryCodec codec;
  final ErrorMapper errorMapper;
  final Uuid _uuid;

  @override
  Future<JsonMap> invoke(String operation, JsonMap payload) async {
    try {
      return await transport.callFunction(operation, payload);
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  @override
  Future<PageResult> query(QueryRequest request) async {
    try {
      final String? cursor = request.cursor;
      if (cursor != null) {
        codec.verifyCursor(cursor, request);
      }
      final QueryPlan plan = codec.plan(request);
      final String? callable = plan.callableOperation;
      if (callable != null) {
        final JsonMap response = await transport.callFunction(
          callable,
          <String, Object?>{
            'congregationId': request.congregationId,
            'namePrefix': ?request.namePrefix,
            'limit': plan.limit,
            'cursor': ?cursor,
            ...?request.equalityFilters,
          },
        );
        return PageResult(
          items: _decodeItems(response['items']),
          nextCursor: response['nextCursor'] as String?,
        );
      }
      final TransportPage page = await transport.runQuery(plan);
      return PageResult(
        items: page.items,
        nextCursor: page.nextCursor ?? _nextCursor(plan, page.items),
      );
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  @override
  Future<JsonMap?> get(RecordLocator locator) async {
    try {
      final String path = codec.recordPath(locator);
      return await transport.getDocument(path);
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  MutationRequest newMutation({
    required String operation,
    required String recordId,
    JsonMap payload = const <String, Object?>{},
  }) {
    QueryCodec.validateId(recordId);
    return MutationRequest(
      operation: operation,
      recordId: recordId,
      requestId: _uuid.v4(),
      payload: payload,
    );
  }

  /// Submits once; a timeout never triggers an automatic retry (S11, S12).
  Future<JsonMap> submitMutation(MutationRequest request) async {
    try {
      return await transport.callFunction(
        request.operation,
        request.toPayload(),
      );
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  String? _nextCursor(QueryPlan plan, List<JsonMap> items) {
    if (items.length < plan.limit) {
      return null;
    }
    final JsonMap last = items.last;
    final Object? id = last['id'];
    if (id is! String) {
      return null;
    }
    return codec.encodeCursor(
      QueryCursor(
        resource: plan.resource,
        congregationId: plan.congregationId,
        filterFingerprint: plan.filterFingerprint,
        orderBy: plan.orderBy,
        lastSortValue: last[plan.orderBy],
        lastId: id,
      ),
    );
  }

  List<JsonMap> _decodeItems(Object? raw) {
    if (raw is! List) {
      return const <JsonMap>[];
    }
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

/// Real Firestore/Cloud Functions transport (S11, S12).
///
/// It deliberately disables persistent browser caching and never issues an
/// automatic retry; every failure surfaces as a safe [AppFailure].
class FirebaseDataTransport implements FirebaseTransport {
  FirebaseDataTransport({
    required this.firestore,
    required this.functions,
    this.codec = const QueryCodec(),
  });

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final QueryCodec codec;

  /// Persistent Firestore browser caching stays off for this release (S12).
  static void disablePersistentCache(FirebaseFirestore firestore) {
    firestore.settings = const Settings(persistenceEnabled: false);
  }

  @override
  Future<JsonMap?> getDocument(String path) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
        .doc(path)
        .get();
    return snapshot.data();
  }

  @override
  Future<TransportPage> runQuery(QueryPlan plan) async {
    Query<Map<String, dynamic>> query = firestore.collection(plan.collection);
    for (final QueryFilter filter in plan.filters) {
      query = query.where(filter.field, isEqualTo: filter.value);
    }
    // A normalized name prefix is a real range constraint on the order key,
    // applied before cursor paging so every page stays prefix-bounded (S09).
    final PrefixRange? range = prefixRangeFor(plan);
    if (range != null) {
      query = query.where(
        plan.orderBy,
        isGreaterThanOrEqualTo: range.lower,
        isLessThan: range.upper,
      );
    }
    query = query.orderBy(plan.orderBy).orderBy(FieldPath.documentId);
    final String? cursor = plan.cursor;
    if (cursor != null) {
      final QueryCursor decoded = codec.decodeCursor(cursor);
      query = query.startAfter(<Object?>[
        decoded.lastSortValue,
        decoded.lastId,
      ]);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(plan.limit)
        .get();
    return TransportPage(
      items: snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                <String, Object?>{'id': doc.id, ...doc.data()},
          )
          .toList(growable: false),
    );
  }

  @override
  Future<JsonMap> callFunction(String operation, JsonMap payload) async {
    final HttpsCallableResult<Map<String, dynamic>> result = await functions
        .httpsCallable(operation)
        .call<Map<String, dynamic>>(payload);
    return Map<String, Object?>.from(result.data);
  }
}
