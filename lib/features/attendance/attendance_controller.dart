/// Attendance editor state for one session (S08, S09, S10).
///
/// Every row starts `unmarked`; opening a session never implies absence. The
/// controller keeps a complete `enrollmentId -> status` map, submits it with
/// the expected session revision, retains the request identity and unsaved
/// choices after a timeout, and turns a stale-revision conflict into a reload
/// offer with both the unsaved and the server copy visible.
library;

import 'package:flutter/foundation.dart';

import '../../domain/attendance.dart';
import '../../domain/class_group.dart';
import '../../domain/ports.dart';
import '../../domain/session.dart';
import '../../domain/validation.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import '../classes/academic_repository.dart';

/// The last mutating command that failed, so [AttendanceController.retry]
/// re-issues exactly that operation with its retained request identity.
enum AttendanceOperation { save, finalize, cancel }

class AttendanceController extends ChangeNotifier implements SessionScoped {
  AttendanceController({
    required this.repository,
    required this.congregationId,
    required this.classId,
    required this.sessionId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AcademicRepository repository;
  final String congregationId;
  final String classId;
  final String sessionId;
  final DateTime Function() _nowUtc;

  AsyncViewState<List<AttendanceRosterEntry>> _state =
      const AsyncViewState<List<AttendanceRosterEntry>>.loading();
  Session? _session;
  ClassStatus? _classStatus;
  AttendanceOperation? _lastFailedOperation;
  List<AttendanceRosterEntry> _roster = const <AttendanceRosterEntry>[];
  final Map<String, AttendanceStatus> _marks = <String, AttendanceStatus>{};
  Map<String, AttendanceStatus>? _serverMarks;
  Map<String, AttendanceStatus>? _localBeforeReload;
  String? _validationMessage;
  String? _errorMessage;
  String? _conflictMessage;
  bool _submitting = false;
  bool _dirty = false;
  String? _requestId;
  int? _expectedRevision;
  int _generation = 0;
  bool _disposed = false;

  AsyncViewState<List<AttendanceRosterEntry>> get state => _state;

  Session? get session => _session;

  List<AttendanceRosterEntry> get roster => _roster;

  Map<String, AttendanceStatus> get marks =>
      Map<String, AttendanceStatus>.unmodifiable(_marks);

  AttendanceStatus statusOf(String enrollmentId) =>
      _marks[enrollmentId] ?? AttendanceStatus.unmarked;

  bool get isSubmitting => _submitting;

  bool get isDirty => _dirty;

  /// True when every roster member carries a non-unmarked status.
  bool get allMarked =>
      _roster.isNotEmpty &&
      _roster.every((AttendanceRosterEntry entry) {
        final AttendanceStatus status = statusOf(entry.enrollmentId);
        return status != AttendanceStatus.unmarked;
      });

  int get markedCount => _marks.values
      .where((AttendanceStatus status) => status != AttendanceStatus.unmarked)
      .length;

  String? get validationMessage => _validationMessage;

  String? get errorMessage => _errorMessage;

  String? get conflictMessage => _conflictMessage;

  bool get hasConflict => _conflictMessage != null;

  Map<String, AttendanceStatus>? get serverMarks => _serverMarks;

  /// The last failed mutating command, so [retry] re-issues exactly it.
  AttendanceOperation? get lastFailedOperation => _lastFailedOperation;

  /// The revision the next mutation will carry; updated from the confirmed
  /// result so a following cancel does not ship a stale revision.
  int? get expectedRevision => _expectedRevision;

  /// True when the editor must not accept changes: the session is canceled or
  /// the owning class is completed/archived (S08).
  bool get isReadOnly {
    final Session? session = _session;
    if (session == null) {
      return false;
    }
    if (session.status == SessionStatus.canceled) {
      return true;
    }
    return _classStatus == ClassStatus.completed ||
        _classStatus == ClassStatus.archived;
  }

  /// The retained request identity, reused by [retry] after a timeout.
  String? get requestId => _requestId;

  Future<void> load() async {
    final int generation = ++_generation;
    _state = const AsyncViewState<List<AttendanceRosterEntry>>.loading();
    _errorMessage = null;
    _conflictMessage = null;
    notifyListeners();
    try {
      final AttendanceView view = await repository.getSessionAttendance(
        congregationId: congregationId,
        classId: classId,
        sessionId: sessionId,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _applyView(view);
      _dirty = false;
      _requestId = null;
      _localBeforeReload = null;
      _serverMarks = null;
      _state = AsyncViewState<List<AttendanceRosterEntry>>.data(_roster);
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _state = AsyncViewState<List<AttendanceRosterEntry>>.fromFailure(
        _failureOf(error),
      );
      notifyListeners();
    }
  }

  void _applyView(AttendanceView view) {
    _session = view.session;
    _classStatus = view.classStatus;
    _roster = view.entries;
    _marks
      ..clear()
      ..addEntries(
        view.entries.map(
          (AttendanceRosterEntry entry) => MapEntry<String, AttendanceStatus>(
            entry.enrollmentId,
            entry.status,
          ),
        ),
      );
    _expectedRevision = view.session.revision;
  }

  void mark(String enrollmentId, AttendanceStatus status) {
    if (isReadOnly) {
      return;
    }
    _marks[enrollmentId] = status;
    _dirty = true;
    _validationMessage = null;
    notifyListeners();
  }

  /// Explicit "Marcar todos presentes"; the change stays unsaved until
  /// `Salvar chamada` (S08). A read-only session never accepts it.
  void markAllPresent() {
    if (isReadOnly) {
      return;
    }
    for (final AttendanceRosterEntry entry in _roster) {
      _marks[entry.enrollmentId] = AttendanceStatus.present;
    }
    _dirty = true;
    _validationMessage = null;
    notifyListeners();
  }

  /// Null when the session may be finalized; otherwise the blocking reason.
  String? finalizeBlocker() {
    if (_roster.isEmpty) {
      return 'Não há alunos no registro desta chamada.';
    }
    if (!allMarked) {
      return 'Marque todos os alunos antes de finalizar.';
    }
    final Session? session = _session;
    if (session != null && session.date.compareTo(recifeToday(_nowUtc())) > 0) {
      return 'Não é possível finalizar uma chamada com data futura.';
    }
    return null;
  }

  Future<bool> save({required bool finalize}) => _submit(finalize: finalize);

  /// Re-issues exactly the command that failed, with its retained requestId
  /// and finalize flag, so a timed-out finalize is never downgraded to a save
  /// and a failed cancel is never re-sent as saveAttendance.
  Future<bool> retry({bool? finalize}) {
    switch (_lastFailedOperation) {
      case AttendanceOperation.finalize:
        return _submit(finalize: true);
      case AttendanceOperation.save:
        return _submit(finalize: false);
      case AttendanceOperation.cancel:
        return cancelSession();
      case null:
        return _submit(finalize: finalize ?? false);
    }
  }

  Future<bool> _submit({required bool finalize}) async {
    if (_submitting || isReadOnly) {
      return false;
    }
    if (finalize) {
      final String? blocker = finalizeBlocker();
      if (blocker != null) {
        _validationMessage = blocker;
        notifyListeners();
        return false;
      }
    }
    _submitting = true;
    _validationMessage = null;
    _errorMessage = null;
    _conflictMessage = null;
    final String requestId = _requestId ??= repository.newRequestId();
    final int generation = ++_generation;
    notifyListeners();
    try {
      final AcademicMutationResult result = await repository.saveAttendance(
        congregationId: congregationId,
        classId: classId,
        sessionId: sessionId,
        expectedRevision: _expectedRevision ?? _session?.revision ?? 1,
        marks: Map<String, AttendanceStatus>.of(_marks),
        finalize: finalize,
        requestId: requestId,
      );
      if (_disposed || generation != _generation) {
        return false;
      }
      _expectedRevision = result.revision;
      _requestId = null;
      _dirty = false;
      _submitting = false;
      _conflictMessage = null;
      _serverMarks = null;
      _localBeforeReload = null;
      _lastFailedOperation = null;
      notifyListeners();
      // Reload the authoritative session/roster so the header reflects the
      // finalized or corrected status and dependent progress can refresh (S08).
      await _refreshAuthoritative();
      return true;
    } on AppFailure catch (failure) {
      if (_disposed || generation != _generation) {
        return false;
      }
      _submitting = false;
      _lastFailedOperation = finalize
          ? AttendanceOperation.finalize
          : AttendanceOperation.save;
      if (failure.code == AppFailureCode.conflict) {
        _conflictMessage = failure.message;
        _localBeforeReload = Map<String, AttendanceStatus>.of(_marks);
      } else {
        _errorMessage = failure.message;
      }
      // The request identity is retained for an explicit same-command retry.
      notifyListeners();
      return false;
    }
  }

  /// Re-reads the authoritative session and roster after a confirmed mutation
  /// instead of only advancing the local revision.
  Future<void> _refreshAuthoritative() async {
    final int generation = ++_generation;
    try {
      final AttendanceView view = await repository.getSessionAttendance(
        congregationId: congregationId,
        classId: classId,
        sessionId: sessionId,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _applyView(view);
      _dirty = false;
      _state = AsyncViewState<List<AttendanceRosterEntry>>.data(_roster);
      notifyListeners();
    } on AppFailure {
      // The confirmed local state stands; the next load reconciles.
    }
  }

  /// Reloads the authoritative server copy after a conflict while keeping the
  /// operator's unsaved choices so both can be compared (S08).
  Future<void> reloadAfterConflict() async {
    final Map<String, AttendanceStatus> local =
        _localBeforeReload ?? Map<String, AttendanceStatus>.of(_marks);
    final int generation = ++_generation;
    try {
      final AttendanceView view = await repository.getSessionAttendance(
        congregationId: congregationId,
        classId: classId,
        sessionId: sessionId,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _session = view.session;
      _roster = view.entries;
      _expectedRevision = view.session.revision;
      _serverMarks = <String, AttendanceStatus>{
        for (final AttendanceRosterEntry entry in view.entries)
          entry.enrollmentId: entry.status,
      };
      _marks
        ..clear()
        ..addAll(local);
      _localBeforeReload = local;
      _conflictMessage = null;
      _requestId = null;
      _dirty = true;
      _state = AsyncViewState<List<AttendanceRosterEntry>>.data(_roster);
      notifyListeners();
    } on AppFailure catch (failure) {
      if (_disposed || generation != _generation) {
        return;
      }
      _errorMessage = failure.message;
      notifyListeners();
    }
  }

  Future<bool> cancelSession() async {
    final Session? session = _session;
    if (session == null || _submitting || isReadOnly) {
      return false;
    }
    _submitting = true;
    _errorMessage = null;
    // The same revision source as the save path, so a cancel after a
    // successful save does not ship the stale cached session revision.
    final int expectedRevision = _expectedRevision ?? session.revision;
    final String requestId = _requestId ??= repository.newRequestId();
    notifyListeners();
    try {
      await repository.cancelSession(
        congregationId: congregationId,
        classId: classId,
        sessionId: sessionId,
        expectedRevision: expectedRevision,
        requestId: requestId,
      );
      if (_disposed) {
        return false;
      }
      _submitting = false;
      _requestId = null;
      _lastFailedOperation = null;
      notifyListeners();
      await load();
      return true;
    } on AppFailure catch (failure) {
      if (_disposed) {
        return false;
      }
      _submitting = false;
      // The request identity is retained so an explicit retry re-issues the
      // cancel command rather than a plain attendance save.
      _lastFailedOperation = AttendanceOperation.cancel;
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    }
  }

  AppFailure _failureOf(Object error) => error is AppFailure
      ? error
      : const AppFailure(
          code: AppFailureCode.unknown,
          message: 'Não foi possível carregar a chamada.',
        );

  @override
  void clearSessionData() {
    _generation++;
    _session = null;
    _classStatus = null;
    _lastFailedOperation = null;
    _roster = const <AttendanceRosterEntry>[];
    _marks.clear();
    _serverMarks = null;
    _localBeforeReload = null;
    _validationMessage = null;
    _errorMessage = null;
    _conflictMessage = null;
    _submitting = false;
    _dirty = false;
    _requestId = null;
    _expectedRevision = null;
    _state = const AsyncViewState<List<AttendanceRosterEntry>>.loading();
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
