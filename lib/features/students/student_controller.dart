/// Student list view state: scope, filters, pagination and refresh
/// (S07, S09, S10).
///
/// Staff scope is fixed to the assigned congregation; a supervisor must select
/// exactly one congregation before creating or listing students. Older requests
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
import 'student_repository.dart';

class StudentController extends ChangeNotifier implements SessionScoped {
  StudentController({
    required this.repository,
    required this.profile,
    this.catalog,
  }) {
    _query = StudentQuery(congregationId: profile.congregationId);
  }

  final StudentRepository repository;
  AccessProfile profile;

  /// Authorized congregation catalog used by a supervisor's scope selector.
  final CongregationRepository? catalog;

  late StudentQuery _query;
  AsyncViewState<List<StudentListEntry>> _state =
      const AsyncViewState<List<StudentListEntry>>.loading();
  List<ClassGroup> _classes = const <ClassGroup>[];
  List<Congregation> _congregations = const <Congregation>[];
  final List<String?> _cursorStack = <String?>[];
  String? _nextCursor;
  int _generation = 0;
  bool _disposed = false;

  StudentQuery get query => _query;

  AsyncViewState<List<StudentListEntry>> get state => _state;

  List<ClassGroup> get classes => _classes;

  List<Congregation> get congregations => _congregations;

  bool get isSupervisor => profile.accessRole == AccessRole.supervisor;

  /// Staff can always create in their own congregation; a supervisor only
  /// after selecting one (S07).
  bool get canCreate => _query.congregationId != null;

  bool get hasPreviousPage => _cursorStack.isNotEmpty;

  bool get hasNextPage => _nextCursor != null;

  /// Reloads the catalog, the active classes and the current student page.
  Future<void> refresh() async {
    await _loadCatalog();
    if (_query.congregationId == null) {
      _emit(const AsyncViewState<List<StudentListEntry>>.emptyData());
      return;
    }
    await _loadClasses();
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

  Future<void> _loadClasses() async {
    final String? congregationId = _query.congregationId;
    if (congregationId == null) {
      _classes = const <ClassGroup>[];
      return;
    }
    try {
      _classes = await repository.listActiveClasses(
        congregationId: congregationId,
      );
    } catch (_) {
      _classes = const <ClassGroup>[];
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
      clearClass: true,
      clearCursor: true,
    );
    _classes = const <ClassGroup>[];
    _cursorStack.clear();
    _nextCursor = null;
    if (congregationId == null) {
      _emit(const AsyncViewState<List<StudentListEntry>>.emptyData());
      return;
    }
    await _loadClasses();
    await _load(cursor: null);
  }

  /// Applies new filters and resets pagination (S09).
  Future<void> applyQuery(StudentQuery next) {
    _query = next.copyWith(clearCursor: true);
    _cursorStack.clear();
    _nextCursor = null;
    return _load(cursor: null);
  }

  Future<void> setSearch(String search) =>
      applyQuery(_query.copyWith(search: search));

  Future<void> setArchived(bool archived) =>
      applyQuery(_query.copyWith(archived: archived));

  Future<void> setClassFilter(String? classId) => applyQuery(
    _query.copyWith(classId: classId, clearClass: classId == null),
  );

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
    final StudentQuery request = _query.copyWith(
      cursor: cursor,
      clearCursor: cursor == null,
    );
    if (request.congregationId == null) {
      _emit(const AsyncViewState<List<StudentListEntry>>.emptyData());
      return;
    }
    _emit(const AsyncViewState<List<StudentListEntry>>.loading());
    try {
      final PageResult page = await repository.listStudents(request);
      if (_disposed || generation != _generation) {
        return;
      }
      _query = request;
      _nextCursor = page.nextCursor;
      final List<StudentListEntry> entries = page.items
          .map(StudentListEntry.fromJson)
          .toList(growable: false);
      _emit(
        entries.isEmpty
            ? (request.hasSearch
                  ? AsyncViewState<List<StudentListEntry>>.emptySearch(
                      query: request.search.trim(),
                    )
                  : const AsyncViewState<List<StudentListEntry>>.emptyData())
            : AsyncViewState<List<StudentListEntry>>.data(entries),
      );
    } catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _emit(
        AsyncViewState<List<StudentListEntry>>.fromFailure(_failureOf(error)),
      );
    }
  }

  AppFailure _failureOf(Object error) => error is AppFailure
      ? error
      : const AppFailure(
          code: AppFailureCode.unknown,
          message: 'Não foi possível carregar os alunos.',
        );

  void _emit(AsyncViewState<List<StudentListEntry>> next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void clearSessionData() {
    _generation++;
    _query = StudentQuery(congregationId: profile.congregationId);
    _classes = const <ClassGroup>[];
    _congregations = const <Congregation>[];
    _cursorStack.clear();
    _nextCursor = null;
    _state = const AsyncViewState<List<StudentListEntry>>.loading();
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
