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
import '../../domain/ports.dart';
import '../../domain/session.dart';
import '../../domain/validation.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import '../classes/academic_repository.dart';

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
    _marks[enrollmentId] = status;
    _dirty = true;
    _validationMessage = null;
    notifyListeners();
  }

  /// Explicit "Marcar todos presentes"; the change stays unsaved until
  /// `Salvar chamada` (S08).
  void markAllPresent() {
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

  /// Explicitly retries a timed-out command with the same request identity.
  Future<bool> retry({required bool finalize}) => _submit(finalize: finalize);

  Future<bool> _submit({required bool finalize}) async {
    if (_submitting) {
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
      notifyListeners();
      return true;
    } on AppFailure catch (failure) {
      if (_disposed || generation != _generation) {
        return false;
      }
      _submitting = false;
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
    if (session == null || _submitting) {
      return false;
    }
    _submitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await repository.cancelSession(
        congregationId: congregationId,
        classId: classId,
        sessionId: sessionId,
        expectedRevision: session.revision,
      );
      if (_disposed) {
        return false;
      }
      _submitting = false;
      notifyListeners();
      await load();
      return true;
    } on AppFailure catch (failure) {
      if (_disposed) {
        return false;
      }
      _submitting = false;
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
