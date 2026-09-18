/// Class list view state: scope, status/name filters, pagination and refresh
/// (S08, S09, S10).
///
/// Staff scope is fixed to the assigned congregation; a supervisor must select
/// exactly one congregation before listing or creating classes. Older requests
/// are discarded by generation so a stale page never replaces a newer scope.
library;

import 'package:flutter/foundation.dart';

import '../../domain/access.dart';
import '../../domain/class_group.dart';
import '../../domain/congregation.dart';
import '../../domain/ports.dart';
import '../../ui/async_content.dart';
import '../auth/auth_controller.dart';
import '../congregations/congregation_repository.dart';
import 'academic_repository.dart';

class ClassController extends ChangeNotifier implements SessionScoped {
  ClassController({
    required this.repository,
    required this.profile,
    this.catalog,
  }) {
    _query = ClassQuery(congregationId: profile.congregationId);
  }

  final AcademicRepository repository;
  AccessProfile profile;

  /// Authorized congregation catalog used by a supervisor's scope selector.
  final CongregationRepository? catalog;

  late ClassQuery _query;
  AsyncViewState<List<ClassListEntry>> _state =
      const AsyncViewState<List<ClassListEntry>>.loading();
  List<Congregation> _congregations = const <Congregation>[];
  final List<String?> _cursorStack = <String?>[];
  String? _nextCursor;
  int _generation = 0;
  bool _disposed = false;

  ClassQuery get query => _query;

  AsyncViewState<List<ClassListEntry>> get state => _state;

  List<Congregation> get congregations => _congregations;

  bool get isSupervisor => profile.accessRole == AccessRole.supervisor;

  /// Staff can always create in their own congregation; a supervisor only
  /// after selecting one (S08).
  bool get canCreate => _query.congregationId != null;

  bool get hasPreviousPage => _cursorStack.isNotEmpty;

  bool get hasNextPage => _nextCursor != null;

  Future<void> refresh() async {
    await _loadCatalog();
    if (_query.congregationId == null) {
      _emit(const AsyncViewState<List<ClassListEntry>>.emptyData());
      return;
    }
    await _load(cursor: null);
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

  /// Changes the supervisor's selected congregation. Staff scope is immutable.
  Future<void> setCongregation(String? congregationId) async {
    if (!isSupervisor) {
      return;
    }
    _query = _query.copyWith(
      congregationId: congregationId,
      clearCongregation: congregationId == null,
      clearCursor: true,
    );
    _cursorStack.clear();
    _nextCursor = null;
    if (congregationId == null) {
      _emit(const AsyncViewState<List<ClassListEntry>>.emptyData());
      return;
    }
    await _load(cursor: null);
  }

  /// Applies new filters and resets pagination (S09).
  Future<void> applyQuery(ClassQuery next) {
    _query = next.copyWith(clearCursor: true);
    _cursorStack.clear();
    _nextCursor = null;
    return _load(cursor: null);
  }

  Future<void> setSearch(String search) =>
      applyQuery(_query.copyWith(search: search));

  Future<void> setStatus(ClassStatus? status) =>
      applyQuery(_query.copyWith(status: status, clearStatus: status == null));

  Future<void> nextPage() {
    final String? cursor = _nextCursor;
    if (cursor == null) {
      return Future<void>.value();
    }
    _cursorStack.add(_query.cursor);
    return _load(cursor: cursor);
  }

  Future<void> previousPage() {
    if (_cursorStack.isEmpty) {
      return Future<void>.value();
    }
    return _load(cursor: _cursorStack.removeLast());
  }

  Future<void> _load({required String? cursor}) async {
    final int generation = ++_generation;
    final ClassQuery request = _query.copyWith(
      cursor: cursor,
      clearCursor: cursor == null,
    );
    if (request.congregationId == null) {
      _emit(const AsyncViewState<List<ClassListEntry>>.emptyData());
      return;
    }
    _emit(const AsyncViewState<List<ClassListEntry>>.loading());
    try {
      final PageResult page = await repository.listClasses(request);
      if (_disposed || generation != _generation) {
        return;
      }
      _query = request;
      _nextCursor = page.nextCursor;
      final List<ClassListEntry> entries = page.items
          .map(ClassListEntry.fromJson)
          .toList(growable: false);
      _emit(
        entries.isEmpty
            ? (request.hasSearch
                  ? AsyncViewState<List<ClassListEntry>>.emptySearch(
                      query: request.search.trim(),
                    )
                  : const AsyncViewState<List<ClassListEntry>>.emptyData())
            : AsyncViewState<List<ClassListEntry>>.data(entries),
      );
    } catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _emit(
        AsyncViewState<List<ClassListEntry>>.fromFailure(_failureOf(error)),
      );
    }
  }

  AppFailure _failureOf(Object error) => error is AppFailure
      ? error
      : const AppFailure(
          code: AppFailureCode.unknown,
          message: 'Não foi possível carregar as turmas.',
        );

  void _emit(AsyncViewState<List<ClassListEntry>> next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void clearSessionData() {
    _generation++;
    _query = ClassQuery(congregationId: profile.congregationId);
    _congregations = const <Congregation>[];
    _cursorStack.clear();
    _nextCursor = null;
    _state = const AsyncViewState<List<ClassListEntry>>.loading();
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
