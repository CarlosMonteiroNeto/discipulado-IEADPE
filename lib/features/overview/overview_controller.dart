/// Overview view state: scope selection, authoritative counts, pending
/// attendance paging and refresh/invalidation (S09, S10).
///
/// Staff scope is fixed to the assigned congregation; a supervisor may select
/// one congregation or `null` (Todas). Older requests are discarded by
/// generation so a stale result never replaces a newer scope (S09, S12).
library;

import 'package:flutter/foundation.dart';

import '../../domain/access.dart';
import '../../domain/congregation.dart';
import '../../domain/ports.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import '../congregations/congregation_repository.dart';
import 'overview_repository.dart';

class OverviewController extends ChangeNotifier implements SessionScoped {
  OverviewController({
    required this.repository,
    required this.profile,
    this.catalog,
  }) {
    _congregationId = profile.congregationId;
  }

  final OverviewRepository repository;
  AccessProfile profile;

  /// Authorized congregation catalog used by a supervisor's scope selector.
  final CongregationRepository? catalog;

  String? _congregationId;
  bool _pendingVisible = false;
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

  String? get congregationId => _congregationId;

  bool get pendingVisible => _pendingVisible;

  AsyncViewState<OverviewCounts> get counts => _counts;

  AsyncViewState<List<PendingSessionEntry>> get pending => _pending;

  List<Congregation> get congregations => _congregations;

  bool get isSupervisor => profile.accessRole == AccessRole.supervisor;

  bool get hasPreviousPage => _cursorStack.isNotEmpty;

  bool get hasNextPage => _nextCursor != null;

  /// Page entry and `Atualizar` both call this: it reloads the catalog, the
  /// authoritative counts and, when open, the first pending page.
  Future<void> refresh() async {
    await _loadCatalog();
    await _loadCounts();
    if (_pendingVisible) {
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
    if (!isSupervisor || _congregationId == congregationId) {
      return;
    }
    _congregationId = congregationId;
    _resetPendingPagination();
    await _loadCounts();
    if (_pendingVisible) {
      await _loadPending(cursor: null);
    }
  }

  /// Reveals or hides the `Chamadas pendentes` section on the same route
  /// (`pendentes=true`, S09) and lazily loads its first page.
  Future<void> togglePending() async {
    _pendingVisible = !_pendingVisible;
    if (!_disposed) {
      notifyListeners();
    }
    if (_pendingVisible) {
      await _loadPending(cursor: null);
    }
  }

  Future<void> refreshPending() => _loadPending(cursor: null);

  Future<void> nextPendingPage() {
    final String? cursor = _nextCursor;
    if (cursor == null) {
      return Future<void>.value();
    }
    _cursorStack.add(_pendingCursor);
    return _loadPending(cursor: cursor);
  }

  Future<void> previousPendingPage() {
    if (_cursorStack.isEmpty) {
      return Future<void>.value();
    }
    return _loadPending(cursor: _cursorStack.removeLast());
  }

  /// Invalidates the counts after a relevant successful mutation (S09).
  Future<void> invalidate() async {
    _resetPendingPagination();
    await _loadCounts();
    if (_pendingVisible) {
      await _loadPending(cursor: null);
    }
  }

  Future<void> _loadCounts() async {
    final int generation = ++_countsGeneration;
    _emitCounts(const AsyncViewState<OverviewCounts>.loading());
    try {
      final OverviewCounts counts = await repository.getOverview(
        congregationId: _congregationId,
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

  Future<void> _loadPending({required String? cursor}) async {
    final int generation = ++_pendingGeneration;
    _emitPending(const AsyncViewState<List<PendingSessionEntry>>.loading());
    try {
      final PendingSessionPage page = await repository.listPendingSessions(
        congregationId: _congregationId,
        cursor: cursor,
      );
      if (_disposed || generation != _pendingGeneration) {
        return;
      }
      _pendingCursor = cursor;
      _nextCursor = page.nextCursor;
      _emitPending(
        page.items.isEmpty
            ? const AsyncViewState<List<PendingSessionEntry>>.emptyData()
            : AsyncViewState<List<PendingSessionEntry>>.data(page.items),
      );
    } catch (error) {
      if (_disposed || generation != _pendingGeneration) {
        return;
      }
      _emitPending(
        AsyncViewState<List<PendingSessionEntry>>.fromFailure(
          _failureOf(error, 'Não foi possível carregar as chamadas pendentes.'),
        ),
      );
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
    _congregationId = profile.congregationId;
    _pendingVisible = false;
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
