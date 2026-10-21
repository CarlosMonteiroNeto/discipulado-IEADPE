import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/supabase_gateway.dart';
import '../data/ministry_repository.dart';
import '../domain/ministry_models.dart';
import '../domain/session_navigation_context.dart';

/// One attendance request that must survive an ambiguous server outcome.
///
/// The marks map is copied and made unmodifiable when the request is captured,
/// so later edits to the page-owned draft cannot change a pending retry.
@immutable
class PendingAttendanceSave {
  PendingAttendanceSave._({
    required this.context,
    required this.operationId,
    required this.expectedRevision,
    required Map<String, AttendanceStatus> marks,
    required this.finalize,
    required this.protectedGeneration,
    required this.protectedContext,
  }) : marks = Map.unmodifiable(Map<String, AttendanceStatus>.from(marks));

  final SessionNavigationContext context;
  final String operationId;
  final int expectedRevision;
  final Map<String, AttendanceStatus> marks;
  final bool finalize;
  final String protectedGeneration;
  final String protectedContext;
}

enum _Phase { idle, submitting, unknown, rejected }

/// Feature-owned owner of one attendance operation at a time.
///
/// This is deliberately memory-only and instance-owned. It composes the
/// existing repository command port and never queues work outside the page.
class AttendanceSaveController extends ChangeNotifier {
  AttendanceSaveController({
    required this.repository,
    String Function()? createOperationId,
  }) : _createOperationId = createOperationId ?? _newOperationId;

  static const _uuid = Uuid();
  static String _newOperationId() => _uuid.v4();

  final MinistryRepository repository;
  final String Function() _createOperationId;

  PendingAttendanceSave? _pending;
  _Phase _phase = _Phase.idle;
  int _epoch = 0;
  bool _disposed = false;

  ProtectedDataBoundary get _boundary => repository.gateway.boundary;
  String get _currentContext => repository.gateway.context;

  PendingAttendanceSave? get pending {
    _discardIfInvalidated(notify: false);
    return _pending;
  }

  bool get isBusy {
    _discardIfInvalidated(notify: false);
    return _phase == _Phase.submitting;
  }

  bool get hasUnknownResult {
    _discardIfInvalidated(notify: false);
    return _phase == _Phase.unknown;
  }

  /// Captures the exact intent once and sends it with one operation ID.
  ///
  /// Ambiguous failures are rethrown while retaining [pending]; a proven
  /// non-committing rejection is rethrown while retaining it as rejected until
  /// the caller performs a fresh read and explicitly calls [clear].
  Future<void> submit({
    required SessionNavigationContext context,
    required int expectedRevision,
    required Map<String, AttendanceStatus> marks,
    required bool finalize,
  }) async {
    if (_disposed) throw StateError('Attendance save controller is disposed.');
    _discardIfInvalidated();
    if (_pending != null) {
      throw StateError('An attendance operation is already pending.');
    }
    if (expectedRevision < 1) throw const DataFailure('invalid');

    final pending = PendingAttendanceSave._(
      context: context,
      operationId: _createOperationId(),
      expectedRevision: expectedRevision,
      marks: marks,
      finalize: finalize,
      protectedGeneration: _boundary.generation,
      protectedContext: _currentContext,
    );
    _pending = pending;
    await _run(pending);
  }

  /// Resends the captured command without reading current controls.
  Future<void> retryPending() async {
    if (_disposed) throw StateError('Attendance save controller is disposed.');
    _discardIfInvalidated();
    final pending = _pending;
    if (pending == null || _phase != _Phase.unknown) {
      throw StateError('There is no unresolved attendance result to retry.');
    }
    await _run(pending);
  }

  /// Discards protected pending data and ignores any in-flight response.
  ///
  /// A proved rejection must only be cleared after an authoritative fresh read
  /// and an explicit operator decision about the next intent.
  void clear() {
    if (_disposed) return;
    _discard();
  }

  Future<void> _run(PendingAttendanceSave pending) async {
    final attempt = ++_epoch;
    _phase = _Phase.submitting;
    _notify();
    // A synchronous listener may clear the owner or invalidate its protected
    // identity. This command has not been sent yet, so revalidate ownership
    // immediately before dispatch and discard it instead of sending.
    if (!_ownsCurrentAttempt(pending, attempt)) return;
    try {
      await repository.command(
        name: 'save_attendance',
        operationId: pending.operationId,
        payload: _payload(pending),
      );
    } catch (error, stackTrace) {
      if (!_ownsCurrentAttempt(pending, attempt)) return;
      _throwFailure(error, stackTrace);
    }

    if (!_ownsCurrentAttempt(pending, attempt)) return;
    _discard();
  }

  /// Checks ownership before touching state, then validates the captured
  /// boundary plus actor context for the attempt that still owns the slot.
  bool _ownsCurrentAttempt(PendingAttendanceSave pending, int attempt) {
    if (_disposed) return false;
    final owned = attempt == _epoch && identical(_pending, pending);
    final identityCurrent =
        pending.protectedGeneration == _boundary.generation &&
        pending.protectedContext == _currentContext;
    if (!owned) {
      if (!identityCurrent) throw const DataFailure('stale');
      return false;
    }
    if (!identityCurrent) {
      _discard();
      throw const DataFailure('stale');
    }
    return true;
  }

  Never _throwFailure(Object error, StackTrace stackTrace) {
    if (error is DataFailure &&
        (error.code == 'permission' || error.code == 'stale')) {
      _discard();
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (error is DataFailure && _provenRejections.contains(error.code)) {
      _phase = _Phase.rejected;
      _notify();
      Error.throwWithStackTrace(error, stackTrace);
    }
    _phase = _Phase.unknown;
    _notify();
    Error.throwWithStackTrace(error, stackTrace);
  }

  /// Only codes that cannot be produced by a receipt/operation conflict are
  /// treated as proved non-committing. The gateway maps SQLSTATE 22023 to
  /// generic `invalid`, which also covers `operation_conflict`, so `invalid`
  /// must stay ambiguous.
  static const _provenRejections = {'stale_revision'};

  Map<String, Object?> _payload(PendingAttendanceSave pending) => {
    'congregation_id': pending.context.congregationId,
    'session_id': pending.context.sessionId,
    'expected_revision': pending.expectedRevision,
    'marks': <String, Object?>{
      for (final entry in pending.marks.entries) entry.key: entry.value.wire,
    },
    'finalize': pending.finalize,
  };

  bool _discardIfInvalidated({bool notify = true}) {
    final pending = _pending;
    if (pending == null ||
        (pending.protectedGeneration == _boundary.generation &&
            pending.protectedContext == _currentContext)) {
      return false;
    }
    _discard(notify: notify);
    return true;
  }

  void _discard({bool notify = true}) {
    _epoch++;
    _pending = null;
    _phase = _Phase.idle;
    if (notify) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _pending = null;
    _phase = _Phase.idle;
    super.dispose();
  }
}
