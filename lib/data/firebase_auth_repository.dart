/// Firebase Auth adapter and [AuthRepository] implementation (S04, S11).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/access.dart';
import '../domain/common.dart';
import '../domain/ports.dart';
import 'error_mapper.dart';

/// SDK seam: Firebase identity and the caller's own profile document.
abstract interface class AuthAdapter {
  Stream<String?> watchUid();

  Stream<JsonMap?> watchProfile(String uid);

  /// Session-scoped persistence: no long-lived credential survives a tab by
  /// default (S04, S12).
  Future<void> configureSessionPersistence();

  Future<void> signInWithPassword(String email, String password);

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Real Firebase adapter. Widgets never touch this directly.
class FirebaseAuthAdapter implements AuthAdapter {
  FirebaseAuthAdapter({required this.auth, required this.firestore});

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  @override
  Stream<String?> watchUid() =>
      auth.authStateChanges().map((User? user) => user?.uid);

  @override
  Stream<JsonMap?> watchProfile(String uid) => firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, dynamic>> snapshot) => snapshot.data(),
      );

  @override
  Future<void> configureSessionPersistence() =>
      auth.setPersistence(Persistence.SESSION);

  @override
  Future<void> signInWithPassword(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => auth.signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required this.adapter,
    this.errorMapper = const ErrorMapper(),
  });

  final AuthAdapter adapter;
  final ErrorMapper errorMapper;

  @override
  Stream<AuthSession?> watchSession() {
    late StreamController<AuthSession?> controller;
    StreamSubscription<String?>? uidSubscription;
    StreamSubscription<JsonMap?>? profileSubscription;

    controller = StreamController<AuthSession?>(
      onListen: () {
        uidSubscription = adapter.watchUid().listen(
          (String? uid) {
            profileSubscription?.cancel();
            profileSubscription = null;
            if (uid == null) {
              controller.add(null);
              return;
            }
            profileSubscription = adapter
                .watchProfile(uid)
                .listen(
                  (JsonMap? json) => _emitProfile(controller, uid, json),
                  onError: (Object error) {
                    controller.addError(errorMapper.map(error));
                  },
                );
          },
          onError: (Object error) {
            controller.addError(errorMapper.map(error));
          },
        );
      },
      onCancel: () async {
        await uidSubscription?.cancel();
        await profileSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  void _emitProfile(
    StreamController<AuthSession?> controller,
    String uid,
    JsonMap? json,
  ) {
    if (json == null) {
      controller.addError(_accessDenied());
      return;
    }
    try {
      final AccessProfile profile = AccessProfile.fromJson(json);
      if (!profile.active) {
        controller.addError(_accessDenied());
        return;
      }
      controller.add(AuthSession(uid: uid, profile: profile));
    } on DataFormatException {
      // A stored profile we cannot decode is never a valid session.
      controller.addError(_accessDenied());
    }
  }

  AppFailure _accessDenied() => const AppFailure(
    code: AppFailureCode.forbidden,
    message: kAccessDeniedMessage,
  );

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await adapter.configureSessionPersistence();
      await adapter.signInWithPassword(email, password);
    } catch (error) {
      throw errorMapper.map(error);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await adapter.sendPasswordReset(email);
    } catch (error) {
      final AppFailure failure = errorMapper.map(error);
      // The response is intentionally generic: an unknown account must not be
      // distinguishable from a known one.
      if (failure.code == AppFailureCode.unauthenticated) {
        return;
      }
      throw failure;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await adapter.signOut();
    } catch (error) {
      throw errorMapper.map(error);
    }
  }
}
