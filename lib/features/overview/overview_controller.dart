/// Overview view state: scope selection, authoritative counts, pending
/// attendance paging and refresh/invalidation (S09, S10).
///
/// Staff scope is fixed to the assigned congregation; a supervisor may select
/// one congregation or `null` (Todas). Older requests are discarded by
/// generation so a stale result never replaces a newer scope (S09, S12).
///
/// The URL-addressable state is held in a single [OverviewQuery] value, so
/// task 13's router can initialize the controller from `congregacao`/
/// `pendentes` and write the state back without editing this file.
///
/// Cross-task obligation for task 13: the relevant successful mutation flows
/// (student/class/session/attendance) must call [invalidate] so the counts do
/// not go stale. That composition lives in `lib/app/`; it is recorded here
/// instead of being claimed as already wired.
library;

import 'package:flutter/foundation.dart';

import '../../domain/access.dart';
import '../../domain/congregation.dart';
import '../../domain/ports.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import '../congregations/congregation_repository.dart';
import 'overview_repository.dart';

/// The URL-addressable overview state shared with task 13's router: the
/// selected scope (`congregacao`) and the pending section flag (`pendentes`).
class OverviewQuery {
  const OverviewQuery({this.congregationId, this.pending = false});

  final String? congregationId;
  final bool pending;

  OverviewQuery copyWith({
    String? congregationId,
    bool clearCongregation = false,
    bool? pending,
  }) => OverviewQuery(
    congregationId: clearCongregation
        ? null
        : (congregationId ?? this.congregationId),
    pending: pending ?? this.pending,
  );

  Map<String, String> toQueryParameters() => <String, String>{
    if (congregationId != null && congregationId!.isNotEmpty)
      'congregacao': congregationId!,
    if (pending) 'pendentes': 'true',
  };

  factory OverviewQuery.fromQueryParameters(Map<String, String> parameters) =>
      OverviewQuery(
        congregationId: _nonEmpty(parameters['congregacao']),
        pending: _isTrue(parameters['pendentes']),
      );
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

bool _isTrue(String? value) {
  final String? normalized = value?.trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

class OverviewController extends ChangeNotifier implements SessionScoped {
  OverviewController({
    required this.repository,
    required this.profile,
    this.catalog,
    OverviewQuery? initialQuery,
  }) {
    final OverviewQuery requested = initialQuery ?? const OverviewQuery();
    _query = OverviewQuery(
      congregationId: isSupervisor
          ? requested.congregationId
          : profile.congregationId,
      pending: requested.pending,
    );
  }

  final OverviewRepository repository;
  AccessProfile profile;

  /// Authorized congregation catalog used by a supervisor's scope selector.
  final CongregationRepository? catalog;

  late OverviewQuery _query;
  AsyncViewState<OverviewCounts> _counts =
      const AsyncViewState<OverviewCounts>.loading();
  AsyncViewState<List<PendingSessionEntry>> _pending =
      const AsyncViewState<List<PendingSessionEntry>>.loading();
  List<Congregation> _congregations = const <Congregation>[];
  final List<String?> _cursorStack = <String?>[];
  String? _pendingCursor;
  String? _nextCursor;
  int _countsGeneration = 0;
  int _pendingGeneration = 0;
  bool _disposed = false;

  /// The single source of truth for scope and the `pendentes` flag.
  OverviewQuery get query => _query;

  String? get congregationId => _query.congregationId;

  bool get pendingVisible => _query.pending;

  /// The current route state, ready for task 13 to write back to the URL.
  Map<String, String> toQueryParameters() => _query.toQueryParameters();

  AsyncViewState<OverviewCounts> get counts => _counts;

  AsyncViewState<List<PendingSessionEntry>> get pending => _pending;

  List<Congregation> get congregations => _congregations;

  bool get isSupervisor => profile.accessRole == AccessRole.supervisor;

  bool get hasPreviousPage => _cursorStack.isNotEmpty;

  bool get hasNextPage => _nextCursor != null;

  /// Page entry and `Atualizar` both invalidate the counts (S09).
  Future<void> refresh() => invalidate();

  /// Stable public invalidation surface: reloads the catalog, the authoritative
  /// counts and, when open, the first pending page. Composed by task 13 after
  /// successful mutations.
  Future<void> invalidate() async {
    _resetPendingPagination();
    await _loadCatalog();
    await _loadCounts();
    if (_query.pending) {
      await _loadPending(cursor: null);
    }
  }

  Future<void> _loadCatalog() async {
    final CongregationRepository? catalog = this.catalog;
    if (catalog == null) {
      return;
    }
    try {
      _congregations = await catalog.listCongregations(active: true);
    } catch (_) {
      // Keep the last known catalog; selection stays usable.
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Changes the supervisor's selected congregation (`null` means Todas). A
  /// staff member's scope is immutable and this is a no-op for them.
  Future<void> setCongregation(String? congregationId) async {
    if (!isSupervisor || _query.congregationId == congregationId) {
      return;
    }
    _query = _query.copyWith(
      congregationId: congregationId,
      clearCongregation: congregationId == null,
    );
    _resetPendingPagination();
    await _loadCounts();
    if (_query.pending) {
      await _loadPending(cursor: null);
    }
  }

  /// Explicitly shows or hides the `Chamadas pendentes` section on the same
  /// route (`pendentes=true`, S09) and lazily loads its first page.
  Future<void> setPendingVisible(bool visible) async {
    if (_query.pending == visible) {
      return;
    }
    _query = _query.copyWith(pending: visible);
    if (!_disposed) {
      notifyListeners();
    }
    if (visible) {
      await _loadPending(cursor: null);
    }
  }

  Future<void> togglePending() => setPendingVisible(!_query.pending);

  Future<void> refreshPending() => _loadPending(cursor: null);

  /// Advances only after the forward page actually loads, so a failed fetch
  /// leaves no phantom previous-page entry.
  Future<void> nextPendingPage() async {
    final String? cursor = _nextCursor;
    if (cursor == null) {
      return;
    }
    final String? previousCursor = _pendingCursor;
    if (await _loadPending(cursor: cursor)) {
      _cursorStack.add(previousCursor);
    }
  }

  /// Retreats only after the previous page actually loads, keeping the stack
  /// entry available for a retry when the fetch fails.
  Future<void> previousPendingPage() async {
    if (_cursorStack.isEmpty) {
      return;
    }
    if (await _loadPending(cursor: _cursorStack.last)) {
      _cursorStack.removeLast();
    }
  }

  Future<void> _loadCounts() async {
    final int generation = ++_countsGeneration;
    _emitCounts(const AsyncViewState<OverviewCounts>.loading());
    try {
      final OverviewCounts counts = await repository.getOverview(
        congregationId: _query.congregationId,
      );
      if (_disposed || generation != _countsGeneration) {
        return;
      }
      _emitCounts(AsyncViewState<OverviewCounts>.data(counts));
    } catch (error) {
      if (_disposed || generation != _countsGeneration) {
        return;
      }
      _emitCounts(
        AsyncViewState<OverviewCounts>.fromFailure(
          _failureOf(error, 'Não foi possível carregar a visão geral.'),
        ),
      );
    }
  }

  Future<bool> _loadPending({required String? cursor}) async {
    final int generation = ++_pendingGeneration;
    _emitPending(const AsyncViewState<List<PendingSessionEntry>>.loading());
    try {
      final PendingSessionPage page = await repository.listPendingSessions(
        congregationId: _query.congregationId,
        cursor: cursor,
      );
      if (_disposed || generation != _pendingGeneration) {
        return false;
      }
      _pendingCursor = cursor;
      _nextCursor = page.nextCursor;
      _emitPending(
        page.items.isEmpty
            ? const AsyncViewState<List<PendingSessionEntry>>.emptyData()
            : AsyncViewState<List<PendingSessionEntry>>.data(page.items),
      );
      return true;
    } catch (error) {
      if (_disposed || generation != _pendingGeneration) {
        return false;
      }
      _emitPending(
        AsyncViewState<List<PendingSessionEntry>>.fromFailure(
          _failureOf(error, 'Não foi possível carregar as chamadas pendentes.'),
        ),
      );
      return false;
    }
  }

  void _resetPendingPagination() {
    _cursorStack.clear();
    _pendingCursor = null;
    _nextCursor = null;
  }

  AppFailure _failureOf(Object error, String fallbackMessage) =>
      error is AppFailure
      ? error
      : AppFailure(code: AppFailureCode.unknown, message: fallbackMessage);

  void _emitCounts(AsyncViewState<OverviewCounts> next) {
    if (_disposed) {
      return;
    }
    _counts = next;
    notifyListeners();
  }

  void _emitPending(AsyncViewState<List<PendingSessionEntry>> next) {
    if (_disposed) {
      return;
    }
    _pending = next;
    notifyListeners();
  }

  @override
  void clearSessionData() {
    _countsGeneration++;
    _pendingGeneration++;
    _query = OverviewQuery(congregationId: profile.congregationId);
    _counts = const AsyncViewState<OverviewCounts>.loading();
    _pending = const AsyncViewState<List<PendingSessionEntry>>.loading();
    _congregations = const <Congregation>[];
    _resetPendingPagination();
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
