/// Firestore-backed [DirectStore] used by the direct transport in production.
///
/// All reads and writes are direct client operations; authorization is
/// enforced by `firestore.rules`, not by a callable function.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/common.dart';
import 'direct_store.dart';

class FirestoreDirectStore implements DirectStore {
  FirestoreDirectStore({required this.firestore});

  final FirebaseFirestore firestore;

  @override
  Future<JsonMap?> read(String path) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
        .doc(path)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return <String, Object?>{'id': snapshot.id, ...data};
  }

  @override
  Future<void> write(String path, JsonMap data) {
    return firestore.doc(path).set(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> delete(String path) => firestore.doc(path).delete();

  @override
  Future<List<JsonMap>> query(StoreQuery query) async {
    Query<Map<String, dynamic>> request = query.group
        ? firestore.collectionGroup(query.collection)
        : firestore.collection(query.collection);
    query.filters.forEach((String field, Object? value) {
      request = request.where(field, isEqualTo: value);
    });
    final String? orderBy = query.orderBy;
    if (orderBy != null) {
      request = request.orderBy(orderBy, descending: query.descending);
    }
    final int? limit = query.limit;
    if (limit != null) {
      request = request.limit(limit);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await request.get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, Object?>{'id': doc.id, ...doc.data()},
        )
        .toList(growable: false);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(DirectTransaction tx) work,
  ) {
    return firestore.runTransaction<T>((Transaction transaction) {
      final DirectTransaction tx = _FirestoreTransaction(
        transaction,
        firestore,
      );
      return work(tx);
    });
  }
}

class _FirestoreTransaction implements DirectTransaction {
  const _FirestoreTransaction(this._transaction, this._firestore);

  final Transaction _transaction;
  final FirebaseFirestore _firestore;

  @override
  Future<JsonMap?> read(String path) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _transaction
        .get(_firestore.doc(path));
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return <String, Object?>{'id': snapshot.id, ...data};
  }

  @override
  Future<void> write(String path, JsonMap data) async {
    _transaction.set(_firestore.doc(path), Map<String, dynamic>.from(data));
  }

  @override
  Future<void> delete(String path) async {
    _transaction.delete(_firestore.doc(path));
  }
}
